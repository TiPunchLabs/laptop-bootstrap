# Review brief 4 — 2026-11-04-agent-workflow

Extra review authorized by the user after review 3 (quote in `mission.md`
Authorizations). No further cycle. Same rules as `AGENTS.md` and the earlier briefs.
Write `docs/missions/2026-11-04-agent-workflow/review-4.md` (§5.5 format) and
nothing else.

## Change under review

Same branch, worktree and base (`de0c4b6`), all staged (`git diff --cached`).
Since review 3: `docs/agent-workflow.md` (§3 step 1 `snap`, §3 step 6 one
sentence, §5.3 launch fence, its read window and one bullet), `mission.md`, this brief;
`review-3.md` is already part of the change. `report.md` still holds the
review-3 PARTIAL text and is rewritten after this review: do not judge it.

## Resolution of review 3 findings

| Finding | Resolution | Where |
|---|---|---|
| F3.1 [major] env gate does not stop `agent start` in one call | Fixed. Each step is a gate: pane split under `pipefail` with `jq -er` and a non-empty id, else exit; then `stop()` (closes the pane, prints STOP, `exit 1`) on failure of `pane run`, `pane wait-output` (now `(?m)^env_dirty=[0-9]+$` on `recent-unwrapped`), `pane read`, or the check. The check accepts only when the lines matching `^env_dirty=[0-9]+$` are exactly one line `env_dirty=0` (dirty, absent, duplicate or suffixed results all fail). `agent start` failure also closes the pane | §5.3 |
| F3.2 [minor] final hash pipe can succeed with an empty hash | Fixed. `h=$(set -o pipefail; printf … \| sha256sum \| cut …) \|\| return 1`, then `[[ $h =~ ^[0-9a-f]{64}$ ]] \|\| return 1`; only a valid hash is printed | §3 step 1 |

## Tests run by Claude Code

`$E` = `~/.local/share/laptop-bootstrap-agent/2026-11-04-agent-workflow/` (outside
the worktree; readable). `$E/snippet-test-3.sh <doc>` extracts the `snap`
function and the §5.3 fence verbatim from the doc and runs them on synthetic
data: a temporary Git repo under `/tmp/claude-1000`, and a `herdr` shell mock
that logs every call. No real Herdr call, no secret.

| Run | Result | Log |
|---|---|---|
| pre-fix doc (`$E/agent-workflow-before-fix-3.md`) | 11 passed, 14 failed (reproduces F3.1 and F3.2) | `$E/snippet-test-3-before-fix.log` |
| fixed doc | 25 passed, 0 failed | `$E/snippet-test-3.log` |

Cases: `snap` nominal (64-hex, stable), unstaged / staged / untracked /
untracked-content changes each change the hash, exclusion ignored; `sha256sum`
returning 1, empty output, malformed output, `cut` returning 1, missing repo,
`git ls-files` failing → STOP, next command not run. Launch: clean → started;
dirty, timeout, result absent, `0` and `1` both shown, duplicate lines,
`env_dirty=0x`, `pane read` failing, `pane run` failing → `agent start` never
called, pane closed, rc 1; split failing or returning no id → not started, rc 1;
`agent start` failing → pane closed, rc 1.

Real Herdr 0.9.1 probe (throwaway pane `w1Q:p4`, closed; `$E/herdr-probe-3.log`):
`wait-output` with the new regex matched (rc 0), a never-matching regex timed out
with rc 1, `pane read` of an unknown pane rc 1.

Real launches of this review's pane with the fixed §5.3 fence, extracted
verbatim (`$E/launch-fence-4.sh`) and run as one Bash call in Claude Code's real
environment:

- Attempt 1 (`$E/agent-start-4a-failclosed.log`): the pane printed
  `env_dirty=0` and `wait-output` matched, but `pane read --lines 5` returned
  only 3 logical lines (`--lines` counts screen rows; the long prompt wraps in a
  narrow pane), so the result line was outside the window. The gate failed
  closed: `STOP: environment not clean or result ambiguous`, pane `w1Q:p5`
  closed, no agent started. Cause confirmed in probe pane `w1Q:p6` (closed;
  `$E/herdr-probe-4.log`): `--lines 5` → 3 lines without the result, `--lines 20`
  → result present.
- Own finding, fixed: read window raised to `--lines 50` (the pane is new, so it
  holds only the startup output and the check) with a comment. Tests re-run:
  25/25.
- Attempt 2 (`$E/agent-start-4.log`): gate passed, `agent_started`, pane
  `w1Q:p7`, rc 0. Screen read before this prompt: no trust dialog.

Other checks after the fixes: `.venv/bin/pre-commit run --files <staged>` with the
dummy vault and credentials unset → exit 0, all Passed/Skipped, gitleaks
("Detect hardcoded secrets") Passed, Ansible-lint Passed (`$E/precommit-5.log`);
`bash -n` on every bash fence → 6/6 (`$E/bash-n-4.log`). Main tree `snap` still
equals the baseline.

Not run: smoke VM, laptop (out of scope; no role or playbook change).
The Python 3.12 venv reservation stays a separate BACKLOG Watch entry; no
version change in this mission.

## What to check

1. F3.1 and F3.2 are resolved, with no new defect (the `stop` function and `$P`
   scope, `exit` inside a function, the Rust `(?m)` regex, `grep -x` on
   `<<<"$out"`, the 64-hex check, the comparison callers).
2. Re-run or inspect the evidence above as far as your limits allow.
3. Overall verdict on the whole change against the acceptance criteria in
   `mission.md`.
