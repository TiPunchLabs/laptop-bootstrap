# Design — fix/cli-tools-shell-hooks

> **Status**: Approved 2026-04-21
> **Target branch**: `fix/cli-tools-shell-hooks`
> **Backlog item**: #1 (Fix shell hooks systemically)

## Problem

The current `cli_tools` role injects shell hooks into `.bashrc` using a `lineinfile` loop that appends each line to end-of-file. This has two failure modes observed on the developer laptop:

1. **Order fragility.** Other tool installers (apt `direnv`, Hashicorp `terraform`, manual starship install) may append their own `eval` lines. If a tool's line lands *before* `eval "$(~/.local/bin/mise activate bash)"`, the downstream tool cannot resolve the mise-managed binary on `PATH`. Reproduced: `starship init bash` failing to find the mise-installed starship when ordered before `mise activate`.
2. **Orphan accumulation.** Legacy pre-mise installs leave behind `complete -C /usr/bin/terraform terraform`, fzf completion/key-binding sources, and duplicate standalone `starship init`/`direnv hook` lines. Nothing in the role cleans them up, so `.bashrc` drifts over time.

## Goals

- Inject mise + starship + direnv shell hooks as a single atomic, idempotent, order-stable block.
- Strip known orphan lines left by pre-mise tooling during the migration.
- Avoid churn on repeated runs (no "changed" flapping).

## Non-goals

- zsh support (no zsh config exists in the role today).
- Auto-removal of standalone `starship init` / `direnv hook` lines that *overlap* with the managed block's content — trades one-time manual cleanup for zero ongoing churn.
- Secret relocation (the separate `POWERDNS_VAULT_API_KEY` leak in `.bashrc` is tracked as its own backlog item).

## Architecture

Two existing roles get targeted edits. No new role, no new module dependency.

- **`roles/cli_tools`** owns the managed hooks block via `ansible.builtin.blockinfile`.
- **`roles/cleanup_legacy`** strips only non-overlapping orphan lines via `ansible.builtin.lineinfile: state=absent`.

Play order is already `cleanup_legacy` → `cli_tools` in `roles/bootstrap/tasks/main.yml`, so scrub runs before block insertion on every run.

## Component 1 — `roles/cli_tools`

### Vars change (`roles/cli_tools/vars/main.yml`)

Replace:

```yaml
cli_tools_bashrc_lines:
  - 'eval "$(~/.local/bin/mise activate bash)"'
  - 'eval "$(starship init bash)"'
```

With:

```yaml
# Shell hooks managed as an ordered block. mise must come first so starship/direnv
# can resolve mise-managed binaries on PATH.
cli_tools_bashrc_block: |
  eval "$(~/.local/bin/mise activate bash)"
  eval "$(starship init bash)"
  eval "$(direnv hook bash)"

cli_tools_bashrc_marker: "# {mark} ANSIBLE MANAGED: cli_tools shell hooks"

# Anchor = the first `HISTCONTROL=` line (Ubuntu default line 13, just after the
# interactive-shell guard and its closing `esac`). We use `insertbefore` because
# blockinfile's `insertbefore` picks the FIRST regex match (whereas `insertafter`
# picks the LAST — which would land our block after user/tool function-local
# `esac` lines later in the file). If no HISTCONTROL line exists, blockinfile
# falls back to EOF, which is still correct in isolation.
cli_tools_bashrc_insert_before: '^HISTCONTROL='
```

### Task change (`roles/cli_tools/tasks/main.yml`)

Replace the final `lineinfile` loop task with:

```yaml
- name: Install managed shell-hooks block after interactive guard
  ansible.builtin.blockinfile:
    path: "/home/{{ bootstrap_local_user }}/.bashrc"
    marker: "{{ cli_tools_bashrc_marker }}"
    insertbefore: "{{ cli_tools_bashrc_insert_before }}"
    block: "{{ cli_tools_bashrc_block }}"
    create: true
    mode: '0644'
  become_user: "{{ bootstrap_local_user }}"
```

Idempotency: `blockinfile` computes a checksum of the managed content between its markers; identical content → no change. No handler needed (shell hooks take effect in next shell; no service to reload).

## Component 2 — `roles/cleanup_legacy`

### Vars addition (`roles/cleanup_legacy/vars/main.yml`)

```yaml
# Orphan bashrc lines from pre-mise tooling. MUST NOT overlap with the cli_tools
# managed block (otherwise lineinfile: state=absent would strip the block's lines
# every run and create churn).
cleanup_legacy_bashrc_lines:
  - 'complete -C /usr/bin/terraform terraform'
  - 'source /usr/share/doc/fzf/examples/key-bindings.bash'
  - 'source /usr/share/doc/fzf/examples/completion.bash'
```

### Task addition (`roles/cleanup_legacy/tasks/main.yml`)

