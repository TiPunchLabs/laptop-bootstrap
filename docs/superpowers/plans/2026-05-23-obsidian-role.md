# Obsidian Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated, idempotent `obsidian` Ansible role that installs a pinned version of the official Obsidian `.deb` (GitHub releases, no apt repo upstream) and wire it into the bootstrap run.

**Architecture:** New `roles/obsidian` with `defaults/` (pinned version + URL), `meta/`, `README.md`, and `tasks/main.yml`. Tasks check the installed version via `dpkg-query`, and only when it differs from the pinned version do they download the `.deb`, install it with `ansible.builtin.apt: deb:` (apt resolves dependencies), and clean up the artifact. The role is invoked from `roles/bootstrap/tasks/main.yml` near `devtools` with its own `obsidian` tag.

**Tech Stack:** Ansible (`ansible.builtin.command`, `get_url`, `apt`, `file`), pre-commit (`ansible-lint`, `yamllint`), Vagrant + libvirt smoke harness.

---

## Reference — spec

Design spec: `docs/superpowers/specs/2026-05-23-obsidian-role-design.md` (approved 2026-05-23).

## Environment note — pre-commit gpg-agent OOM

`pre-commit` runs `ansible-lint`, which syntax-checks every role; some roles
reference the encrypted vault and trigger a gpg decrypt that can fail with
`gpg: ... Cannot allocate memory`. This is unrelated to this feature. Before any
commit that runs the hooks, run:

```bash
gpgconf --kill gpg-agent
```

If the OOM persists on an unrelated role after killing the agent, the hooks for a
given commit may be bypassed with `git commit --no-verify` **only** when the
committed files contain no Ansible/YAML to lint (e.g. docs-only). For this
feature's role/YAML commits, do NOT use `--no-verify` — the new YAML must be
linted; retry after `gpgconf --kill gpg-agent` instead.

## File Structure

- Create: `roles/obsidian/defaults/main.yml` — pinned version, arch, derived URL + dest path.
- Create: `roles/obsidian/meta/main.yml` — galaxy_info, `dependencies: []`.
- Create: `roles/obsidian/tasks/main.yml` — version check → download → apt install → cleanup.
- Create: `roles/obsidian/README.md` — role README (version-bump workflow).
- Modify: `roles/bootstrap/tasks/main.yml` — add `include_role` block for `obsidian` after the `devtools` block.
- Modify: `README.md` — add `obsidian/` to the roles list and the ASCII tree.

---

## Task 1: Scaffold the `obsidian` role (defaults + meta)

**Files:**
- Create: `roles/obsidian/defaults/main.yml`
- Create: `roles/obsidian/meta/main.yml`

- [ ] **Step 1: Create `roles/obsidian/defaults/main.yml`**

```yaml
---
obsidian_version: "1.12.7"
obsidian_arch: "amd64"
obsidian_deb_url: >-
  https://github.com/obsidianmd/obsidian-releases/releases/download/v{{ obsidian_version }}/obsidian_{{ obsidian_version }}_{{ obsidian_arch }}.deb
obsidian_deb_dest: "/tmp/obsidian_{{ obsidian_version }}_{{ obsidian_arch }}.deb"
```

- [ ] **Step 2: Create `roles/obsidian/meta/main.yml`**

```yaml
---
galaxy_info:
  author: xgueret
  description: Install Obsidian from the pinned upstream .deb (GitHub releases)
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

- [ ] **Step 3: Commit**

```bash
gpgconf --kill gpg-agent
git add roles/obsidian/defaults/main.yml roles/obsidian/meta/main.yml
git commit -m "feat(obsidian): scaffold role defaults and meta"
```

---

## Task 2: Write the role tasks (version check → install → cleanup)

**Files:**
- Create: `roles/obsidian/tasks/main.yml`

- [ ] **Step 1: Create `roles/obsidian/tasks/main.yml`**

```yaml
---
- name: Query installed Obsidian version
  ansible.builtin.command:
    cmd: "dpkg-query -W -f='${Version}' obsidian"
  register: obsidian_installed
  changed_when: false
  failed_when: false

- name: Download Obsidian .deb (pinned version)
  ansible.builtin.get_url:
    url: "{{ obsidian_deb_url }}"
    dest: "{{ obsidian_deb_dest }}"
    mode: "0644"
  when: obsidian_installed.stdout | trim != obsidian_version

- name: Install Obsidian from .deb (apt resolves dependencies)
  ansible.builtin.apt:
    deb: "{{ obsidian_deb_dest }}"
    state: present
  when: obsidian_installed.stdout | trim != obsidian_version

- name: Remove downloaded .deb to keep things tidy
  ansible.builtin.file:
    path: "{{ obsidian_deb_dest }}"
    state: absent
  when: obsidian_installed.stdout | trim != obsidian_version
```

- [ ] **Step 2: Lint the new role**

```bash
gpgconf --kill gpg-agent
.venv/bin/ansible-lint roles/obsidian/
```

Expected: no violations on `roles/obsidian/` (ignore any unrelated `internal-error`/gpg-OOM warnings coming from other roles' vault decrypt — those predate this change).

- [ ] **Step 3: Commit**

```bash
gpgconf --kill gpg-agent
git add roles/obsidian/tasks/main.yml
git commit -m "feat(obsidian): install pinned .deb idempotently"
```

---

## Task 3: Wire the role into the bootstrap run

**Files:**
- Modify: `roles/bootstrap/tasks/main.yml` (insert after the `Install devtools` block, before the `Cleanup legacy installations` block)

- [ ] **Step 1: Insert the `obsidian` include block**

Find this exact block in `roles/bootstrap/tasks/main.yml`:

```yaml
- name: Install devtools
  ansible.builtin.include_role:
    name: devtools
    apply:
      tags:
        - devtools
  tags:
    - devtools
