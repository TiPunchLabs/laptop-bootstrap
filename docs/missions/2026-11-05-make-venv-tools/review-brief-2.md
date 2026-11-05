# Review brief 2 — 2026-11-05-make-venv-tools

Same mission, worktree, branch and base (`b4f5ab5`) as `review-brief-1.md`. The
only changes since review 1 are `bin/check_make_venv_tools.sh` (static half) and
`mission.md` (AC6, AC-SAFE, State, Log). `review-1.md` is now staged as-is.

## Resolution of review 1 findings

- F1.1 [minor], substring match: fixed in `bin/check_make_venv_tools.sh:12-39`.
  - Each `make -n` line is split into words with `read -ra`.
  - Every word whose basename is one of the 7 tools must be
    `.venv/bin/<tool>`, and the 3 words before it must be `uv run --no-sync`.
  - A comment can no longer satisfy a bare call. Your counterexample (bare
    `ansible-playbook … # uv run --no-sync .venv/bin/ansible-playbook` in `play`)
    now exits 1 (`f1-comment-bypass.log`).
- F1.2 [minor], swallowed `make -n` failure: fixed.
  - `recipe=$(make -n --no-print-directory "$target")` runs under `set -e`, so a
    failing dry run stops the script. A target removed from the Makefile and from
    `.PHONY` gives `make -n` exit 2 and check exit 2 (`f1-make-error.log`).
  - Each target must also contain at least one `uv run --no-sync .venv/bin/<tool>`
    call. A target still in `.PHONY` but with no recipe now exits 1
    (`f1-missing-target.log`), and so does a recipe with no tool call
    (`f1-no-tool-call.log`).
- F1.3 [minor], AC-SAFE evidence: `safety-check-1.txt` records the comparisons,
  with commands, values and `RESULT` lines.
  - Main snapshot unchanged, main `.venv` checksums and listing unchanged,
    stashes unchanged, `agent-workflow-closeout` has 0 changes, and the remote
    branches are present.
  - It is run again at delivery, as `safety-check-final.txt`.

## Checks run after the fix

All ran with the dummy vault and `env_dirty=0`. The counterexamples ran in scratch
copies; the old tree is `origin/main:Makefile`.

| Check | Exit |
|---|---|
| comment bypass / empty `.PHONY` target / no tool call | 1 / 1 / 1 |
| real `make -n` failure | 2 |
| old Makefile | 1 (14 lines of findings) |
| fixed worktree, full script (static and runtime, decoys) | 0 (`f1-fixed.log`) |
| `pre-commit run --files <15 staged files>` (shellcheck, shfmt included) | 0 (`precommit-2.log`) |

## What to review

- Are F1.1, F1.2 and F1.3 resolved? Do the new checks introduce false failures or
  false passes? Consider:
  - `read -ra` on quoted words such as `'*.retry'`;
  - the `${words[*]:i-3:4}` join;
  - the `clean` recipe, which has `|| true` and redirections;
  - `make -C`.
- Is anything else from review 1's AC table now different?

The same limits as brief 1 apply: read-only, no `uv sync`, no non-dry-run of
`play`, `uninstall-opera` or `vault-*`, and no network.

## Output

Write `docs/missions/2026-11-05-make-venv-tools/review-2.md` (§5.5 format), nothing else.
