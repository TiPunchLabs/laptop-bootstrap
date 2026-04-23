# fix/cli-tools-shell-hooks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fragile `lineinfile` loop that injects shell hooks into `.bashrc` with an idempotent `blockinfile`-managed block, and add a non-overlapping orphan-line scrubber to `cleanup_legacy` — so PATH-dependent tools (starship, direnv) always find mise-managed binaries and pre-mise cruft stops accumulating.

**Architecture:** Two existing roles get targeted edits. `cli_tools` swaps a `lineinfile` loop for a single `blockinfile` task anchored with `insertbefore: '^HISTCONTROL='` (first-match, Ubuntu-default anchor). `cleanup_legacy` adds a `lineinfile: state=absent` loop for orphan lines that do NOT overlap with the managed block content — so both roles are idempotent and co-exist without churn.

**Tech Stack:** Ansible 2.16+ (`ansible.builtin.blockinfile`, `ansible.builtin.lineinfile`), Vagrant + libvirt for smoke tests, pre-commit + ansible-lint for local CI.

**Spec:** `docs/superpowers/specs/2026-04-21-cli-tools-shell-hooks-design.md`

**Target branch:** `fix/cli-tools-shell-hooks` (already checked out, off `main` at `a1819a3`)

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `roles/cli_tools/vars/main.yml` | modify | Replace `cli_tools_bashrc_lines` with 3 new vars (`_block`, `_marker`, `_insert_before`). |
| `roles/cli_tools/tasks/main.yml` | modify (lines 45-53) | Replace `lineinfile` loop with single `blockinfile` task. |
| `roles/cleanup_legacy/vars/main.yml` | modify | Append `cleanup_legacy_bashrc_lines` var. |
| `roles/cleanup_legacy/tasks/main.yml` | modify | Append "Strip orphan bashrc lines" task. |
| `README.md` | modify (section at line 137) | Add "Manual `.bashrc` cleanup on migration" subsection. |
| `test/smoke/README.md` | modify | Add post-provision assertion commands. |

Six file edits across four logical changes → four commits.

---

## Task 1: Replace `lineinfile` loop with `blockinfile` in `cli_tools`

**Files:**
- Modify: `roles/cli_tools/vars/main.yml` (lines 26-30)
- Modify: `roles/cli_tools/tasks/main.yml` (lines 45-53)

- [ ] **Step 1.1: Update `cli_tools` vars**

Replace the last stanza of `roles/cli_tools/vars/main.yml` (currently lines 26-30, starting at the `# Shell hooks to append to .bashrc...` comment) with:

```yaml
# Shell hooks managed as an ordered, atomic block in ~/.bashrc. mise must come
# first so starship/direnv can resolve mise-managed binaries on PATH.
cli_tools_bashrc_block: |
  eval "$(~/.local/bin/mise activate bash)"
  eval "$(starship init bash)"
  eval "$(direnv hook bash)"

cli_tools_bashrc_marker: "# {mark} ANSIBLE MANAGED: cli_tools shell hooks"

# Anchor = the first `HISTCONTROL=` line (Ubuntu default, ~line 13, right after
# the interactive-shell guard). Using `insertbefore` gives first-match semantics
# (whereas `insertafter` would pick the LAST `esac` and land the block at the
# bottom of the file, defeating the ordering fix). If no HISTCONTROL line
# exists, blockinfile falls back to EOF — still correct in isolation.
cli_tools_bashrc_insert_before: '^HISTCONTROL='
```

- [ ] **Step 1.2: Update `cli_tools` task**

Replace lines 45-53 of `roles/cli_tools/tasks/main.yml` (the `Add mise activation + starship init to .bashrc` task) with:

```yaml
- name: Install managed shell-hooks block in .bashrc
  ansible.builtin.blockinfile:
    path: "/home/{{ bootstrap_local_user }}/.bashrc"
    marker: "{{ cli_tools_bashrc_marker }}"
    insertbefore: "{{ cli_tools_bashrc_insert_before }}"
    block: "{{ cli_tools_bashrc_block }}"
    create: true
    mode: '0644'
  become_user: "{{ bootstrap_local_user }}"
```

- [ ] **Step 1.3: Verify lint passes**

Run: `pre-commit run ansible-lint --files roles/cli_tools/tasks/main.yml roles/cli_tools/vars/main.yml`
Expected: `Passed`. If lint flags `name[template]` or similar, adjust wording but keep semantics.

- [ ] **Step 1.4: Verify syntax parses**

Run: `uv run ansible-playbook playbook.yml --syntax-check`
Expected: no errors (requires vault password; `./bin/ansible-vault-pass.sh` must work — if GPG fails, run `gpgconf --kill gpg-agent` and retry).

