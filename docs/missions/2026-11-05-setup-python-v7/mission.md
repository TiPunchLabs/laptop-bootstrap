# Mission 2026-11-05-setup-python-v7 — Dependabot PR #45, `actions/setup-python` 6 → 7

## Objective

> Objectif : traiter le chantier « Maintenance CI » de BACKLOG.md, concernant la PR Dependabot #45 — actions/setup-python v6 → v7.
>
> Dépôt cible exclusivement : TiPunchLabs/laptop-bootstrap.
>
> Applique CLAUDE.md et docs/agent-workflow.md. Pilote le chantier en autonomie avec revue indépendante Codex via Herdr, jusqu’à une PR prête à fusionner.
>
> Commence par vérifier l’état réel du backlog et de la PR #45. Si elle est déjà traitée ou remplacée, établis la situation avant toute modification et évite de créer un doublon.
>
> Investigue la mise à jour à partir des notes de version officielles : changements incompatibles, exigences du runner et effets sur notre CI. Ne change pas la version Python du projet ; le chemin Python 3.12 codé en dur dans ansible.cfg reste un chantier distinct.
>
> Actualise la branche Dependabot si nécessaire, réalise les ajustements strictement utiles et vérifie les contrôles concernés. Privilégie la PR existante ; ne crée une nouvelle PR que si nécessaire, en expliquant pourquoi.
>
> Fais revoir le diff et les preuves par Codex via Herdr. Corrige les constats selon les limites du workflow. Mets à jour BACKLOG.md et la documentation uniquement lorsque le changement le justifie.
>
> Autorisations : inspection, branche/worktree isolé, modifications ciblées ; actualisation de la PR Dependabot ; tests, revue Codex et corrections ; commit, push et création ou mise à jour de PR.
>
> Préserve les modifications utilisateur, les deux stashes et les ressources des autres missions. Utilise le dummy vault et l’environnement nettoyé pour tous les contrôles et hooks concernés, y compris ceux de commit et push.
>
> Ne fusionne pas la PR et n’applique rien au laptop. Ne demande pas de confirmation intermédiaire pour les opérations autorisées.
>
> Termine par un rapport concis : compatibilité constatée, changements, verdict Codex, résultats CI, lien et SHA final de la PR, limites éventuelles et état local.

## Authorizations

Default: repository on a mission branch/worktree. Extra, granted in the objective:
refresh of the Dependabot PR, commit, push, PR update (or creation if needed).
Not granted: merge, laptop apply, smoke-down.

## Scope

In: `.github/workflows/ci.yml` (setup-python major), `BACKLOG.md`, this mission directory.
Out: project Python version, `ansible.cfg` Python 3.12 path (separate Watch entry),
PR #41 (`actions/checkout` 6 → 7, separate Dependabot PR), any role or playbook.

## Initial state (2026-11-05)

- Main tree: `main` at `7a7c1b7`, clean. Snapshot baseline
  `~/.local/share/laptop-bootstrap-agent/2026-11-05-setup-python-v7/main-tree-snap-baseline.txt`
  = `fe6aca0d…33bc5a`.
- Stashes: `stash@{0}` `8556ec79…` (ship/vault-and-smoke), `stash@{1}` `3b790fdf…`
  (feat/smoke-test-vagrant). Baseline in `stash-list-baseline.txt`.
- Other mission resources: worktree `../laptop-bootstrap-worktrees/agent-workflow-closeout`
  (branch `docs/agent-workflow-closeout`); not touched.
- `BACKLOG.md` "In progress" lists PR #45 only. PR #45 open, not replaced (no other
  setup-python PR open), head `d30bf4a`, based on `48a2c49`, 31 commits behind `main`.
  PR #41 (`actions/checkout` 6 → 7) is also open and not tracked in `BACKLOG.md`.

## Compatibility analysis (official sources)

Sources, saved under the evidence dir: GitHub releases of `actions/setup-python`
(`upstream-release-notes.md`), `action.yml` at `v6` and `v7` (`action-v6-v7.diff`),
tag SHAs (`tag-v7-sha.txt`). context7 only indexes setup-python v5, so it was not usable.

