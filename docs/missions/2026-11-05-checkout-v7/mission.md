# Mission 2026-11-05-checkout-v7 — Dependabot PR #41, `actions/checkout` 6 → 7

## Objective

> Objectif : traiter la PR Dependabot #41 — actions/checkout v6 → v7 — jusqu’à une PR vérifiée et prête à fusionner.
>
> Dépôt cible : TiPunchLabs/laptop-bootstrap.
> Applique CLAUDE.md et docs/agent-workflow.md en autonomie, avec revue indépendante Codex via Herdr.
>
> Vérifie d’abord l’état réel de la PR et de main. Privilégie la PR existante et évite tout doublon.
>
> Analyse les notes de version officielles et les changements incompatibles : exigences des runners, authentification Git, persistance des credentials et comportement des options utilisées dans nos workflows. Détermine les adaptations nécessaires à partir du code réel.
>
> Actualise la branche, réalise uniquement les ajustements utiles, puis exécute les contrôles pertinents. Fais revoir le diff et les preuves par Codex ; corrige les constats selon le workflow.
>
> Actualise BACKLOG.md et conserve un rapport de mission distinguant les vérifications exécutées des limites restantes. Vérifie la CI sur le dernier SHA poussé, y compris après ajout du rapport.
>
> Autorisations : inspection, worktree isolé, actualisation de la branche Dependabot, modifications ciblées, tests, revue Codex, commit, push et mise à jour de la PR.
>
> Préserve les deux stashes et les ressources des autres missions. Utilise l’environnement nettoyé et le dummy vault pour tous les contrôles et hooks concernés, y compris lors des commits et push.
>
> Aucune fusion, aucune application au laptop, aucun changement Python ni mise à jour d’autres dépendances.
>
> Poursuis sans confirmation intermédiaire pour les actions autorisées. Termine par un rapport concis : compatibilité, changements, verdict Codex, CI finale, lien et SHA de la PR, état local et limites éventuelles.

## Authorizations

Repository on a mission worktree; refresh of the Dependabot branch; commit, push,
PR update. Not granted: merge, laptop apply, Python change, other dependency bumps.

## Scope

In: `.github/workflows/ci.yml` (checkout major, both jobs), `BACKLOG.md`, this directory.
Out: any other action or dependency version, Python, roles/playbook, the token
hardening noted under Compatibility (recorded in `BACKLOG.md` instead).

## Initial state (2026-11-05)

- Main tree: `main` at `d16b322` (PR #45 merge), clean. Snapshot baseline
  `$E/main-tree-snap-baseline.txt` = `26141f2a…fe02a2`.
- Stashes: `8556ec79…` (ship/vault-and-smoke), `3b790fdf…` (feat/smoke-test-vagrant),
  saved in `$E/stash-list-baseline.txt`.
- Other mission resources: worktree `agent-workflow-closeout` (`4a0bca0`); not touched.
- PR #41 (`$E/pr-state-initial.txt`, all commands exit 0): `OPEN`, `app/dependabot`,
  created 2026-06-25, head `acc801e`, base `main`, `BEHIND` (37 commits behind,
  merge-base `89393ba`). Search `actions/checkout` all states: only #41 open (#1 = 4→6,
  closed). Only open PR in the repository.

`E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/`.

## Compatibility analysis (official sources)

Sources saved in `$E`: `upstream-release-notes.md` (GitHub releases v6.0.0, v6.0.3,
v7.0.0, v7.0.1, v6.1.0), `readme-v7.md` (README at `v7`, "What's new" for v5–v7),
`action-v6.yml`, `action-v7.yml`, `action-v6-v7.diff` (empty: identical), `tag-shas.txt`.
context7 not used for this: the action's own release notes and README are the source.

Use in `ci.yml` (both jobs): `- uses: actions/checkout@v6`, no `with:`; triggers
`push` (main) and `pull_request` (main); no `permissions:`; no git command after checkout.