- [ ] **Step 1.5: Commit**

```bash
git add roles/cli_tools/vars/main.yml roles/cli_tools/tasks/main.yml
git commit -m "$(cat <<'EOF'
fix(cli_tools): manage .bashrc shell hooks via blockinfile

Replace the lineinfile loop with a single blockinfile task anchored
via insertbefore: '^HISTCONTROL=' (Ubuntu default, first-match). The
managed block (mise activate, starship init, direnv hook) now has
guaranteed ordering and can be updated/removed atomically by marker.

EOF
)"
```

---

## Task 2: Add orphan bashrc scrubber to `cleanup_legacy`

**Files:**
- Modify: `roles/cleanup_legacy/vars/main.yml` (append)
- Modify: `roles/cleanup_legacy/tasks/main.yml` (append)

- [ ] **Step 2.1: Add orphan lines var**

Append to `roles/cleanup_legacy/vars/main.yml`:

```yaml

# Orphan bashrc lines left by pre-mise installs. MUST NOT overlap with
# cli_tools_bashrc_block content (e.g., do NOT list `eval "$(starship init bash)"`
# here) — lineinfile: state=absent would then strip the block's lines every run
# and produce false "changed" events forever.
cleanup_legacy_bashrc_lines:
  - 'complete -C /usr/bin/terraform terraform'
  - 'source /usr/share/doc/fzf/examples/key-bindings.bash'
  - 'source /usr/share/doc/fzf/examples/completion.bash'
```

- [ ] **Step 2.2: Add scrub task**

Append to `roles/cleanup_legacy/tasks/main.yml` (after the existing "Remove legacy binaries and directories" task):

```yaml

- name: Strip orphan bashrc lines left by pre-mise installs
  ansible.builtin.lineinfile:
    path: "/home/{{ bootstrap_local_user }}/.bashrc"
    line: "{{ item }}"
    state: absent
  become_user: "{{ bootstrap_local_user }}"
  loop: "{{ cleanup_legacy_bashrc_lines }}"
```

- [ ] **Step 2.3: Verify lint and syntax**

Run: `pre-commit run ansible-lint --files roles/cleanup_legacy/tasks/main.yml roles/cleanup_legacy/vars/main.yml`
Expected: `Passed`.

Run: `uv run ansible-playbook playbook.yml --syntax-check`
Expected: no errors.

- [ ] **Step 2.4: Commit**

```bash
git add roles/cleanup_legacy/vars/main.yml roles/cleanup_legacy/tasks/main.yml
git commit -m "$(cat <<'EOF'
feat(cleanup_legacy): strip orphan bashrc lines from pre-mise installs

Adds a lineinfile: state=absent loop over known literal orphans
(terraform completion, fzf source lines) that are left behind by
pre-mise apt installs and never removed. Deliberately excludes
lines that overlap with cli_tools_bashrc_block to avoid
run-to-run churn.

EOF
)"
```

---

## Task 3: Document the migration-time manual cleanup

**Files:**
- Modify: `README.md` (after line 149, inside the "Migrating from a Pre-mise Laptop" section)

- [ ] **Step 3.1: Add manual cleanup subsection**

Insert the following after line 149 (the `exec bash` note blockquote) in `README.md`:

```markdown

### Manual `.bashrc` cleanup (one-time)

`cli_tools` now installs its shell hooks as a marker-bounded block. If your `.bashrc` already contains standalone copies from pre-mise installs, the role does **not** auto-remove them (doing so would corrupt the managed block on subsequent runs — see the design note in `docs/superpowers/specs/2026-04-21-cli-tools-shell-hooks-design.md`). Delete these literal lines by hand, once per laptop:

```sh
# Lines to remove from ~/.bashrc if present outside the `ANSIBLE MANAGED` block:
eval "$(starship init bash)"
eval "$(direnv hook bash)"
```

After deletion, re-run `uv run ansible-playbook playbook.yml --tags cli-tools` to regenerate a clean block.
```

- [ ] **Step 3.2: Add smoke-test post-provision assertion**

Append to `test/smoke/README.md`:

```markdown

## Post-provision assertions

After `vagrant up` completes, verify the managed shell-hooks block is in place:

```sh
vagrant ssh -c "grep -c 'ANSIBLE MANAGED: cli_tools shell hooks' ~/.bashrc"
# Expected: 2  (one BEGIN marker, one END marker)

vagrant ssh -c "sed -n '/BEGIN ANSIBLE MANAGED: cli_tools/,/END ANSIBLE MANAGED: cli_tools/p' ~/.bashrc"
# Expected: three eval lines in order — mise activate, starship init, direnv hook
```
```

