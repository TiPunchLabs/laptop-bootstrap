# Review brief 3 — 2026-11-04-agent-workflow

Third and last review (correction cycle 2 of 2, workflow §3 step 6). Same rules
as before. Write `docs/missions/2026-11-04-agent-workflow/review-3.md` (§5.5
format) and nothing else. Findings still open after this review go into the final
report as open items; there is no fourth cycle.

## Change under review

Same branch, worktree and base (`de0c4b6`), all staged (`git diff --cached`).
Since review 2: `docs/agent-workflow.md` (§3 step 1, §4.1, §5.2, §5.6),
`mission.md`, this brief; `review-2.md` is now part of the change.

## Resolution of review 2 findings

| Finding | Resolution | Where |
|---|---|---|
| F2.1 [major] snapshot failure masked by `\|\|` callers | Fixed. No reliance on `set -e`: the content is built in `s=$(set -o pipefail; cd … && git … && … \| xargs -0r sha256sum) \|\| return 1`, hashing happens only after that succeeded. Callers use `\|\| { echo STOP >&2; exit 1; }` and `now=$(snap …) \|\| exit`, then a string compare. Doc states the snippets are one Bash call each, so `exit` stops the rest | §3 step 1, §5.2, §5.6 |
| F2.2 [minor] staged and unstaged edits can cancel | Fixed. Separate `git diff --cached --binary` and `git diff --binary` sections, plus HEAD and untracked content hashes | §3 step 1 |
| F2.3 [major] dummy-file failure did not stop | Fixed. `… && [ -s "$D" ] \|\| { echo STOP >&2; exit 1; }`, then `export` on its own line | §4.1 |
| F2.4 [minor] abbreviated resume baseline | Fixed. Full hash and the file `$E/main-tree-snap-baseline.txt` in State; the doc says to record the path | `mission.md` State, §3 step 1 |
| F2.5 [minor] AC10 marked VERIFIED before report | Fixed. AC10 back to `NOT_VERIFIED`, evidence lists both round trips, report pending | `mission.md` |

## Tests run by Claude Code (`$E/snippet-test-2.sh` = the §3 function verbatim)

| Case | Caller | Result |
|---|---|---|
| `cd` fails (`/nonexistent`) | `snap … > f \|\| { echo STOP; exit 1; }; echo reached` | `STOP`, rc 1, `reached` not printed |
| every `git` call fails (function mock) | same | `STOP`, rc 1 |
| `git ls-files` fails inside the pipe | `a=$(snap . x) \|\| { echo STOP; exit 1; }` | `STOP`, rc 1 |
| normal run on this worktree | direct | hash, rc 0 |
| temp repo: HEAD=A, index=B, worktree=A, then `git reset f` | direct, twice | hashes differ (`efc7…` vs `5210…`) |
| §4.1 block with `mkdir` mocked to fail | `bash -c` | `STOP: dummy vault file not ready`, rc 1, `reached` not printed |
| main tree baseline | direct | `106b8ac0…0177`; unstaged `git diff --binary` sha256 still `de419b87…fec0` (unchanged since inspection) |

Also re-run after these edits, before sending this brief: see `mission.md` Log
(pre-commit exit and `bash -n` on every fence are recorded there).

## What to check

1. F2.1–F2.5 are resolved, and the fixes introduce no new problem (quoting,
   `local` inside the function, `"${x[@]}"` when empty, trailing-newline handling
   of `$( )`, binary diffs in a shell variable).
2. Overall verdict on the whole change against the acceptance criteria in
   `mission.md`, given this is the last cycle.
