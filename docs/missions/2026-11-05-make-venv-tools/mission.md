# Mission 2026-11-05-make-venv-tools — Makefile and hook must use the project venv

## Objective

Verbatim (owner, 2026-11-05):

> Objective: fix the laptop validation failure after PR #60 in TiPunchLabs/laptop-bootstrap.
>
> Owner validation: `uv sync --frozen` then `make lint-ansible`. Result:
> `syntax-check[unknown-module]: couldn't resolve community.general.xml`,
> `roles/syncthing/tasks/main.yml:50:3`. The output reports ansible-lint 26.9.0,
> whereas the mission tested the locked 26.1.1. Treat executable/environment
> mismatch as a hypothesis to verify.
>
> Trace the actual execution chain […]. Reproduce the failure and implement the
> smallest consistent fix. Do not restore a Python-version-specific path, install
> global collections, upgrade dependencies, or change the supported Python range.
> Check all affected entry points and active documentation. Add a regression check
> that would catch this specific environment mismatch. Obtain independent Codex
> review through Herdr. […] Correct the earlier completion claim in the new
> mission record without rewriting historical evidence.

## Authorizations

Read-only laptop diagnostics, isolated changes and tests, commit, push, corrective
PR. No merge, no provisioning, no change to the laptop's active environment
(main checkout `.venv`, `~/.local/bin`, pipx/uv tools, `~/.bashrc`).

## Correction of the PR #60 completion claim

