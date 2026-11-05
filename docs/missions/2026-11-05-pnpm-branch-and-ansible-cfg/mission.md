# Mission 2026-11-05-pnpm-branch-and-ansible-cfg — obsolete pnpm branch + Python-independent `ansible.cfg`

## Objective

User's words (English, verbatim, abridged only where marked):

> Objective: complete two BACKLOG items in TiPunchLabs/laptop-bootstrap:
> 1. Safely remove the obsolete fix/pnpm-home-after-mise branch.
> 2. Remove the Python 3.12-specific path in ansible.cfg so the project remains consistent with the environment created by uv sync.
>
> Follow CLAUDE.md and docs/agent-workflow.md. Work autonomously through investigation, implementation, verification, independent Codex review via Herdr, and delivery. Keep the two workstreams distinct in the mission record.
>
> […full text: authorizations (inspect; delete the branch locally and remotely after proving integration; isolated worktree, scoped changes, local and smoke checks where relevant, commit, push, open a PR for the Python fix; remove disposable resources, preserve evidence), exclusions (no merge, no laptop provisioning, no change to its active environment, no deletion of unrelated resources), Workstream 1 and 2 requirements, verification list, Codex review, preservation rules, deliverables.]

## Authorizations

Granted: inspection; deletion of `fix/pnpm-home-after-mise` (local + remote) after
proof; worktree; scoped changes; local and smoke checks; commit, push, open PR;
removal of this mission's disposable resources. Not granted: merge, laptop
provisioning or environment change, deletion of unrelated resources.

User decision (2026-11-05, during this mission): approved option "Local hook,
locked lint" — the ansible-lint pre-commit hook runs `uv run --no-sync ansible-lint`
(locked 26.1.1) instead of the remote hook v24.12.2 + `ansible-core<2.19`, and
`ansible.cfg` gets an empty `collections_path`. Alternatives presented: keep the
remote hook and add `ansible` to its dependencies; stop and keep the path.

## Initial state

- Main tree: `main` = `origin/main` = `5ccad81`, clean. Snapshot baseline
  `$E/main-tree-snap-baseline.txt` = `ac6d357d…c19362e`.
- Stashes (`$E/stash-list-baseline.txt`): `8556ec79…` (ship/vault-and-smoke),
  `3b790fdf…` (feat/smoke-test-vagrant).
- Other resources: worktree `agent-workflow-closeout` (`4a0bca0`), branches
  `docs/agent-workflow-closeout`, remote `docs/readme-refresh`, `feat/mise-autonomy`,
  `feat/mise-node-pnpm`: not touched.

`E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-branch-and-ansible-cfg/`.

------

## Workstream 1 — obsolete branch `fix/pnpm-home-after-mise`

### Integration proof (`$E/ws1-integration-proof.txt`, `$E/ws1-content-evolution.txt`)

- Local and remote branch both at `674c2bfadbe3eebe82108ea42e833cef3f92df81`; one
  commit not in `main` (`674c2bf fix(cli_tools): move PNPM_HOME behind mise-managed binaries`).
- Ancestry: `674c2bf` NOT an ancestor of `main` (expected: squash merge); PR #50
  `MERGED` 2026-10-23, head `674c2bf`, merge commit `5a7fcfd` (ancestor of `main`).
- `5a7fcfd` parent = `2a7e1c2` = branch merge-base; trees identical
  (`54f43640…` both); `git diff 5a7fcfd 674c2bf` exit 0.
- `git patch-id --stable`: `66edef6c…` for both commits; `git cherry -v main branch`
  marks it `-` (equivalent change upstream).
