# Report — 2026-11-07-remove-portainer

## Verdict

PASS for the laptop cleanup and for laptop-bootstrap. One residual,
out-of-scope recreation path remains in the separate `ansible-docker-apps`
repository. It is listed under Decisions required.

## Root of the leftover installation

- Portainer was never installed by laptop-bootstrap. The current tree has no
  reference to it. Its only past traces are two `/etc/hosts` names in git
  history (`portainer.homelab` in f8ec34b, `portainer.local` in the `dns` role
  removed by 59d2aa6).
- The installation came from the separate repository
  `~/Workspace/02-infrastructure/local/ansible-docker-apps`, role `portainer`.
  That role rendered `~/Workspace/07-local/portainer/docker-compose.yml`, a
  standalone Compose project (not a git repo) with two services: `portainer`
  (server, `portainer/portainer-ce:2.33.6`) and `portainer_agent`
  (`portainer/agent:2.33.6`).
- The server container and image no longer existed. The agent container was
  created on 2026-03-11 and kept running with `restart: unless-stopped`
  (`0.0.0.0:9001`, with `docker.sock` and `/var/lib/docker/volumes` bind-mounted).
  Docker's restart policy restarted it after every boot. This was the active
  recreation mechanism.
- No systemd unit (system or user), cron entry, autostart entry, shell rc entry
  or `/etc/hosts` line referred to Portainer.

## Laptop resources removed

| Resource | Identity check before removal | Action |
|---|---|---|
| Container `portainer_agent` | ID 1aa33c8362d1, label `io.portainer.agent=true`, Compose project `portainer` | `docker stop` + `docker rm` |
| Image `portainer/agent:2.33.6` | 23327631ee89; `docker ps -a --filter ancestor=` empty after rm | `docker image rm portainer/agent:2.33.6` |
| Directory `~/Workspace/07-local/portainer/` (compose file, `certs/`, bind-mounted `data/`) | not a git repo; sha256 of compose file `99f24917…`; Syncthing does not sync this path (only `~/Sync/keepass`, `03-second-brain`) | `trash` (recoverable, `trash-list` shows it at 2026-11-07 14:23:57) |

Not removed, on purpose:

- Network `local_network`: shared with `postgresql`, `localstack` and the
  excalidraw and semaphore compose files.
- `/var/lib/docker/volumes`: bind-mounted by the agent, but it is Docker's own
  volume store, not a Portainer resource.
- Image `alpine:3.21`: already present before the mission; used only to make the backup.
- No Docker volume existed for Portainer, so none was removed. No prune was run.

## Backup retained

- `/home/xgueret/Backups/portainer-2026-11-07/portainer-07-local.tar.gz`
  (131534 bytes, sha256 `c83a88e9a993adf214a2d71bf8960f5f596ba8dc49875e2008f67a1d7b262181`).
  File `0600`, directory `0700` (and `~/Backups` `0700`), owner xgueret.
- How it was made: `docker run --rm --pull never --network none`, using the
  local image `alpine:3.21`, with the source mounted read-only. `tar -czpf --numeric-owner`
  preserves the root ownership of `data/`. No sudo was used and no file
  contents were displayed.
- Completeness: the source and the archive both have 19 entries. The listing is
  in the evidence dir, `backup-listing.txt`.
- The archive holds secrets: `portainer.db`, `portainer.key`, `chisel/private-key.pem`
  and TLS `key.pem` files. Keep it private or delete it once it is not needed.
- The trashed directory still holds root-owned files under `data/`. Emptying the
  trash will need root for those entries (`sudo trash-empty`, or a targeted
  `sudo rm` on that trash entry).

## Repository changes

- `BACKLOG.md`: `Last review:` changed to 2026-11-07. No backlog entry existed for Portainer.
- `docs/missions/2026-11-07-remove-portainer/`: `mission.md`, `review-brief-1.md`,
  `review-1.md`, `report.md`.
- No role, variable, Makefile, CI or doc change was needed: nothing in the tree
  installed, configured or documented Portainer.
- Historical references kept: the git history commits f8ec34b and 59d2aa6
  (hosts entries of the removed `dns` role). History is not rewritten. Inside
  this mission's records the word appears by necessity.

