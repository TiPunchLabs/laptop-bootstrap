# 🧪 Smoke-Testing the Bootstrap with Vagrant + libvirt

> **Objective**: Validate that `playbook.yml` runs end-to-end on a *clean* Debian/Ubuntu VM without touching your real laptop.
> **Prerequisites**: `vagrant`, `vagrant-libvirt` plugin, `libvirtd` running, KVM enabled, ~8 GB free disk, ~5 GB RAM available.
> **Estimated duration**: 10–15 min for the first `vagrant up` (box download), 3–5 min for subsequent replays.

## Table of Contents

1. [📖 Introduction](#-introduction)
2. [🏗️ Architecture](#️-architecture)
3. [🛠️ Prerequisites check](#️-prerequisites-check)
4. [📝 Running the smoke test](#-running-the-smoke-test)
5. [🎯 Scoping runs with tags](#-scoping-runs-with-tags)
6. [🔐 Handling ansible-vault](#-handling-ansible-vault)
7. [🔧 Troubleshooting](#-troubleshooting)
8. [✅ Best practices](#-best-practices)
9. [🎓 Conclusion](#-conclusion)
10. [📚 Resources](#-resources)

------

## 📖 Introduction

Why spend an extra 5 minutes on a smoke test when the playbook already ran successfully on your laptop?

Because "it worked on my laptop" hides two classes of bugs:

- **Dormant environment assumptions**: a tool that happens to be pre-installed, a PATH entry you forgot about, a vault password already in `pass`. The playbook silently uses these without declaring them.
- **Non-idempotence masked by prior state**: a task that only converges because a previous run already did half the work. Re-running on a clean system exposes it immediately.

The smoke test is a **fresh Ubuntu VM** where the playbook has to stand on its own. If `vagrant up` succeeds, you've proven the playbook is self-contained.

> **Analogy**: It's the difference between cooking in your own kitchen (you know where the salt is) and cooking in a rental apartment (you find out what your recipe *actually* depends on).

------

## 🏗️ Architecture

### Mental Model

```
 ┌──────────────────────────── HOST (your laptop) ────────────────────────────┐
 │                                                                            │
 │   vagrant up                                                               │
 │      │                                                                     │
 │      ├── libvirt-daemon ──────► QEMU/KVM ──► ┌──── Ubuntu VM ───────────┐ │
 │      │                                       │                          │ │
 │      │   rsync /vagrant ────────────────────►│  /vagrant/               │ │
 │      │   (repo snapshot)                     │  ├── playbook.yml        │ │
 │      │                                       │  ├── roles/              │ │
 │      │                                       │  └── test/smoke/         │ │
 │      │                                       │                          │ │
 │      │   SSH (vagrant user, pubkey)          │  shell provisioner       │ │
 │      │                                       │   └─► apt install ansible│ │
 │      │                                       │                          │ │
 │      │   ansible_local provisioner ─────────►│  ansible-playbook        │ │
 │      │                                       │   playbook.yml (local)   │ │
 │      │                                       │                          │ │
 │      │                                       └──────────────────────────┘ │
 │                                                                            │
 └────────────────────────────────────────────────────────────────────────────┘
```

### Three moving parts

| Component          | Role                                                              |
| ------------------ | ----------------------------------------------------------------- |
| **libvirt + KVM**  | Hypervisor. Creates the actual VM disk, network, CPU allocation.  |
| **vagrant**        | Workflow layer. `up`/`destroy`/`rsync`/`provision` as a habit.    |
| **ansible_local**  | Vagrant provisioner that installs ansible *inside* the VM, then runs the playbook with `hosts: local` and `ansible_connection: local`. Matches exactly how the playbook runs on your laptop. |

### Why `ansible_local` and not the host `ansible` provisioner?

The playbook targets `hosts: local` with `ansible_connection: local`. Running it from the host via SSH would mean rewriting the inventory to target the VM over SSH — and now we're testing a *different* code path than the real bootstrap uses.

`ansible_local` runs ansible *inside* the VM, so the playbook executes in the exact same mode as on a real laptop: local connection, root via become, python interpreter at `/usr/bin/python3`.

------

## 🛠️ Prerequisites check

Run each of these on your host and confirm success:

```sh
# KVM module loaded + CPU virtualization flag present
lsmod | grep -E '^kvm'
grep -Eoc '(vmx|svm)' /proc/cpuinfo   # > 0

# libvirt up
systemctl is-active libvirtd          # active

# vagrant + libvirt plugin
vagrant --version                     # 2.4.x or later
vagrant plugin list | grep libvirt    # vagrant-libvirt present

# You are in the libvirt group (otherwise: sudo usermod -aG libvirt "$USER" && newgrp libvirt)
groups | tr ' ' '\n' | grep -q '^libvirt$' && echo "OK" || echo "MISSING"
```

If any of those fail, run the main bootstrap with `--tags vagrant` first — that's exactly the role that installs and configures this stack.

> ⚠️ **Warning**: If you just added yourself to the `libvirt` group, open a new shell (or `exec bash`) — the group membership isn't picked up by the current session.

------

## 📝 Running the smoke test

### First run

```sh
cd test/smoke
vagrant up
```

What happens, step by step:

1. Vagrant downloads the `bento/ubuntu-24.04` box (~500 MB, cached under `~/.vagrant.d/boxes/` after the first run).
2. libvirt creates a QCOW2 disk, a default NAT network, and boots the VM with 4 GB RAM / 2 vCPU.
3. `rsync` pushes the repo (minus `.git/`, `.venv/`) into `/vagrant/`.
4. The `shell` provisioner runs `apt install ansible-core`.
5. The `ansible_local` provisioner runs `ansible-playbook /vagrant/playbook.yml --limit local --skip-tags vagrant` using a smoke-test-specific `ansible.cfg`.
6. The playbook converges — or fails loudly, which is the whole point.

### Subsequent runs (fast loop)

```sh
# After editing roles on the host:
vagrant rsync       # push the changes
vagrant provision   # re-run ansible without rebooting the VM
```

### Tear down

```sh
vagrant destroy -f  # removes the VM and its disk image
```

> 💡 **Tip**: Keep the VM alive (`vagrant halt` instead of `destroy`) while iterating — the box download and apt install are the slow parts, and `vagrant up` on a halted VM skips them.

------

## 🎯 Scoping runs with tags

The `Vagrantfile` reads three env vars for tag control:

| Variable                    | Effect                                                   |
| --------------------------- | -------------------------------------------------------- |
| `LAPTOP_BOOTSTRAP_TAGS`     | Comma-separated list passed to `--tags`. Default: all.   |
| `LAPTOP_BOOTSTRAP_SKIP_TAGS`| Comma-separated list passed to `--skip-tags`. Default: `vagrant`. |
| `LAPTOP_BOOTSTRAP_VERBOSE`  | Set to `true` to pass `-v` to ansible.                   |

### Example: test only the mise migration path

```sh
LAPTOP_BOOTSTRAP_TAGS=cleanup-legacy,cli-tools vagrant provision
```

### Example: include the vagrant role too (requires nested virtualization)

```sh
LAPTOP_BOOTSTRAP_SKIP_TAGS= vagrant provision
```

> ⚠️ **Warning**: Installing vagrant+libvirt *inside* a libvirt VM requires enabling nested virt on the host (`kvm_intel nested=1` / `kvm_amd nested=1`). On many systems this is off by default. Unless you need to test the vagrant role itself, leave `LAPTOP_BOOTSTRAP_SKIP_TAGS=vagrant`.

------

## 🔐 Handling ansible-vault

The repo ships with `group_vars/all/vault/main.yml` encrypted. Ansible refuses to start if it finds an encrypted file without the password, so by default the smoke harness:

1. **Excludes** `group_vars/all/vault/` from the rsync — the VM never sees the encrypted file.
2. **Stubs** the one vault-backed var actually used by the playbook (`desired_hostname_vault`) via `extra_vars` in the Vagrantfile, so the hostname-change task has something to work with.

If you add a new role that references a vault var, add a stub for it in the Vagrantfile's `extra_vars` hash. Don't try to forward the real vault password unless you specifically want to test decryption — stubs keep the smoke test self-contained and secret-free.

> 💡 **Note**: Committing the plain-text vault password is forbidden (see `rules/security-secrets.md`). The smoke test never reads the real vault.

------

## 🔧 Troubleshooting

### `Call to virDomainCreateWithFlags failed: Permission denied`

Your user isn't in the `libvirt` group, or the current shell hasn't picked up the membership.

```sh
sudo usermod -aG libvirt "$USER"
newgrp libvirt   # or open a new terminal
```

### `Error while connecting to libvirt: ... no such file or directory: '/var/run/libvirt/libvirt-sock'`

libvirtd isn't running.

```sh
sudo systemctl enable --now libvirtd
```

### `Bringing machine 'default' up with 'libvirt' provider... ==> default: Box 'generic/ubuntu2404' could not be found.`

The box download failed — usually a network issue or Vagrant Cloud outage. Try:

```sh
vagrant box add generic/ubuntu2404 --provider libvirt
```

### Playbook fails on `apt update` right after `cleanup-legacy`

This is the same symptom you'd hit on a real laptop if a stale apt source is still present. Run `vagrant ssh -c 'sudo apt update'` to see the real error. Most often it's a removed repo GPG key still referenced in `/etc/apt/sources.list.d/`.

### rsync sync fails with "mkstemp failed: Permission denied"

Your repo contains files owned by root (e.g., from a previous misconfigured bootstrap). Fix ownership on the host:

```sh
sudo chown -R "$USER:$USER" .
```

### "No space left on device" during box download

QCOW2 images end up under `/var/lib/libvirt/images/`. Check free space there, not in `$HOME`. Clean old smoke-test VMs:

```sh
virsh list --all
virsh undefine <name> --remove-all-storage
```

------

## ✅ Best practices

- **Run a smoke test before merging** any PR that touches a role, a var file, or `playbook.yml`. It's the cheapest insurance against "works on my laptop" regressions.
- **Keep the smoke VM ephemeral**: `vagrant destroy` between test cycles when validating non-idempotent changes.
- **Scope with tags** when iterating on one role. Full playbook runs should be reserved for final validation.
- **Don't commit secrets** into the VM. The rsync folder is a snapshot of your working tree — if a `.env` is there, it ships to the VM.
- **Test both distros** you care about by overriding `LAPTOP_BOOTSTRAP_BOX`. `bento/ubuntu-24.04` and `debian/bookworm64` cover the realistic matrix.
- **Baseline a known-good commit**: if something breaks in the VM but works on your laptop, `git stash && vagrant provision` against the stash-free tree to confirm the break is reproducible.

------

## 🎓 Conclusion

The smoke test is a disposable laptop you can rebuild in 10 minutes. Use it to:

- Catch environment assumptions before merge
- Validate that removing a role really is safe
- Reproduce bugs reported by collaborators who ran the playbook on a different OS
- Learn, by breaking things, what your playbook actually depends on

The harness is intentionally small: one `Vagrantfile`, one `ansible.cfg`, a handful of env var switches. If it feels constraining, that's the signal — test-specific complexity belongs in a separate role or in `molecule`, not here.

------

## 📚 Resources

- Vagrant libvirt provider: <https://vagrant-libvirt.github.io/vagrant-libvirt/>
- Vagrant `ansible_local` provisioner: <https://developer.hashicorp.com/vagrant/docs/provisioning/ansible_local>
- Ubuntu `generic` boxes: <https://app.vagrantup.com/generic/boxes/ubuntu2404>
- ADR-0001 (mise migration — what this harness validates): [`docs/adr/0001-unified-cli-tool-management-with-mise.md`](adr/0001-unified-cli-tool-management-with-mise.md)

------

> **Document created on**: 2026-04-20
> **Author**: Xavier GUERET
> **Version**: 1.0
