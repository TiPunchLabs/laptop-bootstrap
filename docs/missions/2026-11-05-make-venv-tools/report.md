# Report — 2026-11-05-make-venv-tools

## Verdict

PASS on the branch.

- The owner's `make lint-ansible` failure after PR #60 is explained, reproduced,
  and fixed in every Makefile entry point and in the ansible-lint hook.
- A regression check, now in CI, catches this environment mismatch.
- Codex review 2: PASS. Final-head CI is checked after the push and reported in the
  session reply.
- Merge and laptop validation are the owner's.

Evidence dir `E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-make-venv-tools/`.

## Correction of the earlier claim

PR #60's mission (`2026-11-05-pnpm-branch-and-ansible-cfg`) reported WS2 as PASS,
and the post-merge closeout told the owner to confirm with `make lint-ansible`.
Its verification only ran `uv run --no-sync <tool>` and the hook. It never ran a
Makefile target, and never with another install of the tool earlier on `PATH`.

- The Makefile entry points were not verified, so WS2 should have been PARTIAL.
- PR #60 broke `make lint-ansible`, and would break `make play` on the syncthing
  task, in such a shell.

Details are in `mission.md`, "Correction". The historical files are unchanged.

## Root cause (proven)

- `make lint-ansible` called a bare `ansible-lint`, resolved through `PATH`.
- The owner's 26.9.0 is pipx's copy at `~/.local/bin/ansible-lint` (ansible-core
  2.21.5), which has no collections. It resolves `community.general.xml` to
  `False`; the project `.venv` resolves it to `True` (`diag-laptop-paths.txt`).
- Before #60, `collections_path` pointed every ansible-core at the venv's
  collections and masked this.

Reproduction, with an owner-like PATH `~/.local/bin:<worktree>/.venv/bin:…`:

| Run | Result | Evidence |
|---|---|---|
| post-#60 cfg | exit 2, exact owner error at `roles/syncthing/tasks/main.yml:50:3` | `before-make-lint-ansible-ownerpath.log` |
| pre-#60 cfg (`5ccad81`) | exit 0 | `control-pre60-cfg.log` |
| post-#60 cfg, `.venv/bin` first on PATH | exit 0 | `before-make-lint-ansible-venvfirst.log` |

How the owner's shell got `~/.local/bin` first is a hypothesis: `~/.bashrc:161`
prepends it after the direnv hook (`:20`). The outcome itself is a fact, since
26.9.0 exists only there.

Two related mismatches were found and covered:

- `uv run --no-sync ansible-lint` (PR #60's hook) runs the `PATH` copy when
  `.venv` is missing.
- `.venv/bin/ansible-lint` alone fails with the owner's PATH: it spawns pipx's
  `ansible`, and stops on a CLI/module version mismatch.

## Change

- `Makefile`: `VENV_RUN ?= uv run --no-sync .venv/bin`, used for `play`
  (and `play-*`), `uninstall-opera`, `lint`, `lint-ansible`, `vault-edit`,
  `vault-view` and `clean`.
- `.pre-commit-config.yaml`: the hook runs
  `uv run --no-sync .venv/bin/ansible-lint -v --force-color`.
- `bin/check_make_venv_tools.sh` (new), plus a CI step:
  - static half: `make -n`, where each tool word must be the command of a
    `uv run --no-sync .venv/bin/<tool>` call, with at least one call per target;
  - runtime half: failing decoys of the 7 tool names come first on `PATH`, with
    the real `.venv/bin` after them; `make lint-ansible` and the hook must pass.
- Docs: `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `docs/agent-workflow.md` §3,
  `docs/guide-daily-usage.md` (troubleshooting), `roles/obsidian/README.md`,
  `roles/syncthing/README.md`.
- `BACKLOG.md`:
  - Cleanup: the `.claude/commands/*` bare calls.
  - Watch: a fresh `uv sync` picks Python 3.15, and `rpds-py` fails to build.
- Unchanged: `ansible.cfg` (`collections_path` stays empty), `uv.lock`,
  `pyproject.toml`, the Python range, global collections, the smoke harness, and
  CI's existing steps.

## Before / after

| Check | Before | After | Evidence |
|---|---|---|---|
| `make lint-ansible`, owner-like PATH | 2 (unknown-module) | 0 | `before-…ownerpath.log`, `v-owner-make-lint-ansible.log` |
| hook, owner-like PATH | — | 0 | `v-owner-hook.log` |
| `VIRTUAL_ENV` = main checkout `.venv` | — | 0 (ignored with a warning) | `v-owner-foreign-venv.log` |
| no `.venv` | silent `PATH` fallback (`uv run --no-sync ansible-lint`) | make 2 / hook 1, "Failed to spawn" | `v-novenv-*.log` |
| regression check | old tree 1, explicit-path-only variant 2 | 0 | `v-check-*.log`, `f1-*.log` |
| `--syntax-check` (playbook, uninstall-opera), ansible-lint, yamllint | — | 0 | `v-*.log` |
| pre-commit on staged files | — | 0 | `precommit-2.log` |

Not executed:

- `make play*`, `make uninstall-opera` and `make vault-*`: only `make -n` was run,
  which prints the recipes without running them.
- Smoke VM: NOT_APPLICABLE (Ansible runs in the VM with `test/smoke/ansible.cfg`).
- The laptop.

## Reviews

- Review 1: PASS_WITH_RESERVATIONS, with three minor findings, all fixed:
  - F1.1: the static check accepted a matching substring anywhere on the line.
  - F1.2: a failing `make -n` was swallowed.
  - F1.3: AC-SAFE lacked comparison evidence.
- Review 2: PASS, no findings. Reservation: the static half splits on whitespace,
  which fits this Makefile's simple recipes but is not a shell parser.
- Codex pane `w1Q:pE` closed.

## Limits

- The laptop is not verified until the owner reruns the validation below.
- `.claude/commands/*.md` still use bare names (BACKLOG Cleanup).
- `uv run` creates an empty `.venv` before failing when none exists (uv
  behaviour; harmless, and the error is explicit).

## Next step (owner)

After merge, in the main checkout:

```bash
uv sync --frozen
make lint-ansible
```

Expect `uv run --no-sync .venv/bin/ansible-lint` echoed by make, then "Passed: 0
failure(s)", whatever `type -a ansible-lint` shows.
