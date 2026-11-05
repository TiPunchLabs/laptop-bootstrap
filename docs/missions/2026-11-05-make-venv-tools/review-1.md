# Review 1 — 2026-11-05-make-venv-tools
VERDICT: PASS_WITH_RESERVATIONS

## Findings

- F1.1 [minor] bin/check_make_venv_tools.sh:21 — The static check matches the expected invocation anywhere on the line, rather than checking the invocation of each tool. I ran the actual static block in memory with a mocked `make`: `ansible-playbook playbook.yml # uv run --no-sync .venv/bin/ansible-playbook` passes (exit 0). The runtime half does not execute `play`, so this regression would escape it too. Expected fix: check the command prefix/structure for each expected recipe rather than accepting a substring, including text in comments. The current recipes are correct; this limits future regression coverage.
- F1.2 [minor] bin/check_make_venv_tools.sh:30 — A failed `make -n` inside process substitution does not propagate through `set -euo pipefail`; an empty recipe stream passes. A read-only reproduction using `make -f /dev/null missing-target` printed the missing-target error, but the consuming loop exited 0. Expected fix: capture each dry run with an explicitly checked exit status before scanning its output, and require the expected invocation to be present.
- F1.3 [minor] docs/missions/2026-11-05-make-venv-tools/mission.md:126 — AC-SAFE is `VERIFIED`, but the supplied evidence contains baseline snapshots only, without saved final hashes/checksums/stash output or an executed comparison result. “Re-checked at delivery” describes a later check, not evidence available for this review. Expected fix: record the comparison command, exit status and result, or keep preservation `NOT_VERIFIED` until that check runs. This is an evidence gap, not evidence of damage.

## AC check

Evidence paths below are relative to `/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-make-venv-tools/`. Runtime statuses are based on inspected implementer logs and `verify-summary-final.txt`; I did not rerun those commands.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | `diag-laptop-paths.txt` distinguishes pipx 26.9.0/core 2.21.5 without the XML module from project 26.1.1/core 2.20.1 with it. Before/control logs show the exact module failure versus success with the old config. The shell PATH ordering mechanism is appropriately identified as a hypothesis. |
| AC2 | VERIFIED | `v-owner-make-lint-ansible.log`, summary exit 0, production profile passed. |
| AC3 | VERIFIED | Owner hook passed; foreign-environment log explicitly warns that the other `VIRTUAL_ENV` is ignored and lint passes, summary exits 0/0. |
| AC4 | VERIFIED | Full Makefile inspection and fresh dry runs show all seven entry points using the combined form. Tagged targets inherit `play`; separate `play-syncthing` dry run includes its tag. Absolute `make -C` dry run resolves the project recipe. |
| AC5 | VERIFIED | Missing-environment logs show creation of an empty `.venv`, then explicit-path spawn failure, make/hook exits 2/1. No fallback executable runs. |
| AC6 | VERIFIED | Old-tree static failure, fixed check success and real-worktree variant failure reaching decoy `ansible-config` are supported by logs, exits 1/0/2. Before/after variant patches are byte-identical. This establishes the requested mismatch coverage, with F1.1/F1.2 limiting broader guarantees. |
| AC7 | VERIFIED | Diff leaves dependency files, Python range, collection configuration and roles unchanged. No Python-specific path or global collection installation is introduced. |
| AC8 | VERIFIED | Changed active documentation uses the combined form or Makefile targets. Remaining agent-command migration is explicitly tracked. Historical mission evidence is unchanged; the new record clearly corrects the earlier completion claim. |
| AC9 | VERIFIED | Inspected syntax logs name both playbooks; lint log reports success; yamllint log is empty with summary exit 0; pre-commit log reports passing applicable hooks, including ShellCheck and shfmt. |
| AC10 | NOT_VERIFIED | No final-head CI run yet; correctly marked pending. |
| AC-SAFE | NOT_VERIFIED | Hook configuration is not weakened, dummy-vault warnings are present and inspected verification commands avoid provisioning. Final preservation comparisons are not evidenced; see F1.3. |

## Commands run

All reviewer commands were read-only inspection or in-memory probes, except writing this review. All inspection calls exited 0.

- `cat AGENTS.md CLAUDE.md docs/agent-workflow.md docs/missions/2026-11-05-make-venv-tools/review-brief-1.md` → exit 0; read governing instructions and scope.
- `git status --short`, `git diff HEAD -- <reviewed paths>`, `git branch --show-current`, `git rev-parse HEAD` → exit 0; staged scope, branch and base match the brief.
- `git diff HEAD --check` → exit 0; no whitespace errors.
- `cat` of Makefile, CI/hook configuration, pyproject, mission, verification script/summary and snapshot helper; `rg --files` of evidence; Python read-only log and patch comparison → exit 0; inspected evidence described above.
- `ls -l .venv` → exit 0; worktree environment is a directory, not the symlink used in the scratch variant.
- `bash -n bin/check_make_venv_tools.sh` → exit 0; shell syntax accepted.
- `make -n --no-print-directory play uninstall-opera lint lint-ansible vault-edit vault-view clean` → exit 0; expected explicit project invocations printed only.
- `make -n --no-print-directory play-syncthing` → exit 0; project invocation with `--tags syncthing`.
- `make -n -C /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/make-venv-tools lint-ansible` → exit 0; expected project invocation.
- `rg -n 'ansible|pre-commit|collections_path' test/smoke/Vagrantfile test/smoke/ansible.cfg ansible.cfg` → exit 0; VM uses its own Ansible/configuration.
- Bash process-substitution failure probe using `make -n --no-print-directory -f /dev/null missing-target` → outer exit 0 despite inner make failure; confirms F1.2.
- Python in-memory execution of the script's static block with mocked dry-run output containing a bare command plus matching comment → exit 0, checker exit 0; confirms F1.1 without changing files.

## Not checked

- Runtime regression script, lint, syntax checks and pre-commit were not rerun: they create temporary files/caches or may initialize hook environments. Existing evidence was reviewed under the instruction to write only this review and use no network.
- No laptop provisioning, vault command, smoke VM, dependency synchronization or network operation was executed. Dry runs were inspected first: these recipes have no recursive-make or forced-execution constructs, so their `make -n` checks do not run the printed commands.
- No final-head CI or independent final preservation comparison; AC10 and AC-SAFE remain pending as explained above.
- No external documentation lookup; review used repository code and supplied execution evidence within the explicit no-network limit.

## Reservations

- The combined explicit path and environment setup addresses both demonstrated failures with a small change. The regression script plus CI step is proportionate to a failure that escaped earlier validation. CI supplies dependency installation, dummy vault setup and a real checkout before the new step; no missing prerequisite is apparent from inspection.
- The symlinked scratch variant is weaker evidence because executable shebangs/environment paths can point outside the scratch tree. The separate real-worktree variant log addresses that concern; CI's normal `.venv` directory matches the latter arrangement.
- Acceptance here covers the implementation and supplied validation, with the minor findings above. It does not establish final CI success, laptop behavior or completed preservation checks.
