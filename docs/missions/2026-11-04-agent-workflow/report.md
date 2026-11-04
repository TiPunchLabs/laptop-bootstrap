# Report — 2026-11-04-agent-workflow

## Executive summary

Objective: install in laptop-bootstrap the Herdr → Claude Code → Codex workflow
(objective → inspect/plan/implement/verify → independent Codex review via Herdr →
fixes → re-review → final report), adapted to this repository, and prove the
Herdr/Codex link with a real exchange.

Verdict: PARTIAL — the deliverable is complete and reviewed (review 4
PASS_WITH_RESERVATIONS, no findings, all final checks green), but AC-SAFE can no
longer be fully verified: one late hook run by Claude Code skipped the dummy vault
setup (see Incident). No secret was displayed or written.

- Done: project instructions (`CLAUDE.md`, `AGENTS.md`), procedure
  (`docs/agent-workflow.md`), mission files in the repo, minimal guide fixes,
  README link, BACKLOG update. Four real brief → review round trips with Codex
  through Herdr. All 13 findings of reviews 1–3 fixed; review 4 (one extra cycle
  authorized by the user for F3.1/F3.2) returned PASS_WITH_RESERVATIONS with no
  findings, and its reservations (final checks) are done below.
- History: reviews 1–3 ended PARTIAL on F3.1 (launch gate) and F3.2 (snapshot
  hash); this report replaces that PARTIAL report.
- Not done, by design: no commit, push, PR, merge, branch deletion or laptop run.
  The Python 3.12 venv pin stays a separate BACKLOG Watch item (no version change).

## Incident (vault safety)

- What: One hook run after the final checks (`pre-commit run --files mission.md`, to validate the last Log line) was launched by Claude Code without `ANSIBLE_VAULT_PASSWORD_FILE` set to the dummy file and without the credential `unset`, contrary to workflow §4.1. It exited 1, output discarded to `/dev/null` (nothing displayed or written). The ansible-lint hook may have called `bin/ansible-vault-pass.sh` → `pass show ansible/vault`; whether it did, and whether the vault was decrypted in memory, cannot be established (atime of the `pass` entry not updated under `relatime`, inconclusive). Re-run with the dummy file → exit 0 (`$E/precommit-final-3.log`).
- Impact: if `pass` was reached, gpg-agent may have released the vault password
  to ansible-lint in memory; nothing reached the terminal, a file or the repo.
  No rotation is needed for a value that was never exposed; that is your call.
- Cause: procedural slip on a one-line re-check, not a defect of the workflow;
  §4.1 already requires the dummy file for every hook run.
- Only this run is affected; every other hook/Ansible run in the mission used the
  dummy file (`precommit-*.log`, `Decryption failed` in `ansible-lint.log`).

## Initial state and preserved user work

- Main checkout `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap`,
  branch `main` = `origin/main` = `de0c4b6`, 2 stashes.
- Uncommitted user work (the `fix/pnpm-global-bin-path` correction; that branch
  has no commits of its own, it points at `94d9f91`): `README.md`,
  `roles/cli_tools/tasks/main.yml`, `roles/cli_tools/vars/main.yml`.
- Preservation evidence: sha256 of `git diff --binary` = `de419b87d062e363c291c8300bbf9717c37f65d5fbe3e4475a8f301fb490fec0`
  at inspection and at the end; full `snap` (HEAD + staged + unstaged +
  untracked) = `106b8ac01bd1aac34cbb55c797008d492f7420aab43c339328677092630e0177`
  at baseline and at the end. Status: VERIFIED. The main checkout was never
  switched, staged or edited.
- `docs/project-claude-md` (`6027b10`, 197-line `CLAUDE.md`): read, reused and
  refreshed. Outdated points corrected: missing `postman_cli` and `apt_keyring`,
  devtools now links `postman-app` (not `postman`), vault password comes from
  `ansible.cfg` → `bin/ansible-vault-pass.sh`.
- References read only: `homelab` (`docs/guides/runbook-dockhost-tfstate-gitlab-migration.md`:
  role/credential table, owner-terminal rule) and `contes-creole`
  (`docs/redesign/codex-review.md`: Codex launch flags, Herdr states, verdict
  block, 2-cycle limit). Neither repository was modified.
