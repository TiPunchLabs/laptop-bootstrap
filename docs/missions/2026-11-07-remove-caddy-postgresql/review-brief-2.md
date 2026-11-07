# Review brief 2 — 2026-11-07-remove-caddy-postgresql

Same mission, objective and rules as `review-brief-1.md`. Still BEFORE any
runtime action: no container stopped, no directory trashed. Repository commit
under review is unchanged: `ansible-docker-apps` worktree
`/home/xgueret/Workspace/02-infrastructure/local/ansible-docker-apps-worktrees/remove-caddy`,
HEAD 65c5de2 (accepted in review 1, AC5/AC6 VERIFIED).

## Resolution of review 1 findings

- F1.1 [blocker] — Accepted. The September clients could not be identified:
  journal starts 2026-10-09 (`journalctl --list-boots`), `~/.bash_history` has
  no timestamps, no Claude Code transcript covers those times. New fact: port
  5432 is published on 0.0.0.0, so a LAN client is possible. Asked the owner;
  answer "Quarantine (Recommended)": no deletion now. Revised plan in
  `mission.md` → "Runtime plan": `docker update --restart=no postgresql`,
  `docker stop postgresql`; container, volume and `07-local/postgresql/` kept;
  reversible with `docker start postgresql`. The deletion is listed as a deferred
  owner step, not executed by this mission.
- F1.2 [major] — Fixed. `backup-sha256.txt` rebuilt with absolute paths for all
  13 files (including `pg-dumpall.sql`, `pg-globals.sql`, three `.dump`);
  `backup-sha256-check.txt` holds `sha256sum -c` output, exit 0, 13 OK. The
  artifacts used by the restore check are named in `mission.md` (Backups).
- F1.3 [major] — Fixed/clarified. `vol-now.txt` was taken before the anonymous
  volume of the restore container was removed. Final inventory `vol-final.txt`;
  `vol-final-diff.txt` is empty (diff exit 0); volume `2ef379cc…` absent.
- F1.4 [major] — Fixed. `runtime-identity.txt`: sanitized inspect (no Env) of
  `postgresql` (ID, image, restart policy, Compose labels, port bindings, mounts,
  networks), containers using the volume (only it), Compose project members,
  caddy containers/images (none), container mounts under the three directory
  targets (none), listeners on 80/443/2019/5432, docker-proxy, unit/cron/
  autostart/hosts counts (0), caddy binary/package (none). Your sandbox has no
  Docker socket: review this file instead of rerunning docker.
- F1.5 [minor] — Fixed. `ca-evidence.txt` gives paths, subjects, dates and
  SHA256 fingerprints for `caddy-internal.crt`, both Caddy entries of the system
  bundle (where `caddy-root.crt`'s content appears) and both laptop Caddy public
  roots. `mission.md` now limits the claim to present trust and marks
  `caddy-root.crt` ownership as inferred. No trust-store file is in the plan.
- AC3 retained outputs: `ada-bundle-verify.txt` (exit 0, head 3e29b22),
  `tar-check.txt` (entries 79/76/2, gzip ok).

## What to review

1. Each resolution above against the evidence files.
2. The revised runtime plan (steps 1–4 in `mission.md`): approve or reject each.
3. Whether the classification and scope text in `mission.md` are now consistent
   with the owner's quarantine decision.

Evidence dir (read-only):
`/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-07-remove-caddy-postgresql/`.
Backups: `ls -la` and `sha256sum -c` only; no content reads except the
unrelated patch, as in brief 1.

## Output

Write `docs/missions/2026-11-07-remove-caddy-postgresql/review-2.md`, same
format as review 1 (VERDICT, Findings F2.<k>, AC check, Deletion plan verdict per
step, Commands run, Not checked, Reservations), and nothing else.
