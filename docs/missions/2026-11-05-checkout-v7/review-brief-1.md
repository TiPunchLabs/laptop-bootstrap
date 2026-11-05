# Review brief 1 — 2026-11-05-checkout-v7

## Mission

- Id: `2026-11-05-checkout-v7`. Objective verbatim (French) in `mission.md`. Summary:
  bring Dependabot PR #41 (`actions/checkout` 6 → 7) to a verified, merge-ready state;
  analyse breaking changes, runner requirements, Git authentication, credential
  persistence and the options our workflows use; only useful adjustments; no merge,
  no laptop, no Python change, no other dependency bump.
- Worktree: this directory, branch `ci/checkout-v7` (no upstream), created from the
  rebased Dependabot head `e55d4ec` (parent `d16b322` = current `origin/main`).
- Push target: `dependabot/github_actions/actions/checkout-7` (PR #41), fast-forward.

## Diff under review

1. Committed by Dependabot: `git diff d16b322 HEAD` → `.github/workflows/ci.yml`,
   `actions/checkout@v6` → `@v7` in jobs `lint` and `terraform`.
2. Staged by Claude Code: `git diff --cached` → `BACKLOG.md` (#41 entry removed,
   "Nothing in progress.", new deferred entry "CI — least-privilege `GITHUB_TOKEN`"),
   `docs/missions/2026-11-05-checkout-v7/mission.md` (new). This brief and your
   review join the same commit.

## Evidence

`E=~/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/` (read-only for you):

- `pr-state-initial.txt` — `gh pr view 41`, PR searches, with `exit=0` lines.
- `upstream-release-notes.md` — release bodies v6.0.0, v6.0.3, v7.0.0, v7.0.1, v6.1.0.
- `readme-v7.md` — README at tag `v7` ("What's new" sections v5, v6, v7; usage block).
- `action-v6.yml`, `action-v7.yml`, `action-v6-v7.diff` (empty: files identical).
- `tag-shas.txt` — `v7` = `v7.0.1` = `3d3c42e…`; `v6` = `v6.1.0` = `d23441a…`.
- `repo-token-permissions.txt` — `default_workflow_permissions: write`; workflow triggers.
- `ci-run-42097130590.log` — CI on `e55d4ec` (merge `a50b6a5` into `d16b322`):
  l.1 runner `2.338.2`, l.17 `ubuntu-26.04`, l.48 `actions/checkout@v7 (SHA:3d3c42e…)`,
  l.51–66 inputs incl. `persist-credentials: true`, `allow-unsafe-pr-checkout: false`,
  `fetch-depth: 1`, l.72 git 2.56.0, l.111–115 token written to
  `$RUNNER_TEMP/git-credentials-*.config` via `includeIf.gitdir` (value masked `***`),
  l.145 `HEAD is now at a50b6a5`, l.188–201 post-job cleanup removing extraheader and
  includeIf. Jobs `lint`, `terraform` success. Only annotation: ubuntu-latest notice.
- `scope-diff.txt` — staged diff stat vs `origin/main`; scoped diff over `.github`,
  `ansible.cfg`, `pyproject.toml`, `.python-version`, `uv.lock` (checkout lines only);
  `uses:` list (setup-python v7, setup-uv v7, setup-terraform v4 unchanged).
- `precommit-1.log`, `precommit-1.env` — hooks below.

## Checks run by Claude Code

- `uv run pre-commit run --files .github/workflows/ci.yml BACKLOG.md docs/missions/2026-11-05-checkout-v7/mission.md`,
  dummy vault, `env_dirty=0` → exit 0 (`precommit-1.env`); 9 hooks Passed, rest Skipped.
- CI run 42097130590 on `e55d4ec` → success.

Not run: smoke VM / laptop (no role, var or playbook change); `actionlint` (not a
project tool); CI on the final heads (after push; AC4b).

## What to review

- Is "no adaptation needed" correct for our real `ci.yml` (triggers, no `with:`, no
  post-checkout git, no container action) against the v7 breaking change, runner
  requirements, Git auth and credential persistence?
- Is the token-hardening item correctly kept out of this PR and accurately described
  in `BACKLOG.md` (not a v7 change, evidence-based)?
- Scope: only checkout lines in workflows; no Python or other dependency change.
- `BACKLOG.md` per `docs/agent-workflow.md` §8; mission file claims vs evidence;
  every `VERIFIED` backed; hard rules in `CLAUDE.md`.

## Output

Write `docs/missions/2026-11-05-checkout-v7/review-1.md` in the §5.5 format, nothing else.
