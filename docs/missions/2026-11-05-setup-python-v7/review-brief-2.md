# Review brief 2 — 2026-11-05-setup-python-v7

Same mission, worktree, branch and base as `review-brief-1.md`; read it for context.
Diff: `git diff 7a7c1b7 HEAD` (Dependabot bump, unchanged) and `git diff --cached`
plus the untracked `review-1.md` (Codex's own review, to be committed as is).

## Resolution of review-1 findings

- F1.1 [major] AC1 without PR-state evidence — fixed. Saved
  `$E/pr-state.txt` (commands, JSON output, `exit=0` for each): PR #45 `OPEN`,
  `app/dependabot`, head `4cd6792`, base `main`, `MERGEABLE`, not draft; search
  `setup-python` across all states → only #45 open (#2 = old 5→6, closed); open PRs →
  #45 and #41 (`actions/checkout` 6 → 7, created 2026-06-25), which supports the
  BACKLOG follow-up; last PR comment is the `@dependabot rebase` at 16:22:10Z.
  Quoted in `mission.md` AC1. The pre-rebase head `d30bf4a` comes from the first
  `gh pr view 45` of the session (not saved to a file; stated as such in the Log).
- F1.2 [minor] AC4 claimed for the final head — fixed. AC4 split: AC4a (rebased
  Dependabot head `4cd6792`, run 42063873439) VERIFIED with log lines quoted; AC4b
  (final head after the bookkeeping commit) NOT_VERIFIED, pending push.
- Reservation 3 (EOL wording) — settled with evidence: `$E/upstream-pr1333-files.txt`
  (`gh api repos/actions/setup-python/pulls/1333/files`) lists only upstream test
  workflows under `.github/workflows/` and `__tests__/data/Pipfile{,.lock}`; no
  `src/` or `dist/` change. Mission table wording updated accordingly.

## Checks rerun

- `uv run pre-commit run --files .github/workflows/ci.yml BACKLOG.md docs/missions/2026-11-05-setup-python-v7/{mission.md,review-brief-1.md,review-1.md,review-brief-2.md}`
  with dummy vault, `env_dirty=0` → see `$E/precommit-2.log` (result quoted in the
  terminal before this prompt: exit 0 expected; if the log says otherwise, it is a finding).

## What to review

Whether F1.1 and F1.2 are resolved, whether any status in `mission.md` is still
unsupported, and anything new in the staged changes. AC4b and AC-SAFE are expected
to stay NOT_VERIFIED until push / report time.

## Output

Write `docs/missions/2026-11-05-setup-python-v7/review-2.md` (§5.5 format), nothing else.
