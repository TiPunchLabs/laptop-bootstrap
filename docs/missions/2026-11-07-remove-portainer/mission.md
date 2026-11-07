# Mission 2026-11-07-remove-portainer — Remove Portainer from the laptop and laptop-bootstrap

## Objective

> Remove Portainer completely from this laptop and from laptop-bootstrap,
> using the project's existing Claude Code + Codex CLI + Herdr workflow.
>
> The owner authorizes removing the obsolete Portainer installation,
> including portainer_agent, and cleaning all Portainer references from
> this repository.

(Full objective text: inspect and identify; clean the repository in an isolated
worktree; clean the laptop with targeted removals after recording the selected
resources and backing up any non-empty Portainer data; verify; Codex review of
the repository changes and the cleanup plan before laptop removals; commit, push,
open a PR, do not merge. Ambiguous ownership: leave intact, report.)

## Authorizations

Default: repository on a mission branch/worktree + smoke VM (no smoke-down).

Extra, granted in the objective:

- Laptop: stop and remove the Portainer agent and any confirmed Portainer server
  container, remove their dedicated startup definitions, images, networks and
  volumes once proven unshared, after backing up non-empty Portainer data outside
  the repository. Targeted removals only, no prune. Docker itself, Open WebUI,
  Ollama and unrelated containers are not touched.
- Git: commit, push, open PR. Merge stays with the owner.

## Scope

In: Portainer resources on this laptop's Docker engine; their startup definition
(`~/Workspace/07-local/portainer/`); Portainer references in laptop-bootstrap.

Out (reported, not changed): the separate repository
`~/Workspace/02-infrastructure/local/ansible-docker-apps` (its own `portainer`
role, the `portainer.local` Caddy block it templates), which holds uncommitted
owner work; the shared Docker network `local_network`; git history of this repo.

## Findings (inspect phase)

Evidence: `~/.local/share/laptop-bootstrap-agent/2026-11-07-remove-portainer/pre-inventory.txt`.

Laptop:

- Container `portainer_agent` (1aa33c8362d1), image `portainer/agent:2.33.6`
  (23327631ee89), `Up 3 days`, port `0.0.0.0:9001`, restart policy
  `unless-stopped`, label `io.portainer.agent=true`, Compose project `portainer`,
  config file `/home/xgueret/Workspace/07-local/portainer/docker-compose.yml`,
  mounts: bind `/var/run/docker.sock`, bind `/var/lib/docker/volumes`; no named or
  anonymous volume; network `local_network`. Created 2026-03-11.
- No `portainer` server container exists; image `portainer/portainer-ce` absent.
- No Docker volume belongs to Portainer: server data is a bind mount,
  `~/Workspace/07-local/portainer/data` (root-owned `portainer.db` 1 MiB,
  `portainer.key/.pub`, `certs/`, `tls/`, `chisel/`, `compose/`, …) plus
  `~/Workspace/07-local/portainer/certs` (self-signed `cert.pem`/`key.pem`).
- `~/Workspace/07-local/portainer/` is not a git repository; sha256 of
  `docker-compose.yml`: `99f249172b1a1ea08af8fe6fc6d7e86dfa1dc60dc8a7d0d9f1880dd09c8aecd8`.
- `local_network` (external in the compose file) is shared: members
  `postgresql`, `localstack`, `portainer_agent`; also declared by the
  excalidraw, semaphore, localstack, postgresql compose files → kept.
- No systemd unit (system or user), cron entry, autostart entry, shell rc entry
  or `/etc/hosts` line mentions Portainer.
- Syncthing: the only `path="~"` entry is the folder-defaults template
  (`id=""`); synced folders are `~/Sync/keepass` and `03-second-brain` → trashing
  `07-local/portainer` does not propagate.

Recreation mechanisms:

- Docker restart policy `unless-stopped` on `portainer_agent` (active; the cause
  of the leftover running since 2026-03-11 across reboots).
- The Compose file above (`docker compose up` in that directory).
- `ansible-docker-apps` (separate repo, branch `feature/postgresql`, origin
  `TiPunchLabs/ansible-docker-apps`): `roles/portainer/` templates that exact
  compose file, gated in `deploy.yml` by `deploy_portainer`. Committed value at
  HEAD and origin/main: `deploy_portainer: true`; the owner's **uncommitted**
  edit sets it to `false`. Latent, out of scope, reported.

Repository (laptop-bootstrap):

- `grep -rniI portainer` over the tree at `origin/main` (fbaa44e), the other
  worktree and both stashes: no match. Nothing installs, configures or documents
  Portainer here.
