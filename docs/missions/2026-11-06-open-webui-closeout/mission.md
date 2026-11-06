# Mission 2026-11-06-open-webui-closeout — Open WebUI: post-merge record, cleanup, version management

## Objective

Owner's words (verbatim):

> Finalize the Open WebUI mission in laptop-bootstrap using the existing
> Claude Code + Codex reviewer + Herdr workflow.
>
> Owner confirmation: Open WebUI is operational on the laptop.
>
> 1. Record validation and clean up
> - Verify PR #62 is merged and its changes are present in origin/main.
> - Record the owner's functional confirmation in the mission report.
>   Distinguish owner-confirmed results from checks you execute yourself.
> - Inspect the open-webui worktree and branch for uncommitted or unmerged work.
> - Remove the mission worktree and local/remote feat/open-webui branches only
>   after confirming all their work is preserved in main.
> - Preserve unrelated files, worktrees, stashes, hooks and environments.
>
> 2. Verify version management
> - Inspect the actual role: open_webui_version must have a default, be
>   overridable through normal Ansible mechanisms, and determine the image
>   passed to docker_container.
> - Check that changing only this variable and rerunning the role deploys the
>   requested version while preserving the data volume and WEBUI_SECRET_KEY.
> - Reuse the mission's existing VM upgrade, persistence and rollback evidence
>   where sufficient. Do not upgrade or downgrade the operational laptop.
> - Verify that a second run with the same version is idempotent.
> - Document the exact variable override and deployment commands, including
>   backup and rollback requirements for database migrations.
> - If corrections are needed, use a new branch/worktree, run appropriate
>   checks, obtain Codex review through Herdr, then commit, push and open a PR.
>   Do not merge it.
>
> Keep the scope limited to these two objectives. Leave Pi-hole/Caddy and
> openwebui.internal integration for a later mission.

## Authorizations

Default (repository on a mission branch/worktree). Extra, granted in the objective:
remove the `feat/open-webui` worktree and branches once preserved in `main`;
commit, push and open a PR for corrections. Not granted: merge; any change to the
laptop (no upgrade/downgrade); Pi-hole, Caddy, `openwebui.internal`.

## Scope

