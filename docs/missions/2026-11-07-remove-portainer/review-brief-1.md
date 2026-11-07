# Review brief 1 — 2026-11-07-remove-portainer

## Mission

- Id: 2026-11-07-remove-portainer
- Objective (verbatim, head): "Remove Portainer completely from this laptop and
  from laptop-bootstrap, using the project's existing Claude Code + Codex CLI +
  Herdr workflow. The owner authorizes removing the obsolete Portainer
  installation, including portainer_agent, and cleaning all Portainer references
  from this repository." Full text and authorizations: `mission.md`.
- Base commit: fbaa44e (origin/main). Branch: `chore/remove-portainer`.
- Files (staged, uncommitted):
  - `BACKLOG.md` — `Last review:` 2026-11-06 → 2026-11-07
  - `docs/missions/2026-11-07-remove-portainer/mission.md` (new)
  - this brief (new)

## What to review

This review happens **before** any laptop removal. Two subjects:

1. Repository changes. The inspection found no Portainer reference in the
   current tree, so the repository change is limited to mission records. Check
   that claim independently (`git grep -niI portainer`, including docs, Makefile,
   CI, inventory, group_vars, roles, `test/smoke`), and check whether anything
   indirectly tied to Portainer exists (ports 9000/9001/9443, `docker.sock`
   mounts, `/var/lib/docker/volumes`, `local_network`, `portainer.local`).
   Git history references (`portainer.homelab` in f8ec34b, `portainer.local`
   removed in 59d2aa6, both `/etc/hosts` entries of the removed `dns` role) are
   intentionally not rewritten.
2. The laptop cleanup plan, `mission.md` § Plan step 3, against the findings
   in `mission.md` § Findings. Judge: target selection (only dedicated Portainer
   resources), ordering (backup before deletion), backup method (no sudo, no
   content read, outside the repository, permissions), use of `trash` rather
   than `rm`, absence of prune, what is deliberately kept (`local_network`,
   Caddyfile block, `ansible-docker-apps`) and whether keeping
   `ansible-docker-apps` untouched is the right call given it holds uncommitted
   owner work and is a separate repository. Point out any recreation mechanism
   the findings missed, as far as you can tell from the evidence.

You must not run Docker or anything else against the laptop (AGENTS.md); judge
the laptop part from the evidence quoted in `mission.md` and below.

## Acceptance criteria (Claude Code status before laptop work)

| ID | Status | Evidence |
|---|---|---|
| AC1 | VERIFIED | `git grep -niI portainer -- . ':!docs/missions/2026-11-07-remove-portainer'` → no output, exit 1 |
| AC2–AC6 | NOT_VERIFIED | laptop work not started (waits for this review) |
| AC7 | NOT_VERIFIED | this review |
| AC8 | NOT_VERIFIED | after review and cleanup |
| AC-SAFE | NOT_VERIFIED | snapshots taken (main tree, ansible-docker-apps); compared at report time |

## Checks run (in the worktree, dummy vault password file)

- `pre-commit run --files BACKLOG.md docs/missions/2026-11-07-remove-portainer/mission.md` → exit 0 (gitleaks, detect-private-key, ansible-lint passed)
- `.venv/bin/yamllint .` → exit 0
- `.venv/bin/ansible-playbook playbook.yml --syntax-check` → exit 0
- `.venv/bin/ansible-lint` → exit 0, "0 failure(s), 0 warning(s) in 81 files"; expected `Decryption failed` warning on the vault

Not run: smoke VM replay — no role, vars or playbook change (NOT_APPLICABLE).

## Laptop evidence (excerpts, from `pre-inventory.txt` and inspection)

```text
portainer_agent  portainer/agent:2.33.6  Up 3 days  0.0.0.0:9001->9001/tcp
  restart=unless-stopped  project=portainer
  cfg=/home/xgueret/Workspace/07-local/portainer/docker-compose.yml
  labels: io.portainer.agent=true
  mounts: bind:/var/run/docker.sock  bind:/var/lib/docker/volumes   (no volumes)
  networks: local_network
docker ps -a --filter ancestor=portainer/agent:2.33.6 → portainer_agent only
docker ps -a --filter label=com.docker.compose.project=portainer → portainer_agent only
local_network members: portainer_agent postgresql localstack
systemd (system+user), crontab, /etc/cron*, ~/.config/autostart, ~/.bashrc, /etc/hosts: no "portainer"
ansible-docker-apps: HEAD and origin/main group_vars/all/main.yml:11 deploy_portainer: true;
  working tree (uncommitted owner edit): deploy_portainer: false
```

## Output

Write `docs/missions/2026-11-07-remove-portainer/review-1.md` in the format of
`docs/agent-workflow.md` §5.5, and nothing else.
