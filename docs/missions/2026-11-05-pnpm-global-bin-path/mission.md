# Mission 2026-11-05-pnpm-global-bin-path — finalize the pnpm global bin path fix

## Objective

Owner prompt of 2026-11-05 (French, summarized; binding points quoted):
"examiner et finaliser le correctif pnpm local mentionné dans BACKLOG.md sous
fix/pnpm-global-bin-path." Understand the uncommitted work in `README.md`,
`roles/cli_tools/tasks/main.yml`, `roles/cli_tools/vars/main.yml`, back it up,
explain the real problem, finish it in an isolated branch/worktree, reproduce and
verify in isolation (node/pnpm resolution, global bins, PATH order, no
duplicates), smoke VM twice if the role changes, Codex review via Herdr, commit,
push, PR, CI.

## Authorizations

Granted: "modifications ciblées, tests isolés/VM, revue Codex, commit, push et
ouverture de PR."
Excluded: "Aucune fusion, aucune application au laptop réel, aucune suppression
des modifications pnpm originales ou des stashes, aucun changement Python ni
nettoyage d'autres branches."

## Scope

In: `roles/cli_tools/vars/main.yml` (shell-hooks block), the comment in
`roles/cli_tools/tasks/main.yml`, `README.md`, `test/smoke/README.md` if its
expectations change, `BACKLOG.md`, this directory.
Out: other roles, Python/venv, `fix/pnpm-home-after-mise`, stashes, the real
laptop (`~/.bashrc` is read only for diagnosis, grep on PNPM/mise lines only).

## Acceptance criteria

`$E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-global-bin-path/`.