## Acceptance criteria

| ID | Status | Evidence |
|---|---|---|
| AC1 | VERIFIED | `git grep -niI portainer -- . ':!docs/missions/2026-11-07-remove-portainer'` → exit 1, no output (re-run by Codex, plus an `rg --hidden` search) |
| AC2 | VERIFIED | `docker ps -a` name/image grep → none; filters `label=io.portainer.agent` → 0, `label=com.docker.compose.project=portainer` → 0 |
| AC3 | VERIFIED | `docker images` / `volume ls` / `network ls` grep portainer → 0/0/0. Diff of pre and post inventories: the only removed lines are the `portainer_agent` container, image 23327631ee89 and its `local_network` membership |
| AC4 | VERIFIED | backup above: 19/19 entries, modes 0600/0700, sha256 recorded before `trash` |
| AC5 | VERIFIED (laptop) | container and restart policy gone; `07-local/portainer` absent; `ss -ltn` on 9000/9001/9443 → 0; systemd system/user and crontab grep → 0. The residual repository path is below |
| AC6 | VERIFIED | `open-webui` same ID and `StartedAt 2026-11-06T12:16:03Z`, `healthy`, restarts=0, `GET 127.0.0.1:3030/health` → 200. `byenvini-dev-pg`, `mailpit`, `postgresql`, `localstack` still `Up (healthy)`. Volumes and networks unchanged |
| AC7 | VERIFIED | `review-1.md`: `VERDICT: PASS_WITH_RESERVATIONS`, no findings. Written before any laptop removal (review 14:23, backup and removals after it) |
| AC8 | see Git state | commit, push and PR follow this report |
| AC-SAFE | VERIFIED | Main-tree snapshot `14021b4b…` and `ansible-docker-apps` snapshot `4339705b…` are unchanged. No `pass`/vault access; dummy vault password file used. Hooks were not bypassed |

## Checks executed

- `pre-commit run --files <mission files, BACKLOG.md>` → exit 0, run again on
  the final file set before the commit.
- `.venv/bin/yamllint .` → exit 0
- `.venv/bin/ansible-playbook playbook.yml --syntax-check` → exit 0
- `.venv/bin/ansible-lint` → exit 0 (0 failures, 0 warnings, 81 files; the
  expected vault `Decryption failed` warning)
- Smoke VM: NOT_APPLICABLE (no role, variable or playbook change).
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-07-remove-portainer/`
  (`pre-inventory.txt`, `post-inventory.txt`, `backup-listing.txt`,
  `backup-sha256.txt`, lint logs, snapshots).

## Review

- Review 1 (Codex via Herdr, agent `lb-review`): PASS_WITH_RESERVATIONS, no
  findings. Its reservations and how they were handled:
  - Backup modes and completeness had to be established before deletion: done,
    see Backup retained.
  - The `ansible-docker-apps` path and the Caddy block had to be reported, not
    described as eliminated: done, see the next section.
  - Pre-commit had to run on the final mission file set: done before the commit.

## Remaining limits and risks

- `ansible-docker-apps` (separate repo, out of scope, holds uncommitted owner
  work on `feature/postgresql`) still contains `roles/portainer/`, the `portainer`
  entry in `deploy.yml` and `uninstall.yml`, and README/CLAUDE.md/CHANGELOG mentions.
  Its committed `group_vars/all/main.yml:11` (HEAD and origin/main) is
  `deploy_portainer: true`. Only the uncommitted local edit sets it to `false`. Running
  `deploy.yml` from a clean checkout of that repo would recreate the server and agent.
- `~/Workspace/07-local/caddy/Caddyfile` (rendered by the same repo, from
  `roles/caddy/templates/Caddyfile.j2`) still has a `portainer.local →
  127.0.0.1:9000` block. Caddy is not running and no container uses it. This
  was left alone because the file belongs to `ansible-docker-apps`.

## Decisions required

- D1: Remove Portainer from `ansible-docker-apps` (role, `deploy.yml` and
  `uninstall.yml` entries, the `deploy_portainer` var, the Caddy template block,
  docs) as a separate change in that repository, after the owner's
  `feature/postgresql` work is committed. Recommended. It is not blocking for this mission.
