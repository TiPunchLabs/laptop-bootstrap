# Syncthing Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an idempotent `syncthing` Ansible role that installs Syncthing, enables its systemd user service (with linger), and manages only the GUI listen address + auth — never touching the device identity, pairings, or relays.

**Architecture:** One new role `roles/syncthing` (mirroring `roles/obsidian`), wired into `roles/bootstrap/tasks/main.yml` via a tag-gated `include_role`, plus a `make play-syncthing` target and README/tags updates. Package install + linger run as root; everything touching the user home or the user systemd manager runs as `bootstrap_local_user`. The GUI password is set correctly (bcrypt) by `syncthing generate --gui-password` on fresh hosts only; on existing hosts only `address`/`user` are reconciled via surgical `community.general.xml` edits.

**Tech Stack:** Ansible (`ansible.builtin.apt`, `getent`, `systemd_service`, `community.general.xml`), Syncthing distro package, ansible-vault, pre-commit (ansible-lint/yamllint), Vagrant smoke harness.

**Spec:** [`docs/superpowers/specs/2026-05-25-syncthing-role-design.md`](../specs/2026-05-25-syncthing-role-design.md)

**Verification model (Ansible, not pytest):** each task ends by running `ansible-lint` on the touched files and `ansible-playbook --syntax-check`, then committing. Behaviour/idempotence is validated end-to-end in Task 9 (smoke VM + real-host replay).

---

## File Structure

- **Create** `roles/syncthing/defaults/main.yml` — role variables (config dir, GUI address, GUI user).
- **Create** `roles/syncthing/meta/main.yml` — galaxy metadata (mirrors other roles).
- **Create** `roles/syncthing/tasks/main.yml` — install, linger, generate-if-fresh, reconcile GUI address/user, enable+start service.
- **Create** `roles/syncthing/README.md` — role documentation.
- **Modify** `group_vars/all/vars.yml` — add the vault-backed public alias `syncthing_gui_password`.
- **Modify** `group_vars/all/vault/main.yml` — add encrypted `vault_syncthing_gui_password` (interactive, via `make vault-edit`).
- **Modify** `roles/bootstrap/tasks/main.yml` — add the tag-gated `include_role` block after the Obsidian block.
- **Modify** `Makefile` — add the `play-syncthing` target.
- **Modify** `README.md` — roles list, ASCII tree, Available Tags table.

---

### Task 1: GUI password variable (vault-backed public alias)

**Files:**
- Modify: `group_vars/all/vars.yml`
- Modify: `group_vars/all/vault/main.yml` (interactive)

- [ ] **Step 1: Add the public alias to `group_vars/all/vars.yml`**

Append this line under the existing aliases (after the `internal_dns_domains` line):

```yaml
syncthing_gui_password: "{{ vault_syncthing_gui_password | default('changeme') }}"
```

The `default('changeme')` keeps the playbook runnable when the vault is absent (the smoke harness excludes the vault from rsync).

- [ ] **Step 2: Add the encrypted secret to the vault (INTERACTIVE — user runs this)**

`ansible-vault` opens an editor and cannot run unattended. In the Claude Code prompt, run:

```
! make vault-edit
```

Add this line inside the decrypted buffer, then save & quit:

```yaml
vault_syncthing_gui_password: "<choose-a-strong-password>"
```

- [ ] **Step 3: Verify the vault still decrypts and the alias resolves**

Run: `make vault-view`
Expected: the decrypted YAML prints, including `vault_syncthing_gui_password`.

Run: `ANSIBLE_VAULT_PASSWORD="$(pass ansible/vault)" uv run ansible -i inventory.yml local -m debug -a "var=syncthing_gui_password" 2>/dev/null | tail -5`
Expected: shows the password value (proves the alias resolves from the vault).

> 💡 If `gpg-agent` OOMs during vault decrypt, run `gpgconf --kill all` then prime with `./bin/ansible-vault-pass.sh` before retrying.