| ID | Criterion | Verification | Status | Evidence |
|---|---|---|---|---|
| AC1 | Original uncommitted files and stashes preserved, backed up before any manipulation | blobs + `snap` before/after, `git stash list` | VERIFIED | end: main tree `snap` = baseline `adcf9327…a079`, 3 files = original blobs, `git diff --binary` sha256 `5b056065…`, stashes = `$E/stashes-before.txt`, `main` = `d751cb6` |
| AC2 | Problem reproduced in isolation with the pre-fix block: `pnpm add -g` fails with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` | local temp-HOME test, smoke VM | VERIFIED | local: existing and fresh layouts fail with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH`; the owner's first version fails with a custom installer `PNPM_HOME` (F1.1) (`$E/local-repro-2.log`); VM pre-fix states B (default home) and B2 (custom home), real mise pnpm 12.17.0: same error (`$E/vm-B-prefix.txt`, `vm-B2-prefix-custom.txt`) |
| AC3 | With the fix: `pnpm add -g` works, the global bin resolves from `$PNPM_HOME/bin`, `pnpm bin -g` = that dir | same | VERIFIED | local 5 layouts (existing, fresh, `XDG_DATA_HOME`, custom installer home, inherited XDG + default installer): add OK, bin from the final `$PNPM_HOME/bin`, `pnpm bin -g` match (`local-repro-2.log`); VM C2 (custom home) and C3 (migration from the owner's first version): same (`vm-C2-after-replays-custom.txt`, `vm-C3-migrated.txt`) |
| AC4 | No PATH regression: mise `node`/`pnpm` first; `$PNPM_HOME/bin` after mise and system dirs; pnpm ≤10 bins in `$PNPM_HOME` still resolve | same | VERIFIED | local and VM: `node`/`pnpm` = mise installs; mise node before `/usr/bin` before `$PNPM_HOME` and `$PNPM_HOME/bin` (VM C2/C3: 14 < 20 < 26, 27); pnpm ≤10 bin `oldtool` in the installer home resolves |
| AC5 | No duplicates after re-sourcing `~/.bashrc` or nested shells; idempotent role (second smoke replay `changed=0`) | same + smoke ×2 `TAGS=mise` | VERIFIED | `$PNPM_HOME/bin` count 1 initially, after sourcing `~/.bashrc` twice, in a nested shell (local, VM C2/C3); one append line after migration; smoke `TAGS=mise`: pre-fix state → `changed=2` then `changed=0` (`smoke-3/4.log`); owner's first version → `changed=3` then `changed=0` (`smoke-5/6.log`) |
| AC6 | mise autonomy: the role does not rewrite an existing `~/.config/mise/config.toml` | smoke | VERIFIED | VM: mise config marker present, sha256 unchanged across every replay; "Install tools from the freshly seeded config" skipped in all replays |
| AC7 | Docs and BACKLOG match reality; distinction with `fix/pnpm-home-after-mise` explained | diff, report | VERIFIED | README, `test/smoke/README.md`, BACKLOG diff; distinction with PR #50 in `report.md`; `review-2.md` AC7 (pending only the report, now written) |
| AC8 | Repo checks with dummy vault and cleaned env (pre-commit incl. gitleaks, ansible-lint, yamllint, syntax), also for commit/push hooks | logs | VERIFIED | ansible-lint, yamllint, syntax-check, pre-commit incl. gitleaks exit 0 (`*-2.log`, `precommit-4.log`), dummy vault, credentials unset. Commit/push hooks run with the same environment at delivery (result outside this file) |
| AC9 | Codex review via Herdr, findings handled per §3 | `review-N.md` | VERIFIED | review 1 CHANGES_REQUESTED (F1.1 major) → fixed; review 2 PASS_WITH_RESERVATIONS, no findings, F1.1 resolved, independent rerun 42/42 (`review-2.md`) |
| AC10 | Commit, push (remote `github-xgueret`), PR, CI result; no merge | PR link | NOT_VERIFIED | after this file is committed: PR and CI on GitHub |

## Plan

1. Inspect, back up, explain (done before this file; see Log).
2. Worktree `../laptop-bootstrap-worktrees/pnpm-global-bin-path` on `fix/pnpm-global-bin-path` (fast-forwarded from `94d9f91`, no own commits, to `d751cb6`); original patch applied.
3. Local isolated reproduction (temp HOME, real mise node 26 / pnpm 12 binaries, synthetic local package, no network).
4. Smoke VM: `smoke-up`, then `smoke-replay TAGS=mise` twice; reproduce/verify inside the VM.
5. Docs/BACKLOG; repo checks; Codex review; commit, push, PR, CI.

## State

- Phase: delivery (commit, push, PR); verdict PASS for AC1–AC9
- Branch / worktree: `fix/pnpm-global-bin-path` (no upstream) / `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/pnpm-global-bin-path`
- Base commit: `d751cb6` (`origin/main`)
- Main tree: baseline `snap` in `$E/main-tree-snap-baseline.txt` = `adcf932744d1601004e0f5b9acee43cd83c5c2acfea668a69c58b3aa8a59a079`; original diff `$E/original.patch` (sha256 `5b056065af80bc08b9f29ca7a018fd903e1e6d00223dc2e949c9c39ed2c6289f`), files copied to `$E/original-files/`, blobs in `$E/original-blobs.txt`, stashes in `$E/stashes-before.txt`
- Evidence dir: `$E`
- Reviewer: herdr agent `lb-review`, pane `w1Q:p9` (created by this mission)
- Review cycle: 2 of 3
- Next step: owner review and merge of the PR; laptop apply by the owner (`report.md` D2); `make smoke-down` on approval

## Log

- 2026-11-05 inspect: `main` = `origin/main` = `d751cb6`; 3 uncommitted files (diff above), 2 stashes, worktree `agent-workflow-closeout` (other mission, untouched). `fix/pnpm-global-bin-path` = `94d9f91`, ancestor of `main`, no own commits, not pushed. Laptop (read only): mise `pnpm` 12.17.0, `node` v26.13.0 first on PATH; `pnpm bin -g` = `~/.local/share/pnpm/bin` (empty); pnpm ≤10 global bins (acorn, ccusage, tsc, …) directly in `~/.local/share/pnpm`. The managed block in `~/.bashrc` already equals the uncommitted `cli_tools_bashrc_block` (applied to the laptop before this mission, not by it). pnpm docs (context7 `/pnpm/pnpm.io`): `globalBinDir` defaults to `$PNPM_HOME/bin`, else `$XDG_DATA_HOME/pnpm/bin`, else `~/.local/share/pnpm/bin`; global commands fail with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` when it is not on PATH.
- 2026-11-05 backup: `$E/original.patch`, `$E/original-files/`, blobs, stashes, `snap` baseline.
- 2026-11-05 implement: worktree created, branch fast-forwarded, patch applied (blobs equal originals), `uv sync --frozen --python 3.12`.
- 2026-11-05 test-local: `$E/local-repro.sh vars-before.yml vars-after.yml` (temp HOME under `/tmp/claude-1000`, stub `mise activate` prepending the real mise node 26 / pnpm 12 dirs, synthetic local package, `--offline`) → 25/25 (`$E/local-repro.log`).
- 2026-11-05 pnpm-setup probe (temp HOME): pnpm 12 `setup` writes `export PATH="$PNPM_HOME/bin:$PATH"` with a prefix-only guard and installs `pnpm`, `pn`, `pnpx`, `pnx` in `$PNPM_HOME/bin`; the role's `replace` regexp does not match it (`$E/pnpm-setup-bashrc.txt`). Kept out of scope: README warning made precise, BACKLOG Watch entry.
- 2026-11-05 docs: README (precise `pnpm setup` warning, `pnpm bin -g` check), `test/smoke/README.md` (block expectation), BACKLOG (entry removed, Watch added, Last review).
- 2026-11-05 verify: ansible-lint, yamllint, syntax-check, pre-commit (staged, dummy vault, credentials unset) exit 0.
- 2026-11-05 smoke: `make smoke-up` exit 0 (full run, `failed=0`); VM state A (fixed by first provision) OK; `vm-check.sh prepare` (main's block, pnpm ≤10 installer block in prepend form, fake `oldtool`, mise config marker) → state B reproduces the error; `TAGS=mise` ×2 → `changed=2`, then `changed=0`; state C all checks OK. VM left running (`smoke-down` needs approval).
- 2026-11-05 review-1: pane `w1Q:p9` (§5.3 gate clean), verdict CHANGES_REQUESTED: F1.1 [major] the `$PNPM_HOME/bin` append ran in the top managed block, before the installer block, so a custom installer `PNPM_HOME` (or a different inherited `XDG_DATA_HOME`) left the real bin dir off PATH. Reproduced by Codex with real pnpm 12.
- 2026-11-05 fix-1: append moved to a second block `cli_tools pnpm global bin` (`cli_tools_pnpm_bashrc_block`, `blockinfile` `insertafter: EOF`), the main block is back to `main`'s content; README and `test/smoke/README.md` adjusted. Local repro extended (custom home, inherited XDG, owner's first version) → 42/42 (`$E/local-repro-2.log`). ansible-lint, yamllint, syntax exit 0.
- 2026-11-05 smoke-2: VM pre-fix state with custom installer home → error (B2); `TAGS=mise` ×2 → `changed=2`, `changed=0`; C2 OK. VM state = owner's first version (laptop layout) → `changed=3`, `changed=0`; C3 OK, one append line. Replays: `smoke-3..6.log`.
- 2026-11-05 verify-2: pre-commit on staged files exit 0 (gitleaks Passed; `$E/precommit-3.log`).
- 2026-11-05 review-2: verdict PASS_WITH_RESERVATIONS, no findings; snapshot unchanged, review newer than brief; pane `w1Q:p9` closed. Reservation (EOF placement only on first insertion) answered by one README sentence; others accepted (pre-existing PATH state not repaired; `pnpm setup` deferred; stubbed hooks locally, real mise in VM).
- 2026-11-05 final: main tree `snap` = baseline, 3 files = original blobs, stashes unchanged; pre-commit exit 0 (`$E/precommit-4.log`); `report.md` written. Smoke VM left running.
