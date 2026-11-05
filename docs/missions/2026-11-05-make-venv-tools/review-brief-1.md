# Review brief 1 — 2026-11-05-make-venv-tools

## Mission

- Id `2026-11-05-make-venv-tools`. Objective (verbatim), authorizations, the
  correction of PR #60's completion claim, the proven root cause and the acceptance
  criteria are in `mission.md` (read it first).
- Worktree: this directory, branch `fix/make-venv-tools` (no upstream), base
  `b4f5ab5` (= origin/main, PR #60 merged). `.venv` is on Python 3.12.12, like the
  laptop's main checkout.
- Short version: after PR #60 emptied `collections_path`, `make lint-ansible` ran a
  bare `ansible-lint` resolved through PATH. On the owner's shell that was pipx's
  26.9.0 (`~/.local/bin`), which has no collections, so it failed on
  `community.general.xml`.

## Diff under review (`git diff --cached --stat`, all staged, nothing committed)

- `Makefile`: `VENV_RUN ?= uv run --no-sync .venv/bin`, used for `play`,
  `uninstall-opera`, `lint`, `lint-ansible`, `vault-edit`, `vault-view` and `clean`.
- `.pre-commit-config.yaml`: the ansible-lint hook entry becomes
  `uv run --no-sync .venv/bin/ansible-lint -v --force-color` (was
  `uv run --no-sync ansible-lint …`).
- `bin/check_make_venv_tools.sh` (new) and a CI step in `.github/workflows/ci.yml`.
- Docs: `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `docs/agent-workflow.md` §3,
  `docs/guide-daily-usage.md`, `roles/obsidian/README.md`, `roles/syncthing/README.md`.
- `BACKLOG.md`: two new entries.
  - Cleanup: `.claude/commands` bare calls.
  - Watch: a fresh `uv sync` picks Python 3.15, where the `rpds-py` build fails.
- `docs/missions/2026-11-05-make-venv-tools/mission.md` (new).

## Why `uv run --no-sync .venv/bin/<tool>` (design choices to challenge)

- A bare `uv run --no-sync ansible-lint`, as in PR #60's hook, silently creates an
  empty `.venv` when none exists, then runs the PATH copy. Evidence: scratch test
  in this session, summarised in mission.md, root cause item 5.
- `.venv/bin/<tool>` alone is not enough. With `~/.local/bin` ahead of `.venv/bin`,
  ansible-lint spawns `ansible` and `ansible-config` from PATH and aborts with
  "Ansible CLI (2.21.5) and python module (2.20.1) versions do not match"
  (`after-make-lint-ansible-ownerpath.log`).
- With the combined form, uv puts `.venv/bin` first and the explicit path never
  falls back. A missing venv fails with "Failed to spawn".

## Evidence

All of it is in `E=~/.local/share/laptop-bootstrap-agent/2026-11-05-make-venv-tools/` (readable):

- Diagnosis: `diag-laptop-paths.txt`, `before-molecule-probe.txt`,
  `before-make-lint-ansible-ownerpath.log`, `control-pre60-cfg.log` (pre-#60 cfg
  used: `pre60-control.cfg.used`), `before-make-lint-ansible-venvfirst.log`,
  `worktree-uv-sync.log` (Python 3.15 failure).
- Verification: `verify.sh` (the script) and `verify-summary-final.txt`.
  - Per-check logs: `v-*.log`.
  - Variant test: `v-check-variant-runtime-real.log`, `fixed-before-variant.patch`
    and `fixed-after-variant.patch`, which are identical.
  - `scope.txt`, `bare-calls-left.txt`, `precommit-1.log`.
- Safety baselines: `main-tree-snap-baseline.txt`, `main-venv-baseline.txt`,
  `stash-list-baseline.txt`.

## Checks run by Claude Code

All ran with the dummy vault, `env_dirty=0` and `VIRTUAL_ENV` unset. The
owner-like PATH is `~/.local/bin:<worktree>/.venv/bin:…`.

| Check | Exit |
|---|---|
| regression check on origin/main tree (scratch export) | 1 (static: 7 recipes flagged) |
| regression check on explicit-path-only variant, in this worktree | 2 (decoy `ansible-config` reached) |
| regression check on the fix | 0 |
| owner PATH: `make lint-ansible` / hook / with `VIRTUAL_ENV`=main `.venv` | 0 / 0 / 0 |
| no `.venv`: `make lint-ansible` / hook | 2 / 1, "Failed to spawn: .venv/bin/ansible-lint" |
| `--syntax-check` playbook, uninstall-opera; ansible-lint; yamllint | 0 each |
| `pre-commit run --files <13 staged files>` | 0 |

Not run:
- `make play*`, `make uninstall-opera` and `make vault-*` were never executed;
  only `make -n` (prints, runs nothing), because they act on the laptop or the vault.
- The smoke VM: NOT_APPLICABLE, because Ansible runs in the VM with
  `test/smoke/ansible.cfg`.
- CI: it runs after the push.
- Nothing was run on the laptop, and its main checkout `.venv` was never used for
  writing.

## What to review

- Is the root cause proven, as distinct from hypothesis? In particular, the
  `~/.bashrc:161` ordering mechanism is marked as a hypothesis for how the owner's
  shell got its PATH.
- Is the fix correct and minimal for every entry point?
  - Makefile targets.
  - The hook. pre-commit may itself run from `~/.local/bin`, a uv tool v4.6.2.
  - Recipes under `cd $(SMOKE_DIR)`.
  - `make -C`.
  - A foreign `VIRTUAL_ENV`.
  - `uv run`'s side effect of creating `.venv` when it is absent.
- Does `bin/check_make_venv_tools.sh` really catch this mismatch, and can it pass
  falsely?
  - The word-splitting loop.
  - The `case` pattern.
  - A `.venv` symlink weakening the runtime half (seen in a scratch copy).
  - CI prerequisites: `uv sync`, `ANSIBLE_VAULT_PASSWORD_FILE`, git checkout,
    `make` available.
- The hard rules in `CLAUDE.md`: hooks not weakened, no secret read, and no laptop
  action (is `make -n` of `play` and `vault-*` acceptable?).
- Are the docs accurate and complete? Is the correction of PR #60's claim fair and
  sufficient, with the history left untouched?
- Proportionality: is a script plus a CI step justified?

You may rerun read-only checks, for example `make -n <target>`,
`bash bin/check_make_venv_tools.sh`, `.venv/bin/ansible-lint` and
`.venv/bin/ansible-playbook … --syntax-check`, with
`ANSIBLE_VAULT_PASSWORD_FILE` already set in your pane. Do not run `uv sync`,
anything that executes `make play*`, `make uninstall-opera` or `make vault-*`
without `-n`, or anything against the laptop.

## Output

Write `docs/missions/2026-11-05-make-venv-tools/review-1.md`, in the
`docs/agent-workflow.md` §5.5 format, and nothing else.