| Topic | Change | Effect on our CI |
|---|---|---|
| Breaking (v7.0.0, PR #2454) | refuses to check out fork PR code under `pull_request_target` / `workflow_run` unless `allow-unsafe-pr-checkout: true` | none: neither trigger is used; CI log shows `allow-unsafe-pr-checkout: false` and a normal checkout on `pull_request` |
| Same change backported (v6.1.0, PR #2500, marked BREAKING) | `v6` tag = `v6.1.0` = `d23441a` | `main` already runs it: identical `action.yml` at `v6` and `v7` |
| Runtime / runner | `node24` (since v5), runner ≥ v2.327.1; v6: authenticated git from Docker container actions needs ≥ v2.329.0 | none: runner 2.338.2; no container action runs git |
| Credential persistence (since v6.0.0) | `persist-credentials` (default `true`) writes the token to `$RUNNER_TEMP/git-credentials-*.config`, linked via `includeIf.gitdir`, removed in post-job cleanup | unchanged by v7; CI log l.111–115 (token masked `***`) and l.200 cleanup |
| ESM migration, dependency updates (v7.0.0); v7.0.1 fixes (unsafe-PR check skip when input is default, ASCII trim of branch, escaped `--unset`) | internal | none |
| Options we rely on (defaults) | `fetch-depth: 1`, `clean: true`, `submodules: false`, `lfs: false`, `set-safe-directory: true` | unchanged; shown at CI log l.57–66 |

Conclusion: no workflow adjustment beyond the version bump. Observation outside v7:
repository default workflow permission is `write` (`$E/repo-token-permissions.txt`)
and `ci.yml` declares no `permissions:`; recorded as a deferred hardening in `BACKLOG.md`.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | PR #41 and `main` state established; no duplicate | `$E/pr-state-initial.txt` (exit 0 each) | VERIFIED |
| AC2 | Breaking changes, runner, Git auth and credential persistence assessed against `ci.yml`; required adaptations identified | release notes, README, `action.yml` diff, `ci.yml`, CI log | VERIFIED (none required) |
| AC3 | Dependabot branch rebased on current `main` without losing setup-python v7 | `git merge-base` = `d16b322`; `git diff origin/main e55d4ec` = the two checkout lines only | VERIFIED |
| AC4a | CI green on the rebased Dependabot head with checkout v7 | run 42097130590 on `e55d4ec`: lint, terraform success; log l.48 `actions/checkout@v7 (SHA:3d3c42e…)`, l.145 merge commit checked out | VERIFIED |
| AC4b | CI green on the final pushed head, including after the report commit | runs on final SHAs | VERIFIED (run 42097936767 on `cc477cd`; report commit checked after push) |
| AC5 | Diff limited to checkout v6 → v7, `BACKLOG.md`, mission files; no Python or other dependency change | `$E/scope-diff.txt`: stat = `ci.yml` (4 lines), `BACKLOG.md`, mission files; scoped diff over `.github`, `ansible.cfg`, `pyproject.toml`, `.python-version`, `uv.lock` = the two checkout lines only | VERIFIED |
| AC6 | `BACKLOG.md` updated (§8) | diff review | VERIFIED |
| AC7 | Hooks pass with dummy vault and cleaned environment, including commit and push | `pre-commit run --files`, commit and push logs | VERIFIED (`commit-1.env`, `precommit-2.log`, `commit-1.log`, `push-1.log`) |
| AC-SAFE | Main tree, stashes, other worktree preserved; no secret read; hooks not bypassed | snapshot compare, stash list, worktree list | VERIFIED (see report) |

## Plan

1. `@dependabot rebase` (done, 19:45:54Z) → `e55d4ec`.
2. Worktree `../laptop-bootstrap-worktrees/checkout-v7`, branch `ci/checkout-v7`, upstream unset.
3. BACKLOG: remove #41 entry; add deferred token-hardening entry.
4. Hooks, Codex review, fixes.
5. Commit, push fast-forward to `dependabot/github_actions/actions/checkout-7`; CI.
6. Report, commit, push; CI on the final SHA.

## State

- Phase: done
- Branch / worktree: `ci/checkout-v7` / `../laptop-bootstrap-worktrees/checkout-v7`
- Base commit: `e55d4ec` (Dependabot rebase onto `d16b322`)
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-05-checkout-v7/`
- Reviewer: herdr agent `lb-review`, pane `w1Q:pC` (closed)
- Review cycle: 1 of 3
- Next step: owner merges PR #41

## Log

- 2026-11-05 inspect: PR #41 `BEHIND` 37 commits, head `acc801e`; no duplicate.
- 2026-11-05 inspect: `@dependabot rebase` 19:45:54Z → `e55d4ec` on `d16b322`.
- 2026-11-05 verify: CI run 42097130590 on `e55d4ec` success.
- 2026-11-05 verify: `pre-commit run --files` (ci.yml, BACKLOG.md, mission.md), dummy vault, `env_dirty=0` → exit 0 (`precommit-1.env`).
- 2026-11-05 review-1: PASS_WITH_RESERVATIONS; F1.1 [minor] AC5 status `see Log` → fixed (VERIFIED with `scope-diff.txt`).
- 2026-11-05 note: the Dependabot-triggered run gets a read-only token whatever the repository default; the BACKLOG entry describes the repository default only.
- 2026-11-05 commit/push: `cc477cd` fast-forward onto PR #41 (hooks passed); CI run 42097936767 success.
- 2026-11-05 report: AC-SAFE checked; Codex pane closed.