- [ ] **Step 4: Commit**

```bash
git add group_vars/all/vars.yml group_vars/all/vault/main.yml
git commit -m "feat(syncthing): add vault-backed GUI password variable"
```

---

### Task 2: Role scaffold — defaults + meta

**Files:**
- Create: `roles/syncthing/defaults/main.yml`
- Create: `roles/syncthing/meta/main.yml`

- [ ] **Step 1: Create `roles/syncthing/defaults/main.yml`**

```yaml
---
# Modern XDG location used by the Ubuntu/Debian package. Override if a host
# uses the legacy ~/.config/syncthing path.
syncthing_config_dir: "/home/{{ bootstrap_local_user }}/.local/state/syncthing"

# GUI listen address. Local-only by default; set to "0.0.0.0:8384" to expose on
# the LAN (only do so with GUI auth enabled).
syncthing_gui_address: "127.0.0.1:8384"

# GUI username. The password is defined in group_vars/all (vault-backed alias
# `syncthing_gui_password`) and is applied only when generating a fresh config.
syncthing_gui_user: "{{ bootstrap_local_user }}"
```

- [ ] **Step 2: Create `roles/syncthing/meta/main.yml`**

```yaml
---
galaxy_info:
  author: xgueret
  description: >-
    Install Syncthing (distro package), enable its systemd user service, and
    manage GUI listen address + auth without touching identity or pairings.
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

- [ ] **Step 3: Lint the two files**

Run: `uv run ansible-lint roles/syncthing/defaults/main.yml roles/syncthing/meta/main.yml`
Expected: no errors (0 failures). `yamllint` clean too.

- [ ] **Step 4: Commit**

```bash
git add roles/syncthing/defaults/main.yml roles/syncthing/meta/main.yml
git commit -m "feat(syncthing): scaffold role defaults and metadata"
```

---

### Task 3: Role tasks — install, service, GUI reconciliation

**Files:**
- Create: `roles/syncthing/tasks/main.yml`

- [ ] **Step 1: Create `roles/syncthing/tasks/main.yml`**

```yaml
---
- name: Install Syncthing package
  ansible.builtin.apt:
    name: syncthing
    state: present

- name: Resolve the deploy user account (needed for XDG_RUNTIME_DIR)
  ansible.builtin.getent:
    database: passwd
    key: "{{ bootstrap_local_user }}"

- name: Set the deploy user uid fact
  ansible.builtin.set_fact:
    syncthing_user_uid: "{{ getent_passwd[bootstrap_local_user][1] }}"

- name: Enable lingering so the user service runs without an active login
  ansible.builtin.command:
    cmd: "loginctl enable-linger {{ bootstrap_local_user }}"
    creates: "/var/lib/systemd/linger/{{ bootstrap_local_user }}"

- name: Check whether a Syncthing config already exists
  become: true
  become_user: "{{ bootstrap_local_user }}"
  ansible.builtin.stat:
    path: "{{ syncthing_config_dir }}/config.xml"
  register: syncthing_config_stat

- name: Generate identity + config + GUI credentials (fresh host only)
  become: true
  become_user: "{{ bootstrap_local_user }}"
  ansible.builtin.command:
    cmd: >-
      syncthing generate
      --home {{ syncthing_config_dir }}
      --gui-user={{ syncthing_gui_user }}
      --gui-password={{ syncthing_gui_password }}
    creates: "{{ syncthing_config_dir }}/config.xml"
  no_log: true
  when: not syncthing_config_stat.stat.exists

- name: Read current GUI listen address
  become: true
  become_user: "{{ bootstrap_local_user }}"
  community.general.xml:
    path: "{{ syncthing_config_dir }}/config.xml"
    xpath: /configuration/gui/address
    content: text
  register: syncthing_gui_address_read
  changed_when: false

