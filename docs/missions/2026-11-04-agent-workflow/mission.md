# Mission 2026-11-04-agent-workflow — install the Herdr → Claude Code → Codex workflow

## Objective

User prompt of 2026-11-04 (French, summarized; the binding points are quoted):
"installer dans laptop-bootstrap le workflow Herdr → Claude Code → Codex utilisé
pour homelab et contes-creole, afin de traiter ensuite les tâches de BACKLOG.md."
Install project instructions and documentation so that the user gives an
objective, Claude Code inspects/plans/implements/verifies, Codex reviews
independently via Herdr, Claude Code fixes and asks for a new review, and a final
report lets the user decide. Adapt the rules to laptop-bootstrap (repository vs
VM vs laptop, no secrets, no `--diff` on secret-bearing files, mise autonomy,
`mise` vs `cli-tools`, checks, hooks, CI is not a laptop proof). Prove the link
with a real brief/report exchange with Codex, without running a backlog task.

## Authorizations

Granted: "inspection, isolation Git, modifications documentaires et de
configuration du workflow dans le dépôt, vérifications et revue Codex."
Excluded: "ne pas commiter, pousser, ouvrir de PR, fusionner, supprimer les
anciennes branches ou appliquer Ansible au laptop."
Extension of 2026-11-04 (second prompt): "J'autorise une extension ciblée de la
limite de cycles : corriger F3.1 et F3.2, puis effectuer une revue Codex
supplémentaire via Herdr." Same exclusions: "aucun commit, push, PR, merge,
nettoyage destructif ni application au laptop." The Python 3.12 reservation
stays a separate subject; no version change here.
Third prompt of 2026-11-04: incident accepted as documented, AC-SAFE not
considered verified; "J'autorise le commit, le push et l'ouverture d'une PR pour
docs/agent-workflow. Aucune fusion ni application au laptop." Python reservation
and old-branch deletion not handled in this step.

## Scope

In: `CLAUDE.md`, `AGENTS.md`, `docs/agent-workflow.md`, this mission directory,
minimal fixes to contradicting guide lines, `README.md` link, `BACKLOG.md`.
Out: roles, playbooks, CI, hooks config, homelab and contes-creole (read only),
the user's uncommitted `fix/pnpm-global-bin-path` work in the main tree.

## Acceptance criteria

Statuses as of the last transition (see State). Evidence paths under `$E` =
`~/.local/share/laptop-bootstrap-agent/2026-11-04-agent-workflow/`.

