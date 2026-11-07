# Mission 2026-11-07-remove-caddy-postgresql — Remove obsolete laptop Caddy and PostgreSQL

## Objective

> Investigate and, where proven safe, remove obsolete laptop Caddy and
> PostgreSQL support using our existing Claude Code + Codex CLI + Herdr workflow.
>
> Owner intent
> - Network Caddy belongs to the homelab project and must remain untouched.
> - Investigate obsolete Caddy and PostgreSQL configuration on the laptop.
> - Identify PostgreSQL consumers before deciding whether its deployment
>   support and runtime resources can be removed.
> - If no consumer or intended use remains, perform the targeted cleanup.

(Full objective, sections 1–4 and Final report: preserve owner work in a private
backup before any mutation, isolated worktrees; establish ownership and consumers
from code, labels, mounts and rendered config, distinguishing the generic
`postgresql` container from project databases; read-only queries only, no
credential/content printing; observe sessions over an interval; remove Caddy if
obsolete; remove PostgreSQL only with no confirmed/unresolved consumer and no
intended use, after a logical backup with a verified restore; no shared
network/image/volume removal, no prune; treat `feature/postgresql` local changes
individually, reconcile against main; keep history; Codex review through Herdr
before destructive runtime cleanup; lint/syntax/reference checks; health of
retained apps; separate PRs per repository; no merge; do not delete
`feature/postgresql`.)

## Authorizations

- Default: repositories on mission branches/worktrees.
- Granted in the objective: private backups; targeted removal of the laptop Caddy
  and generic PostgreSQL runtime resources once supported by evidence and
  reviewed; commit, push and one PR per repository that needs changes. Merge,
  branch deletion and deployment stay with the owner.
- Owner decision 2026-11-07 (AskUserQuestion, answer "Remove it (Recommended)"):
  remove the generic PostgreSQL after a verified, restore-tested backup;
  mo-kreyol-platform will use its own Compose database.
- Owner decision 2026-11-07 after review 1 (F1.1, AskUserQuestion, answer
  "Quarantine (Recommended)"): because the September clients stay unidentified,
  do NOT delete the generic PostgreSQL now. Stop it and disable its restart
  policy; keep container, volume and `~/Workspace/07-local/postgresql/`.
  Reversible with `docker start postgresql`. Final deletion is a later owner step.

## Scope

In: laptop Caddy deployment support (`ansible-docker-apps` role `caddy`) and its
rendered runtime dirs; generic PostgreSQL runtime (container `postgresql`,
volume `postgresql_postgresql-data`, `~/Workspace/07-local/postgresql/`) and its
deployment support (`ansible-docker-apps` branch `feature/postgresql`, never
merged); mission records in laptop-bootstrap.

