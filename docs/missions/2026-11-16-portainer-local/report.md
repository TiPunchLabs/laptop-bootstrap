# Report — 2026-11-16-portainer-local, step S1 (executor)

## Verdict

PARTIAL. Step S1 is complete within its scope. Several mission criteria wait, by
design, on later steps:

- LAN exposure of the laptop (AC2 and AC3 on the laptop, AC4 admin) waits for D1.
- Independent review: S2.
- HomeLab DNS and Caddy: S3 (AC6) and S4 (AC7).

Version: a61f35f7f71deadf9b97497ceecb0cfa3f05ceb3. This is the code commit that was
tested on the VM and applied on the laptop. The commit that adds this report
changes documentation only.

## Summary

- New role `portainer` runs `portainer/portainer-ce:2.45.3` (CE LTS, latest
  patch of the 2.45 LTS line). It uses the named volume `portainer_data`, restart
  policy `unless-stopped` and the `--http-disabled` flag. It publishes HTTPS on
  `127.0.0.1:9443` by default, under its own tag `portainer` (`make play-portainer`).
- A non-loopback bind is refused unless the running instance already has an
  admin (`GET /api/users/admin/check` must answer 204). After that check, the role
  installs a DOCKER-USER filter.
- The Open WebUI filter (tasks and templates) moved into a shared internal role,
  `docker_port_filter`. Both roles import it with `tasks_from: present|absent`.
  For Open WebUI's values, the rendered script and unit are byte-identical to the
  files on the laptop. On the VM, the branch reports `changed=0` against a main-built
  Open WebUI and leaves its rules identical.
- Laptop: applied with `--tags portainer`, loopback only. The first run reported
  `changed=2` and the second `changed=0`. No admin has been created yet and nothing
  is exposed to the LAN.

## Initial state

- Worktree `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/portainer`,
  branch `feat/portainer-local` from `origin/main` 0b892c6. The upstream was unset
  per agent-workflow §3. `uv sync --frozen --python 3.12` was used because the
  default picked 3.15, where `rpds-py` fails to build (known BACKLOG item).
- Main checkout on `feat/mise-act-pinact`, clean. Snapshot baseline
  `6c87c520…056a8`, unchanged at the end (`main-tree-snap-final.log`).
- Laptop baseline (`laptop-baseline.log`): no Portainer container, volume or
  image. DOCKER-USER held only the Open WebUI hook. Docker firewall backend is
  `iptables`. Port 9443 was free; ports 9000 and 9001 were in use on 127.0.0.1 by
  non-Docker processes.

## Work performed

Commits (local, not pushed):

- a5676d9 `docs(missions): add portainer-local mission brief` (mission.md, first as required)
- 86affeb `feat(portainer): run Portainer CE LTS on the laptop behind a shared port filter`
- a61f35f `fix(portainer): skip the API wait under --check`

Files:

- Created `roles/portainer/{README.md,defaults,meta,tasks,vars}/…`.
- Created `roles/docker_port_filter/{README.md,defaults,meta}/…`, plus
  `tasks/main.yml`, which only refuses a direct call.
- Moved, then parameterized:
  - `roles/open_webui/tasks/firewall.yml` → `roles/docker_port_filter/tasks/present.yml`
  - `firewall_absent.yml` → `tasks/absent.yml`
  - `templates/open-webui-firewall.{sh,service}.j2` → `roles/docker_port_filter/templates/firewall.{sh,service}.j2`
- Modified:
  - `roles/open_webui/tasks/main.yml`: `import_role` of the shared filter with the same values.
  - `roles/open_webui/vars/main.yml`: only `open_webui_lan_exposed` remains; the
    chain, unit and script names moved to the filter role's derived defaults.
  - `roles/open_webui/README.md`: pointer to the shared role.
  - `roles/bootstrap/tasks/main.yml`: `include_role portainer`, tag both on the
    task and under `apply:`.
  - `Makefile`: `play-portainer`.
  - `README.md`: tree, tag row, Portainer section.
  - `CLAUDE.md`: role map.
  - `BACKLOG.md`: in-progress entry, and the `ansible-docker-apps` entry now
    states the container-name conflict.
  - `group_vars/all/vars.yml`: commented Portainer LAN block, pending D1.

