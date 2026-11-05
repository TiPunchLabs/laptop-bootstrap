# Review 1 — 2026-11-05-checkout-v7

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- F1.1 [minor] docs/missions/2026-11-05-checkout-v7/mission.md:83 — AC5 has status `see Log`, but the Log contains no scope-verification entry. This does not follow §4.3's status vocabulary. Set it to `VERIFIED` with the scoped diff evidence already available; the review independently confirms the scope.

## AC check

`E` below is `/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/`. Evidence is from local saved outputs, not fresh network queries.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | `pr-state-initial.txt` records exit 0 for PR #41 and both searches: open Dependabot PR against main, initially BEHIND, no duplicate open checkout PR. Local main and origin/main are `d16b322`. |
| AC2 | VERIFIED | Saved release notes/README, identical action metadata, actual workflow and CI log support no adaptation beyond the bump; details below. |
| AC3 | VERIFIED | HEAD `e55d4ec` has parent `d16b322`; merge-base with origin/main is `d16b322`. Committed diff contains exactly the two checkout replacements; setup-python v7 remains. |
| AC4a | VERIFIED | Saved run log shows both jobs checking out PR merge `a50b6a5`, explicitly merging `e55d4ec` into `d16b322` (lines 145 and 366), using checkout SHA `3d3c42e…`. Terraform validates successfully; lint and syntax steps complete through post-job cleanup without a failure. Run success is also recorded in the brief. |
| AC4b | NOT_VERIFIED | Final pushed commits, including the report, do not yet exist in the reviewed state. Requires CI on each final pushed SHA as planned. |
| AC5 | VERIFIED | Full diff against origin/main contains only ci.yml, BACKLOG.md and the two staged mission documents. Workflow diff changes only checkout versions. No Python, other dependency, role or playbook change. Mission status needs F1.1's correction. |
| AC6 | VERIFIED | BACKLOG removes #41 on the mission branch, retains the mission date and adds a sourced deferred hardening entry, consistent with §8. |
| AC7 | NOT_VERIFIED | `precommit-1.env` records `env_dirty=0` and exit 0; `precommit-1.log` contains nine Passed hooks and the remaining hooks Skipped. This proves the reported pre-review invocation only. Commit/push hooks and coverage of the subsequently added brief/review/report remain pending. |
| AC-SAFE | NOT_VERIFIED | Local stash IDs and other worktree HEAD match the recorded initial state. Full final main-tree checksum comparison and resource preservation audit remain report-time work. This reviewer made no git writes and ran no laptop, secret-access or network commands. |

The v7 fork-PR restriction concerns `pull_request_target` and `workflow_run`; ci.yml uses `push` and `pull_request`, with no checkout overrides. The saved v6.1.0 notes also document the backport. Matching action.yml files establish matching inputs/runtime, rather than identity of the implementations.

Both jobs use hosted runners; the observed runner 2.338.2 exceeds the documented Node 24 minimum 2.327.1 and container-auth minimum 2.329.0. There are no declared container actions or subsequent workflow git commands requiring adaptation. Default token authentication, depth 1, cleaning, safe-directory setup, disabled LFS/submodules and `allow-unsafe-pr-checkout: false` are supported by the metadata and actual log. Credential persistence under RUNNER_TEMP predates v7; the log shows masked authentication setup, includeIf removal and credential-file removal in both jobs (lines 219 and 607).

The deferred token item is supported by the saved repository setting (`default_workflow_permissions: write`), absence of workflow permissions and lack of a post-checkout authenticated git requirement. Keeping it outside this dependency bump is appropriate. The Dependabot run itself shows read-only token permissions; the repository default should not be described as the effective permission of that run.

## Commands run

All commands were local and read-only, apart from writing this review. Inspection command groups exited 0; no hooks or CI were rerun by this reviewer.

- `git status --short` → exit 0; three staged documentation/backlog changes before this review, no unstaged or untracked files.
- `git diff HEAD` and `git diff --cached` → exit 0; inspected all staged changes, including the brief.
- `git diff d16b322 HEAD` and `git diff d16b322 HEAD -- .github/workflows/ci.yml` → exit 0; only two checkout version changes.
- `git ls-files --others --exclude-standard` → exit 0; no untracked files before this review.
- `git diff --check HEAD` → exit 0; no whitespace errors in staged changes.
- `git diff --check d16b322 HEAD` → exit 0; no whitespace errors in the dependency commit.
- `git diff origin/main --name-only` and `git diff --name-status origin/main` → exit 0; four expected paths.
- `git diff origin/main -- .github ansible.cfg pyproject.toml .python-version uv.lock` → exit 0; checkout lines only.
- `git log -2 --format='%H %P %s'` and `git merge-base origin/main HEAD` → exit 0; reviewed HEAD and parent match the brief.
- `git branch -vv`, `git worktree list`, `git stash list --format='%H %gs'` → exit 0; isolated branch without upstream, expected worktrees and two stash IDs.
- `cmp /home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/action-v6.yml /home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/action-v7.yml` → exit 0; metadata byte-identical.
- `cat`, `ls -la`, `sed -n`, `tail -n`, `rg -n` and `nl -ba` inspection calls → exit 0; read repository rules, workflow, hook configuration, mission documents, saved release/README/action metadata, PR/settings/tag/scope/hook evidence and CI excerpts. No secret files read.

## Not checked

- Fresh upstream documentation, tag resolution, PR status or GitHub run API status: network prohibited. Context7 was not called for the same reason; conclusions use the supplied official-source snapshots.
- Final commit/push hooks, final report and final CI: pending implementer actions, outside this review's write permissions.
- Local pre-commit rerun: relied on supplied output; hooks can modify files/cache and this review permits only the review file to be written.
- actionlint: not a project tool. Smoke VM and laptop execution: prohibited for this review and unnecessary for this workflow-only change.
- Final main-tree checksum comparison and comprehensive other-mission preservation: left explicitly NOT_VERIFIED rather than inferred from branch/stash listings.

## Reservations

- This approves the reviewed change with one minor documentation finding; it does not establish final merge readiness. Complete AC4b, AC7 and AC-SAFE, and record their actual evidence before the final report claims completion.
- Hooks should cover all final mission files, including this review and the report. The existing hook evidence predates those files.
