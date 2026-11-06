# Mission 2026-11-05-open-webui — Open WebUI on the laptop via Docker

## Objective

Verbatim (owner, 2026-11-05), abridged only where marked:

> Objective: add reproducible Docker-based Open WebUI installation and lifecycle
> management to TiPunchLabs/laptop-bootstrap.
>
> Upstream: https://github.com/open-webui/open-webui
>
> Scope: Manage Open WebUI on the laptop through the repository's existing Ansible
> and Docker conventions. DNS, Pi-hole, Caddy, TLS, and openwebui.internal belong
> to a later homelab mission and must not be modified here.
>
> […] Implementation requirements: dedicated role; official image with an explicit
> stable release tag (no main/latest); existing Docker management mechanism, no
> second competing one; data persisted independently of the container; automatic
> restart and a supported health check; host port, bind address, image version and
> Ollama endpoint configurable with documented defaults; minimum network exposure,
> explained, with the future Caddy adjustment; upstream authentication defaults
> preserved, no credentials committed; secrets, if any, follow repository
> conventions and stay out of logs and diffs; a dedicated tag that does not run
> unrelated roles or cleanup_legacy; Docker prerequisite handled explicitly; no
> automatic image updates; no Docker socket in the container.
>
> Existing installation: identify and preserve; stop only if migration could
> overwrite data or needs an unresolved structural choice.
>
> Verification: lint/syntax/pre-commit with the venv tools and dummy vault;
> deployment in an isolated environment or mission-owned VM, never the laptop;
> startup, health, HTTP, persistence across recreation, restart policy,
> idempotence; Ollama connectivity where supported, distinguishing real tests from
> configuration checks; no real owner account or personal data; Codex review via
> Herdr.
>
> Documentation: installation, URL, prerequisites, configuration, owner validation,
> updates, backup/restore, rollback limits (no "downgrade reverses migrations");
> record the future homelab integration; update BACKLOG.md and mission records.
>
> Authorization: isolated branch/worktree, scoped changes, create and remove
> mission-owned test resources, tests, commit, push, PR. No merge, nothing applied
> on the real laptop, no change to homelab, DNS, Caddy, Pi-hole, existing
> application data or unrelated resources.

## Authorizations

Default (worktree + smoke VM) plus, from the objective: create and remove
mission-owned test resources (includes destroying the mission's own VM), commit,
push, open a PR. No merge. Nothing applied on the real laptop.

## Scope

In: new role `open_webui`, its wiring (bootstrap include, tag `open-webui`, Makefile
target), README / role README / design spec, BACKLOG, mission records.
Out: homelab, DNS, Pi-hole, Caddy, TLS; the existing `brain-rag` Open WebUI data;
the laptop's Ollama configuration; the smoke harness's collection set.

## Initial state (inspected 2026-11-05, read-only)

- Main checkout: `main` at `2284c88`, clean; 2 stashes (left untouched).
  Baseline snapshot: `$E/main-tree-snap-baseline.txt` = `22cb4cf2…35d2e5`.
- Existing worktree `docs/agent-workflow-closeout` (not touched).
- Laptop Docker: server 29.9.0, user in group `docker`.
- Open WebUI on the laptop:
  - image `ghcr.io/open-webui/open-webui:main` (built 2026-06-02, revision `02dc3e6`), no container uses it;
  - volume `brain-rag_open-webui` (compose project `brain-rag`, created 2026-06-12):
    `webui.db` 606 208 B, `uploads/` empty, `cache/` + `vector_db/`, 1.0 G total;
    defined by `~/Workspace/brain-rag/docker-compose.yml` (container `brain-open-webui`,
    `3000:8080` on all interfaces, `ENABLE_OLLAMA_API=false`, OpenAI API → a local RAG server);
  - `~/Workspace/07-local/openWebUI/docker-compose.yml` (v0.8.3, `network_mode: host`):
    its volume does not exist (never started or removed).
- Ollama: host install, `/usr/local/bin/ollama` 0.12.10, systemd `ollama.service`
  (enabled, active), drop-in `OLLAMA_HOST=0.0.0.0` → listens `*:11434`.
- Target-side Python for community.docker: `python3-requests` installed; `python3-docker` absent (not needed).
- Venv: ansible-core 2.20.1, community.docker 5.0.4.

## Design decisions (routine, within the objective)

- Existing data: the `brain-rag` volume belongs to another project with a different
  purpose (RAG front-end, Ollama disabled). The role uses its own volume `open-webui`
  and container `open-webui` and never references `brain-rag_*`: nothing to migrate,
  nothing overwritten. No owner decision required.
- Mechanism: `community.docker` modules (`docker_volume`, `docker_container`) from the
  venv's `ansible` package (same collection source as `community.general` in
  syncthing; `docker` already in `pyproject.toml`). No compose file, no systemd unit.
