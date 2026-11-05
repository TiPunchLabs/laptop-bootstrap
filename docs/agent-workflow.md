# Agent workflow — objective → Claude Code → Codex review → report

How an objective is carried out in this repository with Claude Code as the
implementer, Codex CLI as the independent reviewer and Herdr as the link between
them. The hard rules (permission levels, secrets, tags) are in
[`../CLAUDE.md`](../CLAUDE.md#agent-workflow-and-hard-rules) and apply throughout.

Verified against herdr 0.9.1 and codex-cli 0.166.0 (2026-11-04). The installed
binaries are the authority: check `herdr agent`, `herdr pane`, `codex --help`
when a version changes.

```
 user ── objective ──► Claude Code ── inspect · plan · implement · verify
                           │   ▲
            review-brief-N │   │ review-N  (via Herdr, at most 3 reviews)
                           ▼   │
                         Codex (read/verify only, writes review-N.md)
                           │
 user ◄── report.md ───────┘   decides: commit / PR / merge / apply to laptop
```

## 1. Roles

| Role | Does | Never does |
|---|---|---|
| User (owner) | Gives the objective and any extra authorization; answers decisions; trust/permission prompts; applies to the laptop; merges | — |
| Claude Code | Orchestrates: inspects, writes `mission.md`, implements in isolation, runs checks, briefs Codex, fixes, writes `report.md`, updates `BACKLOG.md` | Acts on the real laptop, reads secrets, answers an agent's permission prompt, commits/pushes/merges without authorization |
| Codex | Independent review of the diff and the evidence against the acceptance criteria; may rerun read-only checks | Edits files other than its `review-N.md`, runs anything against the laptop, uses the network |

Claude Code does not stop for routine choices. It stops and asks only for: a
structural decision not covered by the objective, an action above its permission
level, a trust/permission/sandbox prompt, or a conflict with the user's local work.

## 2. Mission files

Kept in the repository, on the mission branch, and committed with the change when
the user authorizes a commit:

```
docs/missions/<YYYY-MM-DD>-<slug>/
├── mission.md          objective, authorizations, acceptance criteria, plan, state (resume point)
├── review-brief-1.md   what Codex must review (Claude Code)
├── review-1.md         Codex's review (Codex)
├── review-brief-2.md / review-2.md …   correction cycles
└── report.md           final report for the user (Claude Code)
```

Raw evidence (full command logs, patches, checksums) stays outside the repository
in `~/.local/share/laptop-bootstrap-agent/<mission-id>/`; mission files quote the
relevant excerpts. Nothing written to either place may contain a secret value
(gitleaks scans the mission files like any other file).

### `mission.md` skeleton

```markdown
# Mission <id> — <title>

## Objective
<user's words, verbatim>

## Authorizations
Default: repository on a mission branch/worktree + smoke VM (no smoke-down).
Extra, granted in the objective: <e.g. commit, push, open PR — or "none">.

## Scope
In: … / Out: …

## Acceptance criteria
| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | … | command or inspection | NOT_VERIFIED |
| AC-SAFE | User's local work preserved; no secret read or written; hooks not bypassed | §6 | NOT_VERIFIED |

## Plan
1. …

## State
- Phase: inspect | plan | implement | verify | review-N | fix-N | report | done | blocked
- Branch / worktree: … / …
- Base commit: …
- Evidence dir: ~/.local/share/laptop-bootstrap-agent/<id>/
- Reviewer: herdr agent <name>, pane <id> (or none)
- Review cycle: N of 3
- Next step: …

## Log
- <date> <phase>: <one line>
```

Every objective gets at least one acceptance criterion per expected outcome and
`AC-SAFE`. A criterion names how it is verified; "looks right" is not a method.

## 3. Lifecycle

1. **Inspect** — `git status`, `git branch -vv`, `git worktree list`, `git stash
   list`, the matching `BACKLOG.md` entry, related roles/docs. Record the initial
   state in `mission.md`. If the main tree has uncommitted changes, leave them
   alone and record its snapshot (below; `MAIN` = the main checkout, `E` = the
   evidence directory of §2); compare it again before the report and on resume.
   A mismatch means stop and ask.

   ```bash
   # One sha256 over HEAD, the staged patch, the unstaged patch and the content of
   # non-ignored untracked files. Prints only the hash; non-zero exit = no snapshot,
   # and a result that is not 64 hex characters is rejected as a failure.
   # Explicit && chains: `set -e` is ignored when a function is called before ||.
   snap() {  # snap <repo-dir> [path-to-exclude]
     local x=() s h
     [ -n "${2:-}" ] && x=(":!$2")
     s=$(set -o pipefail; cd "$1" && git rev-parse HEAD \
         && echo '#staged' && git diff --cached --binary -- . "${x[@]}" \
         && echo '#unstaged' && git diff --binary -- . "${x[@]}" \
         && echo '#untracked' && git ls-files -o --exclude-standard -z -- . "${x[@]}" | xargs -0r sha256sum) \
       || return 1
     h=$(set -o pipefail; printf '%s\n' "$s" | sha256sum | cut -d' ' -f1) || return 1
     [[ $h =~ ^[0-9a-f]{64}$ ]] || return 1
     printf '%s\n' "$h"
   }
   snap "$MAIN" > "$E/main-tree-snap-baseline.txt" || { echo "STOP: snapshot failed" >&2; exit 1; }
   ```

   Record the baseline file path in `mission.md`. Later comparisons:
   `now=$(snap "$MAIN") || exit 1; [ "$now" = "$(cat "$E/main-tree-snap-baseline.txt")" ] && echo unchanged`.
   The snippets in this file are written for one Claude Code Bash call each
   (a fresh shell): `exit` ends that call, and the next command never runs.
2. **Plan** — write the acceptance criteria and plan. Proceed without waiting
   unless §1 requires a decision.
3. **Implement** — on a new branch from `origin/main`. If the main tree is not
   clean or not on `main`, use a worktree:
   `git worktree add -b <type>/<slug> ../laptop-bootstrap-worktrees/<slug> origin/main`,
   then `git branch --unset-upstream` (so a later push cannot target `main`) and
   `uv sync --frozen` inside it: the pre-commit ansible-lint hook runs that
   worktree's own `.venv` (`uv run --no-sync ansible-lint`) and fails without it.
4. **Verify** — §4. Record each check with its exit status in `mission.md`.
5. **Review** — §5.
6. **Fix and re-review** — at most **2 correction cycles** after the first review
   (3 reviews in total). Each new brief answers every open finding: fixed (where)
   or rejected (why). After the third review, if findings remain open, stop and
   write a `BLOCKED` (or `PARTIAL`) report listing them. Only the user can
   authorize a further cycle; quote that authorization in `mission.md`.
7. **Report** — §7, then update `BACKLOG.md` (§8). Stop: commit/PR/merge/laptop
   follow only from the user's decision.

## 4. Verification

### 4.1 Running Ansible without the vault

`ansible.cfg` calls `pass` for the vault password. Agents never do: they point
Ansible at a dummy password file, exactly like CI. The vault then stays encrypted
(ansible-lint logs `Decryption failed` on `group_vars/all/vault/main.yml`, which
is expected and proves the vault was not opened).

```bash
D=~/.local/share/laptop-bootstrap-agent/dummy-vault-pass
mkdir -p "${D%/*}" && { [ -s "$D" ] || { printf 'agent-dummy-not-a-secret\n' > "$D" && chmod 600 "$D"; }; } \
  && [ -s "$D" ] || { echo "STOP: dummy vault file not ready" >&2; exit 1; }
export ANSIBLE_VAULT_PASSWORD_FILE="$D"
# direnv may have exported credentials into the agent's shell: drop them by name
unset ANSIBLE_VAULT_PASSWORD GITHUB_TOKEN GH_TOKEN $(compgen -e | grep '^TF_VAR_')
```

This applies to `make lint`/`pre-commit` too (the ansible-lint hook reads the vault).
Claude Code's Bash tool does not keep environment changes between calls: put
this block in the same invocation as the Ansible or pre-commit command.

### 4.2 Checks by change type

| Change | Required checks |
|---|---|
| Any | `pre-commit run --files <changed files>` (includes gitleaks on **staged** files: `git add` the mission's files first; staging is not committing) |
| Docs only | the above; check every link and command you cite exists |
| Role, vars, playbook | `.venv/bin/ansible-lint`, `.venv/bin/yamllint .`, `.venv/bin/ansible-playbook playbook.yml --syntax-check`; smoke replay of the touched tag, **twice**, second run `changed=0` |
| `cli_tools` / mise | smoke with `TAGS=mise` (not `cli-tools` unless `cleanup_legacy` is in scope); check the role never rewrites an existing `~/.config/mise/config.toml` |
| `cleanup_legacy` | smoke only; state in the report exactly what it removes |
| `vagrant` | lint only on the VM (`vagrant` tag skipped); say so in the report |
| Shell scripts | shellcheck + shfmt via pre-commit |
| `github-terraform/` | `terraform fmt -check`, `terraform validate` (`init -backend=false`); no plan/apply (needs a token) |

Smoke commands: `make smoke-status`, then `make smoke-up` if needed, then
`make smoke-replay TAGS=<tag> > "$E/smoke-<n>.log" 2>&1; echo "exit=$?"` (a pipe
into `tee` would report `tee`'s status, not the replay's).

### 4.3 Evidence and statuses

Each acceptance criterion and each check gets one status:

- `VERIFIED` — the check ran and its output confirms the criterion (quote the
  command, exit status and the relevant lines).
- `NOT_VERIFIED` — not run, failed to run, or the output does not settle it.
  Say why and what would settle it.
- `NOT_APPLICABLE` — does not apply to this change; say why.

Keep three things apart:

| Level | Proves | Does not prove |
|---|---|---|
| Lint, syntax, CI | the code parses and follows the rules | that it works anywhere |
| Smoke VM | it works on a clean Ubuntu VM, idempotently | that the laptop (with its history) behaves the same |
| Laptop run (owner) | it works on the laptop | — |

A check that was not executed is reported as not executed, never inferred from
a neighbouring one.

## 5. Codex review through Herdr

Run from Claude Code's own Herdr pane (`test "$HERDR_ENV" = 1`), with the
current directory at `$W`. `W` is the mission worktree (absolute), `M` the
mission directory relative to `$W` (`docs/missions/<id>`), `E` the evidence
directory, `D` the dummy vault password file (§4.1), `N` the review number.

### 5.1 Brief

Write `$M/review-brief-$N.md`:

- mission id, objective (verbatim), base commit, branch, file list (`git diff --stat`);
- acceptance criteria table with Claude Code's statuses and evidence;
- checks Claude Code ran (command, exit status), and checks not run (why);
- for N > 1: each previous finding and its resolution;
- what to review (§5.4), the exact output path `$M/review-$N.md` and format (§5.5).

### 5.2 Snapshot (protects the work under review)

With `snap` from §3 step 1:

```bash
snap "$W" "$M/review-$N.md" > "$E/snap-before-$N.txt" || { echo "STOP: snapshot failed" >&2; exit 1; }
```

### 5.3 Start Codex (first review; reuse the agent for later cycles)

```bash
# Gate: every step must succeed and the pane must show exactly one result line,
# `env_dirty=0`; anything else closes the pane and exits before `agent start`.
P=$(set -o pipefail; herdr pane split --current --direction right --cwd "$W" --no-focus \
      --env ANSIBLE_VAULT_PASSWORD_FILE="$D" | jq -er .result.pane.pane_id) && [ -n "$P" ] \
  || { echo "STOP: pane not created" >&2; exit 1; }
stop() { herdr pane close "$P"; echo "STOP: $1; pane $P closed" >&2; exit 1; }
herdr pane run "$P" 'unset ANSIBLE_VAULT_PASSWORD GITHUB_TOKEN GH_TOKEN $(compgen -e | grep "^TF_VAR_"); echo "env_dirty=$(compgen -e | grep -cE "^(ANSIBLE_VAULT_PASSWORD|GITHUB_TOKEN|GH_TOKEN|TF_VAR_.*)$")"' \
  || stop "env check not sent"
herdr pane wait-output "$P" --regex '(?m)^env_dirty=[0-9]+$' --source recent-unwrapped --timeout 15000 \
  || stop "env check result not seen"
# --lines counts screen rows and a narrow pane wraps the prompt: read a wide window
out=$(herdr pane read "$P" --source recent-unwrapped --lines 50) || stop "pane read failed"
[ "$(grep -xE 'env_dirty=[0-9]+' <<<"$out")" = env_dirty=0 ] || stop "environment not clean or result ambiguous"
herdr agent start lb-review --kind codex --pane "$P" -- \
  -C "$W" --sandbox workspace-write --ask-for-approval on-request \
  -c sandbox_workspace_write.network_access=false \
  -c check_for_update_on_startup=false || stop "agent start failed"
```

- On `STOP: environment not clean`, list the surviving variable names in a new
  pane or your own shell (`compgen -e | grep -E '…'`), never their values.

- `workspace-write` makes only `$W` (plus `/tmp`) writable and keeps `.git`
  read-only: Codex cannot stage or commit. Network is off for the session (the
  global config enables it).
- The worktree is not direnv-allowed, so `.envrc` does not load there; the
  `unset` + `compgen` check covers variables inherited from the Herdr server.
- Before the first prompt, read the screen
  (`herdr agent read lb-review --source visible`). Herdr 0.9.1 reports Codex's
  "Trust this folder?" dialog as `idle`, not `blocked`. Trust is saved per
  repository root; the owner trusted this repository on 2026-11-04, so its
  worktrees should not ask again. Any trust or approval request: ask the user,
  never answer it yourself.
- If a flag is rejected, drop it and report it. Never widen permissions instead.

### 5.4 Prompt

```bash
herdr agent prompt lb-review "Read AGENTS.md, then $M/review-brief-$N.md, and do the review it describes. Write your review to $M/review-$N.md and nothing else." --wait --timeout 900000
```

Codex reviews: correctness against the acceptance criteria, the hard rules in
`CLAUDE.md` (permission levels, secrets, `--diff`, mise autonomy, `mise` vs
`cli-tools`, hooks), idempotence, consistency with README/guides, proportionality
(no needless abstraction or script), and whether every `VERIFIED` is backed by
evidence.

### 5.5 Review format (`review-N.md`)

```markdown
# Review N — <mission id>
VERDICT: PASS | PASS_WITH_RESERVATIONS | CHANGES_REQUESTED | BLOCKED
## Findings
- F<N>.<k> [blocker|major|minor] <file:line> — problem — expected fix
## AC check
| ID | Reviewer status | Basis |
## Commands run
- `<command>` → exit <n>, <one-line result>
## Not checked
- … (why)
## Reservations
- …
```

### 5.6 After the review

```bash
now=$(snap "$W" "$M/review-$N.md") || { echo "STOP: snapshot failed" >&2; exit 1; }
[ "$now" = "$(cat "$E/snap-before-$N.txt")" ] && echo unchanged || echo "CHANGED: finding, restore it"
test "$M/review-$N.md" -nt "$M/review-brief-$N.md" && echo fresh
git -C "$W" status --short
```

- `idle`/`done` is not a verdict: parse `VERDICT:` from the file and cross-check
  at least one finding or AC claim against the code yourself.
- `PASS` or `PASS_WITH_RESERVATIONS` → report. `CHANGES_REQUESTED` → fix, next
  brief (§3 step 6). `BLOCKED` → resolve the cause or report `BLOCKED`.

### 5.7 Herdr states

- `working`: wait (`herdr agent wait lb-review --timeout 600000`). A timeout is not
  a failure and never a reason to resend the prompt.
- `blocked`: `herdr agent explain lb-review --format text` and
  `herdr agent read lb-review --source detection`; ask the user.
- `unknown`: send nothing; one more `agent wait --timeout 60000`, then report.
- If the review file is missing after `idle`, read the answer with
  `herdr agent read lb-review --source recent-unwrapped --lines 200` and ask Codex
  once to write the file.
- End of mission: close only the panes this mission created
  (`herdr pane close "$P"`), and record it in `mission.md`.

## 6. Protecting local work and secrets

- Never edit, stage, stash, reset or switch the main tree when it holds changes
  that are not the mission's; work in a worktree. Compare the main-tree checksum
  from §3 step 1 at the end.
- No `git checkout -- <path>`, `git reset --hard`, `git clean`, `rm -rf`
  (`trash` for deletions, with approval).
- Secrets: §4.1, the hard rules in `CLAUDE.md`. If a secret value is ever printed
  into a session or a file, stop, do not repeat it, and report the incident and
  the entry to rotate.

## 7. Final report (`report.md`)

Plain Markdown, English, evidence-based. Sections, when relevant:

- Verdict: `PASS` (all ACs `VERIFIED`, last review PASS or PASS_WITH_RESERVATIONS),
  `PARTIAL`, `BLOCKED`, or `FAIL`, with the reason for anything but PASS.
- Initial state and preserved user changes (with checksums before/after).
- Files created / modified / deleted.
- Acceptance criteria with status and evidence.
- Checks executed vs not executed; what was verified on lint, VM, laptop.
- Reviews: verdict per cycle, findings and their resolution.
- Remaining limits and risks.
- Git state: branch, worktree, commit/push/PR status (only what actually happened).
- Decisions required from the user, and the exact commands for the next step
  (commit, PR, laptop apply such as `make play TAGS=<tag>`).

Claude Code opens it for the user (`setsid -f xdg-open "$M/report.md"`) and
replies with the path, the verdict and the decisions needed.

## 8. `BACKLOG.md`

- Objective completed on the branch → remove its entry in the same branch (the
  file's rule: git history keeps the trace); it disappears from `main` at merge.
- Partially done or blocked → keep the entry, update **Status** and **Next step**.
- Follow-ups found on the way → add them to the matching section (Cleanup,
  Deferred improvements, Watch) with a source reference.
- Update `Last review:` to the mission date.

## 9. Resuming after an interruption

1. Read `docs/missions/<id>/mission.md` → **State** and **Log**.
2. Re-check what it claims: `git worktree list`, `git -C "$W" status --short`,
   main-tree checksum, `herdr agent list`.
3. Continue from **Next step**:
   - `review-N.md` exists and is newer than `review-brief-N.md` → process it (§5.6).
   - Reviewer alive and `working` → wait; do not resend.
   - Reviewer gone, no `review-N.md` → take a new snapshot, start Codex again (§5.3)
     and send the same brief.
   - State contradicts reality (unknown changes, missing worktree) → stop and ask.
4. Append a `resumed` line to the Log.

## 10. Starting the next objective

Open Claude Code in a Herdr pane at the repository root and give, for example:

```text
Objective: <what you want, e.g. the BACKLOG entry "libvirt — assert hardware KVM support">.
Follow docs/agent-workflow.md. Extra authorizations: <none | commit | commit+push+PR>.
```

The session creates `docs/missions/<date>-<slug>/`, works through §3 and ends
with `report.md`. Example mission: `docs/missions/2026-11-04-agent-workflow/`.
