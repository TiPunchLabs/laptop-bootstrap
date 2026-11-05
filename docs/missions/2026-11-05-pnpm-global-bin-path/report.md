# Report — 2026-11-05-pnpm-global-bin-path

## Executive summary

Objective: examine and finalize the owner's uncommitted pnpm fix (BACKLOG entry
"Commit the pnpm global bin path fix", branch `fix/pnpm-global-bin-path`).

Verdict: PASS for AC1–AC9 (all VERIFIED, Codex review 2 PASS_WITH_RESERVATIONS).
AC10 (commit, push, PR, CI) happens after this file is committed; its outcome is
in the PR and in the delivery report, not here.

- Problem: mise manages pnpm 12. Since pnpm 11, global bins go to
  `$PNPM_HOME/bin`, and `pnpm add -g` refuses to run
  (`ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH`) until that directory is on PATH. On
  `main` nothing puts it there, on an existing laptop or a fresh one.
- Owner's diff: appended `$PNPM_HOME/bin` (guarded) inside the top managed block.
  Correct for the default layout; Codex review 1 found it wrong when the pnpm
  installer block later in `~/.bashrc` sets another `PNPM_HOME` (F1.1).
- Final fix: the guarded append lives in a second managed block placed at the
  end of `~/.bashrc`, after the installer block, so it reads the final
  `PNPM_HOME`. Top block back to `main`'s content.
- Not done, by mandate: no merge, nothing applied to the laptop, no Python change.

## Problem and distinction from `fix/pnpm-home-after-mise`

- pnpm docs (context7 `/pnpm/pnpm.io`): `globalBinDir` defaults to
  `$PNPM_HOME/bin`, else `$XDG_DATA_HOME/pnpm/bin`, else `~/.local/share/pnpm/bin`;
  global commands fail with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` when it is not
  on PATH. Laptop (read only): mise pnpm 12.17.0, `pnpm bin -g` =
  `~/.local/share/pnpm/bin`.
- PR #50 (`fix/pnpm-home-after-mise`, squash `5a7fcfd`, merged) fixed another
  bug: the pnpm ≤10 installer block prepended `$PNPM_HOME`, so the standalone
  pnpm shadowed mise's. The `replace` task rewrites that line to append. It never
  put `$PNPM_HOME/bin` on PATH. That branch was not touched.
- `pnpm setup` (pnpm 12, probed in a temp HOME) writes
  `export PATH="$PNPM_HOME/bin:$PATH"` with a prefix-only guard and installs its
  own `pnpm` in `$PNPM_HOME/bin`: it would shadow mise. Not handled by the role;
  documented in README, BACKLOG Watch entry.

## Initial state and preservation

- `main` = `origin/main` = `d751cb6`, 3 uncommitted files (`README.md`,
  `roles/cli_tools/tasks/main.yml`, `roles/cli_tools/vars/main.yml`), 2 stashes.
  `fix/pnpm-global-bin-path` = `94d9f91`, ancestor of `main`, no own commits.
- Backup before any manipulation, in `$E` =
  `~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-global-bin-path/`:
  `original.patch` (sha256 `5b056065…289f`), `original-files/`,
  `original-blobs.txt`, `stashes-before.txt`, `main-tree-snap-baseline.txt`
  (`adcf9327…a079`).
- End of mission: main tree `snap` equal to the baseline, the 3 files equal their
  original blobs, `git diff --binary` sha256 still `5b056065…`, stashes unchanged,
  `main` still `d751cb6`. VERIFIED.
- The laptop's `~/.bashrc` already contained the owner's first version of the
  block (applied before this mission). Read only (grep on PNPM/mise lines).

## Changes (branch `fix/pnpm-global-bin-path`, worktree `…/laptop-bootstrap-worktrees/pnpm-global-bin-path`)

- `roles/cli_tools/vars/main.yml`: new `cli_tools_pnpm_bashrc_block`
  (`PNPM_HOME` default fallback, guarded append of `$PNPM_HOME/bin`) with comment;
  `cli_tools_bashrc_block` unchanged from `main`.
- `roles/cli_tools/tasks/main.yml`: comment of the `replace` task (owner's diff,
  adapted); new `blockinfile` task, marker
  `# {mark} ANSIBLE MANAGED: cli_tools pnpm global bin`, `insertafter: EOF`.