- [ ] **Step 3.3: Lint check**

Run: `pre-commit run --files README.md test/smoke/README.md`
Expected: `Passed` (trailing-whitespace, end-of-file-fixer may auto-fix; if so re-stage).

- [ ] **Step 3.4: Commit**

```bash
git add README.md test/smoke/README.md
git commit -m "$(cat <<'EOF'
docs: document one-time .bashrc cleanup + smoke assertions

- README: add "Manual .bashrc cleanup" subsection to the pre-mise
  migration flow, listing the two literal lines users must delete
  by hand because cli_tools will not touch them (would create
  churn against the managed block).
- test/smoke/README.md: add post-provision grep assertions that
  verify the managed block is present and ordered correctly.

EOF
)"
```

---

## Task 4: Validate on the smoke-test VM (fresh Ubuntu 24.04)

**Files:** none modified; pure validation.

- [ ] **Step 4.1: Destroy any stale smoke VM**

Run: `cd test/smoke && vagrant destroy -f; cd -`
Expected: either "Domain is not created" or clean destruction. Stale VMs would mask role changes.

- [ ] **Step 4.2: Provision fresh VM with the patched roles**

Run: `cd test/smoke && vagrant up; cd -`
Expected: provisioning completes green (all Ansible tasks end in ok/changed, no failed). Expect `changed` on at least the new blockinfile task. Duration: ~10-15 min on libvirt.

- [ ] **Step 4.3: Assert managed block presence**

Run: `cd test/smoke && vagrant ssh -c "grep -c 'ANSIBLE MANAGED: cli_tools shell hooks' ~/.bashrc"; cd -`
Expected: `2`

- [ ] **Step 4.4: Assert block contents and order**

Run: `cd test/smoke && vagrant ssh -c "sed -n '/BEGIN ANSIBLE MANAGED: cli_tools/,/END ANSIBLE MANAGED: cli_tools/p' ~/.bashrc"; cd -`
Expected output must contain these three lines in this order:
```
eval "$(~/.local/bin/mise activate bash)"
eval "$(starship init bash)"
eval "$(direnv hook bash)"
```

- [ ] **Step 4.5: Assert block is positioned BEFORE `HISTCONTROL=`**

Run: `cd test/smoke && vagrant ssh -c "awk '/BEGIN ANSIBLE MANAGED: cli_tools/{b=NR} /^HISTCONTROL=/{h=NR} END{print \"block:\"b, \"hist:\"h, \"ok:\"(b<h)}' ~/.bashrc"; cd -`
Expected: `ok:1` (block line number less than HISTCONTROL line number).

- [ ] **Step 4.6: Assert idempotency — second run is all OK, zero CHANGED**

Run: `cd test/smoke && vagrant provision 2>&1 | tee /tmp/smoke-second-run.log; cd -`
Then: `grep -E 'PLAY RECAP|changed=' /tmp/smoke-second-run.log`
Expected: the PLAY RECAP line shows `changed=0` for the target host.

If `changed != 0`, inspect which task reported changed; most likely culprit is a var typo or an `insertbefore` anchor mismatch on the VM's `.bashrc`. Fix before proceeding.

- [ ] **Step 4.7: Assert starship/direnv actually activate in the VM's shell**

Run: `cd test/smoke && vagrant ssh -c "bash -lic 'type mise && type starship && type direnv'"; cd -`
Expected: all three resolve (either to mise shim path or to function declaration). Failure = the hooks aren't running — check shell guard interaction.

- [ ] **Step 4.8: Record outcome (no commit yet)**

If all assertions pass, smoke test is validated. If any fail, iterate on Tasks 1-3 (fix → re-provision → re-assert) before continuing.

---

## Task 5: Validate on the developer laptop (real-world migration case)

**Files:** none modified; validation on the host machine.

**Context:** Your laptop's `~/.bashrc` already has standalone lines 109 (`mise activate`), 110 (`starship init`), 139 (`direnv hook`) from the previous `lineinfile`-era role. Following the new migration doc from Task 3.

- [ ] **Step 5.1: Back up current `.bashrc`**

Run: `cp ~/.bashrc ~/.bashrc.bak.pre-blockinfile`
Expected: file created.

- [ ] **Step 5.2: Manually remove the three standalone lines**

Use your editor to delete lines matching (each exactly once):
```
eval "$(~/.local/bin/mise activate bash)"
eval "$(starship init bash)"
eval "$(direnv hook bash)"
```

Verify removal: `grep -cE '(mise activate|starship init|direnv hook)' ~/.bashrc`
Expected: `0`

- [ ] **Step 5.3: Run the playbook with --tags cli-tools,cleanup-legacy**

