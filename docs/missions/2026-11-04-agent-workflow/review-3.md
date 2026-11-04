# Review 3 — 2026-11-04-agent-workflow

VERDICT: CHANGES_REQUESTED

## Findings

- F3.1 [major] `docs/agent-workflow.md:235` — The environment check still does not control agent startup when the launch fence runs as one Bash call, as newly prescribed at lines 121–122. A failed `grep` only suppresses `echo clean`; the following `herdr agent start` runs anyway. Executing the exact fence with a shell mock returning `env_dirty=1` from `pane read` printed `MOCK_AGENT_STARTED` and exited 0. Review 2 accepted the manual close/stop instruction; that instruction cannot intervene between commands inside the now-prescribed single call. Make startup conditional on a successful cleanliness check, with executable close/exit handling on failure. Also stop if waiting for or reading the check output fails. No actual pane or agent was started in this reproduction.
- F3.2 [minor] `docs/agent-workflow.md:114` — F2.1 remains partially open: `pipefail` is enabled only inside the content-building command substitution, not in the final `printf | sha256sum | cut` pipeline. If the final hashing command fails, `cut` can return 0 and `snap` reports a successful empty result. With `sha256sum` mocked to return 1 and no untracked inputs, `now=$(snap …) || { echo STOP; exit 1; }; …` reached the next command, exited 0 and returned a zero-length hash. Two such results could be accepted as unchanged. Propagate failure from the final hashing pipeline as well, and reject an absent/malformed hash before accepting a snapshot. The directory/Git producer failure paths are now fixed.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Role/permission rules remain explicit and consistent across CLAUDE.md, AGENTS.md and workflow §1. |
| AC2 | NOT_VERIFIED | Mission criteria and review artifacts exist; final report is still pending and is correctly identified as pending. |
| AC3 | VERIFIED | Evidence statuses and lint/VM/laptop distinction remain defined. AC10 no longer prematurely claims completion. |
| AC4 | VERIFIED | Three-review limit and mandatory blocked/partial report with remaining findings are explicit; this is review 3. |
| AC5 | VERIFIED | State now identifies review-3, reviewer/pane, next step and the complete preservation baseline plus its evidence filename. This verifies the documented resume inputs, not an actual interrupted-session exercise. |
| AC6 | VERIFIED | BACKLOG removal/cleanup/Watch changes and workflow convention remain as assessed in earlier reviews. |
| AC7 | NOT_VERIFIED | Repository-specific rules and dummy-file failure handling are sound; executable environment gating and final snapshot hashing still need F3.1–F3.2. |
| AC8 | VERIFIED | Rechecked guide diff remains confined to the previously verified tag recommendations and cleanup warning. |
| AC9 | VERIFIED | Installed CLI syntax was checked in earlier reviews; the retained launch options are unchanged. All six current Bash fences parse. Runtime safety is separately addressed by findings. |
| AC10 | NOT_VERIFIED | Three brief/review requests demonstrate reviewer reuse; final report and its exchange remain pending. |
| AC-SAFE | NOT_VERIFIED | Full initial hashes are now recorded, but the final main-tree comparison and final hook run remain pending. This review performed read-only checks and wrote only review-3.md. |

## Commands run

