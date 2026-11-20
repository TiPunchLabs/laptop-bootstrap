# Review brief 2 — 2026-11-16-portainer-local

Second review (cycle 2 of 3). Same rules, scope and output format as `review-brief-1.md` (read it).

- Version under review: **`21b839f4c8548dcbaa067265b8bfda2d3511ee27`**. Base: `2962443` (your review 1). Diff: `git diff 2962443 21b839f` (`roles/portainer/tasks/admin.yml` new, `tasks/main.yml` and two more files). Later commit `8c06794`: docs only (`report.md`, possibly `owner-commands-d1.md`).
- Executor answers: `report.md` → "Review 1 (Codex, CHANGES_REQUESTED on 2962443) and resolution"; VM evidence `E/r1-*.log`, `E/poll-*.txt` (statuses seen by an allowed LAN client during each run), `E/scenario.sh`.

## Requested checks

1. F1.1 and F1.2 fixed? Re-derive both scenarios from your review 1 (fresh volume with an existing admin and an empty hash; `--check -vvv` after clearing the hash) and any variant you can construct: is a setup page ever reachable from an allowed LAN client without an admin; does any secret material (hash or password) reach task output, container `Args`/`Config.Cmd`, env, logs, evidence, in any variable state?
2. The one-shot bootstrap container: lifecycle (removed, no leftover file or container holding the hash), idempotence, behaviour when the admin already exists, failure paths, `--check`.
3. No regression of what review 1 accepted (shared `docker_port_filter`, Open WebUI unchanged, loopback default, IPv4, `--http-disabled`).
4. `owner-commands-d1.md` and `report.md` consistent with the new code.

## Output

`docs/missions/2026-11-16-portainer-local/review-2.md`:

```
VERDICT: PASS | PASS_WITH_RESERVATIONS | CHANGES_REQUESTED | BLOCKED
Version: 21b839f4c8548dcbaa067265b8bfda2d3511ee27
```

Findings `F2.<k> …`, status of F1.x, AC check, Commands run, Not checked, Reservations.