Out (not touched): homelab Caddy, Pi-hole, DNS, gateways, remote hosts; system
trust store (`/usr/local/share/ca-certificates/caddy-*.crt`, not the laptop
Caddy's CA, see Findings); `byenvini-dev-pg`, `07-php-db-1`, Supabase volume
`supabase_db_good-points`, `semaphore` role's own `semaphore-postgres`; shared
network `local_network`; shared image `postgres:17-alpine`; `ansible-docker-apps`
Portainer role (decision D1 of mission 2026-11-07-remove-portainer, separate).

## Initial state

- laptop-bootstrap: main checkout `main` @ fbaa44e, clean (origin/main 6c05b78);
  worktrees `agent-workflow-closeout`, `remove-portainer`; 2 stashes (owner).
  Snapshot `14021b4b6df2704d9016ae0325e5d05c583e506c3fcc0c8ab889573b463f3f90`.
- ansible-docker-apps: checkout on `feature/postgresql` @ 3e29b22, 2 unpushed
  commits over main 3bc15a4 (04021f9 role, 3e29b22 README + vault re-encrypt);
  modified `group_vars/all/main.yml`, `group_vars/all/vault/{caddy,postgresql}.yml`,
  `roles/caddy/templates/Caddyfile.j2`, `roles/caddy/vars/main.yml`,
  `roles/portainer/tasks/main.yml`; untracked `caddy/` (rendered runtime, root-owned
  `data/caddy`, `config/caddy`); no stash, single worktree.
  Snapshot `4339705bda83f95cd03c721fc7ed106735cfee1e65b1372dd2674f33754c8bc6`
  (identical to the value recorded by mission 2026-11-07-remove-portainer).
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-07-remove-caddy-postgresql/`
  (`pre-inventory.txt`, `src-*.txt`, `rst-*.txt`, `restore-psql.log`,
  `session-sampling*.txt`, `ref-sweep-5432.txt`, lint logs, `backup-sha256.txt`).

## Findings

### Ownership

| Installation | Owner (evidence) | State |
|---|---|---|
| Laptop Caddy `caddy-proxy` | `ansible-docker-apps` role `caddy` (main 3bc15a4); rendered to `~/Workspace/07-local/caddy/` (app_path on main) and to `ansible-docker-apps/caddy/` (owner's local app_path edit) | No container, no `caddy` image, no unit/cron/autostart, no `/etc/hosts` entry, nothing on 80/443/2019. Only rendered config + data dirs remain |
| Homelab Caddy | `homelab/caddy` (runbook-https-internal), CA trusted via `/usr/local/share/ca-certificates/caddy-internal.crt` (SHA256 08:D4:CD:80:…:6F:FA) | Out of scope, untouched |
| `caddy-root.crt` (0600 root; its bundle entry: 2025 root, SHA256 8A:5C:2C:04:…:D8:54) | Observed: not identical to either laptop Caddy root (71:2D:3D:36:…, DB:6F:B0:B3:…). Ownership inferred only from the file name used by the homelab `internal_ca_trust` role source; not established | Out of scope, untouched |
| Generic `postgresql` (bc836235f6bd, `postgres:17-alpine`, 0.0.0.0:5432, `unless-stopped`) | Compose project `postgresql`, file `~/Workspace/07-local/postgresql/docker-compose.yml`, rendered by `ansible-docker-apps` role `postgresql` on `feature/postgresql` only (04021f9); volume `postgresql_postgresql-data`; network `local_network` | Running |
| `byenvini-dev-pg` | Compose project `byenvini` (`01-projets/tipunchlabs/byenvini`), port 5433, own volume/network | Excluded, untouched |
| `07-php-db-1` | Compose project `07-php` (`103-apprentissage/07-php`), 127.0.0.1:5434, exited | Excluded, untouched |
| Supabase (`supabase_db_good-points`, `good-points-supabase` network) | Supabase CLI project good-points; no container | Excluded, untouched |

Startup mechanism of the generic PostgreSQL: Docker restart policy
`unless-stopped` (restarted after every boot, 76 starts in logs). Ansible entry
point: `deploy.yml` role `postgresql` on `feature/postgresql` only.

### PostgreSQL consumers

Contents (read-only queries): roles `postgres`, `mokreyol`; databases `postgres`
(no user tables), `mokreyol` (alembic_version=8e582d4ed8d3, `users`, `entries`,
`entry_history`, all 0 rows; enums entrystatus/historyaction/userrole),
`mokreyol_test` (empty). Both mokreyol databases created 2026-04-15.

| Suspected consumer | Class | Evidence |
|---|---|---|
| mo-kreyol-platform | Confirmed, dormant; owner decided removal | Default `database_url` `…@localhost:5432/mokreyol` (`backend/src/mo_kreyol_platform/config.py:5`, `.env.example`); log: `CREATE USER mokreyol`, `CREATE DATABASE mokreyol[_test]` 2026-04-15, asyncpg DDL 2026-04-15/04-24; last commit 8a26f9f 2026-04-15; untracked auth WIP. Its own `docker-compose.yml` defines `postgres:16-alpine` on 5432 (conflicted with the generic one). 0 rows to lose |
| byenvini (Payload CMS) | Excluded (historical) | Log 2026-07-07: `payload_*` DDL and `ozakajou_ci_check` create/drop; DB no longer present. Now `DATABASE_URI -> localhost:5433/byenvini_dev` (.env), container `byenvini-dev-pg` since 2026-07-16 |
| kandidat | Excluded | Own Compose `postgres` service (`5433:5432`, `postgres:17-alpine`); no `kandidat` DB on the generic server; DBeaver connection `172.25.0.4:5432/kandidat` = kandidat Compose network, not `local_network` (172.24.0.0/16) |
| Open WebUI | Excluded | laptop-bootstrap role uses SQLite in volume `open-webui`; no DB URL; not on `local_network` |
| semaphore | Excluded | Own `semaphore-postgres` service in its role; not deployed |
| localstack | Excluded | Member of `local_network`; no PostgreSQL configuration |
| homelab / KANDIDAT-GITOPS docs (`@postgresql:5432/…`) | Excluded | Refer to the dockhost PostgreSQL on the homelab |
| 10-labs exercise, 99-temp backups | Excluded | Exercise `.env` (`mydatabase`, absent), stale compose backups |
| Unknown clients 2026-09-04 (×2), 2026-09-30 (×1) | Unresolved — blocks deletion (review 1 F1.1); owner chose quarantine | `could not send data to client: Broken pipe`; `log_connections` off, so no db/user/source. No database other than mokreyol/postgres exists, no DDL logged, no client config found pointing at the generic server besides mo-kreyol-platform. Port is published on 0.0.0.0, so a LAN client is possible. Not resolvable after the fact: journal starts 2026-10-09, `~/.bash_history` has no timestamps, no Claude Code transcript covers those times |
| Scheduled jobs | Excluded | No crontab entries; system/user timers have no pg job; no `~/.pgpass`, `~/.pg_service.conf` |
| Live sessions | None observed | `session-sampling-3.txt`: 54 samples every 10 s, 16:00:00–16:08:55, starting 8 min after a laptop boot (15:52:09, the session was interrupted): `client backend` sessions 0, established TCP on :5432 0, in every sample. Earlier windows (`session-sampling.txt`, `-2.txt`, ~3 and ~2 min) also 0 clients; their `xact_commit` increments step by 2 in both mokreyol DBs at once (autovacuum pattern, plus Claude Code's own dump/fingerprint queries), not client traffic |

Caveat: `pg_stat_database` counters are reset by crash recovery (27 unclean
shutdowns in the log), so zero counters are not used as proof of disuse.

### Caddy consumers

No dependency: Caddy is not running, so none of its `*.local` hosts resolve to it
(no `/etc/hosts` entry, no listener). Present trust evidence: neither laptop
Caddy root is in `/etc/ssl/certs/ca-certificates.crt` today (the only two Caddy
entries there are 08:D4:… and 8A:5C:…); past trust is not established either
way. Evidence: `ca-evidence.txt`. Open WebUI is served directly on `127.0.0.1:3030`. The
backends it proxied (Proxmox, NAS, kandidat, vpngate, k8s) belong to the homelab.

### `feature/postgresql` and local modifications

| Item | Classification | Treatment |
|---|---|---|
| 04021f9 `feat(postgresql): add shared PostgreSQL role` | PostgreSQL, covered by decision | Not integrated; preserved in branch + bundle |
| 3e29b22 `docs(postgresql): …re-encrypt vault` | PostgreSQL, covered | Not integrated; preserved |
| `group_vars/all/vault/postgresql.yml` (modified, encrypted) | PostgreSQL, covered | Left in checkout; in backup patch |
| `group_vars/all/vault/caddy.yml` (modified, encrypted) | Caddy, covered | File deleted on cleanup branch; in backup patch |
| `roles/caddy/templates/Caddyfile.j2`, `roles/caddy/vars/main.yml` (kandidat.local, vpngate.local) | Caddy, covered (those backends are served by the homelab Caddy) | Role deleted on cleanup branch; in backup patch |
| `group_vars/all/main.yml`: `deploy_caddy`/`deploy_postgresql` lines | Covered | Removed / never on main |
| `group_vars/all/main.yml`: `app_path` → repo dir, `deploy_excalidraw/open_webui/portainer: false` | Unrelated | Preserved in checkout; exported as `ada-unrelated-local-changes.patch` against the cleanup branch |
| `roles/portainer/tasks/main.yml` `remove_orphans: true` | Unrelated (Portainer, D1 of previous mission) | Preserved in checkout and in the unrelated patch |
| untracked `caddy/` | Caddy runtime (rendered by the app_path edit) | Backed up; trashed 16:37:07 after review 2 (`execution.log`) |

Portainer: `ansible-docker-apps` main still contains the `portainer` role. The
cleanup branch starts from origin/main and adds nothing; nothing reintroduces
Portainer on the laptop (`deploy_portainer` is untouched on main, D1 stays open).

## Backups (private, `~/Backups/caddy-postgresql-2026-11-07/`, dir 0700, files 0600)

- `ada-feature-postgresql.bundle` (`git bundle verify` OK), `ada-uncommitted.patch`
  (+ `.base`, `.stat`; `git apply --cached --check` on base OK),
  `ada-unrelated-local-changes.patch`.
- `caddy-07-local.tar.gz` (79/79 entries), `caddy-ada-untracked.tar.gz` (76/76),
  `postgresql-07-local.tar.gz` (2/2) — made with `alpine:3.21`, `--network none`,
  source read-only, `--numeric-owner`. They hold private keys / a password.
- `pg-dumpall.sql` (globals + all DBs, `--clean --if-exists`), `pg-globals.sql`,
  `pg-{mokreyol,mokreyol_test,postgres}.dump` (custom format).
- Checksums: evidence `backup-sha256.txt`.

Checksums: `backup-sha256.txt` now lists all 13 files with absolute paths;
`sha256sum -c` → exit 0, 13 OK (`backup-sha256-check.txt`). The restore check
used `pg-dumpall.sql` (psql) and `pg-mokreyol.dump` (pg_restore), mounted
read-only, and those files are unchanged since (mtime 15:48, checksums above).
Bundle verify and tar/gzip checks: `ada-bundle-verify.txt`, `tar-check.txt`.

Restore check: throwaway `postgres:17-alpine`, `--network none`, trust auth,
backup mounted read-only. `psql -f pg-dumpall.sql` exit 0 with 2 expected errors
(`DROP ROLE postgres` "current user cannot be dropped", `CREATE ROLE postgres`
"already exists"). Roles, databases (owner/encoding/collation), tables, row
counts, alembic version and enum types: identical to the source. `mokreyol` password
hash restored (checked as boolean). `pg_restore -l` OK on the three custom dumps;
`pg_restore` of `mokreyol` into a fresh DB → 4 tables. Container and its
anonymous volume `2ef379cc…` (identified by diff against `vol-pre.txt`,
no container attached) removed with `docker volume rm`; final state
`vol-final.txt`, `diff vol-pre.txt vol-final.txt` → exit 0 (review 1 F1.3 read
the intermediate `vol-now.txt`, taken before that removal).

## Runtime plan (revised after review 1; executed only after Codex review 2)

Identity, attachment and listener evidence: `runtime-identity.txt` (container ID
bc836235f6bd…, Compose project/config/working dir, port 5432 on all addresses,
single named volume, only user of `postgresql_postgresql-data`, no container
mounts anything under the three directories, no caddy container/image/listener/
unit/cron/autostart/hosts entry). Each step re-checks identity before acting.

PostgreSQL — quarantine (owner decision), nothing deleted:
1. `docker update --restart=no postgresql` (after checking the ID prefix bc836235f6bd).
2. `docker stop postgresql`.

Caddy — runtime dirs, after re-checking that no container mounts them:
3. `trash ~/Workspace/07-local/caddy` (backup `caddy-07-local.tar.gz`).
4. `trash ~/Workspace/02-infrastructure/local/ansible-docker-apps/caddy` (backup
   `caddy-ada-untracked.tar.gz`; untracked rendered runtime, not source work).

Deferred owner decision (not run, not approved by review 2, F2.1). A stopped
server records no sessions, so the quarantine only surfaces clients that
break. Before final deletion the owner should: (a) let a defined period pass
(suggested: 30 days, to 2026-12-07) with everyday use of the projects that
could reach 5432 on this laptop or the LAN; (b) consider any failure seen in
that period ("connection refused" on 5432) as a consumer and restart with
`docker update --restart=unless-stopped postgresql && docker start postgresql`
(the original policy); (c) accept the September clients as unidentified, in
writing; (d) take a fresh dump and recheck identity (container ID bc836235f6bd,
only user of the volume) right before:
`docker rm postgresql && docker volume rm postgresql_postgresql-data &&
trash ~/Workspace/07-local/postgresql`. The 2026-11-07 backups stay in
`~/Backups/caddy-postgresql-2026-11-07/` either way.

Kept: image `postgres:17-alpine` (kandidat Compose uses it), network
`local_network` (localstack; excalidraw/semaphore Compose files), trust-store
CAs, every other container/volume/network/image. No prune.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Ownership of each Caddy/PostgreSQL installation established | labels, mounts, rendered files, repo code (Findings) | VERIFIED (runtime targets via `runtime-identity.txt`; older trusted CA ownership inferred, out of scope) |
| AC2 | Consumer matrix with evidence; unresolved cases named | Findings + sampling | VERIFIED |
| AC3 | Owner work preserved in a private recoverable backup before mutation | bundle verify, patch check, tar counts, modes | VERIFIED |
| AC4 | PostgreSQL backup restorable in an isolated instance | restore check above | VERIFIED |
| AC5 | Caddy deployment support removed from `ansible-docker-apps` (role, flag, vault file, playbooks, current docs) | `git grep -i caddy` outside CHANGELOG → none; lint/syntax | VERIFIED (65c5de2; reviews 1–2) |
| AC6 | Generic PostgreSQL deployment support not present on any main; `feature/postgresql` accounted for | `git ls-tree origin/main` | VERIFIED (feature/postgresql kept, 2 commits not integrated) |
| AC7 | Caddy runtime removed; PostgreSQL quarantined (stopped, restart=no); nothing recreates either | docker inventory, restart policy, file checks | VERIFIED (`execution.log`: postgresql exited, restart=no, volume+dir kept; both Caddy dirs in trash; 0 listeners on 5432; no unit/cron/hosts/caddy image) |
| AC8 | Retained apps healthy; unrelated resources equal to baseline | inventory diff, open-webui health | VERIFIED (`inventory-diff.txt`: only the default `bridge` network ID differs, recreated by the 15:52 boot; open-webui a874108bcb69 healthy, /health 200; byenvini-dev-pg ready; mailpit, localstack healthy) |
| AC9 | Codex review before runtime cleanup | `review-2.md` VERDICT | VERIFIED (review 1 CHANGES_REQUESTED; review 2 PASS_WITH_RESERVATIONS, all 4 steps approved before execution) |
| AC10 | Separate PRs, CI state reported, no merge | gh | NOT_VERIFIED |
| AC-SAFE | Owner work preserved; no secret printed or committed; hooks not bypassed; homelab untouched | snapshots, gitleaks | NOT_VERIFIED |

## State

- Phase: report
- Branches / worktrees: laptop-bootstrap `chore/remove-caddy-postgresql` at
  `../laptop-bootstrap-worktrees/remove-caddy-postgresql` (base 6c05b78);
  ansible-docker-apps `chore/remove-caddy` at
  `../ansible-docker-apps-worktrees/remove-caddy` (base 3bc15a4)
- Reviewer: herdr agent `lb-review`, pane w1Q:pN
- Review cycle: 2 of 3; review 1 CHANGES_REQUESTED (F1.1–F1.5)

## Log

- 2026-11-07 inspect: repo states, runtime inventory, CA fingerprints, consumer trace.
- 2026-11-07 decision: owner chose removal of the generic PostgreSQL.
- 2026-11-07 backup: owner work, runtime dirs, pg_dumpall + restore check (PASS).
- 2026-11-07 implement: ansible-docker-apps Caddy removal staged; lint/syntax/pre-commit exit 0.
- 2026-11-07 resumed: session interrupted; laptop booted 15:52:09 (not caused by the mission). Snapshots of both owner trees unchanged; all containers restarted by their policies (open-webui same ID a874108bcb69, new StartedAt 19:58:05Z, healthy). 9-min session sampling done.
- 2026-11-07 review-1: CHANGES_REQUESTED (F1.1 blocker, F1.2–F1.4 major, F1.5 minor); no runtime action taken.
- 2026-11-07 fix-1: evidence files added; September clients not resolvable; owner chose quarantine.
- 2026-11-07 review-2: PASS_WITH_RESERVATIONS (F2.1, F2.2 minor), steps 1–4 approved.
- 2026-11-07 execute: 16:37:07 postgresql restart=no + stopped; both Caddy runtime dirs trashed; post checks green.
- 2026-11-07 fix-2: F2.1 deferred-deletion criteria written; F2.2 table wording fixed.
