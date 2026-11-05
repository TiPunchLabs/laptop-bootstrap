# Review brief 1 — 2026-11-05-pnpm-global-bin-path

Rules: `AGENTS.md`. Write `docs/missions/2026-11-05-pnpm-global-bin-path/review-1.md`
(format `docs/agent-workflow.md` §5.5) and nothing else.

## Objective (verbatim excerpt, see `mission.md`)

"examiner et finaliser le correctif pnpm local mentionné dans BACKLOG.md sous
fix/pnpm-global-bin-path." Respect mise autonomy, preserve existing global
installs and packages, update docs and BACKLOG, reproduce and verify in
isolation, smoke VM twice if the role changes.

## Problem (as established by Claude Code)

- mise manages `pnpm = "12"` (12.17.0 on the laptop and in the VM). Since pnpm
  11, global bins go to `globalBinDir`, default `$PNPM_HOME/bin` (else
  `$XDG_DATA_HOME/pnpm/bin`, else `~/.local/share/pnpm/bin`), and global
  commands fail with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` when that dir is not
  on PATH (pnpm docs via context7 `/pnpm/pnpm.io`).
- On `main`, nothing puts `$PNPM_HOME/bin` on PATH: the managed block only runs
  `mise activate`; the old standalone-installer block (pnpm ≤10) adds
  `$PNPM_HOME` itself, which `cli_tools` (PR #50) rewrites from prepend to
  append. So `pnpm add -g` fails, on an existing laptop and on a fresh one.
- `fix/pnpm-home-after-mise` (PR #50, squash `5a7fcfd`, merged) fixed a different
  problem: the installer's `$PNPM_HOME` prepend shadowed mise's `pnpm`. It did not
  address pnpm ≥11's `bin` subdirectory.

## Change under review

Branch `fix/pnpm-global-bin-path`, worktree
`…/laptop-bootstrap-worktrees/pnpm-global-bin-path`, base `d751cb6`, all staged
(`git diff --cached`). The owner's uncommitted diff (applied unchanged, blobs
equal the originals) plus completions by Claude Code:

- owner diff: `roles/cli_tools/vars/main.yml` (block: `PNPM_HOME` default + guarded
  append of `$PNPM_HOME/bin`, comment), `roles/cli_tools/tasks/main.yml` (comment),
  `README.md` (bullet);
- Claude Code: `README.md` (precise `pnpm setup` warning, `pnpm bin -g` check),
  `test/smoke/README.md` (block expectation), `BACKLOG.md` (entry removed, Watch
  item, Last review), `mission.md`, this brief.

## Evidence (`$E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-global-bin-path/`)

| Check | Result | File |
|---|---|---|
| Local isolated repro (`local-repro.sh vars-before.yml vars-after.yml`: temp HOME, stub `mise activate` prepending the real mise node 26 / pnpm 12 dirs, synthetic local package, `--offline`) | 25/25: pre-fix fails with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` (existing and fresh layouts); fixed: add OK, bin from `$PNPM_HOME/bin`, `pnpm bin -g` match, mise node/pnpm first, order node < `/usr/bin` < `$PNPM_HOME/bin`, count 1 after re-source ×2 and nested shell, pnpm ≤10 bin still resolves, `XDG_DATA_HOME` honoured | `local-repro.log` |
| `pnpm setup` probe in temp HOME | writes `export PATH="$PNPM_HOME/bin:$PATH"` (prefix-only guard), installs `pnpm` etc. in `$PNPM_HOME/bin`; role `replace` regexp does not match → documented, BACKLOG Watch | `pnpm-setup-bashrc.txt` |
| `make smoke-up` (full run with the fix) | exit 0, `failed=0` | `smoke-up.log` |
| VM state A (after first provision) | add OK, all checks OK | `vm-A-fixed.txt` |
| VM state B (`vm-check.sh prepare`: main's block, installer block in pnpm ≤10 prepend form, fake `oldtool`, mise config marker) | `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` with real mise pnpm 12.17.0 | `vm-B-prefix.txt` |
| `make smoke-replay TAGS=mise` ×2 | exit 0 ×2; `changed=2` (shell-hooks block, installer line) then `changed=0` | `smoke-1.log`, `smoke-2.log` |
| VM state C | add OK; order 14 < 20 < 26 (`$PNPM_HOME` 27); counts 1; `oldtool` resolves; mise config sha unchanged | `vm-C-after-replays.txt` |
| ansible-lint, yamllint, syntax-check, pre-commit (dummy vault, credentials unset) | exit 0 each; gitleaks Passed | `ansible-lint.log`, `yamllint.log`, `syntax.log`, `precommit-1.log` |

Not run: real laptop (forbidden; its `~/.bashrc` was only grepped for PNPM/mise
lines and already contains the new block, applied before this mission).
Network-dependent pnpm installs (synthetic local package only).
You may rerun `local-repro.sh` (writes only under `$TMPDIR`, e.g. `TMPDIR=/tmp`).

## What to check

1. The diagnosis and that the change fixes it, for existing and fresh laptops.
2. Shell correctness of the block (quoting, guard, `set -u` safety is not
   required for `.bashrc`, behaviour when `PNPM_HOME` is set elsewhere or empty,
   interaction with the installer block and the `replace` task, non-interactive
   shells).
3. mise autonomy and preservation of existing global packages/bins.
4. Docs and BACKLOG accuracy; whether anything necessary is missing, or anything
   unnecessary was added.
5. Whether every `VERIFIED` in `mission.md` is backed by the evidence.
