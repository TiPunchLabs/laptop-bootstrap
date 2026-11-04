# Review 2 — 2026-11-04-agent-workflow

VERDICT: CHANGES_REQUESTED

## Findings

- F2.1 [major] `docs/agent-workflow.md:105` — Snapshot failures still do not reliably propagate in the documented callers. Calling a Bash function on the left of `||` or `&&` disables `errexit` inside its body, including this subshell. Extracting the exact function and running `snap /nonexistent <exclude> || echo "STOP: snapshot failed"` returned exit 0 and the current worktree's valid hash after the failed `cd`; the STOP branch never ran. §5.2 uses precisely this calling pattern, and §5.6 puts the function in a pipeline tested by `&&`. Explicitly propagate failures from `cd` and each producer instead of relying on `set -e`; make the caller actually stop on failure rather than returning success from `echo`. Test the function through both documented callers, including failures before and during hashing. F1.4 remains open for snapshots; the smoke logging change is resolved.
- F2.2 [minor] `docs/agent-workflow.md:106` — `git diff HEAD` captures the net working-tree content but not a distinct staged version. For a tracked file with HEAD=A, index=B and working tree=A, it emits no patch; resetting index B to A leaves the snapshot unchanged and loses staged user work. Hash separate staged and unstaged patches (or equivalent index/worktree representations), plus HEAD and untracked content. F1.3 is improved for staged-only changes but still incomplete when staged and unstaged edits cancel.
- F2.3 [major] `docs/agent-workflow.md:140` — Dummy-file setup failures print STOP but do not stop execution. With a mock `mkdir` returning 1, the exact §4.1 block reached the following command, exited 0 and left `ANSIBLE_VAULT_PASSWORD_FILE` unset. Lines 147–148 now explicitly instruct placing Ansible/pre-commit in that same invocation: those commands can therefore proceed after failed setup and fall back to `ansible.cfg`'s forbidden password helper. Make failure exit/return nonzero before any subsequent command, and gate the Ansible invocation on successful setup. No helper or Ansible command was run in this reproduction. F1.5's missing-parent issue is fixed, but its failure-handling requirement remains open.
- F2.4 [minor] `docs/missions/2026-11-04-agent-workflow/mission.md:62` — The resume baseline is only `3ccad843…9b83`; neither State nor Log names a file containing the complete original snapshot. A fresh session cannot compare a recomputed full hash against that abbreviated value, as §9 requires. Record the full baseline or its exact persistent evidence filename. Reviewer/pane, phase, cycle and AC statuses otherwise resolve F1.2.
- F2.5 [minor] `docs/missions/2026-11-04-agent-workflow/mission.md:46` — AC10 is now `VERIFIED (cycle 1)` even though its criterion includes the final report exchange and `report.md` is still absent. The review's existence and freshness support the review round trip, not the entire stated outcome; review 1 explicitly left AC10 `NOT_VERIFIED` for this reason. Keep the full criterion `NOT_VERIFIED` until the report exists and the exchange is evidenced, or split the completed review round trip from the pending report outcome. This is a VERIFIED claim with incomplete supporting evidence.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Role/permission rules unchanged and consistent with review 1. |
| AC2 | NOT_VERIFIED | Criteria now have statuses and evidence references; report remains pending, correctly acknowledged by Claude Code for AC2. |
| AC3 | VERIFIED | Evidence definitions and lint/VM/laptop distinction remain explicit. AC10's application of the rule needs F2.5. |
| AC4 | VERIFIED | Three-review limit and blocked/partial report rule unchanged. |
| AC5 | NOT_VERIFIED | Review phase, agent/pane and cycle are now usable; complete preservation baseline still needed (F2.4). |
| AC6 | VERIFIED | BACKLOG convention and diff remain as assessed in review 1. |
| AC7 | NOT_VERIFIED | Broader credential cleanup works with synthetic exports, but snapshot and dummy-file failure paths remain unsafe (F2.1–F2.3). Repository-specific tag/mise/VM/Postman rules are unchanged. |
| AC8 | VERIFIED | Guide changes remain limited to the previously verified recommendations. |
| AC9 | VERIFIED | Previously checked launch flags remain; installed `herdr pane wait-output --help` accepts the new options. All six Bash fences parse. This does not establish successful execution of the revised pane launch. |
| AC10 | NOT_VERIFIED | First review exists and is newer than its brief; this second request demonstrates continued reviewer reuse. Final report is absent (F2.5). |
| AC-SAFE | NOT_VERIFIED | Final main-tree comparison and final hook run remain pending. This review used read-only checks and wrote only review-2.md. |

