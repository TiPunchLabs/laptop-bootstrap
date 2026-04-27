# libvirt role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone `roles/libvirt` Ansible role that installs the KVM/libvirt user stack (`qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `bridge-utils`, `virtinst`, `virt-manager`, `ovmf`), adds the local user to `libvirt`+`kvm` groups, and starts `libvirtd`. The `vagrant` role consumes it via `meta/main.yml` so vagrant-libvirt still works without duplicating packages or service handling.

**Architecture:** New leaf role under `roles/libvirt/` with the standard project layout (`meta/`, `tasks/`, `vars/`, `README.md`). It's invoked by default from `roles/bootstrap/tasks/main.yml` (always-on, like `docker`/`git`/`devtools`) and pulled in transitively by `roles/vagrant` through `meta/main.yml: dependencies`. The `vagrant` role's `vars/main.yml` and `tasks/main.yml` are trimmed of the now-duplicated package/group/service handling.

**Tech Stack:** Ansible (collections: `ansible.builtin`), apt, systemd. Lint via `ansible-lint` + `yamllint` (already wired in `pre-commit`). Smoke test via the existing `test/smoke/` Vagrant harness.

**Spec:** [`docs/superpowers/specs/2026-04-26-libvirt-role-design.md`](../specs/2026-04-26-libvirt-role-design.md)

**Branch:** `feat/libvirt-role` (already created, spec already committed)

---

## File Structure

**Created:**
- `roles/libvirt/meta/main.yml` — galaxy_info stub, no deps
- `roles/libvirt/vars/main.yml` — `libvirt_packages`, `libvirt_user_groups`
- `roles/libvirt/tasks/main.yml` — apt install, user groups, libvirtd service
- `roles/libvirt/README.md` — role overview + post-install caveat

**Modified:**
- `roles/bootstrap/tasks/main.yml` — add `include_role: libvirt` block before the vagrant block
- `roles/vagrant/meta/main.yml` — declare `libvirt` as a dependency
- `roles/vagrant/vars/main.yml` — drop libvirt-stack packages from `vagrant_libvirt_dependencies`
- `roles/vagrant/tasks/main.yml` — drop the user-group and libvirtd-service tasks
- `README.md` — add `libvirt/` to the role list and the ASCII tree

---

## Task 1: Create the `libvirt` role skeleton

**Files:**
- Create: `roles/libvirt/meta/main.yml`
- Create: `roles/libvirt/vars/main.yml`
- Create: `roles/libvirt/tasks/main.yml`
- Create: `roles/libvirt/README.md`

- [ ] **Step 1: Create `roles/libvirt/meta/main.yml`**

```yaml
---
galaxy_info:
  author: xgueret
  description: Install the KVM/libvirt user stack (qemu-kvm, virt-manager, virtinst, ovmf) and configure libvirtd
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Ubuntu
      versions:
        - jammy
        - noble
    - name: Debian
      versions:
        - bookworm
        - trixie

dependencies: []
```

- [ ] **Step 2: Create `roles/libvirt/vars/main.yml`**

```yaml
---
libvirt_packages:
  - qemu-kvm
  - libvirt-daemon-system
  - libvirt-clients
  - bridge-utils
  - virtinst
  - virt-manager
  - ovmf

libvirt_user_groups:
  - libvirt
  - kvm
```

- [ ] **Step 3: Create `roles/libvirt/tasks/main.yml`**

```yaml
---
- name: Install KVM/libvirt packages
  ansible.builtin.apt:
    name: "{{ libvirt_packages }}"
    state: present

- name: Add local user to libvirt and kvm groups
  ansible.builtin.user:
    name: "{{ bootstrap_local_user }}"
    groups: "{{ libvirt_user_groups }}"
    append: true

- name: Enable and start libvirtd
  ansible.builtin.service:
    name: libvirtd
    enabled: true
    state: started
```

- [ ] **Step 4: Create `roles/libvirt/README.md`**