In: post-merge record in `docs/missions/2026-11-05-open-webui/report.md`; cleanup
of the mission worktree/branches; version-management review and its documentation
in `roles/open_webui/README.md`.
Out: role code changes (none needed), laptop changes, homelab integration.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | PR #62 merged, its head in `origin/main` | `gh pr view 62`, `git merge-base --is-ancestor 2356c04 origin/main` | VERIFIED: `state MERGED`, `mergedAt 2026-11-06T01:25:15Z`, merge commit `67db4bc` = `origin/main`; ancestor check exit 0 |
| AC2 | Owner confirmation recorded, separated from agent checks | `report.md` → "Post-merge record" | VERIFIED: owner statement quoted verbatim without widening its scope (F1.1 fixed); agent read-only probe listed separately (`laptop-readonly-probe.log`) |
| AC3 | Worktree/branches removed only after their work is in `main` | `git status --porcelain` (empty), `git log origin/main..feat/open-webui` (empty), ignored dirs `.ansible`, `test/smoke/.vagrant` hold no file, no mission VM in `virsh list --all`; then `git worktree remove`, `git branch -d` | VERIFIED: worktree removed, `Deleted branch feat/open-webui (was 2356c04)`; remote branch already gone (GitHub deleted it at merge: `fetch --prune` `[deleted] origin/feat/open-webui`, `ls-remote` empty) |
| AC4 | `open_webui_version` has a default, is overridable, and selects the image | read `defaults/main.yml` (`"v0.13.0"`), `tasks/main.yml` (`image: "{{ open_webui_image }}:{{ open_webui_version }}"`, assert `^v\d+\.\d+\.\d+$`); role defaults are the lowest variable precedence | VERIFIED (code inspection; `-e` override exercised on the VM, group_vars override follows Ansible precedence, not executed) |
| AC5 | Changing only the variable deploys the version, keeps volume and secret key | reuse `vm-upg-*` evidence: run 1 `-e open_webui_version=v0.12.5`, run 2 same args without it (default v0.13.0) | VERIFIED: run 2 `changed=1` (only the container task); after: image v0.13.0, version 0.13.0, alembic `0bd252b206fb` → `e42c8f710a36`, same user, same key sha256 prefix `3217401197e04f68`, old token HTTP 200 |
| AC6 | Second run with the same version idempotent | `vm-upg-3-idem.log`, `vm-rb-4-idem.log` | VERIFIED: `changed=0` both |
| AC7 | Exact override/deploy commands, backup and rollback requirements documented | `roles/open_webui/README.md` → Updating, Rollback | VERIFIED by inspection after the fix (see Log) and against the VM rollback evidence (`vm-rb-steps-{1,2}.log`); Codex review 1 found the operational docs consistent |
| AC-SAFE | Local work, stashes, hooks, other worktrees preserved; no secret read; laptop unchanged | stash list vs baseline, `git worktree list`, hooks `INSTALL_PYTHON`, no `make play`/`ansible-playbook` against the laptop | VERIFIED: `safety-check-1.log` (2026-11-06T19:38): main checkout on `main` at `67db4bc`, `git status --porcelain --untracked-files=all` empty (it was clean at the start, per the session git status; no `snap` baseline was taken), stash list identical to `stash-list-baseline.txt`, both hooks' `INSTALL_PYTHON` = main checkout venv, worktree `agent-workflow-closeout` still at `4a0bca0`; no secret read (dummy vault only); no `make play`/`ansible-playbook` run against the laptop, only the read-only probe |

## Plan

1. Verify merge, inspect and remove the mission worktree/branches.
2. Read-only laptop probe; record owner confirmation.
3. Inspect version management; reuse VM evidence.
4. Fix the README gap; docs checks; Codex review via Herdr; commit, push, PR.

## State

- Phase: done (report written; commit/push/PR authorized, merge is the owner's)
- Branch / worktree: `docs/open-webui-closeout` / `../laptop-bootstrap-worktrees/open-webui-closeout`
- Base commit: `67db4bc` (`origin/main`)
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-06-open-webui-closeout/`
  (VM evidence reused from `…/2026-11-05-open-webui/`)
- Reviewer: herdr agent `lb-review`, pane `w1Q:pG` (closed at the end of the mission)
- Review cycle: 2 of 3 (review 1: CHANGES_REQUESTED, F1.1 and F1.2 fixed; review 2: PASS_WITH_RESERVATIONS)

## Log

- 2026-11-06 inspect: PR #62 merged (`67db4bc`); `feat/open-webui` clean, nothing unmerged; worktree and local branch removed; remote branch already deleted by GitHub.
- 2026-11-06 verify: read-only laptop probe (healthy, v0.13.0, loopback only).
- 2026-11-06 implement: the role needs no change. README gap found: "Updating"
  said "or override it" without the exact mechanism, and the general note
  suggested `-e` for one-off overrides. For `open_webui_version` a one-off `-e` is
  a trap: `make` targets do not pass `-e`, so the next run returns to the default
  tag, which is an unbacked downgrade of a migrated database. The README now gives
  the persistent override locations, the deploy and check commands, and that
  warning; rollback step 3 now points at the same place.
- 2026-11-06 review-1: CHANGES_REQUESTED. F1.1: the report widened the owner's
  statement to UI, admin account and Ollama; now quoted verbatim, items left
  unconfirmed. F1.2: AC-SAFE, AC7 and the phase claimed completion early; safety
  checks run and recorded (`safety-check-1.log`), statuses corrected.
- 2026-11-06 review-2: PASS_WITH_RESERVATIONS, no open findings. Pane `w1Q:pG` closed. report.md written.