- Installed tools: herdr 0.9.1, codex-cli 0.166.0 (`--help` checked for every
  command used).

## Files (branch `docs/agent-workflow`, all staged, not committed)

Created:
- `CLAUDE.md` — refreshed orientation + hard rules (targets/permissions table,
  secrets, `--diff`, mise autonomy, `mise` vs `cli-tools`, hooks, CI ≠ laptop, git).
- `AGENTS.md` — Codex reviewer role and limits (30 lines; Codex does not read
  `CLAUDE.md` by itself).
- `docs/agent-workflow.md` — roles, mission files, lifecycle, verification by
  change type, evidence statuses, Herdr/Codex procedure, protection of local work,
  report, backlog rule, resume, how to start an objective.
- `docs/missions/2026-11-04-agent-workflow/` — `mission.md`, `review-brief-{1,2,3,4}.md`,
  `review-{1,2,3,4}.md` (written by Codex), this `report.md`.

Modified:
- `docs/guide-daily-usage.md` — 6 lines that presented `make play-cli-tools` /
  `TAGS=cli-tools` as "cli_tools only" now say `TAGS=mise`; the migration case
  keeps `make play-cli-tools` with its cleanup warning; the post-merge `make play`
  for `software.yml` (untagged) is kept, with a note that it runs `cleanup_legacy`.
- `README.md` — one link to the workflow (different hunk from the user's
  uncommitted README change: no conflict expected).
- `BACKLOG.md` — removed "Project-level `CLAUDE.md`" (done by this branch);
  added Cleanup "Delete `docs/project-claude-md`" (after merge); added Watch
  "`ansible.cfg` pins the venv to Python 3.12".

## Workflow retained

- User gives an objective plus optional extra authorizations; Claude Code works
  without asking except for structural decisions, actions above its level,
  trust/permission prompts, or conflicts with local work.
- Three targets: repository (autonomous, on a branch/worktree), smoke VM
  (autonomous except `smoke-down`), real laptop (owner only, after approving the
  exact command).
- Mission files in `docs/missions/<date>-<slug>/`; raw evidence in
  `~/.local/share/laptop-bootstrap-agent/<id>/`.
- Codex in a Herdr pane, `--sandbox workspace-write`, network off, credentials
  unset in the pane and checked by a fail-closed gate before `agent start`, dummy
  vault file; writes only `review-N.md`; worktree snapshot before/after each review.
- At most 3 reviews (2 correction cycles), then PARTIAL/BLOCKED report; further
  cycles only on quoted user authorization. Both paths were exercised here.
- Agents run Ansible/pre-commit with `ANSIBLE_VAULT_PASSWORD_FILE` pointing at a
  dummy file, so the vault is never decrypted and `pass` is never called.

## Extension cycle (F3.1, F3.2)

Authorization (second prompt, quoted in `mission.md`): fix F3.1 and F3.2, one
extra Codex review via Herdr; same exclusions.

- F3.1 fix, `docs/agent-workflow.md` §5.3: every step gates the next. Pane split
  under `pipefail` with `jq -er` and a non-empty id, else exit. `stop()` closes the
  pane, prints `STOP: <reason>` and exits 1 on failure of `pane run`,
  `pane wait-output` (`(?m)^env_dirty=[0-9]+$`, `recent-unwrapped`, 15 s),
  `pane read`, the check, or `agent start`. The check accepts only when the lines
  matching `^env_dirty=[0-9]+$` are exactly the single line `env_dirty=0`.
- F3.2 fix, §3 step 1 `snap`: final `printf | sha256sum | cut` under `pipefail`
  with `|| return 1`, then `[[ $h =~ ^[0-9a-f]{64}$ ]] || return 1`.
- Own finding during the real launch: `pane read --lines 5` counts screen rows; in
  a narrow pane the long prompt wraps, so the read returned 3 logical lines without
  the `env_dirty=0` line. The gate failed closed (no agent, pane `w1Q:p5` closed).
  Fixed to `--lines 50` with a comment. The proposal in the previous report's D1
  had the same `--lines 5` defect.