- `cat AGENTS.md docs/missions/2026-11-04-agent-workflow/review-brief-3.md`, `cat` of mission.md, workflow and CLAUDE.md, and `nl -ba` excerpts of workflow/mission → exit 0; read requirements, fixes and evidence references.
- `git status --short`, `git diff HEAD --stat`, `git diff --cached --name-only`, `git diff --name-only`, `git ls-files -o --exclude-standard` → exit 0; twelve staged documentation files, no initial unstaged or untracked files.
- `git diff HEAD --check` → exit 0; no whitespace errors.
- `git diff HEAD -- BACKLOG.md README.md docs/guide-daily-usage.md` → exit 0; rechecked surrounding changes. `git branch --show-current`, `git rev-parse HEAD`, `git worktree list` → exit 0; docs/agent-workflow at de0c4b636a6a2271ab1b86b16f20515722de0ef9, isolated from main.
- Inline Python extracted all six workflow Bash fences and passed each to `bash -n` → all exit 0; syntax only.
- Extracted the exact `snap` definition without executing the baseline-writing command: direct worktree call with review-3 excluded → exit 0, hash `6338e4c3df353ea006d2fa985492a8510c8652280d0ade1cf81b41ee4169fd56`.
- Exact `snap` on `/nonexistent`, through both the OR/exit caller and the assignment/exit caller → exit 1, STOP printed, following `echo reached` not executed. Shell mocks failing all Git calls, or only `git ls-files`, through these callers → exit 1, STOP, no following command. No Git writes.
- Exact `snap` with synthetic Git output and two distinct staged versions → exit 0; hashes differ (`1279b4b3…efe9d` versus `f65a1db8…0112`), resolving the index-cancellation issue in F2.2.
- Exact `snap` with a shell mock making final `sha256sum` fail → exit 0; assignment caller reached the next command with `hash-length=0` (F3.2).
- Exact §4.1 fence with `mkdir` mocked to fail and dummy-file export unset → exit 1; stderr `STOP: dummy vault file not ready`, following command not reached. No file creation or Ansible execution; F2.3 resolved.
- Exact §5.3 launch fence with `herdr` mocked to return a synthetic pane id and `env_dirty=1` → exit 0, stdout `MOCK_AGENT_STARTED` (F3.1). Used real jq on synthetic JSON; no Herdr mutation or credential value access.
- Inline Python checked local link targets in AGENTS.md, CLAUDE.md, README.md, workflow and daily guide, and final-report existence → exit 0; no missing targets, report absent.
- `git diff HEAD --binary -- . ':!docs/missions/2026-11-04-agent-workflow/review-3.md' | sha256sum` → exit 0; initial tracked-content hash `4dbd31e14714c9090ff554985fb8669cb0bd2b8b9032b9b750890150f8510345`.
- Final `git status --short`, the same tracked-content hash command, `git ls-files -o --exclude-standard -- . ':!docs/missions/2026-11-04-agent-workflow/review-3.md'`, `test -s` and verdict/section `rg` check → exit 0; tracked hash unchanged, no other untracked files, required review structure present.

## Not checked

- Final main-tree comparison or external evidence contents: full baseline and continuity hashes are recorded in mission.md, but final comparison remains the implementer's responsibility. Did not inspect the main checkout or any secrets.
- Pre-commit rerun: hooks may modify files/caches; mission Log quotes exit 0 after the fixes. Final checks including this review and report have not happened yet. Earlier Ansible lint/syntax results remain implementer evidence, not independently rerun checks.
- Real revised pane launch, trust handling and interruption recovery: no panes or agents created/changed. The remaining launch issue was reproduced with mocks only.
- Actual binary/untracked-file fixture mutations: prohibited by the review's single-output-file and no-Git-writes limits. By inspection, `git diff --binary` produces a textual patch representation suitable for the quoted shell variable; command substitution's trailing-newline normalization is deterministic. No syntax/quoting defect found there.
- Smoke VM, laptop execution, network and secret-producing commands: outside reviewer permissions; no role/playbook changes require them for this review.

## Reservations

- F2.2–F2.5 are resolved. F2.1's directory/Git failure handling is resolved, with its final hashing failure path remaining as F3.2. Existing broad credential cleanup, mise seeding/tag distinctions, smoke exclusions, Postman paths and guide changes retain the earlier positive assessments; no implementation files or hooks changed.
- This is the last review. Carry F3.1–F3.2 as open findings into a PARTIAL/BLOCKED final report under workflow §3 step 6; no fourth review cycle is requested. Pending final-report and preservation checks must retain honest statuses.