- Git history: `portainer.homelab` (f8ec34b, initial commit) and
  `portainer.local` (removed in 59d2aa6) were `/etc/hosts` entries of the removed
  `dns` role. History is not rewritten.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | No Portainer support or reference remains in the current repository tree, outside this mission's own records | `git grep -niI portainer -- . ':!docs/missions/2026-11-07-remove-portainer'` returns nothing | VERIFIED |
| AC2 | No Portainer container (running or stopped) on the laptop | `docker ps -a` filtered on name, image, `io.portainer.agent` label and Compose project `portainer` | VERIFIED |
| AC3 | No dedicated Portainer image remains; no shared network or volume removed | `docker images`, `docker network ls`, `docker volume ls` diffed against pre-inventory | VERIFIED |
| AC4 | Portainer data backed up outside the repository before deletion; backup readable and complete | `tar -tzvf` listing, file count vs source, sha256 recorded | VERIFIED |
| AC5 | No active startup mechanism can recreate Portainer on the laptop | container gone (restart policy gone with it); compose dir no longer at its path; no unit/cron; dormant ansible-docker-apps path documented | VERIFIED |
| AC6 | Open WebUI healthy and unrelated Docker resources preserved | `docker inspect open-webui` health + same container ID/StartedAt; `curl 127.0.0.1:3030/health`; pre/post container list diff = only `portainer_agent` | VERIFIED |
| AC7 | Codex reviewed repo changes and cleanup plan before laptop removals | `review-1.md` verdict | VERIFIED |
| AC8 | Commit, push, PR opened, not merged; CI status reported | `gh pr view` | VERIFIED |
| AC-SAFE | User's local work preserved (main tree and ansible-docker-apps snapshots unchanged); no secret read or written; hooks not bypassed | §6 snapshots; pre-commit run | VERIFIED |

## Plan

1. Repository: mission records only (no Portainer code to remove); update
   `BACKLOG.md` `Last review:`. Lint the changed files.
2. Codex review 1: repository diff + the cleanup plan below.
3. Laptop cleanup (after review), in order:
   1. Backup `~/Workspace/07-local/portainer/` (compose file, `certs/`,
      root-owned `data/`) with a throwaway container from the local image
      `alpine:3.21` (`--pull never --network none`, source mounted read-only),
      to `~/Backups/portainer-2026-11-07/portainer-07-local.tar.gz`, owned by
      xgueret, dir `0700`, file `0600`. Verify the archive lists every source
      entry; record sha256. No sudo. File contents are not read.
   2. `docker stop portainer_agent && docker rm portainer_agent` (by name, after
      re-checking ID 1aa33c8362d1).
   3. `docker image rm 23327631ee89` (`portainer/agent:2.33.6`) after checking
      `docker ps -a --filter ancestor=` is empty.
   4. `trash ~/Workspace/07-local/portainer` (startup definition + bind data;
      recoverable from the trash; backup kept separately).
   5. Not removed: `local_network` (shared), `alpine:3.21` (pre-existing),
      `07-local/caddy/Caddyfile` `portainer.local` block (Caddy config owned by
      ansible-docker-apps, Caddy not running), `ansible-docker-apps` repository.
4. Verify AC2–AC6; record post-inventory.
5. Report, commit, push, PR.

## State

- Phase: done
- Branch / worktree: chore/remove-portainer / ../laptop-bootstrap-worktrees/remove-portainer
- Base commit: fbaa44e
- Evidence dir: ~/.local/share/laptop-bootstrap-agent/2026-11-07-remove-portainer/
- Main-tree baseline: `$E/main-tree-snap-baseline.txt` (14021b4b…)
- ansible-docker-apps baseline: `$E/ansible-docker-apps-snap-baseline.txt` (4339705b…)
- Reviewer: herdr agent lb-review (codex), pane w1Q:pH
- Review cycle: 1 of 3 (PASS_WITH_RESERVATIONS)
- Next step: owner merges PR #64; optional D1 in ansible-docker-apps

## Log

- 2026-11-07 inspect: leftover = `portainer_agent` from standalone compose project `07-local/portainer`; no Portainer reference in laptop-bootstrap tree.
- 2026-11-07 plan: worktree created from origin/main fbaa44e; plan written.
- 2026-11-07 review-1: Codex PASS_WITH_RESERVATIONS, no findings.
- 2026-11-07 laptop: backup `~/Backups/portainer-2026-11-07/portainer-07-local.tar.gz` (19/19 entries); `portainer_agent` removed; image 23327631ee89 removed; `07-local/portainer` trashed.
- 2026-11-07 verify: AC2–AC6 and AC-SAFE verified (see report.md).
- 2026-11-07 git: 3efbb25 pushed, PR #64 opened, CI lint+terraform pass; reviewer pane w1Q:pH closed.