Run: `uv run ansible-playbook playbook.yml --tags cli-tools,cleanup-legacy --ask-become-pass`
Expected: completes green, `cleanup_legacy: Strip orphan bashrc lines` reports `ok` (no orphans to strip on this laptop), `cli_tools: Install managed shell-hooks block` reports `changed`.

- [ ] **Step 5.4: Verify block placement**

Run: `grep -n 'ANSIBLE MANAGED: cli_tools\|^HISTCONTROL=' ~/.bashrc`
Expected: two marker lines (BEGIN/END) appear BEFORE the `HISTCONTROL=` line.

- [ ] **Step 5.5: Re-run for idempotency**

Run: `uv run ansible-playbook playbook.yml --tags cli-tools,cleanup-legacy --ask-become-pass`
Expected: `changed=0` in PLAY RECAP for localhost.

- [ ] **Step 5.6: Open new shell and verify tools resolve**

Run: `bash -lic 'type mise starship direnv'`
Expected: all three resolve successfully. If any complain "not found", the hook ordering or `insertbefore` anchor misfired on your laptop — investigate before PR.

- [ ] **Step 5.7: Backup cleanup**

Only after full validation: `trash ~/.bashrc.bak.pre-blockinfile`
(Per user's safe-delete policy — never `rm -rf`, always `trash`.)

---

## Task 6: Final lint pass, push, and open PR

- [ ] **Step 6.1: Full pre-commit run on all changed files**

Run: `pre-commit run --from-ref main --to-ref HEAD`
Expected: all hooks pass.

- [ ] **Step 6.2: Review commit history**

Run: `git log --oneline main..HEAD`
Expected: four commits in order — docs(specs), fix(cli_tools), feat(cleanup_legacy), docs (README + smoke).

- [ ] **Step 6.3: Push branch**

Run: `git push -u origin fix/cli-tools-shell-hooks`
Expected: branch created on origin.

- [ ] **Step 6.4: Open PR targeting main**

Run:
```bash
gh pr create --base main --head fix/cli-tools-shell-hooks --title "fix(cli_tools): manage .bashrc shell hooks atomically via blockinfile" --body "$(cat <<'EOF'
## Summary

Backlog item #1 (fix shell hooks systemically). Replace the fragile `lineinfile` loop in `cli_tools` with a marker-bounded `blockinfile` for the mise+starship+direnv hooks. Anchor `insertbefore: '^HISTCONTROL='` gives first-match semantics and pins the block just after the Ubuntu interactive-shell guard. Add a non-overlapping orphan-line scrubber to `cleanup_legacy` (terraform completion, fzf source lines) — deliberately does NOT touch the overlap lines, documented as a one-time manual migration step.

Design doc: `docs/superpowers/specs/2026-04-21-cli-tools-shell-hooks-design.md`.

## Test plan

- [x] Smoke-test on fresh Ubuntu 24.04 Vagrant VM: block inserted correctly, idempotent on second run, hooks resolve in shell.
- [x] Developer laptop migration: manual standalone-line removal documented and followed; second run reports `changed=0`.
- [ ] CI green on GitHub Actions.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL returned.

- [ ] **Step 6.5: Await CI**

Wait for GitHub Actions. If green, ready for review. If red, inspect failing job log and fix.

---

## Self-Review (performed by plan author)

### Spec coverage

| Spec section | Task(s) |
|---|---|
| Component 1 — `cli_tools` vars | Task 1.1 |
| Component 1 — `cli_tools` tasks | Task 1.2 |
| Component 2 — `cleanup_legacy` vars | Task 2.1 |
| Component 2 — `cleanup_legacy` tasks | Task 2.2 |
| Edge case: fresh Ubuntu VM | Task 4.3-4.7 |
| Edge case: pre-existing standalone lines (laptop) | Task 5.2, 5.6 |
| Edge case: idempotency | Task 4.6, 5.5 |
| Migration doc update | Task 3.1 |
| Smoke-test assertion doc | Task 3.2 |

All spec deliverables covered.

### Placeholder / ambiguity fixes made inline

- Task 1.1 step: exact lines to replace, full new var block shown.
- Task 4.5: concrete awk one-liner instead of "verify ordering".
- Task 5.7: `trash` instead of `rm` per user rule.

### Type/name consistency

- `cli_tools_bashrc_block`, `cli_tools_bashrc_marker`, `cli_tools_bashrc_insert_before` referenced consistently in both var and task steps.
- `cleanup_legacy_bashrc_lines` same name in var and task loop.
- Marker string `"# {mark} ANSIBLE MANAGED: cli_tools shell hooks"` identical in Task 1, Task 3.2, Task 4.3, Task 4.4.