```markdown
# libvirt

Install the KVM/libvirt user stack and configure `libvirtd`:

- Packages: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `bridge-utils`, `virtinst`, `virt-manager`, `ovmf`
- Adds the bootstrapping user (`bootstrap_local_user`) to the `libvirt` and `kvm` groups
- Enables and starts the `libvirtd` service

## Requirements

- Debian 12+ / Ubuntu 22.04+
- The variable `bootstrap_local_user` must be defined (set by the `bootstrap` role)

## Dependencies

None. Consumed transitively by `roles/vagrant` via `meta/main.yml`.

## Post-install

Group membership only takes effect for **new** sessions. To pick it up in
the current shell:

```bash
newgrp libvirt
newgrp kvm
```

…or simply log out and back in.

## Example

```yaml
- hosts: localhost
  become: true
  roles:
    - role: libvirt
```
```

- [ ] **Step 5: Verify the role layout**

Run:
```bash
find roles/libvirt -type f | sort
```

Expected output (exactly these four files):
```
roles/libvirt/README.md
roles/libvirt/meta/main.yml
roles/libvirt/tasks/main.yml
roles/libvirt/vars/main.yml
```

- [ ] **Step 6: Lint the new role in isolation**

Run:
```bash
gpgconf --kill gpg-agent  # avoid the known OOM during vault decrypt
ansible-lint roles/libvirt
```

Expected: `Passed: 0 failure(s), 0 warning(s)` (or no output / exit 0).

- [ ] **Step 7: Commit**

```bash
git add roles/libvirt
git commit -m "feat(libvirt): add standalone libvirt/KVM role"
```

---

## Task 2: Wire the `libvirt` role into `bootstrap`

**Files:**
- Modify: `roles/bootstrap/tasks/main.yml` (insert one block before the existing `Install vagrant + libvirt` block)

- [ ] **Step 1: Open `roles/bootstrap/tasks/main.yml`**

Locate the existing block (around the middle of the file):

```yaml
- name: Install vagrant + libvirt
  ansible.builtin.include_role:
    name: vagrant
    apply:
      tags:
        - vagrant
  tags:
    - vagrant
```

- [ ] **Step 2: Insert the `libvirt` include_role block immediately before it**

The new block:

```yaml
- name: Install libvirt / KVM stack
  ansible.builtin.include_role:
    name: libvirt
    apply:
      tags:
        - libvirt
  tags:
    - libvirt

- name: Install vagrant + libvirt
  ansible.builtin.include_role:
    name: vagrant
    apply:
      tags:
        - vagrant
  tags:
    - vagrant
```

(The `vagrant` block already exists — only the `libvirt` block is added above it.)

- [ ] **Step 3: Lint**

```bash
ansible-lint roles/bootstrap playbook.yml
```

Expected: `Passed`.

- [ ] **Step 4: Commit**

```bash
git add roles/bootstrap/tasks/main.yml
git commit -m "feat(bootstrap): include libvirt role before vagrant"
```

---

## Task 3: Make `vagrant` depend on `libvirt`

**Files:**
- Modify: `roles/vagrant/meta/main.yml`

- [ ] **Step 1: Edit `roles/vagrant/meta/main.yml`**

Change:

```yaml
dependencies: []
```

to:

```yaml
dependencies:
  - role: libvirt
```

The full file becomes:

```yaml
---
galaxy_info:
  author: xgueret
  description: Install Vagrant with libvirt provider and vagrant-libvirt plugin
  license: MIT
  min_ansible_version: "2.14"
  platforms:
    - name: Ubuntu
      versions:
        - jammy
        - noble
    - name: Debian
      versions:
        - bookworm
        - trixie

dependencies:
  - role: libvirt
```

- [ ] **Step 2: Lint**

```bash
ansible-lint roles/vagrant
```

Expected: `Passed`.

- [ ] **Step 3: Commit**

```bash
git add roles/vagrant/meta/main.yml
git commit -m "feat(vagrant): depend on libvirt role"
```

---

## Task 4: Trim duplicates from the `vagrant` role

**Files:**
- Modify: `roles/vagrant/vars/main.yml`
- Modify: `roles/vagrant/tasks/main.yml`

- [ ] **Step 1: Trim `roles/vagrant/vars/main.yml`**

Replace the existing `vagrant_libvirt_dependencies` list with the slimmed-down version (libvirt-stack packages move to `roles/libvirt`):