- Image `ghcr.io/open-webui/open-webui:v0.13.0` (latest stable, 2026-11-03, security fixes).
- Exposure: `127.0.0.1:3030` → `8080`. 3000 is avoided: the `brain-rag` compose publishes `0.0.0.0:3000`.
- Ollama: host Ollama via `host.docker.internal:host-gateway` (upstream Linux method).
- Secret key: `WEBUI_SECRET_KEY_FILE=/app/backend/data/.webui_secret_key`, so the
  key `start.sh` generates lives in the volume and survives recreation. No secret in
  the repo, the vault or Ansible output.
- Docker prerequisite: meta dependency on `docker` (precedent: `vagrant` → `libvirt`).

## Acceptance criteria

Evidence files are in `$E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`.
"VM" = mission-owned Vagrant/libvirt VM (`bento/ubuntu-24.04`, `192.168.121.70`),
driven over SSH by the worktree venv's ansible-core 2.20.1 / community.docker 5.0.4
via `$E/run-vm.sh` (vault-free copy of the worktree, dummy vault password,
in-memory fact cache).

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Dedicated role `open_webui`, tag `open-webui` (task + `apply`), `make play-open-webui`; tag runs only `docker` + `open_webui` | `vm-run-1b.log`: tasks executed = bootstrap `always` facts, `docker` (+ `apt_keyring`), `open_webui`; no `cleanup_legacy`/`cli_tools` task; `make help` lists `play-open-webui` | VERIFIED |
| AC2 | Pinned stable tag `v0.13.0`; assert rejects `main` | defaults; `vm-run-assert-main.log`: `assertion … evaluated_to: false`, exit 2 | VERIFIED |
| AC3 | Data in named volume, survives recreation | `vm-persist-before/after.log`: container `5383d9624157` removed, role recreated `5bef7a46c23a`; key sha256 prefix `c654fa33c03c300c` unchanged, user row kept, pre-recreation session token → HTTP 200; `vm-upg-*`: same on a version bump | VERIFIED |
| AC4 | `unless-stopped`; health check healthy; restart after reboot | `vm-checks-1.log`: `restart=unless-stopped`, `health=healthy`, Healthcheck JSON; `vm-reboot.log`: VM up 23:56:33, container started 23:56:38, `healthy`, `/health` → `{"status":true}` | VERIFIED |
| AC5 | Port, bind, version, Ollama URL configurable; default loopback | `vm-checks-1.log`: only `127.0.0.1:3030` listening, VM LAN IP:3030 refused; `vm-upg-before.log`: overrides `192.168.121.70:3031`, name/volume `owui-upg`, `v0.12.5` honoured, reachable from the laptop; Ollama URL shown in `/ollama/config`. Ollama URL is a first-start seed only (`vm-ollama-url.log`: env changed to `:11999`, Open WebUI still uses `:11434`) — documented, not a role defect | VERIFIED (Ollama URL: install-time only, documented) |
| AC6 | Auth defaults kept; no credential committed or logged | no `WEBUI_AUTH`/`ENABLE_SIGNUP` in role; `vm-checks-2.log`: `auth: true`, first account `admin`, then `enable_signup: false`, 2nd signup 403, unauthenticated `/api/models` 401; gitleaks Passed; scripts print only key fingerprints | VERIFIED |
| AC7 | Docker prerequisite explicit; tag alone installs Docker on a clean host | `vm-run-1.log` failed on fresh VM (`python3-debian is not installed`) → fix in `docker` role; `vm-run-1b.log` installs Docker CE then Open WebUI, exit 0 | VERIFIED |
| AC8 | No socket mount, no auto-update | `vm-checks-1.log`: `docker.sock mounted: 0`, `privileged=false`; `pull: missing`; no updater container | VERIFIED |
| AC9 | Second run `changed=0` | fresh empty volume with current code: `vm-run-8-fresh-current-code.log` changed=2 → `vm-run-9-idem.log` changed=0; `vm-run-2.log`, `vm-run-3.log`, `vm-run-5-after-reboot.log`, `vm-upg-3-idem.log`, `vm-run-7-docker-and-owui.log`: `changed=0`; `vm-run-6-check.log` (`--check`) `changed=0` | VERIFIED |
| AC10 | HTTP UI served | `vm-checks-1.log`: `GET /` 200 `text/html`, `<title>Open WebUI`; `/api/config` version 0.13.0 | VERIFIED |
| AC11 | Ollama connectivity | VM: stub on `0.0.0.0:11434` (not real Ollama) — container resolves `host.docker.internal` → `172.17.0.1`, `/api/version` OK; Open WebUI `/ollama/api/version` and `/api/models` return the stub's model (`vm-checks-2.log`). Laptop: transient `alpine` container with `host-gateway` reached the real Ollama 0.12.10 and listed its models (`laptop-ollama-probe.log`). Not tested: Open WebUI against the real laptop Ollama, inference. | VERIFIED (path + integration against stub; real-Ollama-through-Open-WebUI is owner validation) |
| AC12 | Lint | `pre-commit run --files <12 files>` exit 0 (`pre-commit-1.log`), ansible-lint exit 0 (production profile), yamllint exit 0, `--syntax-check` exit 0, `bin/check_make_venv_tools.sh` exit 0 | VERIFIED |
| AC13 | Docs + BACKLOG | `roles/open_webui/README.md`, README (tag row + section + tree), CLAUDE.md map, spec, BACKLOG (5 entries). Backup → update → rollback executed as documented (`vm-rb-steps-1.log`, `vm-rb-steps-2.log`): archive mode 0600; v0.12.5 alembic `0bd252b206fb` → v0.13.0 `e42c8f710a36` → restored, back on v0.12.5 with `0bd252b206fb`, user kept, sign-in 200, healthy; `vm-rb-4-idem.log` changed=0 | VERIFIED |
| AC-SAFE | Main tree, stashes, `brain-rag` data, laptop untouched; no secret read; hooks not bypassed | main snapshot `22cb4cf2…35d2e5` = baseline; stash list = baseline; `brain-rag_open-webui` CreatedAt/webui.db mtime unchanged; no open-webui/owui container or volume on the laptop; dummy vault only; hooks never skipped | VERIFIED |

