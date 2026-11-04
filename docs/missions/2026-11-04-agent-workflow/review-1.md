# Review 1 — 2026-11-04-agent-workflow

VERDICT: CHANGES_REQUESTED

## Findings

- F1.1 [major] `docs/agent-workflow.md:202` — The launch snippet unsets three named variables, but its check also detects `GITHUB_TOKEN`, `GH_TOKEN`, and every other `TF_VAR_*`. Those remain inherited if present. The check returns success when it finds them, and the subsequent commands still start Codex; reading five terminal lines is the only gate. A subshell with empty synthetic exports reproduced the surviving names and exit 0 without inspecting credential values. Clear all credential names covered by the policy and make a failed cleanliness check prevent agent startup, with an explicit recovery step.
- F1.2 [major] `docs/missions/2026-11-04-agent-workflow/mission.md:57` — The mission already says `done` and directs the next session to a user decision on `report.md`, although that file does not exist and this is the first review. Reviewer and cycle point to a Log that contains neither; all AC statuses say `see report`, and the brief omits the AC status/evidence table required by §5.1. Following §9 after an interruption therefore starts from contradictory state and requires asking the user. Record the actual `review-1` phase, reviewer/pane, cycle and next step; give each AC a defined status and available evidence, keeping unfinished checks `NOT_VERIFIED`. Update these fields at each transition rather than pre-filling completion.
- F1.3 [minor] `docs/agent-workflow.md:98` — The main-tree preservation checksum hashes only unstaged tracked changes. Staged and untracked user work can change or disappear while this checksum stays identical. In this worktree, the same command produces zero diff bytes despite 42,050 bytes from `git diff HEAD --binary`, demonstrating the staged-change blind spot. Define a preservation snapshot that covers staged and unstaged changes and nonignored untracked paths/content, and use the same definition before/after and on resume. Keep the patch contents out of session output.
- F1.4 [minor] `docs/agent-workflow.md:192` — `snap` does not propagate failures from `cd`, `git diff`, file enumeration or hashing: the final `sha256sum` can successfully hash an empty/partial stream. The smoke logging example at line 149 similarly returns `tee`'s status, potentially recording a failed replay as exit 0. `false | sha256sum` reproduced a valid empty-stream hash and exit 0. Require pipeline failure propagation and explicit successful snapshot/check completion before comparing hashes or assigning `VERIFIED`; preserve the replay's exit status when logging it.
- F1.5 [minor] `docs/agent-workflow.md:127` — On a fresh installation, the dummy-password snippet writes into `~/.local/share/laptop-bootstrap-agent/` without creating it. No preceding step creates that parent directory. Redirection and `chmod` then fail, but the following export/unset can make the block appear successful and leave Ansible pointed at a nonexistent file. Create the parent first and stop on creation/write failures before exporting the path. The directory exists in this session, so this is a first-run issue found by inspection.
- F1.6 [minor] `CLAUDE.md:8` — The parent-context link `../../CLAUDE.md` does not exist from this worktree. It resolves under `local/`, whereas the normal checkout has a different depth. This breaks the docs-only requirement to check cited links in the very isolation layout the workflow prescribes. Make the scope explanation self-contained or provide a reference that works from the supported worktree layout.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Roles and repository/VM/laptop limits are explicit in CLAUDE.md, AGENTS.md and workflow §1; owner retains merge and laptop execution. |
| AC2 | NOT_VERIFIED | Mission layout and per-objective criteria are defined, but current statuses/evidence and resume metadata are incomplete (F1.2); final report pending. |
| AC3 | VERIFIED | §4.3 defines the three evidence statuses and distinguishes lint, VM and laptop proof; CI description agrees with `.github/workflows/ci.yml`. Current mission's use of statuses is covered by F1.2. |
| AC4 | VERIFIED | §3 limits the loop to three reviews and requires a blocked/partial report if findings remain. |
| AC5 | NOT_VERIFIED | §9 defines resume branches, but the live mission cannot supply the state it requires (F1.2). |
| AC6 | VERIFIED | Removal convention matches BACKLOG.md; superseded CLAUDE.md work becomes a cleanup entry conditional on merge, and Python-path issue becomes Watch work. No branch deletion performed. |
| AC7 | NOT_VERIFIED | Tag distinctions, seed-only mise config, hooks and target limits agree with code; credential cleanup and preservation/check snippets need F1.1 and F1.3–F1.5. |
| AC8 | VERIFIED | Guide diff is limited to mise/cli-tools recommendations and a full-run cleanup warning; these agree with bootstrap tags and Makefile. |
| AC9 | VERIFIED | Installed versions report herdr 0.9.1 and codex-cli 0.166.0. Local help accepts the split/start/run and Codex CLI options examined; all five Bash blocks parse. Runtime safety is separately covered by findings; the jq response path was not independently exercised. |
| AC10 | NOT_VERIFIED | This session received the brief and writes the review; orchestrator receipt, snapshot/freshness checks and final report remain to be evidenced by Claude Code. |
| AC-SAFE | NOT_VERIFIED | Review stayed within read-only inspection and this output file. Full main-tree before/after hashes and final hook evidence were not supplied; historical absence of secret access cannot be inferred from the brief alone. |