| ID | Criterion | Verification | Status | Evidence |
|---|---|---|---|---|
| AC1 | Roles of user, Claude Code and Codex, and their permission limits, are explicit | inspection + Codex review | VERIFIED | `review-1.md` AC1; `CLAUDE.md` table, `AGENTS.md`, workflow §1 |
| AC2 | Per-objective acceptance criteria, mission files kept in the repo (brief, review, report) | workflow §2, this directory | VERIFIED | this directory: mission, 4 briefs, 4 reviews, `report.md`; `review-4.md` AC2 |
| AC3 | Evidence statuses and executed vs not-executed checks defined; CI ≠ laptop | workflow §4.3, `CLAUDE.md` | VERIFIED | `review-1.md` AC3 |
| AC4 | Correction cycles bounded (≤ 2 after the first review), blocked report defined | workflow §3 step 6 | VERIFIED | `review-1.md` AC4 |
| AC5 | Resume conditions defined and usable from this file | workflow §9 + this State section | VERIFIED | `review-3.md`, `review-4.md` AC5 (documented inputs); used for real at the start of the extension cycle (Log `resumed`) |
| AC6 | `BACKLOG.md` rule follows the removal convention; backlog updated | workflow §8, `BACKLOG.md` diff | VERIFIED | `review-1.md` AC6 |
| AC7 | laptop-bootstrap rules (targets, consent, secrets, `--diff`, mise autonomy, `mise` vs `cli-tools`, checks, hooks, CI ≠ laptop) | `CLAUDE.md`, workflow §4 | VERIFIED | F3.1/F3.2 fixed; 25/25 behaviour tests (`$E/snippet-test-3.log`; pre-fix doc 14 failed); real launch failed closed then passed (`$E/agent-start-4a-failclosed.log`, `$E/agent-start-4.log`); `review-4.md` AC7 VERIFIED, no findings |
| AC8 | Contradicting guide recommendations fixed, nothing else rewritten | `git diff docs/guide-daily-usage.md` | VERIFIED | `review-1.md` AC8 |
| AC9 | Herdr commands and Codex flags match installed versions | `--help`, live run | VERIFIED | herdr 0.9.1 / codex 0.166.0 help; live split/run/wait-output/start/prompt in `$E/agent-start.json`, `$E/agent-prompt-1.json`; trust dialog shown as `idle` (doc fixed) |
| AC10 | Real brief → Codex review → report exchange via Herdr | briefs, reviews, `report.md` | VERIFIED | 3 brief → review round trips via `lb-review` (pane `w1Q:p3`), snapshots unchanged, reviews newer than briefs; `report.md` written. Review 4 via new `lb-review` (pane `w1Q:p7`, started by the fixed fence), snapshot unchanged, `review-4.md` PASS_WITH_RESERVATIONS |
| AC-SAFE | Main-tree work unchanged; no secret read or written; vault not decrypted; hooks not bypassed | `snap`, dummy vault, pre-commit | NOT_VERIFIED | VERIFIED: main tree `snap` = baseline `106b8ac0…0177` and `git diff --binary` sha256 = `de419b87…fec0` at start, resume and end; no secret value displayed or written; hooks run, none skipped. NOT_VERIFIED: "vault not decrypted" for one hook run without the dummy file (see Log `incident`) |

## Plan

1. Inspect repo state, docs, CI, hooks, `docs/project-claude-md`, references, Herdr/Codex.
2. Worktree `../laptop-bootstrap-worktrees/docs-agent-workflow`, branch `docs/agent-workflow` from `origin/main`.
3. Write `CLAUDE.md` (refresh of `6027b10` + rules), `AGENTS.md`, `docs/agent-workflow.md`; fix guide lines; README link; BACKLOG.
4. Verify: pre-commit on changed files (staged, dummy vault), ansible-lint, yamllint, syntax-check.
5. Codex review via Herdr, fix, re-review (≤ 2 cycles).
6. `report.md`.

## State