## Design choices (mission items 1–5)

- Version: Docker Hub tags `lts`, `sts`, `latest` and `2.45.3` share index digest
  `sha256:3609c307…e96e`. GitHub releases list 2.45.3 as "LTS", the newest, dated
  2026-10-21. The docs pages say `lts`; the role pins `2.45.3` and asserts `X.Y.Z`.
  context7 timed out twice. The official docs and Docker Hub were read instead,
  through a delegated fetch agent (see Delegations).
- Protocol for Caddy (item 3): HTTPS to 9443. HTTP 9000 is documented upstream
  as "for legacy reasons" and would carry the admin password and the session token
  in clear over the Wi-Fi LAN. That token is root-equivalent through the Docker
  socket. The trade-off is that Caddy must accept a self-signed certificate:
  `tls_insecure_skip_verify` is justified, or pinning with `tls_trusted_ca_certs`.
  This goes into the S3 brief. 9000 is disabled, and 8000 (Edge tunnel, optional
  per the docs) is not published.
- Socket (item 4): the mounts are exactly the documented two, `/var/run/docker.sock`
  (bind) and the volume on `/data`. Verified with `docker inspect` on the VM and
  on the laptop. The risk and its mitigations are in `roles/portainer/README.md`.
- Health check (item 1): the image has no shell, curl or wget. On the VM,
  `docker exec … sh` returns "executable file not found". The image config has
  `Healthcheck: null` and entrypoint `/portainer`, so a Docker HEALTHCHECK cannot
  be defined. The role waits from the host on `GET /api/system/status` until it
  answers 200, then asserts `Version == portainer_version`. As a consequence,
  `docker ps` shows no `(healthy)` for Portainer. The reviewer should judge
  whether this meets "a supported health check".
- Restart policy: `unless-stopped`, not upstream's `always`, consistent with
  `open_webui`. The filter's "stop before a port change" step relies on a stopped
  container staying stopped.
- Filter reuse (item 2): rather than a second copy, the existing mechanism moved
  into `docker_port_filter`. It keeps one chain, unit and script per caller
  (`PORTAINER-INGRESS`, `portainer-firewall.service`,
  `/usr/local/sbin/portainer-firewall`). Each chain returns everything except its
  own mapping, so the two filters do not interact.
- Admin (item 5): the guard makes the order mandatory under either D1 option.
  Since 2.39.4/2.43, Portainer also requires a one-time setup token from the log
  before admin init. On the VM, an init without it returned 403 "Invalid or
  missing setup token". This is a second barrier, not a replacement for the guard.

## Verification and evidence

