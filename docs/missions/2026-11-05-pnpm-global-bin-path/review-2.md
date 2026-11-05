# Review 2 — 2026-11-05-pnpm-global-bin-path

VERDICT: PASS_WITH_RESERVATIONS

## Findings

None requiring changes. F1.1 is resolved: the new, separately marked block is inserted after an existing installer block, reads its final `PNPM_HOME`, and appends its bin directory. The original shell-hooks block equals HEAD again. The legacy replacement retains its previous scope and does not match the new append.

Independent rerun: **42 passed, 0 failed**, including reproduction of the first version's custom-home failure and successful installs with the corrected version across all five layouts. Direct execution of the installed `blockinfile` module against temporary files also confirmed creation, EOF insertion, distinct markers, missing-final-newline handling, and repeat-run idempotence. No real laptop or VM operations were performed.

## AC check

`$E` means `/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-global-bin-path`.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | NOT_VERIFIED | Final main-tree/stash preservation comparison remains pending, as stated in the mission. Backup evidence was inspected in review 1; this review does not replace the final comparison. |
| AC2 | VERIFIED | Independent offline rerun reproduces the pre-fix error for existing/fresh layouts and F1.1 for the owner's first version. VM B2 reports the same error with custom home and real pnpm 12.17.0. |
| AC3 | VERIFIED | Independent rerun: existing, fresh, XDG, custom installer home, and inherited XDG with default installer all install successfully; executable resolution and `pnpm bin -g` match the final home. VM C2/C3 independently support custom-home repair and migration. |
| AC4 | VERIFIED for tested layouts | Local rerun confirms mise node/pnpm precedence, system directories before the global bin directory, and legacy `oldtool` resolution. VM C2/C3 show indices 14 < 20 < 26 (home) < 27 (bin). Preexisting PATH placement remains subject to the reservation below. |
| AC5 | VERIFIED | Local rerun confirms count one initially, after two sources and in a nested shell. Supplied smoke logs 3/4 show `changed=2`, then `changed=0`; logs 5/6 show `changed=3`, then `changed=0`; all have `failed=0`. C3 reports one append line after migration. Direct temporary-file module checks also confirm idempotence. |
| AC6 | VERIFIED | Existing config remains protected by `force: false`; installs remain gated on newly seeded config. VM C2/C3 report `mise_config_unchanged=yes` with markers retained; all four new replay logs skip tool installation. |
| AC7 | NOT_VERIFIED in full | README/smoke docs correctly describe initial EOF placement and the difference from the old installer-home fix. BACKLOG removal/Watch entry follows the workflow. Final report is still pending; later edits have the placement limitation below. |
| AC8 | NOT_VERIFIED in full | Supplied ansible-lint, syntax, yamllint and pre-commit evidence supports completed checks. `precommit-3.log` reports gitleaks and applicable lint hooks Passed; commit/push hooks remain pending. The AC row still says pre-commit pending, although the final Log entry correctly records it complete. |
| AC9 | VERIFIED for review and F1.1 resolution | Review 1 is present; its finding is resolved by code inspection and independent reproduction. This file supplies review 2. |
| AC10 | NOT_VERIFIED | Commit, push, PR and CI are pending subsequent steps; no completion inferred. |

Every current `VERIFIED` mission row (AC2–AC6) has supporting evidence for its quoted scenarios. No unsupported successful check was identified.

## Commands run

All reviewer commands below exited 0. `$E` is notation for the evidence directory above; Python drivers used its literal absolute path.

- `cat AGENTS.md docs/missions/2026-11-05-pnpm-global-bin-path/review-brief-2.md docs/missions/2026-11-05-pnpm-global-bin-path/mission.md` → exit 0; read current instructions, correction and statuses.
- `git status --short`, `git diff HEAD -- roles/cli_tools README.md BACKLOG.md test/smoke/README.md`, and `cat CLAUDE.md docs/agent-workflow.md` → exit 0 each; inspected scope, changes and review requirements.
- `cat roles/cli_tools/vars/main.yml roles/cli_tools/tasks/main.yml roles/cleanup_legacy/tasks/main.yml`, targeted `git diff HEAD` for vars/smoke README, and `git diff HEAD --check` → exit 0 each; reviewed complete role logic and whitespace.
- `cat "$E/local-repro.sh"` → exit 0; audited updated rendering, clean-shell setup, offline installs and assertions.
- `python3 -` evidence reader → exit 0; read `local-repro-2.log`, VM B2/C2/B3/C3, smoke logs 3–6, `ansible-lint-2.log`, `yamllint-2.log`, `syntax-2.log`, and `precommit-3.log`. Raw results support the brief; the empty yamllint log's exit 0 is attested by the brief.
- `TMPDIR=/tmp bash "$E/local-repro.sh" "$E/vars-before.yml" roles/cli_tools/vars/main.yml "$E/vars-owner.yml"` → exit 0; 42/42 assertions passed using current role vars and temporary homes (`/tmp/pnpm-repro.N9uokW`).
- `cat roles/cleanup_legacy/vars/main.yml`, `git diff HEAD --stat`, targeted mission/brief diff, and `rg -n` inspection of installed `ansible/modules/blockinfile.py` → exit 0 each; checked cleanup exclusions and insertion/update implementation.
- `python3 -` temporary-file/module driver → exit 0; invoked `.venv/bin/python -m ansible.modules.blockinfile` with structured arguments against missing, empty and existing files under `/tmp/pnpm-block-review.*`. Each first insertion changed the file, each second call did not. A later unrelated appended line survived with the block in place. The driver also checked top-block equality with HEAD, absence of cleanup-line overlap, `bash -n`, and repeated sourcing with custom home containing spaces/globs, empty home and custom XDG. All assertions passed.
- Final `python3 -` snapshot/verdict check and `git diff HEAD --check` → exit 0 each; worktree excluding this review matches `$E/snap-before-2.txt`, review verdict is present, and tracked changes have no whitespace errors.

## Not checked

- Real laptop and smoke VM execution: prohibited for this reviewer. VM claims were assessed from supplied outputs; no laptop application is claimed.
- Network/Context7/current online documentation and registry-backed installs: prohibited. Actual offline pnpm behavior and installed module source were used for verification.
- Lint, playbook syntax and pre-commit reruns: supplied logs inspected instead. Pre-commit may modify files outside this review's write scope.
- Final main-tree/stash comparison, commit/push hooks, PR and CI: pending mission steps.

## Reservations

- `insertafter: EOF` controls the first insertion only. Later appended content remains after the managed block; an unrelated comment was retained in the independent check. If a later edit changes `PNPM_HOME` or replaces PATH after this block, the final-home guarantee no longer holds, and rerunning the role will not relocate the existing block. Keep home-setting installer/configuration lines before it. This does not block the tested existing-installation repair, and the task comment/brief correctly acknowledge the placement behavior.
- The guard preserves a preexisting bin entry's position and existing duplicates. It prevents adding another occurrence rather than repairing arbitrary PATH state. The newer `pnpm setup` prepend remains explicitly deferred in README/BACKLOG.
- Local tests stub mise activation and other shell hooks; actual mise integration is supported by the supplied VM evidence. Non-interactive child processes inherit their parent's environment; the unchanged README wording is not an environment-independent resolution guarantee.
- Final mission completion still requires the pending preservation, reporting and delivery steps. This verdict approves the reviewed correction, not those unexecuted steps.