| Topic | v6 | v7 | Effect on `ci.yml` |
|---|---|---|---|
| Runtime | `node24` | `node24` (ESM build) | none; runner ≥ 2.327.1 already required since v6 |
| Inputs | … `pip-install` … | `pip-install` removed; `mirror`, `mirror-token` added | none: we only pass `python-version: '3.12'` |
| Python versions | — | "Remove EOL Python versions" (upstream PR #1333): touches only upstream test workflows and `__tests__/data` (`upstream-pr1333-files.txt`) | none: 3.12 resolves (3.12.16 in CI) |
| Behaviour | — | manifest fetch validated and retried; stderr warnings annotated as warnings | none / slightly more robust |
| Major tag | — | `v7` = `v7.1.0` = `6d4fd22` | CI runs v7.1.0 |

Hosted runner in CI: `2.338.2`, image `ubuntu-26.04`.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | PR #45 state established, no duplicate PR | `pr-state.txt`: `gh pr view 45` → exit 0, `OPEN`, author `app/dependabot`, head `dependabot/github_actions/actions/setup-python-7` @ `4cd6792`, base `main`, `MERGEABLE`; `gh pr list --state all --search setup-python` → exit 0, only #45 open (#2 closed 5→6); `gh pr list --state open` → exit 0, #45 and #41 (`actions/checkout` 6 → 7, opened 2026-06-25) | VERIFIED |
| AC2 | Breaking changes and runner requirements assessed from official notes; none affects `ci.yml` | release notes + `action.yml` diff vs inputs used in `ci.yml` | VERIFIED |
| AC3 | Dependabot branch up to date with `main` | `git merge-base origin/dependabot/…/setup-python-7 origin/main` = `origin/main` | VERIFIED |
| AC4a | CI green with setup-python v7 on the rebased Dependabot head, Python 3.12 unchanged | run 42063873439 on `4cd6792`: lint + terraform `success`; log l.269 `actions/setup-python@v7 (SHA:6d4fd22…)`, l.381 `Successfully set up CPython (3.12.16)` | VERIFIED |
| AC4b | Same on the final PR head (after the bookkeeping commit) | run on the final head SHA, job conclusions | VERIFIED (run 42066320239 on `cdeb5b3`: lint, terraform success; PR `MERGEABLE`/`CLEAN`) |
| AC5 | Workflow diff limited to the major bump; project Python version and `ansible.cfg` untouched | `git diff origin/main -- .github ansible.cfg pyproject.toml .python-version` | VERIFIED |
| AC6 | `BACKLOG.md` updated per §8 (entry removed; untracked follow-up recorded) | diff review | VERIFIED |
| AC7 | Local pre-commit hooks pass on changed files with dummy vault and cleaned env | `pre-commit run --files …` | VERIFIED (exit 0; commit and pre-push hooks passed) |
| AC-SAFE | Main tree, both stashes, other worktree preserved; no secret read; hooks not bypassed | snapshot compare, `git stash list`, `git worktree list` | VERIFIED (see report) |

## Plan

1. `@dependabot rebase` on PR #45 (Dependabot keeps authorship of its commit).
2. Worktree `../laptop-bootstrap-worktrees/setup-python-v7` on branch
   `ci/setup-python-v7` from the rebased Dependabot head, upstream unset.
3. No workflow adjustment needed (AC2). Remove the #45 entry from `BACKLOG.md`,
   record PR #41 as an untracked follow-up.
4. Local hooks on changed files; Codex review; fixes.
5. Commit, push to `dependabot/github_actions/actions/setup-python-7` (explicit
   refspec) so PR #45 carries the change; no new PR. Check CI on the final head.
6. Report.

Why no new PR: the existing PR already holds the only required code change; adding
the bookkeeping commit on top keeps one PR. Side effect: once a non-Dependabot commit
is on the branch, Dependabot stops rebasing it automatically; acceptable because the
PR is meant to be merged now.

## State

- Phase: done
- Branch / worktree: `ci/setup-python-v7` / `../laptop-bootstrap-worktrees/setup-python-v7`
- Base commit: `4cd6792` (Dependabot rebase onto `7a7c1b7`)
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-05-setup-python-v7/`
- Reviewer: herdr agent `lb-review`, pane `w1Q:pB` (closed)
- Review cycle: 2 of 3
- Next step: owner merges PR #45

## Log

- 2026-11-05 inspect: PR #45 open, head `d30bf4a` (pre-rebase, from the first `gh pr view 45`), 31 commits behind main; #41 open and untracked.
- 2026-11-05 inspect: `@dependabot rebase` posted 16:22Z; Dependabot pushed `4cd6792`.
- 2026-11-05 verify: CI run 42063873439 on `4cd6792` success (lint, terraform).
- 2026-11-05 review-1: CHANGES_REQUESTED (F1.1 PR-state evidence missing, F1.2 AC4 final head claimed early).
- 2026-11-05 fix-1: saved `pr-state.txt` and `upstream-pr1333-files.txt`; AC1 evidence quoted; AC4 split into AC4a (VERIFIED) / AC4b (pending).
- 2026-11-05 verify: `pre-commit run --files` (ci.yml, BACKLOG.md, mission docs), dummy vault, `env_dirty=0` → exit 0 (`precommit-2.log`).
- 2026-11-05 review-2: PASS_WITH_RESERVATIONS, no findings; reservations: verify final-head CI and AC-SAFE before reporting.
- 2026-11-05 commit/push: `cdeb5b3` pushed fast-forward onto PR #45 (hooks passed); CI run 42066320239 success.
- 2026-11-05 report: AC-SAFE checked (main tree, stashes, other worktree unchanged); Codex pane closed.
