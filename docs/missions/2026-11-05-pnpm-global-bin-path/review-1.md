# Review 1 — 2026-11-05-pnpm-global-bin-path

VERDICT: CHANGES_REQUESTED

## Findings

- F1.1 [major] roles/cli_tools/vars/main.yml:31 — The bin directory is selected before a later installer block can set `PNPM_HOME`. The role deliberately inserts its managed block before other hooks (`tasks/main.yml:56`), while the legacy pnpm installer exports a literal home directory later. With no inherited `PNPM_HOME` and a custom installer location, the new block appends the default `~/.local/share/pnpm/bin`; the installer then sets the custom home and appends only that home, leaving its `bin` directory absent. I reproduced `pnpm add -g` failing with `ERR_PNPM_GLOBAL_BIN_DIR_NOT_IN_PATH` using real mise pnpm 12 and an offline local package. This also affects an existing default-location installer when a different `XDG_DATA_HOME` is inherited. Resolve the effective installer home before appending its bin directory, or add the guarded append after the installer establishes its final home. Preserve the old bins and mise precedence. Add an isolated check with an initially unset `PNPM_HOME`, a later custom installer export, and a second fresh shell; the current existing-layout test uses matching defaults and misses this case.

Reproduction used the exact export/case portion extracted from the YAML block, followed by the existing installer's post-replacement form:

```sh
# Initially: HOME=/tmp/pnpm-review.loang8j5, PNPM_HOME unset.
# Execute the managed export/case, then the later installer block:
export PNPM_HOME=/tmp/pnpm-review.loang8j5/custom-pnpm
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PATH:$PNPM_HOME" ;;
esac
# Run real mise pnpm with its node on PATH, installing a local package offline.
```

Observed: `add_rc=1`; PATH ended with
`/tmp/pnpm-review.loang8j5/.local/share/pnpm/bin:/tmp/pnpm-review.loang8j5/custom-pnpm`;
pnpm reported that `/tmp/pnpm-review.loang8j5/custom-pnpm/bin` was not in PATH.

## AC check

`$E` below means `/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-global-bin-path`.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | NOT_VERIFIED | Role files equal their original backups; original patch SHA-256 matches the mission. Final main-tree snapshot/stash comparison remains pending, as correctly stated in the mission. |
| AC2 | VERIFIED | Independent offline rerun reproduces the pre-fix error for both existing and fresh layouts. `vm-B-prefix.txt` reports the same error with pnpm 12.17.0. |
| AC3 | NOT_VERIFIED for full existing-laptop scope | Independent rerun passes all three documented layouts; VM states A/C support successful installs and executable resolution. F1.1 demonstrates an additional existing-installer layout that still fails. The mission's quoted successful results are supported, but do not cover this layout. |
| AC4 | VERIFIED for tested layouts | Local rerun confirms mise node/pnpm first, system directories before global bins, and resolution of the legacy `oldtool`. VM state C reports indices 14 < 20 < 26, with legacy home at 27. Custom-home integration needs the F1.1 correction. |
| AC5 | VERIFIED for tested layouts | Independent rerun: bin count one initially, after two sources, and in a nested shell. Supplied smoke logs show `changed=2`, then `changed=0`, both `failed=0`. VM replays were not repeated by the reviewer. |
| AC6 | VERIFIED | `force: false` preserves existing mise config; install is gated by config creation. VM state C reports `mise_config_unchanged=yes` and marker count one; both replay logs skip tool installation. |
| AC7 | NOT_VERIFIED | Docs accurately describe the tested default layout, the distinction from PR #50, and the deferred `pnpm setup` problem. Final report is pending; F1.1 limits the unconditional existing-layout claim. BACKLOG removal on the feature branch follows the workflow. |
| AC8 | NOT_VERIFIED | Supplied lint/pre-commit logs support the completed checks; commit/push hooks remain pending, as stated. No hooks were rerun by the reviewer. |
| AC9 | NOT_VERIFIED | This review supplies the independent review; handling its finding remains pending. |
| AC10 | NOT_VERIFIED | Commit, push, PR and CI are subsequent implementation steps, outside this review. |

All six mission rows currently marked `VERIFIED` have supporting local/VM output for the scenarios quoted. The issue is incomplete coverage of a real installer configuration, rather than an invented successful execution.

## Commands run

