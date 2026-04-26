# Design — feat/libvirt-role

> **Status**: Approved 2026-04-26
> **Target branch**: `feat/libvirt-role`

## Problem

KVM/libvirt is currently installed only as a side-effect of the `vagrant` role. Users who want to run VMs with `virt-manager` / `virt-install` without installing Vagrant have no first-class path: the packages are bundled into `vagrant_libvirt_dependencies`, the `libvirtd` service start lives in the vagrant tasks, and the `libvirt` group membership is added there too.

Two packages from a standard libvirt stack are also missing: `virtinst` (the `virt-install` CLI) and `ovmf` (UEFI firmware for guests).

## Goals

- Provide a standalone `libvirt` role that installs the full KVM/libvirt user stack and is invoked by default during bootstrap.
- Add the local user to both `libvirt` and `kvm` groups (today only `libvirt` is added).
- Enable + start `libvirtd` from the new role.
- Have `vagrant` consume the new role as a dependency so vagrant-libvirt continues to work end-to-end without duplication.

## Non-goals

- Hardware capability check (`/dev/kvm`, `vmx`/`svm` CPU flag detection) — out of scope for "install the packages".
- Triggering `newgrp libvirt` automatically — group membership takes effect on the next login session; documented but not forced.
- ADR — change is small and follows existing role-per-concern patterns; no architectural decision worth recording.
- zsh / fish shell integration — none exists in the project today.

## Architecture

One new role + one dependency edit + one cleanup. No new module, no new external system.

- **`roles/libvirt`** (new) owns the package install, the user → groups membership, and the `libvirtd` service.
- **`roles/vagrant/meta/main.yml`** declares `libvirt` as a dependency.
- **`roles/vagrant`** drops the now-duplicated package list entries and the redundant group/service tasks.
- **`roles/bootstrap/tasks/main.yml`** invokes `libvirt` by default (always-on, like `docker`/`git`/`devtools`), placed **before** the vagrant block so the dependency is satisfied even when running with `--tags vagrant`.

Run order in `bootstrap/tasks/main.yml`: `… → libvirt → vagrant → git → docker → devtools → cleanup_legacy → cli_tools`.

## Component 1 — `roles/libvirt`

### Layout

```
roles/libvirt/
├── README.md
├── meta/main.yml
├── tasks/main.yml
└── vars/main.yml
```

No `handlers/`, no `templates/`, no `files/` — the role has no config to render and no daemon-reload triggers.

### Vars (`roles/libvirt/vars/main.yml`)

```yaml
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

### Tasks (`roles/libvirt/tasks/main.yml`)

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

### Meta (`roles/libvirt/meta/main.yml`)

Standard `galaxy_info` stub aligned with the other roles in the project (no `dependencies:` — `libvirt` is a leaf).

### Implicit dependency on `bootstrap`

`bootstrap_local_user` is set as a fact by `roles/bootstrap/tasks/main.yml` (the `whoami` + `set_fact` pair). The new `libvirt` role uses that fact and is invoked from `bootstrap/tasks/main.yml`, so the fact is always available by the time the user task runs. No defensive default — fail loudly if the contract is broken.

## Component 2 — `roles/vagrant` cleanup

### Vars (`roles/vagrant/vars/main.yml`)

`vagrant_libvirt_dependencies` becomes:

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

Removed (now owned by `libvirt`): `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `bridge-utils`, `virt-manager`.

### Tasks (`roles/vagrant/tasks/main.yml`)

Remove these two tasks (duplicates of what `libvirt` now does):

- `Ensure the current user is in the libvirt group`
- `Enable and start the libvirtd service`

### Meta (`roles/vagrant/meta/main.yml`)

Add:

```yaml
dependencies:
  - role: libvirt
```

This guarantees `libvirt` is applied before `vagrant` even when someone runs `ansible-playbook playbook.yml --tags vagrant` (the default tag-resolution does include role dependencies).

## Component 3 — `roles/bootstrap` wiring

`roles/bootstrap/tasks/main.yml` gets a new `include_role` block, mirroring the pattern of the other roles, placed **before** the vagrant block:

```yaml
- name: Install libvirt / KVM stack
  ansible.builtin.include_role:
    name: libvirt
    apply:
      tags:
        - libvirt
  tags:
    - libvirt
```

## Documentation

- `README.md` — add `libvirt/` entry under the `roles/` list with a one-line description (`KVM + libvirt user stack (qemu-kvm, virt-manager, virtinst, ovmf, …)`); update the ASCII tree.
- `roles/libvirt/README.md` — short role README following the format of `roles/bootstrap/README.md`. Document the post-install caveat: group membership requires re-login (or `newgrp libvirt && newgrp kvm`) for the running shell to pick it up.

## Testing

- `pre-commit` (`ansible-lint`, `yamllint`) on the touched files.
- Smoke test via the existing `test/smoke/` Vagrant harness — replays the full playbook on a clean VM. Validates that:
  - `libvirt` role runs cleanly idempotent (a second run reports zero changes).
  - `vagrant` role still installs cleanly with its trimmed dep list and the `libvirt` meta-dependency.
  - `vagrant up` from inside the smoke VM still succeeds end-to-end (existing behavior preserved).

No new unit tests are added — the existing smoke harness already exercises the full role chain.

## Migration notes

- Existing laptops already have the libvirt packages installed via the vagrant role. Re-running the playbook is a no-op for them on packages, but **will** add the user to the `kvm` group (new) and is otherwise idempotent.
- The two removed vagrant tasks become no-ops (the new role does the same thing earlier in the run), so playbook output cleanly shifts ownership without changing observable system state.

## Out of scope / future work

- Hardware KVM capability assertion (could later be added as a `pre_tasks` check in the libvirt role).
- Default libvirt network tuning (`virsh net-autostart default`, custom bridges) — keep the role minimal until a real need shows up.
