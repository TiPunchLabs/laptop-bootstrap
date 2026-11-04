# Review brief 2 — 2026-11-04-agent-workflow

Second review (correction cycle 1 of 2). Same rules as `review-brief-1.md` and
`AGENTS.md`. Write `docs/missions/2026-11-04-agent-workflow/review-2.md` (§5.5
format) and nothing else.

## Change under review

Same branch, worktree and base (`de0c4b6`). Everything is staged: `git diff
--cached`. Since review 1, the files changed are `docs/agent-workflow.md`,
`CLAUDE.md`, `mission.md`, and this brief was added. Your `review-1.md` is now
part of the change.

## Resolution of review 1 findings

| Finding | Resolution | Where |
|---|---|---|
| F1.1 [major] env cleanup incomplete, check not a gate | Fixed. Unset now covers `ANSIBLE_VAULT_PASSWORD GITHUB_TOKEN GH_TOKEN` and every `TF_VAR_*` (`$(compgen -e \| grep '^TF_VAR_')`), in §4.1 and §5.3. The check prints `env_dirty=<count>`; `pane wait-output --regex 'env_dirty=[0-9]+'` waits for it (the typed command line cannot match because it contains `$(`); the gate is `grep -qx 'env_dirty=0'`; on failure: close the pane, list names only, stop | `docs/agent-workflow.md` §4.1, §5.3 |
| F1.2 [major] mission state pre-filled as done | Fixed. State shows phase `review-2`, reviewer `lb-review`/`w1Q:p3`, cycle 2 of 3, next step; each AC has a status and evidence, unfinished ones `NOT_VERIFIED`; Log records each transition | `mission.md` |
| F1.3 [minor] main-tree checksum misses staged/untracked | Fixed. One `snap <repo> [exclude]` function (HEAD + `git diff HEAD --binary` + untracked file hashes) used for the main tree (§3 step 1, §6, §9) and the review snapshot (§5.2, §5.6). Prints only the hash | §3 step 1, §5.2, §5.6 |
| F1.4 [minor] failures not propagated | Fixed. `snap` runs in a subshell with `set -euo pipefail` and callers stop on non-zero exit; smoke logging redirects to a file and echoes the replay's own exit status | §3 step 1, §4.2 |
| F1.5 [minor] dummy file parent not created | Fixed. `mkdir -p "${D%/*}"`, write + `chmod` chained, export only on success, else `STOP` | §4.1 |
| F1.6 [minor] parent link broken from worktree | Fixed. Plain reference to `02-infrastructure/CLAUDE.md`, no relative link | `CLAUDE.md` line 6-8 |
| (own) trust dialog reported as `idle` by Herdr 0.9.1 | Added: read the visible screen before the first prompt | §5.3 |

## Acceptance criteria (Claude Code statuses)

See the table in `mission.md` (status + evidence per AC). AC2 and AC-SAFE stay
`NOT_VERIFIED` until the report and the final checks; AC5 and AC7 depend on this
review.

## Checks run by Claude Code after the fixes

| Command | Exit | Result |
|---|---|---|
| `.venv/bin/pre-commit run --files <staged files>` (dummy vault, credentials unset) | 0 | all Passed/Skipped; gitleaks `Passed`; ansible-lint `Passed` |
| `bash -n` on each ```bash fence of `docs/agent-workflow.md` | 0 ×6 | syntax only |
| `snap` test (worktree, main tree, `/nonexistent`) | 0, 0, 1 | failure propagates |
| env gate with synthetic `GH_TOKEN GITHUB_TOKEN TF_VAR_other ANSIBLE_VAULT_PASSWORD` (empty dummy values) | 0 | `env_dirty=0` after the unset; a separate run with only `GH_TOKEN` set and no unset printed `env_dirty=1` |

Not run: smoke VM, laptop (out of scope); new pane launch with the revised gate
(the current reviewer pane was cleaned with the cycle-1 commands and checked
`env-clean`; the revised gate will be exercised on the next launch).

## What to check

1. Each F1.x is resolved without new problems; the snippets are correct.
2. `mission.md` now supports §9 resume without asking the user.
3. Anything from brief 1 §"What to check" that the fixes affected.