- Phase: done — verdict PARTIAL (deliverable reviewed PASS_WITH_RESERVATIONS; AC-SAFE not fully verifiable after the Log `incident`)
- Branch / worktree: `docs/agent-workflow` (no upstream) / `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/docs-agent-workflow`
- Base commit: `de0c4b6` (`origin/main`)
- Main tree (`../../laptop-bootstrap`): baseline `snap` (final §3 definition) in `$E/main-tree-snap-baseline.txt` = `106b8ac01bd1aac34cbb55c797008d492f7420aab43c339328677092630e0177`. Continuity with the start of the mission: sha256 of `git diff --binary` = `de419b87d062e363c291c8300bbf9717c37f65d5fbe3e4475a8f301fb490fec0` at inspection and when the baseline was taken (`$E/main-tree-initial.patch`, `.sha256`)
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-04-agent-workflow/`
- Reviewer: reviews 1–3 herdr agent `lb-review`, pane `w1Q:p3` (closed). Review 4: new `lb-review` pane `w1Q:p7` started with the fixed §5.3 fence (closed)
- Review cycle: 4 (one extra cycle authorized by the user; no further one)
- Next step: PR review and merge by the owner (merge not authorized to agents); after merge, BACKLOG cleanup of `docs/project-claude-md`

## Log

- 2026-11-04 inspect: main tree on `main` with 3 uncommitted files (pnpm global bin fix), unstaged sha256 `de419b87…fec0`.
- 2026-11-04 implement: worktree created, `uv sync --frozen --python 3.12` (a 3.14 venv broke the ansible-lint hook; moved to `$E/venv-py314-unused`), files written.
- 2026-11-04 verify: pre-commit on staged files exit 0 (gitleaks Passed); ansible-lint, yamllint, syntax-check exit 0 with dummy vault.
- 2026-11-04 review-1: pane `w1Q:p3`, env gate clean, Codex trust dialog answered "Trust and continue" by the owner; verdict CHANGES_REQUESTED (2 major, 4 minor).
- 2026-11-04 fix-1: F1.1–F1.6 addressed (see `review-brief-2.md`).
- 2026-11-04 review-2: verdict CHANGES_REQUESTED (2 major, 3 minor: snapshot/dummy-file failure handling, staged-vs-unstaged, baseline, AC10).
- 2026-11-04 fix-2: F2.1–F2.5 addressed (see `review-brief-3.md`); snippets tested through the documented callers (`$E/snippet-test-2.sh`).
- 2026-11-04 verify-2: pre-commit on staged files exit 0 (gitleaks Passed); bash -n on workflow fences: 6 ok, 0 failed.
- 2026-11-04 review-3: verdict CHANGES_REQUESTED (F3.1 major, F3.2 minor); cycle limit reached, fixes not applied.
- 2026-11-04 report: main tree unchanged; pane `w1Q:p3` closed; `report.md` written, verdict PARTIAL.
- 2026-11-04 resumed: user authorized one extra cycle for F3.1/F3.2. Main tree `snap` = baseline, `git diff --binary` sha256 = `de419b87…fec0`.
- 2026-11-04 fix-3: F3.1 launch fence gated step by step (`stop` closes the pane, exits before `agent start`); F3.2 final hash pipe under `pipefail` + 64-hex check. `$E/snippet-test-3.sh`: pre-fix doc 14 failed / 11 passed (`$E/snippet-test-3-before-fix.log`), fixed doc 25/25 (`$E/snippet-test-3.log`). Real Herdr probe pane `w1Q:p4` (closed): wait-output timeout rc 1, read of unknown pane rc 1, regex matches (`$E/herdr-probe-3.log`).
- 2026-11-04 launch-4: attempt 1 failed closed (`pane read --lines 5` missed the `env_dirty=0` line in a wrapped narrow pane; pane `w1Q:p5` closed, no agent); fixed to `--lines 50`, tests 25/25; attempt 2 started `lb-review` in pane `w1Q:p7`, no trust dialog.
- 2026-11-04 review-4: verdict PASS_WITH_RESERVATIONS, no findings; snapshot unchanged (`f59f4ed4…6da`), review newer than brief; pane `w1Q:p7` closed.
- 2026-11-04 final: pre-commit on 16 staged files exit 0 (gitleaks, Ansible-lint Passed; `$E/precommit-final-2.log`), `git diff --cached --check` exit 0; main tree `snap` = baseline, `git diff --binary` sha256 = `de419b87…fec0`; `report.md` rewritten.
- 2026-11-04 incident: One hook run after the final checks (`pre-commit run --files mission.md`, to validate the last Log line) was launched by Claude Code without `ANSIBLE_VAULT_PASSWORD_FILE` set to the dummy file and without the credential `unset`, contrary to workflow §4.1. It exited 1, output discarded to `/dev/null` (nothing displayed or written). The ansible-lint hook may have called `bin/ansible-vault-pass.sh` → `pass show ansible/vault`; whether it did, and whether the vault was decrypted in memory, cannot be established (atime of the `pass` entry not updated under `relatime`, inconclusive). Re-run with the dummy file → exit 0 (`$E/precommit-final-3.log`).
- 2026-11-04 deliver: incident accepted by the owner (AC-SAFE stays NOT_VERIFIED); commit, push and PR authorized, no merge. Remote checked `git@github-xgueret:TiPunchLabs/laptop-bootstrap.git`, `ssh -T` → xgueret. Commit hooks run with the dummy vault and cleaned environment.