## Plan

1. Role `open_webui` (defaults, tasks, meta, README) + bootstrap include + Makefile + README + spec.
2. Lint with venv tools and dummy vault.
3. VM: mission-owned smoke VM (`vagrant up --no-provision` from the worktree), playbook
   from a vault-free copy of the worktree, run with the venv's Ansible over SSH
   (VM's apt ansible-core has no community.* collections).
4. Functional checks (AC3–AC11), then destroy the VM.
5. Codex review via Herdr, fixes, report, BACKLOG, commit, push, PR, CI.

## State

- Phase: report
- Branch / worktree: `feat/open-webui` / `../laptop-bootstrap-worktrees/open-webui`
- Base commit: `2284c88`
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`
- Reviewer: herdr agent lb-review (Codex), pane `w1Q:pF` (created by this mission)
- Review cycle: 2 of 3
- Next step: commit, push, PR, CI (authorized)

## Log

- 2026-11-05 inspect: initial state recorded; worktree created from `origin/main`.
- 2026-11-05 inspect: deviation — `pre-commit install` run in the worktree rewrote the
  shared `.git/hooks/{pre-commit,pre-push}` `INSTALL_PYTHON` to the worktree venv;
  restored immediately by `pre-commit install` from the main checkout (both now point
  at `laptop-bootstrap/.venv/bin/python`). No file in the main tree changed.
- 2026-11-05 implement: role, wiring, docs; `docker` role gains `python3-debian` (fresh-VM failure, `vm-run-1.log`).
- 2026-11-05 verify: VM created (`vagrant up --no-provision` from the worktree's `test/smoke`). Host incident: libvirt dnsmasq for `vagrant-libvirt` (`192.168.121.1:53`) stopped answering mid-mission (not caused by the mission, not repaired: host resource). Workaround inside the VM only: resolved drop-in `DNS=1.1.1.1 9.9.9.9`.
- 2026-11-05 verify: wait loop replaced by `docker_container state: healthy` (native in community.docker 5.0.4); runs 2+ re-done after the change.
- 2026-11-05 verify: limitation — with `docker` and `open-webui` both selected (and in a full run), the `docker` role runs twice (`include_role` + meta dependency); idempotent, `changed=0` (`vm-run-7`). Same as `vagrant`→`libvirt`.
- 2026-11-05 verify: limitation — the version assert runs after the `docker` dependency (meta dependencies run first).
- 2026-11-05 verify: fresh empty volume re-run with the current code (`vm-run-8`, changed=2; `vm-run-9`, changed=0).
- 2026-11-05 review-1: Codex PASS_WITH_RESERVATIONS, F1.1 [minor] rollback/restore ordering.
- 2026-11-05 fix-1: F1.1 fixed (README rollback steps; restore without start). Also: backup archive `umask 077`, helper image `alpine:3`, restore mount `:ro`.
- 2026-11-05 fix-1: Codex "not checked" items executed: backup → update → rollback round trip (`vm-rb-*`), Ollama URL change on an initialized volume (`vm-ollama-url.log`) → found that `OLLAMA_BASE_URL` only seeds the first start; documented in role README, defaults, spec.
- 2026-11-05 fix-1: `vm-run-10-final-tree.log` changed=0; the five tested role/wiring files are byte-identical to the worktree.
- 2026-11-05 review-2: Codex PASS, no findings.
- 2026-11-05 cleanup: Codex pane `w1Q:pF` closed; mission VM destroyed (`vagrant destroy -f`, exit 0; authorized: mission-owned test resource).
- 2026-11-05 report: `report.md` written; AC-SAFE verified.