Evidence directory: `E=~/.local/share/laptop-bootstrap-agent/2026-11-16-portainer-local/`.
VM runs use the worktree venv's Ansible over SSH (`E/run-vm.sh`, `E/run-vm-main.sh`
for the origin/main tree), like the earlier Open WebUI missions. `make smoke-up`
installed Docker but then failed, as expected, on the VM's distro
`community.docker` (`pull: missing`, BACKLOG item "Smoke VM cannot run roles that
use community.*"). This happens on `main` too (`E/smoke-up.log`).

### Lint and static checks

| Check | Result |
|---|---|
| `uv run --no-sync .venv/bin/ansible-lint` (dummy vault) | exit 0, 0 failures, 0 warnings, production profile (`E/lint-3.log`) |
| `.venv/bin/yamllint .` | exit 0 |
| `ansible-playbook playbook.yml --syntax-check` | exit 0 |
| `pre-commit run --files <staged files>` (incl. gitleaks) | exit 0 (`E/pre-commit-2.log`); the hooks also ran on each commit |

### Acceptance criteria

| ID | Status | Evidence |
|---|---|---|
| AC1 | VERIFIED (VM + laptop, loopback) | VM `vm-10` changed=2 → `vm-11` changed=0; laptop `laptop-02-apply.log` ok=27 changed=2 → `laptop-03-idem.log` changed=0. Only `docker` + `portainer` + the two `always` facts ran (task list in `vm-10`). Image `portainer/portainer-ce:2.45.3`, volume `portainer_data`, `unless-stopped`. Health: host-side API wait (see Design choices) |
| AC2 | VM VERIFIED; laptop loopback VERIFIED; laptop LAN NOT_VERIFIED (D1 pending) | VM `vm-checks-S3.log` + `vm-checks-S3-counters.log`: allowed host → 200, a container on another Docker network → 000 (PORTAINER DROP 5 pkts), 9000/8000 → 000, `ip6tables DOCKER-USER` empty. VM `vm-checks-S5.log`: after a source change the host gets 000 while Open WebUI still answers it 200. Laptop `laptop-after-apply.log`: `127.0.0.1:9443` only, no IPv6 listener, `docker port` → `127.0.0.1:9443` |
| AC3 | VM VERIFIED; laptop: Open WebUI unchanged VERIFIED, Portainer filter lifecycle NOT_APPLICABLE until exposure | VM: before exposure, the refused run made no change (`vm-12`, `vm-checks-S2`). Docker restart: both units re-ran before dockerd (`vm-docker-restart.log`). VM reboot: both units finished before docker.service (`vm-reboot.log`). Disable: unit, script, hook and chain removed, docker `Requires` no longer lists portainer-firewall, rerun changed=0 (`vm-16`, `vm-17`, `vm-checks-S6`). Open WebUI sentinel: script/unit hashes and rules identical to the main-built baseline after the branch run, after exposure and after disable (`vm-owui-files-main.txt` vs `vm-owui-files-branch.txt`, `vm-owui-S3.txt`, `vm-owui-S6.txt`). Laptop: DOCKER-USER and OPEN-WEBUI-INGRESS identical before/after, hashes `ab2e1a0b…` / `e835d061…` unchanged. The templates render byte-identical to those laptop files (`E/render/`) |
| AC4 | Guard VERIFIED (VM); laptop admin NOT_VERIFIED (D1) | VM: LAN request with no admin → fatal "has no admin account yet (… HTTP 404)", changed=0, no unit/chain (`vm-12`). After admin creation (204) exposure succeeds (`vm-13`). Port change while exposed → refused, nothing changed (`vm-19`). Admin persists across container recreation (`vm-admin-persist.log`). No secret in repo or diffs (gitleaks pass). The setup token is redacted in every evidence log. The VM throwaway admin password was generated inside the VM (`/root/pt-admin-pass`) and never printed |
| AC5 | VERIFIED | Mounts exactly `portainer_data:/data` and `/var/run/docker.sock` (bind), on VM and laptop. Args `["--http-disabled"]`. Risk section in `roles/portainer/README.md` |
| AC6 | NOT_APPLICABLE (S3) | — |
| AC7 | NOT_APPLICABLE (S4) | — |
| AC8 | VERIFIED | `open-webui` id `96ee79d99b4e…`, StartedAt `2026-11-15T14:37:36Z`, restarts 0, healthy, `/health` 200, same before and after. Ollama not touched. `byenvini-dev-pg`, `mailpit`, `localstack`, `github-action-labs-lab-1` unchanged. See the litellm note under Deviations |
| AC-SAFE | VERIFIED | No merge, no push, no laptop reboot (only the disposable VM was rebooted). Old backup untouched (sha256 `c83a88e9…2181`). Main snapshot unchanged. No `pass`/vault access (dummy password file; the laptop run used an exported tree without the vault directory). Hooks not bypassed |

### Laptop apply: exact command

```bash
# E/run-laptop.sh laptop-02-apply.log, which runs:
cd "$E/tree-laptop-a61f35f"      # git archive a61f35f, vault directory excluded
ANSIBLE_VAULT_PASSWORD_FILE=~/.local/share/laptop-bootstrap-agent/dummy-vault-pass \
  /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/portainer/.venv/bin/ansible-playbook \
  -i inventory.yml playbook.yml --tags portainer
```

It was preceded by `--check` (`laptop-01-check.log`), which predicted changes only
on "Create the Portainer data volume" and "Run the Portainer container".
Equivalent owner command: `make play-portainer` from the worktree. sudo was
available non-interactively; no vault value was needed for this tag.

## Deviations, risks and limitations

- The first laptop `--check` (`laptop-00-check.log`, commit 86affeb) failed in
  the API wait, because check mode creates no container. This was fixed in
  a61f35f and re-verified on the VM (`vm-22`, `vm-23`) and on the laptop
  (`laptop-01-check.log`). Nothing was changed by the failed check.
- The laptop was applied from an exported tree rather than `make play-portainer`
  in the worktree. Reason: no vault access, and the tag uses no vault variable.
  The code is identical to a61f35f.
- Laptop setup window: the container started at 16:20:57Z without an admin.
  Portainer stops its setup service after 5 minutes. Before creating the admin,
  run `docker restart portainer` (another 5 minutes), then take the token with
  `docker logs portainer 2>&1 | grep -o 'setup_token=[^ ]*'`.
- Observed drift (not caused or changed by this mission): the live `open-webui`
  container is published on `192.168.10.217:3030`, while the repo and the
  installed filter script say `0.0.0.0:3030`. The next `make play-open-webui`
  would recreate it on `0.0.0.0`.
- Unrelated laptop activity during the mission:
  - The `litellm` compose project's containers were recreated at 16:07:39Z.
  - An unused anonymous volume `f19f4815…` was created at 16:06:49Z.
  - Both predate the first laptop Docker change of this mission (16:20:57Z) and
    were not touched.
- `make smoke-up` failed on the VM's old `community.docker`. This is pre-existing,
  in the BACKLOG and unchanged.
- The filter trusts source addresses (spoofing `192.168.10.70`), as for Open WebUI.
- The Portainer UI can modify containers managed by this repository; the README
  warns against it.
- Not executed: a laptop reboot (not authorized); a laptop Docker restart (not
  needed while Portainer has no filter); the laptop LAN matrix (D1).
- Smoke VM left running (no `smoke-down`, which needs approval). Its state:
  Portainer on loopback with a test admin, and the Open WebUI sentinel exposed to
  192.168.121.1.

## Delegations (model economy, A3)

- `web-fetch` agent on haiku, two prompts:
  - Portainer install page, CLI flags, release notes, setup-token and timeout
    FAQs, GitHub releases, Docker Hub tags API, Dockerfile.
  - Its output was cross-checked against the running image on the VM: version,
    endpoints, no shell, no HEALTHCHECK, setup token.
- Everything else (code, VM and laptop runs, evidence) was done in this session.
  The checks were sequential and state-dependent, so a delegation would have cost
  more than it saved.

## Decisions required

- D1 (admin bootstrap), still open. Facts that bear on it:
  - From the CLI docs: `--admin-password` takes a bcrypt hash. Passed as a
    container argument, it is readable in `docker inspect`.
  - `--admin-password-file` takes a plaintext password file. The mission's
    recommendation wording ("bcrypt hash … with `--admin-password-file`") mixes
    the two.
  - Both apply only when the admin is first created.
  - The recommended option needs a role change: a vault-backed variable, plus the
    guard accepting a run where the admin is created at container start. It also
    needs the owner's `ansible-vault edit`.
  - The alternative needs no code change. The owner creates the admin on
    `https://127.0.0.1:9443` with the setup token, then uncomments the two lines
    in `group_vars/all/vars.yml` and runs `make play-portainer`.
- The S3 brief should carry the protocol choice: upstream
  `https://192.168.10.217:9443` with `tls_insecure_skip_verify` (or a pinned
  certificate), as justified above.

## Recommended next action

- Pilot: record D1 in mission.md and dispatch the S2 review of a5676d9..HEAD.
  The report commit follows a61f35f.
- After D1 (alternative), the owner runs:
  1. `docker restart portainer`
  2. create the admin at `https://127.0.0.1:9443`, using
     `docker logs portainer 2>&1 | grep -o 'setup_token=[^ ]*'`
  3. uncomment `portainer_bind_address` and `portainer_allowed_sources` in
     `group_vars/all/vars.yml`
  4. `make play-portainer` twice (the second run should report `changed=0`)
  5. the AC2/AC3 laptop matrix
- Nothing was pushed; push and PR wait for the pilot.