- §3 step 6: one sentence, further cycles only on quoted user authorization.

## Verification and evidence

Evidence dir `$E` = `~/.local/share/laptop-bootstrap-agent/2026-11-04-agent-workflow/`.

| Check | Command / method | Result | Status |
|---|---|---|---|
| Hooks incl. gitleaks | `.venv/bin/pre-commit run --files <staged>` (dummy vault, credentials unset) | exit 1 on the very first run (venv on Python 3.14, see Deviations), exit 0 on every later run including after the F3 fixes (`precommit-5.log`) and the final run (`precommit-final-2.log`); `Detect hardcoded secrets` and `Ansible-lint` Passed | VERIFIED |
| ansible-lint | `.venv/bin/ansible-lint` | exit 0, `Decryption failed` on vault (expected) | VERIFIED |
| yamllint / syntax | `.venv/bin/yamllint .`, `ansible-playbook playbook.yml --syntax-check` | exit 0 (no YAML changed since) | VERIFIED |
| Snippet syntax | `bash -n` on every bash fence | 6/6 (`bash-n-4.log`) | VERIFIED (syntax only) |
| F3 behaviour, pre-fix | `snippet-test-3.sh agent-workflow-before-fix-3.md` | 11 passed, 14 failed: reproduces F3.1 and F3.2 (`snippet-test-3-before-fix.log`) | VERIFIED |
| F3 behaviour, fixed | `snippet-test-3.sh docs/agent-workflow.md` (functions extracted verbatim from the doc; temp Git repo; `herdr` mock logging calls; synthetic data only) | 25/25 (`snippet-test-3.log`) | VERIFIED |
| snap cases | same | nominal 64-hex and stable; unstaged, staged, untracked, untracked-content changes each change the hash; exclusion honoured; `sha256sum` rc 1, empty output, malformed output, `cut` rc 1, missing repo, `git ls-files` rc 1 → STOP, next command not run | VERIFIED |
| Launch gate cases | same | clean → started; dirty, timeout, absent, mixed 0/1, duplicate, `env_dirty=0x`, read fails, run fails → no start, pane closed, rc 1; split fails / no id → no start, rc 1; start fails → pane closed, rc 1 | VERIFIED |
| Real Herdr behaviour | probe panes `w1Q:p4`, `w1Q:p6` (closed) | wait-output match rc 0, timeout rc 1, read of unknown pane rc 1; `--lines 5` vs `--lines 20` window (`herdr-probe-3.log`, `herdr-probe-4.log`) | VERIFIED |
| Real launch, fixed fence | `launch-fence-4.sh` (verbatim §5.3) as one Bash call | attempt 1 failed closed (`agent-start-4a-failclosed.log`); after the window fix, attempt 2 started `lb-review` in `w1Q:p7` (`agent-start-4.log`), no trust dialog | VERIFIED |
| Herdr/Codex link | 4 × `agent prompt --wait`, reviews read from files | `agent-prompt-{1,2,3,4}.json`, `codex-pane-transcript*.txt` | VERIFIED |
| Reviewer isolation | `snap` worktree before/after each review | unchanged ×4; reviews newer than briefs ×4 | VERIFIED |
| Independent re-check | Codex re-ran the extracted snippets with in-memory mocks | same outcomes as `snippet-test-3.log` (`review-4.md` Commands run) | VERIFIED |
| Main tree preserved | `snap` vs `main-tree-snap-baseline.txt`; sha256 of `git diff --binary` | equal at resume and at the end (see Initial state) | VERIFIED |
| Smoke VM | — | not run: no Ansible code changed | NOT_APPLICABLE |
| Laptop | — | not run: forbidden in this mission | NOT_APPLICABLE |

Acceptance criteria: AC1–AC10 VERIFIED; AC-SAFE NOT_VERIFIED on the "vault not decrypted" part only (Incident); see `mission.md`. Execution
of the snippets was proven with mocks and one real launch; the cleanliness check
itself proves only that the four variable families are absent from the pane.