- `README.md`: owner's bullet adapted to the second block, keep `PNPM_HOME`
  setters above it, precise `pnpm setup` warning, `pnpm bin -g` check.
- `test/smoke/README.md`: post-provision expectation for the new block.
- `BACKLOG.md`: entry removed (done on this branch), Watch entry for `pnpm setup`,
  `Last review: 2026-11-05`.
- This mission directory.

## Verification and evidence

| Check | Method | Result | Status |
|---|---|---|---|
| Local isolated repro | `$E/local-repro.sh` (temp HOME per case, clean `env -i` interactive bash, stub `mise activate` prepending the real mise node 26 / pnpm 12 dirs, stub fzf/starship/direnv, synthetic local package, `--offline`) | 42/42 (`local-repro-2.log`): `main` fails (existing, fresh); owner's first version fails with a custom installer home; final version passes in 5 layouts (existing, fresh, `XDG_DATA_HOME`, custom installer home, inherited XDG with default installer) | VERIFIED |
| Smoke VM, full first run | `make smoke-up` (fix included) | exit 0, `failed=0` | VERIFIED |
| VM reproduction | `vm-check.sh prepare` (main's block, pnpm ≤10 installer block in prepend form, fake `oldtool`, mise config marker), real mise pnpm 12.17.0 | error reproduced, default home (B) and custom home (B2) | VERIFIED |
| VM fix + idempotence | `make smoke-replay TAGS=mise` twice per state | from pre-fix custom-home state: `changed=2` → `changed=0`; from the owner's first version (laptop layout): `changed=3` → `changed=0` (`smoke-3..6.log`) | VERIFIED |
| VM resolution and PATH | `vm-check.sh check` (C2, C3) | add OK, bin from the final `$PNPM_HOME/bin`, `pnpm bin -g` match, node/pnpm from mise, order 14 (node) < 20 (`/usr/bin`) < 26 (`$PNPM_HOME`) < 27 (`bin`), count 1 after re-sourcing twice and nested shell, one append line after migration, new block last, `oldtool` resolves | VERIFIED |
| mise autonomy | marker in `~/.config/mise/config.toml`, sha256 across replays | unchanged; tool install task skipped | VERIFIED |
| Lint / syntax | ansible-lint, yamllint, `--syntax-check` (dummy vault, credentials unset) | exit 0 | VERIFIED |
| Hooks | pre-commit on staged files incl. gitleaks | exit 0 (`precommit-4.log`) | VERIFIED |
| Laptop | — | not run: forbidden | NOT_APPLICABLE |

Limits: locally, mise activation and the other hooks are stubs; real mise is
covered in the VM. pnpm installs used a local package (no registry). CI checks
lint only; it is not a laptop proof.

## Reviews

| Review | Verdict | Findings | Outcome |
|---|---|---|---|
| 1 | CHANGES_REQUESTED | F1.1 [major] bin dir chosen before the installer sets `PNPM_HOME` | fixed (EOF block) |
| 2 | PASS_WITH_RESERVATIONS | none; independent rerun 42/42, `blockinfile` behaviour checked on temp files | reservations: EOF placement only on first insertion (README sentence added); pre-existing PATH state not repaired; `pnpm setup` deferred; stubs locally |

## Remaining risks

- If a line that changes `PNPM_HOME` is later added after the new block, the bin
  directory it points to is not added (documented).
- `pnpm setup` would prepend `$PNPM_HOME/bin` and shadow mise's pnpm (BACKLOG Watch).
- Non-interactive shells do not read `~/.bashrc` (unchanged behaviour).

## State

- Smoke VM `smoke_default` left running (`make smoke-down` needs the owner's approval).
- Worktree and branch kept for the PR. Herdr pane `w1Q:p9` closed.

## Decisions required

- D1 — Review and merge the PR (merge not authorized to agents).
- D2 — After merge, apply on the laptop yourself: `make play TAGS=mise`. The
  laptop's installer line is already in append form, so expect `changed=2` (top
  block cleaned of the first-version lines, new end block), then `changed=0` on a
  second run; then `exec bash` and `pnpm bin -g`.
- D3 — `make smoke-down` to destroy the smoke VM.