```

Insert immediately **after** it:

```yaml
- name: Install Obsidian
  ansible.builtin.include_role:
    name: obsidian
    apply:
      tags:
        - obsidian
  tags:
    - obsidian
```

- [ ] **Step 2: Syntax-check the playbook**

```bash
gpgconf --kill gpg-agent
.venv/bin/ansible-playbook playbook.yml --syntax-check
```

Expected: `playbook: playbook.yml` with no syntax errors.

- [ ] **Step 3: Commit**

```bash
gpgconf --kill gpg-agent
git add roles/bootstrap/tasks/main.yml
git commit -m "feat(bootstrap): invoke obsidian role with dedicated tag"
```

---

## Task 4: Role README + root README

**Files:**
- Create: `roles/obsidian/README.md`
- Modify: `README.md`

- [ ] **Step 1: Create `roles/obsidian/README.md`**

```markdown
# obsidian

Install [Obsidian](https://obsidian.md/) from the official upstream `.deb`
attached to the GitHub releases of `obsidianmd/obsidian-releases`.

There is **no upstream apt repository**, so the version is pinned and the `.deb`
is downloaded directly. Dependencies are resolved by apt (`ansible.builtin.apt:
deb:`), not `dpkg -i`. The `.deb` registers its own `.desktop` entry and icon.

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `obsidian_version` | `1.12.7` | Pinned Obsidian version (without the `v` prefix). |
| `obsidian_arch` | `amd64` | Debian architecture of the asset (only `amd64` is published upstream). |
| `obsidian_deb_url` | derived | Full GitHub release download URL. |
| `obsidian_deb_dest` | `/tmp/obsidian_<version>_<arch>.deb` | Local download path. |

## Upgrading

Bump `obsidian_version` in `defaults/main.yml`, then re-run:

```bash
ansible-playbook playbook.yml --tags obsidian
```

The role compares the installed version (`dpkg-query`) to the pinned one and only
downloads + installs when they differ — a replay at the pinned version is a no-op.

## Requirements

- Debian 12+ / Ubuntu 22.04+ (`amd64`)

## Dependencies

None.

## Example

```yaml
- hosts: localhost
  become: true
  roles:
    - role: obsidian
```
```

- [ ] **Step 2: Add `obsidian/` to the roles list in `README.md`**

Find this line:

```
  - `devtools/`: Development tools (Postman, etc.)
```

Insert immediately **after** it:

```
  - `obsidian/`: Obsidian notes app (pinned upstream `.deb` from GitHub releases)
```

- [ ] **Step 3: Add `obsidian/` to the ASCII tree in `README.md`**

Find this line:

```
│   ├── devtools/  ·  docker/  ·  git/  ·  libvirt/  ·  vagrant/
```

Replace it with:

```
│   ├── devtools/  ·  docker/  ·  git/  ·  libvirt/  ·  obsidian/  ·  vagrant/
```

- [ ] **Step 4: Commit**

```bash
gpgconf --kill gpg-agent
git add roles/obsidian/README.md README.md
git commit -m "docs(obsidian): document role and list it in README"
```

---

## Task 5: Functional verification on the host

This installs Obsidian on the real laptop. Run from the repo root.

- [ ] **Step 1: First run — installs Obsidian**

```bash
.venv/bin/ansible-playbook playbook.yml --tags obsidian --diff
```

Expected: the `Download Obsidian .deb` and `Install Obsidian from .deb` tasks
report `changed`; the play recap shows `changed>=2`, `failed=0`.

- [ ] **Step 2: Verify the installed version**

```bash
dpkg-query -W -f='${Version}\n' obsidian
```

Expected: `1.12.7`.

- [ ] **Step 3: Verify the launcher is registered and the temp .deb is gone**

```bash
test -f /usr/share/applications/obsidian.desktop && echo "desktop OK"
ls /tmp/obsidian_1.12.7_amd64.deb 2>/dev/null || echo "tmp cleaned OK"
```

Expected: `desktop OK` and `tmp cleaned OK`.

- [ ] **Step 4: Idempotence — second run is a no-op**

```bash
.venv/bin/ansible-playbook playbook.yml --tags obsidian --diff
```

Expected: play recap shows `changed=0`, `failed=0` (the `dpkg-query` task is
`ok` with `changed_when: false`, all gated tasks skipped).

---

## Task 6: Full pre-commit + smoke test (clean-room idempotence)

- [ ] **Step 1: Run the full pre-commit suite**

```bash
gpgconf --kill gpg-agent
.venv/bin/pre-commit run --all-files
```

Expected: `ansible-lint` and `yamllint` pass. If `ansible-lint` reports an
`internal-error` with `Cannot allocate memory` on an unrelated role, re-run
`gpgconf --kill gpg-agent` and try again — it is the known vault-decrypt OOM, not
a fault in this change.

- [ ] **Step 2: (Optional) Smoke-test on a clean VM**

Follow `docs/guide-smoke-test-vagrant.md` to replay the full playbook in
`test/smoke/`. Confirm:
- the `obsidian` role installs `1.12.7` on a fresh host;
- a second replay reports `changed=0` for the obsidian tasks;
- `dpkg-query -W obsidian` reports `1.12.7`.

---

## Done criteria

- `roles/obsidian/` exists with `defaults`, `meta`, `tasks`, `README.md`.
- `ansible-playbook playbook.yml --tags obsidian` installs Obsidian `1.12.7`; a
  second run is `changed=0`.
- `roles/bootstrap/tasks/main.yml` invokes `obsidian` with the `obsidian` tag.
- Root `README.md` lists the new role in both the prose list and the ASCII tree.
- `pre-commit run --all-files` passes (modulo the documented gpg-OOM retry).