## Commands run

- `cat` of AGENTS.md, brief 2, CLAUDE.md, mission.md, workflow and review 1; `sed -n '90,180p' docs/agent-workflow.md`; `nl -ba` excerpts of workflow and mission → exit 0; inspected fixes, requirements and line references.
- `git status --short`, `git diff HEAD --stat`, `git diff HEAD -- CLAUDE.md BACKLOG.md README.md docs/guide-daily-usage.md`, `git diff --cached --name-only`, `git diff --name-only`, `git ls-files -o --exclude-standard`, `git branch --show-current`, `git rev-parse HEAD` → exit 0; ten staged documentation files, initially no unstaged/untracked files, branch docs/agent-workflow at de0c4b636a6a2271ab1b86b16f20515722de0ef9.
- `git diff --check HEAD` → exit 0; no whitespace errors.
- Inline Python extraction of six Bash fences, each passed to `bash -n` → all exit 0; syntax only.
- Exact extracted `snap` called directly on this worktree with review-2 excluded → exit 0, hash `f6a49ad0d12354b61aa91300aaaa4e1c0bb5a5d52adced275d67a130e0b9c060`. Direct call on `/nonexistent` → exit 1, no hash. Same missing-directory call followed by the documented `|| echo "STOP: snapshot failed"` → exit 0, failed-cd diagnostic and the worktree hash, no STOP message (F2.1).
- Exact extracted `snap` with a shell mock making all Git calls fail, invoked through the documented OR caller → overall exit 0; emitted the empty-stream hash and STOP, demonstrating that the caller also masks the function's nonzero status.
- Exact §4.1 block in a subprocess with `mkdir` mocked to fail and the dummy-file export unset → exit 0; printed STOP followed by `next-command-reached; dummy-exported=` (F2.3). No filesystem writes, secret access or Ansible execution.
- Documented credential unset with empty synthetic `ANSIBLE_VAULT_PASSWORD`, `GITHUB_TOKEN`, `GH_TOKEN`, `TF_VAR_other` exports, followed by the documented count expression → exit 0, `env_dirty=0`; no credential values printed.
- Synthetic Git mock presenting the same HEAD/net diff and two different staged versions to the extracted `snap` → exit 0, identical hashes; confirms the function never requests the distinct index patch (F2.2). No Git writes.
- Inline Python check of local Markdown links in AGENTS.md, CLAUDE.md, README.md, workflow and daily guide, report existence and review-1 freshness → exit 0; no missing link targets, report absent, review 1 newer than brief 1.
- `herdr pane wait-output --help` → exit 0; supports pane argument, `--regex` and `--timeout`; help states that existing output is searched before polling.
- `git diff HEAD --binary -- . ':!docs/missions/2026-11-04-agent-workflow/review-2.md' | sha256sum` → exit 0; initial tracked-content hash `876402a7ad2181dd47226cd0ad8114232ca4c10fc5bd8c158099c8a20eeba1ac`.
- Final `git status --short`, the same hash command, `git ls-files -o --exclude-standard -- . ':!docs/missions/2026-11-04-agent-workflow/review-2.md'`, `test -s` and section/verdict `rg` check → exit 0; tracked hash unchanged, no other untracked files, required review structure present.

## Not checked

- Revised pane launch, cleanup/gate output capture and failure recovery in Herdr: brief explicitly says this launch was not exercised; no panes or agents were created or altered during review. F1.1's broader cleanup and explicit close/stop instruction are accepted by inspection and synthetic testing, with live behavior reserved.
- Main-tree snapshot comparison and external evidence files: no final comparison supplied; kept inspection within the worktree. No secrets or vault contents were read.
- Pre-commit rerun: hooks may modify files/caches; accepted the brief's quoted exit 0 as implementer evidence, not an independently rerun check. A final run including the review/report remains the implementer's responsibility.
- Ansible checks, smoke VM, laptop runs and network lookup: no role changes; existing review limits apply. The dummy-setup failure was tested using shell mocks only.

## Reservations

- F1.6 is resolved. F1.2 is substantially resolved except the resume baseline in F2.4. Credential cleanup and smoke exit-status logging are improved without adding scripts or changing hooks.
- One correction cycle remains after this review; §3 requires a blocked/partial report if findings remain after review 3.