## Reviews

| Review | Verdict | Findings | Outcome |
|---|---|---|---|
| 1 | CHANGES_REQUESTED | F1.1 env cleanup not a gate (major), F1.2 mission state pre-filled (major), F1.3 checksum missed staged/untracked, F1.4 failures not propagated, F1.5 dummy-file parent, F1.6 broken parent link | all fixed; residue of F1.1 became F3.1 |
| 2 | CHANGES_REQUESTED | F2.1 `set -e` ignored before `\|\|` (major), F2.2 staged/unstaged cancel, F2.3 dummy failure did not stop (major), F2.4 abbreviated baseline, F2.5 AC10 claimed early | all fixed; residue of F2.1 became F3.2 |
| 3 | CHANGES_REQUESTED | F3.1 (major), F3.2 (minor) | limit reached → PARTIAL; fixed in the authorized extension |
| 4 | PASS_WITH_RESERVATIONS | none | reservations = final report, main-tree comparison, final hooks: done |

## Deviations, risks and limitations

- Worktree venv: `uv sync` picked Python 3.14; `ansible.cfg` hardcodes
  `./.venv/lib/python3.12/...`, so the pre-commit ansible-lint hook failed. Rebuilt
  with `--python 3.12`; the 3.14 venv was moved (not deleted) to
  `$E/venv-py314-unused`. Separate BACKLOG Watch item; versions not changed.
- The cycle limit was exceeded by one review, on the user's explicit authorization.
- Snapshot definitions changed between cycles; each before/after pair used the
  same definition.
- Codex trust dialog (review 1): shown as `idle` by Herdr 0.9.1; answered "Trust
  and continue" on the owner's choice. `~/.codex/config.toml` now trusts the repo
  root. Not shown again for review 4.
- Codex printed a sandbox warning at startup (read-only PATH alias creation);
  reviews unaffected.
- This Claude Code session inherited `ANSIBLE_VAULT_PASSWORD` and
  `TF_VAR_github_token` via direnv. Values never read or printed; only names checked.
- The gate's `--lines 50` assumes a fresh pane; a reused pane with old output could
  make the check fail closed (never open). Safe direction.
- Resume (§9) was used once for real (this extension), not under a crash.
- `CONTRIBUTING.md` says "Open an issue" while issues are disabled: not changed.
- Left in place: temp test repos under `/tmp/claude-1000/snaptest.*`, evidence dir.

## Git state

- Main checkout: `main` at `de0c4b6`, user's 3 modified files untouched.
- Worktree `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/docs-agent-workflow`,
  branch `docs/agent-workflow` from `de0c4b6`; the 16 mission files form one commit, pushed to `origin/docs/agent-workflow` with a PR to `main` (owner authorization, D1).
- No merge, no branch deleted. Herdr panes created by this
  mission (`w1Q:p3`, `w1Q:p4`, `w1Q:p5`, `w1Q:p6`, `w1Q:p7`) all closed; `w1Q:p1`,
  `w1Q:p2` and other workspaces untouched.
- No Ansible run against the laptop; no infrastructure change.

## Decisions required

- D0 — Incident: accepted by the owner as documented (2026-11-04); AC-SAFE stays
  NOT_VERIFIED and the verdict stays PARTIAL.
- D1 — Commit, push and PR of `docs/agent-workflow`: authorized by the owner
  (2026-11-04), done in this branch (commit hash, PR and CI on GitHub). Merge is
  not authorized to agents: owner decision after PR review.
- D2 — After merge: BACKLOG cleanup entry for `docs/project-claude-md`; optional
  `trash ~/.local/share/laptop-bootstrap-agent/2026-11-04-agent-workflow/venv-py314-unused`.
- D3 — Separately: the Python 3.12 venv pin (BACKLOG Watch), when you choose.

## Next action — starting the next objective

After D1, in a Herdr pane, `cd` to the repository and start Claude Code with:

```text
Objective: <e.g. BACKLOG "libvirt — assert hardware KVM support">.
Follow docs/agent-workflow.md. Extra authorizations: <none | commit | commit+push+PR>.
```