```yaml
vagrant_libvirt_dependencies:
  - libvirt-dev          # vagrant-libvirt plugin compilation
  - nfs-common           # vagrant synced folders over NFS
  - nfs-kernel-server
  - build-essential      # native gem builds
  - zlib1g-dev
  - ruby-dev
  - libxml2-dev
  - libxslt-dev
  - libguestfs-tools     # qcow2 / vagrant box manipulation
```

Removed (now in `roles/libvirt`): `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `bridge-utils`, `virt-manager`. Leave `vagrant_hashicorp_gpg`, `vagrant_hashicorp_deb822`, and `vagrant_packages` untouched.

- [ ] **Step 2: Trim `roles/vagrant/tasks/main.yml`**

Delete these two tasks (they are now handled by `roles/libvirt`):

```yaml
- name: Ensure the current user is in the libvirt group
  ansible.builtin.user:
    name: "{{ bootstrap_local_user }}"
    groups: libvirt
    append: true

- name: Enable and start the libvirtd service
  ansible.builtin.service:
    name: libvirtd
    enabled: true
    state: started
```

After deletion the file ends on the `Install the vagrant-libvirt plugin` task (preceded by `Check if vagrant-libvirt plugin is installed`).

- [ ] **Step 3: Verify nothing else in the file references the removed packages or tasks**

Run:
```bash
grep -nE "libvirt-daemon-system|libvirt-clients|bridge-utils|virt-manager|qemu-kvm|libvirtd|name: libvirt$" roles/vagrant/tasks/main.yml roles/vagrant/vars/main.yml
```

Expected output: empty (no matches). If there are any matches, re-check that the removals in steps 1–2 were applied cleanly.

- [ ] **Step 4: Lint**

```bash
ansible-lint roles/vagrant
```

Expected: `Passed`.

- [ ] **Step 5: Commit**

```bash
git add roles/vagrant/vars/main.yml roles/vagrant/tasks/main.yml
git commit -m "refactor(vagrant): drop libvirt-stack packages and tasks now owned by libvirt role"
```

---

## Task 5: Update top-level `README.md`

**Files:**
- Modify: `README.md` (two places: the role bullet list, and the ASCII tree)

- [ ] **Step 1: Update the bullet list under "Project Structure"**

Locate the `- \`roles/\`: Contains the Ansible roles` block. Insert this bullet immediately after the `git/` line and before the `vagrant/` line:

```markdown
  - `libvirt/`: KVM + libvirt user stack (qemu-kvm, virt-manager, virtinst, ovmf, ...) — also consumed by `vagrant/` as a meta-dependency
```

The relevant excerpt becomes:

```markdown
  - `git/`: Git configuration
  - `libvirt/`: KVM + libvirt user stack (qemu-kvm, virt-manager, virtinst, ovmf, ...) — also consumed by `vagrant/` as a meta-dependency
  - `vagrant/`: Vagrant + libvirt + vagrant-libvirt plugin (system-managed per ADR-0001)
```

- [ ] **Step 2: Update the ASCII tree**

In the same `README.md`, find the ASCII tree line:

```
│   ├── devtools/  ·  docker/  ·  git/  ·  vagrant/
```

Replace it with:

```
│   ├── devtools/  ·  docker/  ·  git/  ·  libvirt/  ·  vagrant/
```

- [ ] **Step 3: Verify the diff is exactly two lines added/changed**

Run:
```bash
git diff README.md
```