- name: Read current GUI user
  become: true
  become_user: "{{ bootstrap_local_user }}"
  community.general.xml:
    path: "{{ syncthing_config_dir }}/config.xml"
    xpath: /configuration/gui/user
    content: text
  register: syncthing_gui_user_read
  changed_when: false

- name: Compute current GUI values
  ansible.builtin.set_fact:
    syncthing_gui_address_current: >-
      {{ syncthing_gui_address_read.matches | map(attribute='address') | list | first | default('', true) }}
    syncthing_gui_user_current: >-
      {{ syncthing_gui_user_read.matches | map(attribute='user') | list | first | default('', true) }}

- name: Stop the Syncthing user service before editing config
  become: true
  become_user: "{{ bootstrap_local_user }}"
  ansible.builtin.systemd_service:
    name: syncthing.service
    scope: user
    state: stopped
  environment:
    XDG_RUNTIME_DIR: "/run/user/{{ syncthing_user_uid }}"
  when: >-
    syncthing_gui_address_current != syncthing_gui_address
    or syncthing_gui_user_current != syncthing_gui_user

- name: Set GUI listen address
  become: true
  become_user: "{{ bootstrap_local_user }}"
  community.general.xml:
    path: "{{ syncthing_config_dir }}/config.xml"
    xpath: /configuration/gui/address
    value: "{{ syncthing_gui_address }}"
  when: syncthing_gui_address_current != syncthing_gui_address

- name: Set GUI user
  become: true
  become_user: "{{ bootstrap_local_user }}"
  community.general.xml:
    path: "{{ syncthing_config_dir }}/config.xml"
    xpath: /configuration/gui/user
    value: "{{ syncthing_gui_user }}"
  when: syncthing_gui_user_current != syncthing_gui_user

- name: Enable and start the Syncthing user service
  become: true
  become_user: "{{ bootstrap_local_user }}"
  ansible.builtin.systemd_service:
    name: syncthing.service
    scope: user
    enabled: true
    state: started
  environment:
    XDG_RUNTIME_DIR: "/run/user/{{ syncthing_user_uid }}"
```

- [ ] **Step 2: Lint the tasks file**

Run: `uv run ansible-lint roles/syncthing/tasks/main.yml`
Expected: no errors. (If ansible-lint flags `command` for `loginctl`/`syncthing generate`, both are correctly guarded with `creates:`, which satisfies the `no-changed-when`/idempotency rules; resolve any genuine finding before committing.)

- [ ] **Step 3: Commit**

```bash
git add roles/syncthing/tasks/main.yml
git commit -m "feat(syncthing): install, enable user service, reconcile GUI settings"
```

---

### Task 4: Role README

**Files:**
- Create: `roles/syncthing/README.md`

- [ ] **Step 1: Create `roles/syncthing/README.md`**

````markdown
# syncthing

Install [Syncthing](https://syncthing.net/) from the distro repository, enable
its **systemd user service** (with lingering, so it survives reboot without an
active login), and manage **only** the web GUI settings.

## What it does — and what it never touches

Manages:

- the `syncthing` package (`apt`, idempotent);
- the systemd **user** service `syncthing.service` (enabled + started);
- the `<gui>` listen `address` and `user` in `config.xml` (surgical XML edits).

**Never touches** (so your setup keeps working):

- `cert.pem` / `key.pem` — the device identity / device ID;
- `<device>` / `<folder>` nodes — your pairings and shared folders;
- relays / discovery / NAT toggles — remote peers keep connecting;
- the GUI **password** on an existing host (see below).

`syncthing generate` runs **only** when `config.xml` is absent (a fresh host), so
on an already-configured machine the identity and pairings are preserved
untouched.

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `syncthing_config_dir` | `/home/<user>/.local/state/syncthing` | Syncthing home (XDG state dir used by the package). |
| `syncthing_gui_address` | `127.0.0.1:8384` | GUI listen address. Set `0.0.0.0:8384` to expose on the LAN (only with auth). |
| `syncthing_gui_user` | `<deploy user>` | GUI username. |
| `syncthing_gui_password` | vault (`group_vars/all`) | GUI password. Applied **only** when generating a fresh config. |

## GUI password

The password is set with a correct bcrypt hash by `syncthing generate
--gui-password` **only on a fresh host**. On an existing host the role never
re-writes it (no re-hash churn, no risk to the running config). To rotate it,
change it in the Syncthing GUI (Actions → Settings → GUI).

## Requirements

- Debian 12+ / Ubuntu 22.04+ with `systemd --user` available.
- `community.general` collection (ships the `xml` module) — already vendored.

## Dependencies

None. (Relies on `bootstrap_local_user`, set by the `bootstrap` role.)

## Example

```bash
ansible-playbook playbook.yml --tags syncthing
# or
make play-syncthing
```
````

- [ ] **Step 2: Commit**

```bash
git add roles/syncthing/README.md
git commit -m "docs(syncthing): add role README"
```

---

### Task 5: Wire the role into bootstrap

**Files:**
- Modify: `roles/bootstrap/tasks/main.yml`

- [ ] **Step 1: Add the include block after the Obsidian block**

Find this existing block in `roles/bootstrap/tasks/main.yml`:

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

Insert immediately **after** it:

```yaml
- name: Install and configure Syncthing
  ansible.builtin.include_role:
    name: syncthing
    apply:
      tags:
        - syncthing
  tags:
    - syncthing
