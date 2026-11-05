# Review brief 2 — 2026-11-05-pnpm-global-bin-path

Correction cycle 1 of 2. Same rules as `AGENTS.md` and `review-brief-1.md`. Write
`docs/missions/2026-11-05-pnpm-global-bin-path/review-2.md` (§5.5 format) and
nothing else.

## Change under review

Same branch, worktree and base (`d751cb6`), all staged (`git diff --cached`).
Since review 1: `roles/cli_tools/vars/main.yml`, `roles/cli_tools/tasks/main.yml`,
`README.md`, `test/smoke/README.md`, `mission.md`, this brief; `review-1.md` is
now part of the change.

## Resolution of review 1

| Finding | Resolution | Where |
|---|---|---|
| F1.1 [major] bin dir chosen before the installer sets `PNPM_HOME` | Fixed. The guarded append moved out of the top block into a second block, `# {mark} ANSIBLE MANAGED: cli_tools pnpm global bin` (`cli_tools_pnpm_bashrc_block`), installed by a new `blockinfile` task with `insertafter: EOF`, so on first insertion it lands after the installer's block and reads its final `PNPM_HOME` (default fallback otherwise). `blockinfile` keeps an existing block where it is. The top block is back to `main`'s content, so no file outside this mission differs from `main` in the top block | `vars/main.yml`, `tasks/main.yml` (last task), README bullet, `test/smoke/README.md` |

Reservations from review 1, answered: a pre-existing `$PNPM_HOME/bin` entry keeps
its position (guard only avoids adding one) — accepted, no change; non-interactive
shells — README wording unchanged (pre-existing, outside this fix).

## New evidence (`$E` as in brief 1)

| Check | Result | File |
|---|---|---|
| `local-repro.sh vars-before.yml vars-after.yml vars-owner.yml` (now renders both blocks; installer home configurable) | 42/42. Owner's first version + custom installer home → `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` (F1.1 reproduced). Fixed version: existing, fresh, `XDG_DATA_HOME`, custom installer home, inherited XDG with default installer → add OK, bin from the final `$PNPM_HOME/bin`, `pnpm bin -g` match, mise first, order, counts 1, `oldtool` resolves. Each case runs in a new `env -i` interactive shell | `local-repro-2.log` |
| VM: pristine pre-fix bashrc + installer block with custom home `/home/vagrant/custom-pnpm` | error reproduced | `vm-B2-prefix-custom.txt` |
| `make smoke-replay TAGS=mise` ×2 | `changed=2` (installer line, new EOF block), then `changed=0` | `smoke-3.log`, `smoke-4.log` |
| VM after replays (C2) | `PNPM_HOME=/home/vagrant/custom-pnpm`, add OK, bin from `custom-pnpm/bin`, order 14 < 20 < 26 (`$PNPM_HOME`) < 27 (`bin`), counts 1, new block is last, mise config sha unchanged | `vm-C2-after-replays-custom.txt` |
| VM migration: top block = owner's first version (the laptop's current layout), default installer | before: works (`vm-B3-owner.txt`); `TAGS=mise` ×2 → `changed=3` (top block, installer line, EOF block), then `changed=0`; after (C3): one append line in the file, count 1, add OK | `smoke-5.log`, `smoke-6.log`, `vm-C3-migrated.txt` |
| ansible-lint, yamllint, syntax-check (dummy vault, credentials unset) | exit 0 each | `ansible-lint-2.log`, `yamllint-2.log`, `syntax-2.log` |
| pre-commit on staged files | see `mission.md` Log (run before sending this brief) | `precommit-3.log` |

## What to check

1. F1.1 is resolved without new problems (EOF placement on existing and fresh
   files, later edits appended after the block, `create: true`, idempotence,
   marker naming, interaction with the `replace` task and `cleanup_legacy`).
2. Docs and BACKLOG still accurate.
3. Every `VERIFIED` in `mission.md` is backed by the evidence.