Append (after the existing "Remove legacy binaries and directories" task):

```yaml
- name: Strip orphan bashrc lines left by pre-mise installs
  ansible.builtin.lineinfile:
    path: "/home/{{ bootstrap_local_user }}/.bashrc"
    line: "{{ item }}"
    state: absent
  become_user: "{{ bootstrap_local_user }}"
  loop: "{{ cleanup_legacy_bashrc_lines }}"
```

## Data flow / ordering guarantees

```
ansible-playbook bootstrap.yml
  └─ role: cleanup_legacy
       ├─ apt purge (existing)
       ├─ remove apt sources/keyrings (existing)
       ├─ remove legacy binaries (existing)
       └─ strip orphan bashrc lines (NEW)              ← runs first
  └─ role: cli_tools
       ├─ install mise, render config, install tools (existing)
       └─ install managed hooks block (REPLACED)        ← runs after scrub
```

On repeat runs: scrub is a no-op (orphans already gone); blockinfile is a no-op (content matches markers). Zero changed tasks.

## Edge cases

| Case | Behavior |
|---|---|
| Fresh Ubuntu 24.04 (smoke VM) | Block inserted before `HISTCONTROL=` at ~line 13 (just after the interactive-shell guard). Scrub is no-op. |
| Custom `.bashrc` with no `HISTCONTROL=` line | `insertbefore` regex misses → blockinfile falls back to EOF. Block still correct in isolation; loses the "before other hooks" property. Acceptable degraded behavior. |
| Bashrc with later function-local `esac` lines (developer laptop has 4) | Not relevant — anchor is `HISTCONTROL=`, not `esac`. First-match semantics of `insertbefore` pin the block to line 13. |
| Pre-existing standalone `starship init` / `direnv hook` lines (developer laptop, line 110 and 139) | Not auto-removed. Documented one-time manual step in `docs/guide-pre-mise-migration.md`. |
| Managed block already present, content drifted | Checksum mismatch → block regenerated with correct content. One "changed" event, then converges. |
| `.bashrc` missing entirely | `create: true` + `mode: '0644'` creates a fresh file containing only the managed block. |

## Rollback

Changing `state: absent` on the `blockinfile` task removes the managed block cleanly via its markers. The scrubbed orphan lines are not restored (acceptable — they were dead code).

## Testing

### Smoke test (Vagrant on libvirt)

The existing `test/smoke/Vagrantfile` provisions a clean Ubuntu 24.04 VM and runs the full playbook. Fresh VM has no orphans, so this validates the install path.

Add a post-provision assertion to `test/smoke/README.md` (manual step):

```bash
vagrant ssh -c "grep -c 'ANSIBLE MANAGED: cli_tools shell hooks' ~/.bashrc"
# expected: 2 (BEGIN + END markers)

vagrant ssh -c "grep -A3 'BEGIN ANSIBLE MANAGED: cli_tools' ~/.bashrc"
# expected: mise activate, then starship init, then direnv hook, in that order
```

### Migration test (developer laptop, existing state)

1. Manually remove standalone `eval "$(direnv hook bash)"` at line 139 (one-time).
2. Run `ansible-playbook bootstrap.yml --tags cli_tools,cleanup_legacy --ask-vault-pass`.
3. Verify:
   - Managed block appears just before `HISTCONTROL=` (around line 10, above the first HIST setting).
   - Lines 109–110 (pre-existing `mise activate` / `starship init`) still there — duplicates with the block. Expected; user removes manually per migration doc.
   - No `complete -C /usr/bin/terraform terraform` (confirmed absent already).
   - `mise doctor` reports no PATH issues.
4. Re-run the playbook. Expected: 0 changed tasks.

## Follow-up / migration doc update

Extend the existing **Migrating from a Pre-mise Laptop** section in `README.md` (line 137) with a "Manual `.bashrc` cleanup" subsection listing the exact literal strings that the role does *not* auto-remove on migration:

```
eval "$(starship init bash)"     # remove the standalone copy; block owns it now
eval "$(direnv hook bash)"       # same
```

## Deliverables checklist

- [ ] `roles/cli_tools/vars/main.yml` — swap `cli_tools_bashrc_lines` for the 3 new vars.
- [ ] `roles/cli_tools/tasks/main.yml` — replace the `lineinfile` loop task with `blockinfile`.
- [ ] `roles/cleanup_legacy/vars/main.yml` — add `cleanup_legacy_bashrc_lines`.
- [ ] `roles/cleanup_legacy/tasks/main.yml` — append "Strip orphan bashrc lines" task.
- [ ] `README.md` — extend "Migrating from a Pre-mise Laptop" section with manual-cleanup subsection.
- [ ] Smoke-test run green on Vagrant.
- [ ] Second playbook run on laptop reports 0 changed tasks.