```

> The `apply: tags:` wrapper is mandatory: without it a `--tags syncthing` run gates the include but leaves the role's inner tasks untagged, so they silently skip while the run looks green.

- [ ] **Step 2: Syntax-check the playbook scoped to the new tag**

Run: `uv run ansible-playbook -i inventory.yml playbook.yml --syntax-check --tags syncthing`
Expected: `playbook: playbook.yml` with no parse errors.

- [ ] **Step 3: Lint**

Run: `uv run ansible-lint roles/bootstrap/tasks/main.yml`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add roles/bootstrap/tasks/main.yml
git commit -m "feat(bootstrap): invoke syncthing role with dedicated tag"
```

---

### Task 6: Makefile `play-syncthing` target

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add `play-syncthing` to the `.PHONY` line**

Change:

```makefile
.PHONY: play-cli-tools play-docker play-git play-vagrant play-devtools play-cleanup-legacy play-obsidian
```

to:

```makefile
.PHONY: play-cli-tools play-docker play-git play-vagrant play-devtools play-cleanup-legacy play-obsidian play-syncthing
```

- [ ] **Step 2: Add the `TAGS :=` assignment after the `play-obsidian` one**

After:

```makefile
play-obsidian:       TAGS := obsidian
```

add:

```makefile
play-syncthing:      TAGS := syncthing
```

- [ ] **Step 3: Add the target dependency line after the `play-obsidian` one**

After:

```makefile
play-obsidian:       play ## Run only the obsidian role
```

add:

```makefile
play-syncthing:      play ## Run only the syncthing role
```

- [ ] **Step 4: Verify the target registers in help**

Run: `make help | grep play-syncthing`
Expected: `play-syncthing       Run only the syncthing role`

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat(make): add play-syncthing target to run only the syncthing role"
```

---

### Task 7: Top-level README updates

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the role to the `roles/` bullet list**

After the `obsidian/` bullet (the `Obsidian notes app …` line), add:

```markdown
  - `syncthing/`: Syncthing file sync — installs the distro package, enables the systemd user service, manages GUI address/auth (never touches identity/pairings)
