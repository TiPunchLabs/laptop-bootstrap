# Review brief 1 — 2026-11-06-open-webui-closeout

## Mission

- Id: `2026-11-06-open-webui-closeout`. Objective (verbatim) and authorizations:
  `docs/missions/2026-11-06-open-webui-closeout/mission.md`. In short: record the
  owner's post-merge confirmation of PR #62, clean up the old mission worktree and
  branches, verify how `open_webui_version` drives the deployed image, and
  document the exact override, deployment, backup and rollback steps. No role
  code change, no laptop change, no homelab work.
- Base commit: `67db4bc` (`origin/main`, merge of PR #62). Branch:
  `docs/open-webui-closeout`. Worktree:
  `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui-closeout`.
- Everything is staged and nothing is committed. Review with `git diff --cached`.

## Files

```
 BACKLOG.md                                           | Last review date only
 docs/missions/2026-11-05-open-webui/report.md        | new section "Post-merge record (2026-11-06)"
 docs/missions/2026-11-06-open-webui-closeout/mission.md | new
 docs/missions/2026-11-06-open-webui-closeout/review-brief-1.md | new (this file)
 roles/open_webui/README.md                           | Variables note, Updating rewritten, Rollback step 3
```

## Acceptance criteria and evidence

See the table in `mission.md` → Acceptance criteria. Evidence is readable at:

- `~/.local/share/laptop-bootstrap-agent/2026-11-06-open-webui-closeout/laptop-readonly-probe.log`:
  the agent's read-only probe of the laptop (`docker ps`, `docker inspect`, `curl
  /health` and `/api/config`, `ss`, `docker volume ls`).
- `~/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`: VM evidence
  reused from the first mission. The upgrade test is `vm-upg-1-v0125.log`,
  `vm-upg-2-v0130.log`, `vm-upg-3-idem.log`, `vm-upg-before.log`,
  `vm-upg-after.log` and `vm-upg-probe.sh`. The backup, update and rollback test is
  `vm-rb-*.log` and `vm-rb-probe.sh`. `run-vm.sh` is the runner.
  - Upgrade arguments: every run used
    `--tags open-webui -e open_webui_container_name=owui-upg -e open_webui_volume_name=owui-upg -e open_webui_host_port=3031 -e open_webui_bind_address=192.168.121.70 -e open_webui_health_timeout=600`.
    Run 1 added `-e open_webui_version=v0.12.5`. Run 2 used the same arguments
    without that option, so it fell back to the default v0.13.0; it reported
    `changed=1`, from the container task only. Run 3 repeated run 2 and reported
    `changed=0`.
  - Rollback arguments: every run used `-e open_webui_container_name=owui-rb -e open_webui_volume_name=owui-rb -e open_webui_host_port=3032`.
    `rb-1` added `-e open_webui_version=v0.12.5`. `rb-2` had no version option, so
    it ran the default v0.13.0. `rb-3` and `rb-4` added
    `-e open_webui_version=v0.12.5` again.

## Checks run by Claude Code

- `uv run --no-sync .venv/bin/pre-commit run --files <staged files>` (dummy vault, cleaned env) → exit 0
  (`…/2026-11-06-open-webui-closeout/pre-commit-1.log`; rerun after the brief is added).
- Repository checks, all read-only: `gh pr view 62`,
  `git merge-base --is-ancestor 2356c04 origin/main` (exit 0), and
  `git status --porcelain`, `git log origin/main..feat/open-webui` and a `find` of
  the ignored dirs before removing the worktree.
- Laptop: read-only probe only (above).

Not run: no role code changed, so there was no lint or VM run beyond pre-commit.
Overriding through `group_vars` was not executed; it relies on Ansible variable
precedence, where role defaults are the lowest. Nothing was run on the laptop that
changes it.

## What to review

1. `roles/open_webui/README.md` → Updating and Rollback. Check them against
   `roles/open_webui/{defaults,tasks}/main.yml`, `Makefile` and
   `group_vars/all/vars.yml`:
   - Are the override locations correct and complete?
   - Are the commands exact and runnable? Does `/api/config` really return
     `.version`? See the probe log.
   - Is the `-e` warning accurate (the `make` targets pass no extra vars)?
   - Does the Rollback section stay consistent with Updating?
2. `report.md` → Post-merge record: are owner-confirmed claims kept apart from
   agent-executed checks, and is every agent claim backed by the probe log?
3. `mission.md`: is every `VERIFIED` backed by the cited evidence? In particular,
   does AC5 hold: changing only the version variable keeps the volume data and
   the secret key?
4. Hard rules in `CLAUDE.md`. Scope: nothing about Pi-hole, Caddy or
   `openwebui.internal` beyond what already existed.

## Output

Write `docs/missions/2026-11-06-open-webui-closeout/review-1.md` in the format of
`docs/agent-workflow.md` §5.5. That is the only file you create or edit.