Expected: one new bullet line, one tree line modified. Nothing else.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): document the new libvirt role"
```

---

## Task 6: Whole-tree lint + idempotency check on the local machine

**Files:** none — verification only.

- [ ] **Step 1: Run all pre-commit hooks on the whole tree**

```bash
gpgconf --kill gpg-agent  # avoid GPG OOM during vault decrypt
make lint
```

Expected: every hook either `Passed` or `Skipped`. No `Failed`. If `Ansible-lint` fails with `Cannot allocate memory`, re-run `gpgconf --kill gpg-agent` and retry.

- [ ] **Step 2: First playbook run (apply)**

Run on the local laptop (this machine):

```bash
make play TAGS=libvirt
```

Expected: tasks for `libvirt` execute. The user-group task may report `changed` (because `kvm` is newly added), or `ok` (if both groups are already present from prior vagrant runs). The package and service tasks should be `ok` since the laptop already has them from past vagrant role runs.

- [ ] **Step 3: Second playbook run (idempotency)**

Run again, immediately:

```bash
make play TAGS=libvirt
```

Expected in the recap: `changed=0`. Any non-zero `changed` count is a bug — investigate the offending task.

- [ ] **Step 4: Verify no commit needed for this task**

Run:
```bash
git status
```

Expected: `nothing to commit, working tree clean`. (This task only validates; no files change.)

---

## Task 7: Optional — full smoke test on a clean VM

**Files:** none — verification only. Skip if the smoke harness is unavailable or too costly for this change; Task 6 already covers idempotency on the laptop.

- [ ] **Step 1: Boot the smoke VM**

```bash
make smoke-up
```

Expected: Vagrant brings up the VM (5–10 min cold).

- [ ] **Step 2: Replay the playbook**

```bash
make smoke-replay
```

Expected: full playbook applies cleanly. The `libvirt` role reports `changed` on first apply (packages installed, user added to groups, service started). The `vagrant` role still completes, including the vagrant-libvirt plugin install.

- [ ] **Step 3: Replay again for idempotency**

```bash
make smoke-replay
```

Expected: `changed=0` for the `libvirt` role tasks.

- [ ] **Step 4: Tear down**

```bash
make smoke-down
```

Expected: VM destroyed.

---

## Task 8: Push branch and open PR

**Files:** none — git/GitHub only.

- [ ] **Step 1: Verify the branch state**

Run:
```bash
git log --oneline origin/main..HEAD
```

Expected: a chain of commits matching the tasks above, in order:
```
docs(readme): document the new libvirt role
refactor(vagrant): drop libvirt-stack packages and tasks now owned by libvirt role
feat(vagrant): depend on libvirt role
feat(bootstrap): include libvirt role before vagrant
feat(libvirt): add standalone libvirt/KVM role
docs(specs): add libvirt role design
```

- [ ] **Step 2: Push the branch**

```bash
git push -u origin feat/libvirt-role
```

- [ ] **Step 3: Open a PR**

```bash
gh pr create --title "feat(libvirt): standalone KVM/libvirt role" --body "$(cat <<'EOF'
## Summary
- New `roles/libvirt` role installing the KVM/libvirt user stack (`qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `bridge-utils`, `virtinst`, `virt-manager`, `ovmf`), adding the local user to `libvirt` + `kvm` groups, and starting `libvirtd`.
- `roles/vagrant` now consumes it via `meta/main.yml: dependencies`, with the duplicated packages and tasks removed.
- Invoked by default from `roles/bootstrap/tasks/main.yml` so KVM is available without installing Vagrant.

Spec: `docs/superpowers/specs/2026-04-26-libvirt-role-design.md`

## Test plan
- [x] `make lint` passes
- [x] `make play TAGS=libvirt` is idempotent on the developer laptop (`changed=0` on the second run)
- [ ] (optional) `make smoke-up && make smoke-replay` runs cleanly on the smoke VM

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Confirm PR URL**

`gh pr create` prints the URL. Capture it for the user.

---

## Self-Review Notes

- **Spec coverage:** every component in the spec maps to a task — Component 1 (`roles/libvirt`) → Task 1; Component 2 (`vagrant` cleanup) → Tasks 3+4; Component 3 (`bootstrap` wiring) → Task 2; Documentation → Tasks 1 (role README) + 5 (top-level README); Testing → Tasks 6+7; Migration notes → covered by the idempotency check in Task 6.
- **No placeholders:** every step shows the exact code/command. The role README in Task 1.4 reuses the post-install caveat from the spec verbatim.
- **Type / name consistency:** `bootstrap_local_user` is referenced consistently across the new role's tasks and the existing bootstrap role. `libvirt_packages` and `libvirt_user_groups` names match between vars and tasks. The package list matches the spec exactly (7 items).
- **Commit style:** Conventional Commits (`feat(libvirt): …`, `refactor(vagrant): …`, `docs(readme): …`) — consistent with the repo's git log.
- **Branch hygiene:** all changes go on `feat/libvirt-role` (already created), spec already committed, never on `main`.
