# Review brief 1 — 2026-11-07-remove-caddy-postgresql

## Mission

Objective (verbatim head; full summary in `mission.md`): "Investigate and, where
proven safe, remove obsolete laptop Caddy and PostgreSQL support … If PostgreSQL
has no confirmed or unresolved consumer and no remaining intended use, remove its
laptop deployment support and dedicated resources … Before destructive runtime
cleanup, have Codex independently review the consumer investigation, exact
deletion plan and backup/restore evidence."

This review happens BEFORE any runtime deletion. Nothing has been removed from
Docker or the filesystem yet (only a throwaway restore-check container and its
anonymous volume, created and removed by Claude Code).

## What to review

1. `docs/missions/2026-11-07-remove-caddy-postgresql/mission.md` (this worktree):
   ownership table, consumer matrix, `feature/postgresql` classification, backups,
   restore check, runtime deletion plan, scope. Challenge any classification that
   the evidence does not support, especially: mo-kreyol-platform (owner decided
   removal), the unresolved 2026-09 broken-pipe clients, and the claim that the
   trusted `caddy-*.crt` CAs are not the laptop Caddy's.
2. Repository diff in the separate repository worktree
   `/home/xgueret/Workspace/02-infrastructure/local/ansible-docker-apps-worktrees/remove-caddy`
   (branch `chore/remove-caddy`, base origin/main 3bc15a4, one local commit
   65c5de2, not pushed): `git -C <that path> diff --stat origin/main..HEAD` and
   `git -C <that path> show HEAD`. Also check that
   `~/Backups/caddy-postgresql-2026-11-07/ada-unrelated-local-changes.patch`
   applies on 65c5de2 (`git apply --check` in a throwaway checkout is fine,
   or reason from the owner checkout's `git diff` hunks; the patch is not secret).
   Check: no remaining active Caddy reference (CHANGELOG history and the new
   "Removed" entry are intentional), no Portainer reintroduced, no PostgreSQL role
   introduced, playbooks still valid, docs consistent (CLAUDE.md there is French
   on purpose).
3. Hard rules: no secret printed or written (the encrypted vault file is deleted,
   not decrypted); no `--diff`; homelab Caddy, Pi-hole, DNS, remote hosts out of
   scope; no shared network/image/volume in the deletion plan; no prune.

## Checks run by Claude Code (exit status)

ansible-docker-apps worktree, dummy vault password file, credentials unset:
- `.venv/bin/yamllint .` → 0
- `.venv/bin/ansible-playbook deploy.yml --syntax-check` → 0; `uninstall.yml` → 0
- `.venv/bin/ansible-lint` → 0 (0 failures, 0 warnings, 32 files)
- `.venv/bin/pre-commit run --files <changed files>` → 0 (gitleaks, ansible-lint,
  yamllint, markdownlint, codespell passed); commit hooks (incl. commitizen) → 0
- `--list-tags`: deploy `[excalidraw, open_webui, portainer, semaphore]`;
  uninstall adds `clean, cleanup`.

Runtime (read-only): `docker ps -a`/`inspect` (labels, mounts, networks, env
NAMES only), `docker volume/network/images ls`, `ss -ltn`, systemd/cron/autostart
greps, CA fingerprints, psql catalog queries, `docker logs` summaries with
passwords redacted, workspace `rg` sweep (`ref-sweep-5432.txt`). Session sampling:
`session-sampling-3.txt` (authoritative, 9 min after a fresh boot);
`session-sampling.txt` and `-2.txt` are short earlier windows cut by a session
interruption. The laptop rebooted at 15:52:09 between them (not mission-caused).

Evidence dir (read-only for you):
`/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-07-remove-caddy-postgresql/`.
Do NOT open `~/Backups/caddy-postgresql-2026-11-07/` contents (secrets); you may
`ls -la` it and check `sha256sum` against `backup-sha256.txt`.

You may rerun read-only checks: `docker ps/inspect --format` (never print `.Config.Env`
values), `docker volume/network ls`, `git grep`, `rg`, lint commands above.
Do not run `psql` writes, `docker stop/rm`, `pass`, `ansible-vault`, or anything
that changes the laptop.

## Not run

- Smoke VM: NOT_APPLICABLE (no laptop-bootstrap role, var or playbook change).
- Ansible run of `ansible-docker-apps` against the laptop: not run (owner only).

## Output

Write `docs/missions/2026-11-07-remove-caddy-postgresql/review-1.md` in this
worktree and nothing else, with this format:

```markdown
# Review 1 — 2026-11-07-remove-caddy-postgresql
VERDICT: PASS | PASS_WITH_RESERVATIONS | CHANGES_REQUESTED | BLOCKED
## Findings
- F1.<k> [blocker|major|minor] <file:line> — problem — expected fix
## AC check
| ID | Reviewer status | Basis |
## Deletion plan verdict
- step N: approve | reject — reason
## Commands run
- `<command>` → exit <n>, <one-line result>
## Not checked
- … (why)
## Reservations
- …
```