Mission `2026-11-05-pnpm-branch-and-ansible-cfg` (PR #60, merged as `b4f5ab5`)
reported PASS for WS2 and stated in its report (`report.md`, "Not executed / limits"):
"`make play` from the laptop's `.venv` resolves the same way as the matrix, but this
was not executed there". The post-merge closeout told the owner to confirm with
`make lint-ansible`. Both were wrong:

- The verification matrix ran `uv run --no-sync <tool>` and the pre-commit hook only.
  It never ran a Makefile target, and never with another install of the same tool
  earlier on `PATH`.
- `make lint-ansible`, `make play*`, `make uninstall-opera`, `make lint` and the
  vault targets called bare tool names, resolved through `PATH`. The removed
  `collections_path` had been hiding this: it pointed every ansible-core, wherever
  installed, at the venv's collections.
- Result: PR #60 broke `make lint-ansible` (proven below), and would also break
  `make play` on the syncthing task, in any shell where a pipx/uv-tool copy precedes
  `.venv/bin`. WS2's PASS should have been PARTIAL: the Makefile entry points were
  not verified.

The historical files of that mission are left unchanged; this record supersedes
the claim.

## Root cause (proven)

Evidence `E=~/.local/share/laptop-bootstrap-agent/2026-11-05-make-venv-tools/`.

1. `make lint-ansible` ran `ansible-lint`, resolved through `PATH` (`make -n`:
   `ansible-lint`, `diag-laptop-paths.txt`).
2. ansible-lint 26.9.0 on this machine exists only in pipx venvs. `~/.local/bin/ansible-lint`
   links to `~/.local/share/pipx/venvs/ansible-lint/bin/ansible-lint`, which is 26.9.0
   on ansible-core 2.21.5 and has no `ansible_collections`. Its resolver gives
   `community.general.xml -> False`; the project `.venv` gives `True`
   (`.venv/lib/python3.12/site-packages/ansible_collections/...`) (`diag-laptop-paths.txt`).
   `~/.local/bin/ansible-playbook` is molecule's pipx copy (core 2.21.5), with the
   same unresolved module (`before-molecule-probe.txt`).
3. `~/.bashrc:161` (`export PATH="$HOME/.local/bin:$PATH"`) runs after the direnv
   hook (`:20`). A shell can therefore have `~/.local/bin` ahead of the venv that
   `.envrc` activates. The owner's 26.9.0 output proves that their shell resolved
   the pipx copy. The exact PATH history of that shell was not observed
   (hypothesis for the mechanism, fact for the outcome).
4. Reproduction in an isolated worktree (venv 3.12.12, owner-like
   `PATH=~/.local/bin:<worktree>/.venv/bin:…`):
   - post-#60 `ansible.cfg`: `make lint-ansible` exited 2 with the owner's exact error
     (`syntax-check[unknown-module] … community.general.xml`,
     `roles/syncthing/tasks/main.yml:50:3`) (`before-make-lint-ansible-ownerpath.log`);
   - same PATH, pre-#60 `ansible.cfg` (`5ccad81`): exit 0, "Passed"
     (`control-pre60-cfg.log`);
   - post-#60, `.venv/bin` first: exit 0 (`before-make-lint-ansible-venvfirst.log`).
5. Two further mismatches surfaced during the fix:
   - `uv run --no-sync ansible-lint` (PR #60's hook) silently creates an empty
     `.venv` when none exists and runs the `ansible-lint` found on `PATH` (pipx 26.9.0).
   - Calling `.venv/bin/ansible-lint` by path is not enough with the owner's PATH:
     it spawns `ansible`/`ansible-config` from `PATH` and stops with "Ansible CLI
     (2.21.5) and python module (2.20.1) versions do not match"
     (`after-make-lint-ansible-ownerpath.log`, first attempt).

## Fix

`uv run --no-sync .venv/bin/<tool>` for every Ansible tool and pre-commit in the
Makefile (`VENV_RUN`) and in the ansible-lint hook entry. The explicit path never
falls back to `PATH`, and fails loudly when `.venv` is missing. uv puts `.venv/bin`
first on `PATH` and sets `VIRTUAL_ENV` for spawned tools. A foreign `VIRTUAL_ENV`
is ignored with a warning.

- Unchanged: `ansible.cfg` (`collections_path =` stays empty, no Python-specific
  path), `uv.lock`, `pyproject.toml`, Python range, global collections.
- Regression check: `bin/check_make_venv_tools.sh`, run in CI.
  - Static half: `make -n` (prints only) for `play`, `uninstall-opera`, `lint`,
    `lint-ansible`, `vault-edit`, `vault-view` and `clean`. Every tool word must sit
    in `uv run --no-sync .venv/bin/<tool>`.
  - Runtime half: failing decoys of the 7 tool names first on `PATH`, the real
    `.venv/bin` after them (the owner's shape), then `make lint-ansible` and
    `pre-commit run ansible-lint --all-files` must pass.
  - After review 1: the static half checks each tool word's own command
    (`uv run --no-sync .venv/bin/<tool>` as the 4 preceding words), requires at
    least one such call per target, and stops on a failing `make -n`.
- Docs: `README.md` (setup comment, check command, note, Daily Operations row),
  `CONTRIBUTING.md`, `CLAUDE.md` (Commands), `docs/agent-workflow.md` §3,
  `docs/guide-daily-usage.md` (troubleshooting), `roles/obsidian/README.md`,
  `roles/syncthing/README.md`, `BACKLOG.md` (two new entries).
- Not changed: smoke harness (Ansible runs inside the VM with its own
  `test/smoke/ansible.cfg`), CI's existing `uv run <tool>` steps (clean runner, no
  other install), `.claude/commands/*.md` (synced from global commands; BACKLOG
  Cleanup entry).

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Root cause proven by reproduction and control | `diag-laptop-paths.txt`, `before-make-lint-ansible-ownerpath.log` (exit 2, exact error), `control-pre60-cfg.log` (exit 0) | VERIFIED |
| AC2 | `make lint-ansible` passes with the owner-like PATH | `v-owner-make-lint-ansible.log` exit 0 ("Passed: 0 failure(s)… 'production'") | VERIFIED |
| AC3 | Hook passes with the owner-like PATH; foreign `VIRTUAL_ENV` tolerated | `v-owner-hook.log` exit 0 (Ansible-lint Passed); `v-owner-foreign-venv.log` exit 0 with `VIRTUAL_ENV` = main checkout `.venv` | VERIFIED |
| AC4 | Every Makefile Ansible/pre-commit entry point uses the venv form | `bin/check_make_venv_tools.sh` static half (`v-check-fixed.log`); `v-make-n.txt` | VERIFIED |
| AC5 | Missing `.venv` fails loudly, never falls back to `PATH` | `v-novenv-make.log` (exit 2, "Failed to spawn: .venv/bin/ansible-lint"), `v-novenv-hook.log` (exit 1, same) | VERIFIED |
| AC6 | Regression check catches the bug and the explicit-path-only variant, passes on the fix | `v-check-old.log` exit 1, `v-check-variant-runtime-real.log` exit 2 (decoy `ansible-config` reached), `v-check-fixed.log` exit 0; after F1.1/F1.2: comment bypass, empty recipe, no tool call → exit 1, real `make -n` failure → exit 2, old Makefile → exit 1, fix → exit 0 (`f1-*.log`) | VERIFIED |
| AC7 | No Python-specific path, no global collection, no dependency or Python-range change | `scope.txt`: forbidden paths none; the only `collections_path` hit is a Makefile comment | VERIFIED |
| AC8 | Active docs consistent | `bare-calls-left.txt`: remaining hits in active docs are prose/tool names, `.claude/commands/*` (BACKLOG Cleanup) or `pre-commit run` (hook entry is PATH-independent) | VERIFIED |
| AC9 | Standard checks pass: `--syntax-check` (playbook, uninstall-opera), ansible-lint, yamllint, pre-commit on changed files | `v-syntax-check.log`, `v-syntax-check-opera.log`, `v-ansible-lint.log`, `v-yamllint.log` exit 0; `precommit-1.log` exit 0 (13 staged files) | VERIFIED |
| AC10 | CI green on final head, including the new step | CI run log | NOT_VERIFIED |
| AC-SAFE | Main checkout, its `.venv`, stashes and unrelated resources unchanged; no secret read; hooks not bypassed | `safety-check-1.txt` (after review 1): main snapshot = baseline, main `.venv` checksums + listing = baseline, stashes = baseline, `agent-workflow-closeout` 0 changes, remote branches present; re-run at delivery (`safety-check-final.txt`). Hooks unchanged except the ansible-lint entry (same checks, PATH-independent); dummy vault throughout | VERIFIED |

## State

- Phase: done (on branch; CI on final head reported in the session reply)
- Branch / worktree: `fix/make-venv-tools` / `../laptop-bootstrap-worktrees/make-venv-tools` (venv 3.12.12)
- Base commit: `b4f5ab5` (= origin/main)
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-05-make-venv-tools/`
- Main-tree baseline: `main-tree-snap-baseline.txt` (`95e9a896…dbecb5ac`); main `.venv` baseline: `main-venv-baseline.txt`
- Reviewer: herdr agent `lb-review` (codex), pane `w1Q:pE`
- Review cycle: 2 of 3 (pane `w1Q:pE` closed)
- Next step: owner merges the PR, then `uv sync --frozen && make lint-ansible` in the main checkout

## Log

- 2026-11-05 inspect: owner's 26.9.0 traced to `~/.local/bin/ansible-lint` (pipx); `make lint-ansible` calls a bare name.
- 2026-11-05 inspect: fresh worktree `uv sync --frozen` chose Python 3.15.1 and failed (`rpds-py` build, PyO3 max 3.14; `worktree-uv-sync.log`); rebuilt on `--python 3.12` like the laptop's `.venv`. BACKLOG Watch entry.
- 2026-11-05 implement: first attempt (`.venv/bin/<tool>` only) failed with the owner's PATH (CLI/module version mismatch); replaced with `uv run --no-sync .venv/bin/<tool>`.
- 2026-11-05 verify: `verify.sh` final run (`verify-summary-final.txt`): check old 1, check fixed 0, owner PATH make/hook/foreign venv 0, no venv 2/1, syntax ×2, yamllint, ansible-lint 0. Variant (explicit path only) in the real worktree: runtime check exit 2 (`v-check-variant-runtime-real.log`), files restored byte-identical. pre-commit staged exit 0.
- 2026-11-05 review-1: Codex PASS_WITH_RESERVATIONS, 3 minor findings (F1.1 substring match, F1.2 swallowed `make -n` failure, F1.3 AC-SAFE without comparison evidence).
- 2026-11-05 fix-1: static half rewritten (per-word command check, ≥1 call per target, `recipe=$(make -n …)` under `set -e`); counterexamples `f1-*.log`; `safety-check-1.txt` recorded.
- 2026-11-05 review-2: Codex PASS, no findings. Pane closed. report.md written.