- Current `main`: the task added by `674c2bf` is at
  `roles/cli_tools/tasks/main.yml:69-75` with the same name, regexp and replacement;
  only the comment was extended later by `4bf8f32` (#59, pnpm ≥ 11 block), which
  also added a follow-up task. Nothing from the branch is missing.
- No worktree on the branch, no open PR with that head (`gh pr list --head` → `[]`),
  reflog: created from `2a7e1c2`, one commit. A branch not checked out anywhere
  holds no uncommitted work.

### Deletion (`$E/ws1-deletion.log`, dummy vault, `env_dirty=0`)

- Refs re-checked at `674c2bf` immediately before deletion.
- `git branch -d fix/pnpm-home-after-mise` → exit 0 ("merged to
  refs/remotes/origin/fix/pnpm-home-after-mise, but not yet merged to HEAD").
  Forced deletion was not needed.
- `git push origin --delete fix/pnpm-home-after-mise` → exit 0 (pre-push hook ran);
  `git ls-remote` afterwards empty; commit `674c2bf` still in the object store.
- `BACKLOG.md`: Cleanup entry removed ("Nothing to clean up.").

------

## Workstream 2 — Python-independent `ansible.cfg`

### Root cause

- `ansible.cfg:3` (since the initial commit `f8ec34b`, no recorded rationale):
  `collections_path = ./.venv/lib/python3.12/site-packages/ansible_collections`.
- Consumers traced: `make play*`/`lint-ansible` (binaries from the direnv-activated
  `.venv`), CI (`uv run …`), smoke (`test/smoke/ansible.cfg`, VM's apt Ansible —
  not this file), pre-commit ansible-lint hook (remote repo v24.12.2 in a
  pre-commit-managed venv with `jmespath`, `ansible-core<2.19`, **no collections**).
- ansible-core `_collection_finder.py:185-213`: configured paths first, then
  `sys.path`, keeping only dirs that contain `ansible_collections`. So every run
  from the uv venv finds the venv's collections through `sys.path` on any Python;
  only the pre-commit hook, which runs outside the venv, needs the hardcoded path.
- Reproduction (`$E/ws2-repro-hook-3.14.log`): venv on Python 3.14, original
  config → hook exit 1, `syntax-check[unknown-module]: couldn't resolve
  module/action 'community.general.xml'` at `roles/syncthing/tasks/main.yml:50`.
  `$E/ws2-repro-3.14-current-cfg.txt`: venv runs still find community.general 12.2.0
  via `sys.path` while the configured `python3.12` path does not exist.
- Removing the line alone is wrong (`$E/ws2-cfg-variants-3.14.txt`): the default
  `COLLECTIONS_PATHS` (`~/.ansible/collections:/usr/share/ansible/collections`) then
  precedes `sys.path`, and `community.general.xml` resolves to
  `~/.ansible/collections` (11.4.7 on this laptop) instead of the venv (12.2.0).

### Solution (approved by the user)

- `ansible.cfg`: `collections_path =` (empty, with a comment). Resolves to the
  project dir, which has no `ansible_collections`, so it is dropped; only the
  running interpreter's `sys.path` (the uv venv) is searched — same "venv only"
  behaviour as before, without the Python version.
- `.pre-commit-config.yaml`: ansible-lint hook becomes a `repo: local`,
  `language: system` hook, `entry: uv run --no-sync ansible-lint -v --force-color`,
  `pass_filenames: false`, `always_run: true` (same as upstream's hook definition).
  It runs the `uv.lock` ansible-lint 26.1.1 — the one CI runs. `uv.lock`,
  `pyproject.toml` and the supported Python range are unchanged.
- Docs: `docs/agent-workflow.md` §3 (`uv sync --frozen`, no `--python 3.12`),
  `README.md` and `CONTRIBUTING.md` setup (hook runs from `.venv`),
  `docs/guide-daily-usage.md` troubleshooting (new entry), `BACKLOG.md` (Watch
  entry removed). Historical specs/plans and past mission reports untouched.

### Verification (`$E/ws2-matrix-summary.txt`, script `$E/matrix.sh`)

Each interpreter: `uv sync --frozen --python X`, `ansible-config dump`,
`ansible-galaxy collection list`, plugin-loader resolution of `community.general.xml`,
`ansible-playbook playbook.yml --syntax-check`, `ansible-lint`, `yamllint .`,
`pre-commit run ansible-lint --all-files`. Dummy vault, `env_dirty=0`, `VIRTUAL_ENV`
unset and other `.venv/bin` removed from `PATH`.

| Python | ansible-core | community.general (resolved from) | syntax | lint | yamllint | hook |
|---|---|---|---|---|---|---|
| 3.12.12 | 2.20.1 | 12.2.0 (`.venv/lib/python3.12/…`) | 0 | 0 | 0 | 0 |
| 3.14.7 | 2.20.1 | 12.2.0 (`.venv/lib/python3.14/…`) | 0 | 0 | 0 | 0 |
| 3.11.17 | 2.19.5 | 11.4.2 (`.venv/lib/python3.11/…`) | 0 | 0 | 0 | 0 |

`~/.ansible/collections` (11.4.7) is never selected. `$E/ws2-hook-binary.txt`: the
hook command resolves to the worktree's `.venv/bin/ansible-lint` 26.1.1
(ansible-core 2.20.1, `sys.prefix` = worktree `.venv`).

Smoke VM: NOT_APPLICABLE — the VM loads `test/smoke/ansible.cfg`
(`test/smoke/Vagrantfile:52`) and its own apt Ansible; neither changed file is used
there. Laptop: not run (owner only).

------

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| WS1-AC1 | Branch content proven integrated in `main` | tree, patch-id, cherry, current implementation | VERIFIED |
| WS1-AC2 | No unique work, worktree, open PR or session lost | worktree list, `gh pr list --head`, reflog | VERIFIED |
| WS1-AC3 | Branch deleted locally and remotely, safe `-d` | `$E/ws1-deletion.log` | VERIFIED |
| WS2-AC1 | Original mismatch reproduced in isolation | `$E/ws2-repro-hook-3.14.log` | VERIFIED |
| WS2-AC2 | No Python-version path in active config; collections resolve from the uv venv | `ansible.cfg`, matrix | VERIFIED |
| WS2-AC3 | Works on 3.12 and another supported Python | matrix 3.12, 3.14 (+3.11) | VERIFIED |
| WS2-AC4 | No Python pin, no dependency/lock change, range unchanged | `$E/ws2-scope.txt`: `git diff origin/main --stat -- uv.lock pyproject.toml .python-version .github` empty; no `.python-version`; no active `python3.12` / `--python 3.12` / `ansible-core<2.19` / `v24.12.2` reference left | VERIFIED |
| WS2-AC5 | Active docs updated, history untouched | diff review, grep | VERIFIED |
| AC-HOOKS | pre-commit on all changed files, commit and push hooks pass (dummy vault, clean env) | logs | NOT_VERIFIED (pending) |
| AC-CI | CI green on the final pushed SHA incl. report commit | GitHub runs | NOT_VERIFIED (pending) |
| AC-SAFE | Main tree, stashes, unrelated resources preserved; no secret read | snapshot, stash list | NOT_VERIFIED (report time) |

## State

- Phase: deliver
- Branch / worktree: `fix/ansible-cfg-python-path` / `../laptop-bootstrap-worktrees/ansible-cfg-python-path`
- Base commit: `5ccad81`
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-branch-and-ansible-cfg/`
- Reviewer: herdr agent `lb-review`, pane `w1Q:pD`
- Review cycle: 1 of 3
- Next step: commit, push, open PR, CI, report

## Log

- 2026-11-05 WS1 inspect + proof; WS1 local and remote deletion (exit 0 each).
- 2026-11-05 WS2 root cause traced; 3.14 hook failure reproduced; cfg variants compared.
- 2026-11-05 decision: user approved local hook + empty `collections_path`.
- 2026-11-05 WS2 implement + matrix 3.12/3.14/3.11 all exit 0.
- 2026-11-05 verify: `pre-commit run --files` on the 8 staged files, dummy vault, `env_dirty=0` → exit 0 (`precommit-1.log`).
- 2026-11-05 review-1: PASS_WITH_RESERVATIONS, no findings. Reservations: empty `collections_path` is not an enforced venv boundary (repo-local `ansible_collections`, extra sys.path or env overrides still count); `uv run --no-sync` trusts the existing `.venv` (needs `uv sync`, documented); the 3.14 reproduction inherited a foreign `VIRTUAL_ENV` that uv ignored.
