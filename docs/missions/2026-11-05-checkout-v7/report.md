# Report — 2026-11-05-checkout-v7

## Verdict

PASS. Dependabot PR #41 (`actions/checkout` 6 → 7) is rebased on `main`, green in
CI and mergeable. No workflow adjustment was needed. Codex review 1:
PASS_WITH_RESERVATIONS, one minor finding fixed. Merge is the owner's.

## Compatibility

Sources: GitHub releases v6.0.0, v6.0.3, v7.0.0, v7.0.1, v6.1.0; README and
`action.yml` at `v6`/`v7` (evidence dir
`~/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/`).

- Only breaking change in v7: checkout refuses fork PR code under
  `pull_request_target` / `workflow_run` unless `allow-unsafe-pr-checkout: true`.
  `ci.yml` triggers on `push` and `pull_request` only: not affected.
- The same change was backported as v6.1.0, and `v6` already points to it; `action.yml`
  is byte-identical at `v6` and `v7`. `@v7` = v7.0.1 (`3d3c42e`).
- Runner: `node24`, runner ≥ v2.327.1 (≥ v2.329.0 for authenticated git from Docker
  container actions). CI runner 2.338.2; no container action runs git.
- Git auth and credential persistence: unchanged since v6. Default
  `persist-credentials: true` stores the token in `$RUNNER_TEMP/git-credentials-*.config`
  through `includeIf.gitdir`; post-job cleanup removes it (CI log). No step runs git
  after checkout.
- Options used: none set; defaults in effect (`fetch-depth: 1`, `clean: true`,
  `submodules: false`, `lfs: false`, `set-safe-directory: true`) are unchanged.

## Changes

- `.github/workflows/ci.yml`: `actions/checkout@v6` → `@v7` in `lint` and `terraform`
  (Dependabot's commit, rebased by `@dependabot rebase` to `e55d4ec` on `main` `d16b322`).
- `BACKLOG.md`: #41 entry removed ("Nothing in progress."); new deferred improvement
  "CI — least-privilege `GITHUB_TOKEN`".
- `docs/missions/2026-11-05-checkout-v7/`: mission, review brief, review, this report.

Pushed fast-forward onto the existing PR branch; no new PR. Dependabot no longer
auto-rebases that branch.

## Executed verifications

| ID | Status | Evidence |
|---|---|---|
| AC1 | VERIFIED | `pr-state-initial.txt`: #41 open, BEHIND 37, only checkout PR open |
| AC2 | VERIFIED | release notes, README, identical `action.yml`, `ci.yml`, CI logs |
| AC3 | VERIFIED | `e55d4ec` parent = `d16b322` = `origin/main`; setup-python v7 kept |
| AC4a | VERIFIED | run 42097130590 on `e55d4ec`: lint, terraform success |
| AC4b | VERIFIED for `cc477cd` | run 42097936767 on `cc477cd`: lint, terraform success; PR `MERGEABLE`, `CLEAN`. The commit adding this report is checked after push (session reply) |
| AC5 | VERIFIED | `scope-diff.txt`: only the two checkout lines in workflows; no Python or other dependency change |
| AC6 | VERIFIED | BACKLOG diff; Codex review 1 |
| AC7 | VERIFIED | `pre-commit run --files` on all changed files exit 0, commit and pre-push hooks passed, dummy vault, `env_dirty=0` (`commit-1.env`, `precommit-2.log`, `commit-1.log`, `push-1.log`) |
| AC-SAFE | VERIFIED | main-tree snapshot `26141f2a…fe02a2` unchanged; both stashes unchanged; `agent-workflow-closeout` clean at `4a0bca0`; no secret read; no hook skipped |

## Review

- Review 1: PASS_WITH_RESERVATIONS. F1.1 [minor] AC5 status `see Log` → set to
  VERIFIED with `scope-diff.txt`. Reservations (final CI, hooks on all files,
  AC-SAFE) addressed above. Codex pane `w1Q:pC` closed.

## Limits

- Not executed: smoke VM and laptop (not applicable, CI-only change), `actionlint`
  (not a project tool), fresh network re-check by Codex (sandbox has no network).
- CI proves the workflow runs with v7, nothing about the laptop.
- Token hardening is out of scope: the repository default token is `write`
  (`repo-token-permissions.txt`; run 42097936767 l.28 `Contents: write` for a
  non-Dependabot push; the Dependabot run had read-only). Tracked in `BACKLOG.md`.
- If `main` moves before merge, rebase the branch by hand.

## Local state

- Main tree: `main` at `d16b322`, clean, unchanged.
- Worktree `../laptop-bootstrap-worktrees/checkout-v7`, branch `ci/checkout-v7`
  (no upstream); remove after merge.

## Next step (owner)

Merge PR #41: https://github.com/TiPunchLabs/laptop-bootstrap/pull/41.