## Commands run

- `cat AGENTS.md docs/missions/2026-11-04-agent-workflow/review-brief-1.md CLAUDE.md docs/agent-workflow.md` → exit 0; read governing instructions and brief.
- `git status --short`, `git diff HEAD --stat`, `git diff HEAD`, `git diff --cached --stat`, `git diff HEAD -- docs/guide-daily-usage.md` → exit 0; eight staged files, no initial unstaged/untracked files, documentation-only change.
- `git show 6027b10:CLAUDE.md` → exit 0; compared the previous orientation document with the refreshed version.
- `cat` of mission.md, BACKLOG.md, Makefile, `.pre-commit-config.yaml`, `ansible.cfg`, `.github/workflows/ci.yml`, bootstrap/cli_tools tasks, smoke Vagrantfile, devtools main/Postman tasks and postman_cli tasks/defaults → exit 0; inspected implementation and quoted-check context. `nl -ba` of workflow and mission → exit 0; located findings.
- `git diff HEAD --check` → exit 0; no whitespace errors.
- `git branch -vv`, `git worktree list`, `git stash list`, `git ls-files -o --exclude-standard` → exit 0; confirmed isolated branch at de0c4b6 with no upstream and no initial untracked files; did not alter Git state.
- Isolated `bash -c` reproduction using empty synthetic credential exports, the documented `unset`, and `compgen -e | grep -E '^(ANSIBLE_VAULT_PASSWORD|TF_VAR_.*|GITHUB_TOKEN|GH_TOKEN)$' || echo env-clean` → exit 0; names `GH_TOKEN`, `GITHUB_TOKEN`, `TF_VAR_other` survive and the check reports success. No inherited credential values printed.
- `bash -c 'false | sha256sum; printf "pipeline-exit=%s\n" "$?"'` → exit 0; failed producer yields the empty-stream SHA256 and `pipeline-exit=0`.
- `command -v herdr codex jq uv` and `test -d /home/xgueret/.local/share/laptop-bootstrap-agent` → exit 0; binaries and existing dummy-file parent found.
- `herdr pane split --help`, `herdr pane run --help`, `herdr agent start --help`, `codex --help`, `herdr --version`, `codex --version` → exit 0; local options and versions checked. Codex emitted a read-only-filesystem warning for PATH alias creation; no approval or retry requested.
- Inline Python inspection of local Markdown link targets and report existence, plus byte counts from `git diff --binary` and `git diff HEAD --binary` → exit 0; missing parent link, absent report, and 0 versus 42,050 diff bytes confirmed.
- Inline Python extraction of each workflow Bash fence followed by `bash -n` → exit 0 for all five blocks; syntax only, not execution.
- `git diff HEAD --binary -- . ':!docs/missions/2026-11-04-agent-workflow/review-1.md' | sha256sum` → exit 0; initial tracked-content hash `ea23b24a073a488235d5fd1ca4432749213eae410df30e40c413014dd0e9bd35`. Matching `git ls-files -o --exclude-standard -z` exclusion piped to `xargs -0r sha256sum` → exit 0, no initial untracked input.
- Final `git status --short`, the same tracked-content hash command, `git ls-files -o --exclude-standard -- . ':!docs/missions/2026-11-04-agent-workflow/review-1.md'`, `test -s` of the review and `rg -n '^(VERDICT:|## )'` of the review → exit 0; tracked hash unchanged, no other untracked files, review present with the required verdict and sections.

## Not checked

- Main checkout contents and preservation comparison: kept inspection inside this worktree; supplied initial hash is abbreviated and no final comparison is quoted.
- Pre-commit rerun: hooks can edit files and initialize caches; reviewer may write only this review. The brief's successful run predates two edits and says a final rerun is pending.
- Ansible lint/yamllint/syntax checks: earlier exit statuses are supplied by Claude Code; not independently rerun for this documentation change. No vault contents or secret-producing scripts were read or executed.
- Smoke VM and laptop execution: outside reviewer permissions and unnecessary for this documentation change.
- New Herdr pane/agent creation, jq response shape, agent reuse, final review retrieval and interruption recovery: no orchestration mutations performed. Only local help and this received brief demonstrate the available launch path.
- Network documentation lookup: forbidden by repository review limits; used installed help and repository code.

## Reservations

- No unsupported claim marked `VERIFIED` was found in the submitted AC table: its problem is that every status is instead deferred to an absent report (F1.2).
- Repository-specific technical descriptions are consistent with inspected code, including untagged bootstrap tasks, cleanup ordering, mise `force: false` and install-on-seed behavior, vault exclusion/stubs, default skipped `vagrant` tag, and separate Postman desktop/CLI paths. No additional script or abstraction is needed to address these findings.
