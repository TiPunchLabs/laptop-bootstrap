# Report — 2026-11-16-portainer-local, step S1 (executor), updated for D1 and review 1

## Verdict

PARTIAL. S1 is complete, including the D1 implementation, which was tested on the
VM. The remaining criteria wait on other actors:

- Laptop LAN exposure and admin (AC2/AC3/AC4 on the laptop): the owner's vault
  edit and apply, see `owner-commands-d1.md`.
- Independent review: S2, cycle 1 answered below (review 2 pending).
- HomeLab DNS and Caddy: S3 (AC6) and S4 (AC7).

Version: 21b839f4c8548dcbaa067265b8bfda2d3511ee27. This is the current code commit,
tested on the VM. The laptop runs a61f35f (S1, loopback only). Commits after
a61f35f have only been run on the laptop in `--check` mode without the vault,
refused as designed with no change (`laptop-10-check-nohash.log` for 5de0c8a,
`laptop-20-check-nohash.log` for 21b839f). The commit that adds this update
changes documentation only.

## Merge (owner decision MERGE, 2026-11-20)

Owner decision, relayed by the pilot: « Pousser + PR + fusion (Recommandé) ».

- Pre-merge commits on `feat/portainer-local`, hooks passed (dummy vault password):
  - 4b968a2 `docs(missions)`: review-2.md (Codex, PASS_WITH_RESERVATIONS on
    21b839f, F1.1 and F1.2 fixed), review-brief-2.md, report-s3-homelab.md
    (homelab MR !108), mission.md D2 record.
  - 16cdf40 `chore(vault)`: the owner's encrypted vault edit from
    owner-commands-d1.md step 2 (adds `vault_portainer_admin_password_hash`).
    Still `$ANSIBLE_VAULT` encrypted, check-ansible-vault hook passed. The agent
    did not read its content.
- Remote `origin` = `git@github-xgueret:TiPunchLabs/laptop-bootstrap.git`
  (`ssh -T` -> `Hi xgueret!`).
