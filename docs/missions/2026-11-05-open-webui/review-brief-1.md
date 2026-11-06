# Review brief 1 — 2026-11-05-open-webui

## Mission

- Id: `2026-11-05-open-webui`. Objective (verbatim, abridged where marked) and
  authorizations: `docs/missions/2026-11-05-open-webui/mission.md` → Objective.
  In short: add reproducible Docker-based Open WebUI installation and lifecycle
  management (dedicated role, pinned stable official image, existing Docker
  mechanism, persistent data, restart + health check, configurable port / bind /
  version / Ollama URL, minimum exposure, upstream auth defaults, no committed
  credential, dedicated tag without unrelated roles or `cleanup_legacy`, explicit
  Docker prerequisite, no auto-update, no Docker socket). No homelab/DNS/Caddy work.
- Base commit: `2284c88` (`origin/main`). Branch: `feat/open-webui`.
  Worktree: `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui`.
- All changes are staged, nothing committed: review with `git diff --cached`
  (plus `git diff` for anything unstaged; there should be none except this
  brief's sibling `review-1.md`).

## Files

```
 BACKLOG.md                                                   |  33 +++
 CLAUDE.md                                                    |   6 +-
 Makefile                                                     |   4 +-
 README.md                                                    |   6 +
 docs/missions/2026-11-05-open-webui/mission.md               | new
 docs/missions/2026-11-05-open-webui/review-brief-1.md        | new (this file)
 docs/superpowers/specs/2026-11-05-open-webui-role-design.md  | new
 roles/bootstrap/tasks/main.yml                               |   9 +
 roles/docker/tasks/install_docker_docker_compose_plugin.yml  |   1 +
 roles/open_webui/{README.md,defaults,meta,tasks}/main.yml    | new
```

## Acceptance criteria and evidence

The AC table with Claude Code's statuses and evidence references is in
`mission.md` → Acceptance criteria. Raw evidence (logs, the VM runner and the
check scripts) is outside the repository, readable:
`/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`:

- `run-vm.sh`, `inventory-vm.yml` — how the VM runs were driven.
- `vm-run-1.log` (fresh VM, failed on `python3-debian`), `vm-run-1b.log` (fresh
  install, green), `vm-run-2.log`, `vm-run-3.log` (idempotence),
  `vm-run-assert-main.log`, `vm-run-4-recreate.log`, `vm-run-5-after-reboot.log`,
  `vm-run-6-check.log`, `vm-run-7-docker-and-owui.log`, `vm-upg-1-v0125.log`,
  `vm-upg-2-v0130.log`, `vm-upg-3-idem.log`.
- `vm-checks.sh` / `vm-checks-1.log`, `vm-checks-2.sh` / `vm-checks-2.log`,
  `ollama-stub.py`, `vm-persist.sh` / `vm-persist-{before,after}.log`,
  `vm-reboot.log`, `vm-upg-probe.sh` / `vm-upg-{before,after}.log`,
  `laptop-ollama-probe.log` (read-only probe on the laptop: transient container).
- `pre-commit-1.log`, `lint-ansible-{1,2}.log`, `yamllint-1.log`, `syntax-1.log`.

Note: `vm-run-1b.log` ran with the earlier task shape (a separate
`docker_container_info` wait loop), later replaced by `state: healthy`. Every run
from `vm-run-2.log` on uses the current code, including a fresh install from an
empty volume (`vm-fresh-volume-reset.log`, `vm-run-8-fresh-current-code.log`
changed=2, `vm-run-9-idem.log` changed=0). Docker itself was installed on the
fresh VM only by `vm-run-1b.log`.

## Checks run by Claude Code

- `uv run --no-sync .venv/bin/pre-commit run --files <the 12 staged files>` → exit 0
- `uv run --no-sync .venv/bin/ansible-lint` → exit 0 (production profile; vault
  `Decryption failed` warnings expected: dummy password)
- `uv run --no-sync .venv/bin/yamllint .` → exit 0
- `uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --syntax-check` → exit 0
- `bash bin/check_make_venv_tools.sh` → exit 0
- VM runs and functional checks listed above.

Not run: `make smoke-replay` (the VM's distro ansible-core has no
`community.docker`; see BACKLOG entry); anything on the real laptop except the
read-only probes recorded in `mission.md` → Initial state and
`laptop-ollama-probe.log`; Open WebUI against the real laptop Ollama.

## What to review

Per `docs/agent-workflow.md` §5.4, in particular:

1. Correctness of `roles/open_webui/tasks/main.yml` against community.docker 5.0.4
   (installed in `.venv`, `ansible-doc community.docker.docker_container`):
   idempotence, `state: healthy` + `healthy_wait_timeout`, `pull: missing`,
   `container_default_behavior: no_defaults`, mounts, `etc_hosts: host-gateway`,
   healthcheck options.
2. Tag wiring (`roles/bootstrap/tasks/main.yml`, `apply: tags:`) and the meta
   dependency on `docker`: does `--tags open-webui` run anything unrelated?
3. Security: exposure (`127.0.0.1:3030`), auth defaults untouched, the
   `WEBUI_SECRET_KEY_FILE` approach (no secret in repo/vault/logs), no socket, no
   auto-update; hard rules in `CLAUDE.md`.
4. The `docker` role change (`python3-debian`): justified and harmless on the laptop?
5. Documentation accuracy: `roles/open_webui/README.md` (owner validation
   commands, backup/restore commands, rollback statement — it must not imply a
   downgrade reverses migrations), README, CLAUDE.md, spec, BACKLOG.
6. Whether every `VERIFIED` in `mission.md` is backed by the cited evidence, and
   whether any criterion of the objective is missing.
7. Proportionality: no needless abstraction.

## Output

Write `docs/missions/2026-11-05-open-webui/review-1.md` in the format of
`docs/agent-workflow.md` §5.5. That is the only file you create or edit.