```

- [ ] **Step 2: Add the role to the ASCII tree**

In the `roles/` section of the fenced tree, change the line:

```
│   ├── devtools/  ·  docker/  ·  git/  ·  libvirt/  ·  obsidian/  ·  vagrant/
```

to:

```
│   ├── devtools/  ·  docker/  ·  git/  ·  libvirt/  ·  obsidian/  ·  syncthing/  ·  vagrant/
```

- [ ] **Step 3: Add a row to the "Available Tags" table**

After the `obsidian` row is absent (there is none) — insert the `syncthing` row after the `devtools` row:

```markdown
| `syncthing` | Install Syncthing + enable its user service + manage GUI settings |
```

- [ ] **Step 4: Verify markdown renders (no broken table)**

Run: `uv run ansible-lint README.md 2>/dev/null; grep -n "syncthing" README.md`
Expected: the new role bullet, tree entry, and tag row all show.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(syncthing): document role and list it in README"
```

---

### Task 8: Full lint pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full pre-commit suite**

Run: `make lint`
Expected: every hook `Passed` or `Skipped` (ansible-lint, yamllint, shellcheck, vault check, etc.). Fix any failure and amend the relevant commit.

- [ ] **Step 2: Syntax-check the whole playbook**

Run: `uv run ansible-playbook -i inventory.yml playbook.yml --syntax-check`
Expected: no parse errors.

---

### Task 9: End-to-end verification (smoke VM + real host)

**Files:** none (verification only)

- [ ] **Step 1: Smoke-test a fresh install + idempotence**

Run: `make smoke-up` (first time) then `make smoke-replay TAGS=syncthing`
Expected on the VM:
- `syncthing` package installed;
- a fresh config + identity generated;
- `systemctl --user is-enabled syncthing` → `enabled`, `is-active` → `active`;
- GUI address = `127.0.0.1:8384`, GUI user set.

- [ ] **Step 2: Confirm idempotence**

Run: `make smoke-replay TAGS=syncthing` a second time.
Expected: recap shows **`changed=0`** for the syncthing tasks (no stop/start, no edit).

- [ ] **Step 3: Real-host replay (this laptop — enables the service)**

> This is the intended behaviour change on your machine: it enables + starts the
> user service (currently `disabled`/`dead`). It is a config no-op (address/user
> already match). Run consciously.

Run: `make play-syncthing`
Expected: only the linger + enable/start tasks report `changed`; GUI tasks `ok`.

- [ ] **Step 4: Verify identity + pairings preserved on the real host**

Run: `ls -l ~/.local/state/syncthing/cert.pem ~/.local/state/syncthing/key.pem`
Expected: **unchanged mtime** (Dec 12 — not regenerated).

Run: `systemctl --user is-enabled syncthing.service && systemctl --user is-active syncthing.service`
Expected: `enabled` and `active`.

Then open `http://127.0.0.1:8384` and confirm your paired devices and shared folders are all still present.

- [ ] **Step 5: Smoke teardown (optional)**

Run: `make smoke-down`

---

## Self-Review

- **Spec coverage:** install (Task 3), user service + linger (Task 3), GUI address/user reconciliation (Task 3), GUI password via generate (Task 3), vault password (Task 1), bootstrap wiring with `apply: tags:` (Task 5), Makefile target (Task 6), README + role README (Tasks 4, 7), smoke + idempotence + real-host verification (Task 9). All spec sections map to a task.
- **"Don't break" guarantees:** `cert.pem`/`key.pem` never referenced for write; `syncthing generate` guarded by `creates:` (existing host = skip); XML edits scoped strictly to `/configuration/gui/{address,user}`; password never edited on an existing host; relays/discovery never referenced. Verified in Task 9 Step 4.
- **No placeholders:** every code/edit step shows full content; the only interactive step (vault edit, Task 1 Step 2) is explicitly delegated to the user via `! make vault-edit`.
- **Name consistency:** `bootstrap_local_user`, `syncthing_config_dir`, `syncthing_gui_address`, `syncthing_gui_user`, `syncthing_gui_password`, `syncthing_user_uid`, and the `syncthing` tag are used identically across all tasks.