- PR: https://github.com/TiPunchLabs/laptop-bootstrap/pull/69 (head 16cdf40).
- CI: run 44820853771, jobs lint and terraform, success
  (https://github.com/TiPunchLabs/laptop-bootstrap/actions/runs/44820853771).
  No CI fix was needed. CI is not a laptop proof.
- Merge: merge commit f8299e94c401f15bcc529f93972b84045af25321, 2026-11-20T21:31:30Z;
  branch `feat/portainer-local` kept. Local `main` fast-forwarded 019c7fa ->
  f8299e9 with `git fetch origin main:main` (no working tree touched).
- No playbook was run for this step. This commit, which records the merge, is
  on `feat/portainer-local` only, after the merge.

## Review 1 (Codex, CHANGES_REQUESTED on 2962443) and resolution

Fix commit: 21b839f `fix(portainer): bootstrap the admin with a one-shot container
(review 1)`. Evidence: `E/r1-*.log` (VM runs), `E/poll-*.txt` (statuses seen by an
allowed LAN client during each run). Scenarios ran through `E/scenario.sh`.

### F1.1 [major] The pre-exposure check trusted the running instance, not the volume to be mounted

Fixed.

- `roles/portainer/tasks/admin.yml` runs before the volume, the filter and the
  container are touched.
- "Admin ready" now requires the running `portainer` container to mount
  `portainer_volume_name` on `/data` **and** answer 204 on
  `/api/users/admin/check` at its bridge address. That address is independent of
  the published bind and port.
- Otherwise:
  - with a hash, a one-shot bootstrap container creates the admin on that exact
    volume first;
  - without a hash, LAN exposure is refused.
- Volume creation moved after this step, so a refusal changes nothing.

VM evidence, with a poller on the host as an allowed LAN client every 0.2 s:

| Scenario | Result |
|---|---|
| Initialized instance, `portainer_volume_name` → new volume, no hash, LAN (`r1-f11a2-*`) | Refused, changed=0, new volume not created; poller 61 × 204 (the untouched old instance), 0 × 404 |
| Same with hash (`r1-f11b2-*`) | Old container stopped → bootstrap on the new volume → `portainer` recreated on `pt_fresh2`; poller 31 × 000 (port closed) then 67 × 204, **0 × 404**; login with the hash password 200; no setup token; rerun changed=0 |
| Fresh install, hash, LAN, `-vvv` (`r1-fresh-hash-lan-vvv`) | changed=3; 0 × 404; login 200; Args `["--http-disabled"]` |
| Laptop-like: loopback instance without admin, then the owner sequence (`r1-ll2-*`) | `--check` changed=4 with no state change; apply `-vvv` changed=9 with 0 × 404; rerun changed=0; steady `--check` changed=0 |
| Emergency `docker stop`, rerun with hash (`r1-stopped-hash`) | Bootstrap on the volume that already has an admin (Portainer skips the flag), then started; 0 × 404 |
| Emergency `docker stop`, rerun without hash (`r1-stopped-nohash`) | Refused, changed=0, stays stopped |

Defect found and fixed during these tests: the first F1.1-b run (`r1-f11b-*`)
left the bootstrap container running.

- Cause: a block's `when` is re-evaluated for its `always` tasks. The block set
  `portainer_admin_ready`, which made its own condition false, so the removal was
  skipped.
- Effect: the real container crash-looped on the BoltDB lock and served nothing
  (poller: only 000, no 404).
- Fix: the decision is frozen in `portainer_bootstrap_needed` before the block.
  Verified by the `r1-f11b2-*` replay.

### F1.2 [major] Secret material could reach output (conditional no_log, hash in Args)

Fixed by design, as reconsidered at the pilot's request.

- Portainer 2.45.3 has no file mechanism for a hash: `--admin-password-file`
  reads plaintext, and Docker secrets need Swarm. So the hash is never given to
  the long-running container. Only the unpublished, short-lived
  `portainer-bootstrap` container gets `--admin-password`, and it is removed in an
  `always` section.
- `no_log: true` is unconditional on every task that sees the hash or container
  facts:
  - bootstrap start, bootstrap info and bootstrap removal;
  - the current-container probe;
  - "Run the Portainer container";
  - the filter's container probe.
- Upgrade path: a container made by 5de0c8a/2962443 (hash in Args) is recreated
  with `--http-disabled` only.

VM evidence:

- Reviewer's transition: hash present → hash empty, `--check -vvv` against a
  container that still had the hash in Args (`r1-f12a-*`, then `r1-f12b-*` with the
  hash set). Both changed=2 (preview), 0 occurrences of the hash or its salt.
- Real upgrade run `-vvv` with the hash empty (`r1-f12c-*`): Args became
  `["--http-disabled"]`, `Config.Cmd` has no admin flag, no bootstrap container
  left.
- After all scenarios, `docker inspect` of every container on the VM:
  0 bcrypt strings, 0 `admin-password`.
- Scan of 24 `E/r1-*.log` files (several at `-vvv`, plus `--check`): 0 full hash,
  0 salt, 0 strings matching the bcrypt pattern.
- Malformed hash (`r1-badhash`): refused, value not echoed.
- The README's secrecy statements were rewritten for this design and now cover
  every variable state.

### Minor findings

None were listed in review 1. Reservations noted by the reviewer:

- Open WebUI's check-mode unit skip is intentional.
- No password file is used.
- The laptop D1 apply is pending.

These are unchanged. Open WebUI was rechecked on the VM from this branch:
changed=0, script, unit and rules identical to the main-built baseline
(`vm-owui-R1.txt`).

### Laptop (read-only)

- `--check` of 21b839f without the vault: refused at "Refuse LAN exposure without
  a proven admin account", changed=0. Still `127.0.0.1:9443`; DOCKER-USER holds
  only the Open WebUI hook; no bootstrap container (`laptop-20-check-nohash.log`).
- The bridge-address probe works on the laptop: `https://172.17.0.4:9443` answered
  303, the timed-out setup state (`laptop-bridge-probe.log`).
- The owner procedure keeps the same steps; its expected recaps and checks are
  updated in `owner-commands-d1.md`.

## Update for D1 (admin from a vault bcrypt hash)

Owner decision, recorded in mission.md: « Hash dans Vault ». Commits:

- 5de0c8a `feat(portainer): create the admin from a vault bcrypt hash (D1)`
- 2962443 `fix(docker_port_filter): let --check preview a first exposure`

### Implementation

- Variable `portainer_admin_password_hash`:
  - role default `""`;
  - on this laptop, an alias in `group_vars/all/vars.yml` of
    `vault_portainer_admin_password_hash` (encrypted `group_vars/all/vault/main.yml`,
    with `| default('')`, the repository's public-alias convention).
- Flag `--admin-password <bcrypt hash>`, not `--admin-password-file`. Per the
  pinned version's CLI docs, `--admin-password-file` reads a plaintext password
  from a file, which would put the password itself on disk. `--admin-password` is
  the documented flag for a bcrypt hash, so no file and no file mode are involved.
  - Superseded by review 1: the hash no longer sits in the long-running
    container's Args; only the one-shot bootstrap container gets it (see Review 1).
- No leak through Ansible:
  - "Run the Portainer container" is `no_log` when a hash is set;
  - the filter's `docker_container_info` probe is `no_log` for Portainer, via the
    new parameter `docker_port_filter_container_info_no_log`, default false;
    Open WebUI is unchanged;
  - the format assert (`^[$]2[aby][$][0-9]{2}[$][./A-Za-z0-9]{53}$`) does not echo
    the value.
- Guards:
  - Before exposure: the existing admin check is kept and now also passes when a
    hash is set.
  - New, after the container starts: when exposed, the role checks
    `admin/check` again; anything but 204 makes it `docker stop` the container and
    fail the run.
- `group_vars/all/vars.yml` now publishes `0.0.0.0:9443` for `192.168.10.70`.
  Without the vault hash the run is refused before any change; this was proven on
  the laptop in `--check` mode (`laptop-10-check-nohash.log`).
- Found while replaying the owner's sequence: under `--check`, "Enable the LAN
  filter unit" failed on a first exposure because the unit file is not written in
  check mode. This came from the original open_webui code. Fix: skip that task in
  check mode when the unit file would change (2962443). Real runs are unchanged;
  Open WebUI from the branch still reports `changed=0` with identical files and
  rules (`vm-owui-S10.txt`).

### VM tests with a throwaway hash

The password was generated in the VM and the hash made with `htpasswd -niBC 10`
(stdin). Ansible received it through a 0600 vars file (`E/vm-throwaway/`), never on
a command line.

| Case | Result | Evidence |
|---|---|---|
| Existing instance with an admin + hash + LAN | Container recreated (Args changed). Portainer log: "instance already has an administrator user defined, skipping admin password related flags". Old password login 200, hash password 422 | `vm-30-*` |
| Fresh volume + hash + LAN, one run | changed=2. Log "created admin user with the given password" before "starting HTTPS server"; no setup token; admin_check 204; login 200 | `vm-31-*` |
| Rerun with `-v` | changed=0 | `vm-32-*` |
| Laptop-like: loopback instance without admin, then hash + LAN | Container recreated, admin created at start, 204, login 200 | `vm-33-*`, `vm-34-*` (run with `-vvv`) |
| `--check --diff` with hash | changed=0, no value printed | `vm-35-*` |
| Malformed hash | Refused by the format assert, changed=0, value not echoed | `vm-36-*` |
| group_vars LAN, no hash, no admin | Refused before any change, still 127.0.0.1, no unit or chain | `vm-37-*`, `vm-38-*` |
| group_vars LAN + hash | Filter for 192.168.10.70, `0.0.0.0:9443`, 204; rerun changed=0 | `vm-39-*`, `vm-40-*` |
| Owner sequence: `--check` → apply → rerun → `--check` | changed=3 (script, unit, container), no state change → changed=6 → 0 → 0 | `vm-45-*` to `vm-49-*` |
| Hash leak scan | 0 occurrences of the hash or its salt across `vm-30`…`vm-49` logs | grep in session |

Not verified: the stop-on-no-admin branch of the post-start check. It would need
a Portainer that ignores `--admin-password` on a database without an admin, which
could not be reproduced. The branch is a plain `docker stop` plus an assert.

### Laptop

- No apply of the D1 code (vault needed).
- `--check` run of 5de0c8a without the vault: refused at "Refuse LAN exposure
  without an admin account", changed=0 (`laptop-10-check-nohash.log`).
- The current instance answers `admin/check` with HTTP 303: setup timed out, no
  admin. Harmless: with the hash, the container is recreated and the admin is
  created at start (same as the laptop-like VM case).
- State after S1 and D1 work (`laptop-state-d1.log`):
  - Portainer on `127.0.0.1:9443`;
  - DOCKER-USER holds only the Open WebUI hook;
  - Open WebUI files and container unchanged;
  - backup unchanged;
  - main checkout snapshot unchanged (`main-tree-snap-final-2.log`).

### Owner commands

`~/.local/share/laptop-bootstrap-agent/2026-11-16-portainer-local/owner-commands-d1.md`
(copy: `owner-commands-d1.md` in this mission directory). It covers:

1. Hash generation with `htpasswd -nBC 12 ''` (no echo, no argument, into a 0600
   file under `$XDG_RUNTIME_DIR`).
2. `make vault-edit` with `:r`, then `shred -u`.
3. `--check` preview, then `make play-portainer` twice.
4. The checks to report back: recap lines, status codes, rule listings, counters,
   hashes, Caddy/dns-71 matrix, and "login OK" only. It never asks for the
   password, the hash or `docker inspect portainer`.

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
| AC4 | D1 implementation and guards VERIFIED (VM, see Update for D1); laptop admin NOT_VERIFIED (owner apply pending) | VM: LAN request with no admin → fatal "has no admin account yet (… HTTP 404)", changed=0, no unit/chain (`vm-12`). After admin creation (204) exposure succeeds (`vm-13`). Port change while exposed → refused, nothing changed (`vm-19`). Admin persists across container recreation (`vm-admin-persist.log`). No secret in repo or diffs (gitleaks pass). The setup token is redacted in every evidence log. The VM throwaway admin password was generated inside the VM (`/root/pt-admin-pass`) and never printed |
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

- D1: recorded and implemented (see Update for D1). Remaining owner action: the
  vault edit and laptop apply in `owner-commands-d1.md`.
- Vault commit: the owner's `make vault-edit` modifies the encrypted
  `group_vars/all/vault/main.yml` in this worktree. The pilot decides whether it
  is committed on `feat/portainer-local`. Without that commit, `main` after merge
  would lack the hash, and the next run would refuse LAN exposure on a fresh
  install. An existing admin is unaffected.
- The S3 brief should carry the protocol choice: upstream
  `https://192.168.10.217:9443` with `tls_insecure_skip_verify` (or a pinned
  certificate), as justified above.

## Recommended next action

- Pilot: dispatch review 2 on 21b839f; this report answers F1.1 and F1.2. Then
  hand the owner `owner-commands-d1.md` (updated for 21b839f) and collect the
  reported outputs.
- Superseded: pushed, PR #69 merged as f8299e9 (see Merge).