All commands below exited 0, including the Python checks that intentionally asserted the reproduced pnpm failure. The pnpm operation inside the custom-home probe exited 1 as described above.

- `cat AGENTS.md docs/missions/2026-11-05-pnpm-global-bin-path/review-brief-1.md CLAUDE.md docs/agent-workflow.md` → exit 0; read review scope, constraints and required format.
- `git status --short` and `git diff HEAD -- . ':!docs/missions/2026-11-05-pnpm-global-bin-path/review-1.md'` → exit 0 each; inspected all seven staged files, with no initial untracked files.
- `cat` of the mission, complete role vars/tasks and reference mise config → exit 0; inspected shell ordering and seed-only config behavior.
- `ls -la "$E/"` and `cat` of the using-superpowers skill and Codex reference → exit 0 each; inspected available evidence and applicable process instructions.
- `cat "$E/local-repro.sh" "$E/vm-check.sh"` → exit 0; audited test isolation, assertions, and VM preparation/check logic.
- `cat` of `local-repro.log`, VM states A/B/C, both replay logs, `ansible-lint.log`, `precommit-1.log`, `syntax.log`, and `pnpm-setup-bashrc.txt` under `$E` → exit 0; checked the raw evidence against the brief and mission.
- `TMPDIR=/tmp bash "$E/local-repro.sh" "$E/vars-before.yml" roles/cli_tools/vars/main.yml` → exit 0; independently reproduced and verified all 25 assertions with the current role block, using only temporary homes and offline packages.
- `git diff HEAD --check`, `git rev-parse --short HEAD`, `git branch --show-current`, and `git ls-files --others --exclude-standard` → exit 0 each; clean whitespace, base `d751cb6`, branch `fix/pnpm-global-bin-path`, no initial untracked files.
- `nl -ba roles/cli_tools/vars/main.yml`, numbered README inspection, and `tail -n 8 "$E/smoke-up.log"` → exit 0; checked line references and full-provision recap (`failed=0`).
- `python3 -` shell probe → exit 0; extracted current YAML, ran `bash -n` (exit 0), and checked repeated sourcing for inherited custom `PNPM_HOME` containing spaces/glob characters, empty `PNPM_HOME`, and custom XDG with empty `PNPM_HOME`. All passed. The same driver reproduced F1.1 with a later custom installer export and real pnpm/node, entirely under `/tmp`.
- `python3 -` fixture/backup check → exit 0; before fixture equals HEAD, after fixture equals current YAML, both owner role files equal backups, original patch SHA-256 equals `5b056065af80bc08b9f29ca7a018fd903e1e6d00223dc2e949c9c39ed2c6289f`. The yamllint log is empty; its exit 0 is attested by the brief rather than embedded in that log.
- `git diff --name-only HEAD`, `git diff --cached --stat`, `cat .pre-commit-config.yaml`, and numbered task inspection → exit 0 each; confirmed scope, hook configuration, insertion point and legacy replacement regexp.
- Final `python3 -` snapshot check and `git diff HEAD --check` → exit 0 each; review exists with the stated verdict, and the worktree snapshot excluding this review equals `$E/snap-before-1.txt`.

## Not checked

- Real laptop execution or configuration inspection: prohibited. The mission explicitly does not claim laptop application.
- Smoke VM execution: prohibited for this reviewer; assessed the supplied logs and scripts instead.
- Network, Context7/current online documentation, and registry-backed installs: prohibited. The diagnosis was checked against the supplied evidence and actual offline pnpm behavior.
- Lint/syntax/pre-commit reruns: supplied logs inspected; unnecessary to repeat for the shell-ordering finding. Pre-commit can modify files, outside this review's write scope.
- Final main-tree/stash preservation, commit/push hooks, PR and CI: still pending in the mission, not inferred as complete.

## Reservations

- The local reproduction stubs mise activation and the other hooks; actual mise interaction is supported by the supplied VM evidence.
- A preexisting `$PNPM_HOME/bin` entry is retained in its existing position. The guard prevents adding duplicates; it does not repair previous duplicates or precedence. The README warning and BACKLOG Watch item explicitly defer the newer `pnpm setup` prepend, and the supplied probe supports that limitation.
- Normal Ubuntu non-interactive shells return before the managed block. Child processes can inherit an interactive parent's PATH; the existing README description of non-interactive resolution should not be interpreted as a guarantee independent of the inherited environment.
