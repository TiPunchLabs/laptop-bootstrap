# Postman CLI Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated `postman_cli` Ansible role that installs the pinned Postman CLI binary and makes it own `/usr/local/bin/postman`, without colliding with the Postman desktop app installed by `devtools`.

**Architecture:** A standalone role modeled on `obsidian` (version-gated download/extract for idempotence). The versioned tarball is extracted into `/opt/postman-cli/` and the ELF binary is symlinked into `PATH`; the binary resolves its sibling `lib/` via `/proc/self/exe`, so the symlink works. The `devtools` desktop symlink is renamed to `postman-app` to free the `postman` name.

**Tech Stack:** Ansible (ansible.builtin: assert, command, get_url, unarchive, file, stat), Make, Vagrant+libvirt smoke harness.

## Global Constraints

- **Pinned version:** `postman_cli_version: "1.40.0"` (current upstream `latest`).
- **Download URL (versioned, verified):** `https://dl-cli.pstmn.io/download/version/{{ postman_cli_version }}/linux64`.
- **Install dir:** `/opt/postman-cli/` — **Binary path:** `/opt/postman-cli/postman-cli` — **PATH symlink:** `/usr/local/bin/postman`.
- **Architecture:** amd64 / `x86_64` only (Postman ships `linux64` only); fail clean otherwise.
- **Config scope:** binary only — **no** `postman login`, no API key, no vault, no man-page install.
- **Tag/include gotcha:** any tag-gated `include_role` MUST use `apply: tags:` inside **and** an outer `tags:` — outer tag alone makes the include look green while inner tasks silently skip.
- **Conventions:** English everywhere; Conventional Commits; `git switch`; GitHub Flow (work stays on branch `feat/postman-cli-role`). Each commit ends with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Lint gotcha:** if `ansible-lint` / a `pre-commit` commit fails with `Cannot allocate memory` during vault decrypt, run `gpgconf --kill all && ./bin/ansible-vault-pass.sh` then retry (known GPG-agent OOM).
- **Branch precondition:** all work happens on `feat/postman-cli-role` (already created). The approved spec lives at `docs/superpowers/specs/2026-06-28-postman-cli-role-design.md` (currently untracked — committed in Task 1).

---

### Task 1: Scaffold the `postman_cli` role (defaults, meta, tasks)

**Files:**
- Create: `roles/postman_cli/defaults/main.yml`
- Create: `roles/postman_cli/meta/main.yml`
- Create: `roles/postman_cli/tasks/main.yml`
- Commit (also): `docs/superpowers/specs/2026-06-28-postman-cli-role-design.md`

**Interfaces:**
- Consumes: gathered fact `ansible_facts['architecture']`.
- Produces: role `postman_cli` (no return vars); installs binary at `/opt/postman-cli/postman-cli`, symlink `/usr/local/bin/postman`. Default var names: `postman_cli_version`, `postman_cli_download_url`, `postman_cli_install_dir`, `postman_cli_bin_link`, `postman_cli_tarball_dest`.

- [ ] **Step 1: Write `roles/postman_cli/defaults/main.yml`**

```yaml
---
postman_cli_version: "1.40.0"
postman_cli_download_url: >-
  https://dl-cli.pstmn.io/download/version/{{ postman_cli_version }}/linux64
postman_cli_install_dir: "/opt/postman-cli"
postman_cli_bin_link: "/usr/local/bin/postman"
postman_cli_tarball_dest: "/tmp/postman-cli-{{ postman_cli_version }}.tar.gz"
```

- [ ] **Step 2: Write `roles/postman_cli/meta/main.yml`** (mirrors `roles/obsidian/meta/main.yml`)

```yaml
---
galaxy_info:
  author: xgueret
  description: Install the Postman CLI from the pinned upstream tarball (dl-cli.pstmn.io)
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

- [ ] **Step 3: Write `roles/postman_cli/tasks/main.yml`**

```yaml
---
- name: Assert the host architecture is supported (Postman ships linux64 only)
  ansible.builtin.assert:
    that:
      - ansible_facts['architecture'] == 'x86_64'
    fail_msg: >-
      The Postman CLI is only published for x86_64 (linux64); this host is
      {{ ansible_facts['architecture'] }}.

- name: Query installed Postman CLI version
  ansible.builtin.command:
    cmd: "{{ postman_cli_bin_link }} --version"
  register: postman_cli_installed
  changed_when: false
  failed_when: false

- name: Decide whether a (re)install is needed
  ansible.builtin.set_fact:
    postman_cli_needs_install: >-
      {{ (postman_cli_installed.rc != 0
          or (postman_cli_installed.stdout | trim) != postman_cli_version) | bool }}

- name: Remove any previous install dir (purge stale version files)
  ansible.builtin.file:
    path: "{{ postman_cli_install_dir }}"
    state: absent
  when: postman_cli_needs_install | bool

- name: Ensure the install dir exists
  ansible.builtin.file:
    path: "{{ postman_cli_install_dir }}"
    state: directory
    mode: "0755"
  when: postman_cli_needs_install | bool

- name: Download the pinned Postman CLI tarball
  ansible.builtin.get_url:
    url: "{{ postman_cli_download_url }}"
    dest: "{{ postman_cli_tarball_dest }}"
    mode: "0644"
  when: postman_cli_needs_install | bool

- name: Extract the Postman CLI tarball
  ansible.builtin.unarchive:
    src: "{{ postman_cli_tarball_dest }}"
    dest: "{{ postman_cli_install_dir }}"
    remote_src: true
  when: postman_cli_needs_install | bool

- name: Ensure the Postman CLI binary is executable
  ansible.builtin.file:
    path: "{{ postman_cli_install_dir }}/postman-cli"
    mode: "0755"
  when: postman_cli_needs_install | bool

- name: Symlink the Postman CLI into PATH (CLI owns /usr/local/bin/postman)
  ansible.builtin.file:
    src: "{{ postman_cli_install_dir }}/postman-cli"
    dest: "{{ postman_cli_bin_link }}"
    state: link
    force: true

- name: Remove the downloaded tarball to keep things tidy
  ansible.builtin.file:
    path: "{{ postman_cli_tarball_dest }}"
    state: absent
  when: postman_cli_needs_install | bool
```

- [ ] **Step 4: Lint the new role**

Run: `ansible-lint roles/postman_cli`
Expected: `Passed` (0 failures). If it errors with `Cannot allocate memory`, run `gpgconf --kill all && ./bin/ansible-vault-pass.sh` then re-run.

- [ ] **Step 5: Commit (role scaffold + the approved spec)**

```bash
git add roles/postman_cli docs/superpowers/specs/2026-06-28-postman-cli-role-design.md
git commit -m "feat(postman_cli): add role to install pinned Postman CLI

Standalone role (modeled on obsidian) that downloads the version-pinned
Postman CLI tarball, extracts it to /opt/postman-cli, and symlinks the
binary to /usr/local/bin/postman. Idempotent via postman --version probe.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Wire the role into `bootstrap` and the Makefile

**Files:**
- Modify: `roles/bootstrap/tasks/main.yml` (add an `include_role` block after the `devtools` block)
- Modify: `Makefile` (`.PHONY` line + `TAGS` assignment + target row)

**Interfaces:**
- Consumes: role `postman_cli` from Task 1.
- Produces: tag `postman-cli`; Make target `play-postman-cli`.

- [ ] **Step 1: Add the include block to `roles/bootstrap/tasks/main.yml`**

Insert immediately **after** the existing `- name: Install devtools` include block (and before `- name: Install Obsidian`):

```yaml
- name: Install Postman CLI
  ansible.builtin.include_role:
    name: postman_cli
    apply:
      tags:
        - postman-cli
  tags:
    - postman-cli
```

- [ ] **Step 2: Register the Make target in `Makefile`**

Add `play-postman-cli` to the existing `.PHONY: play-cli-tools ...` line, then add these two rows alongside the other `play-*` rows:

```makefile
play-postman-cli:    TAGS := postman-cli
play-postman-cli:    play ## Run only the postman_cli role
```

- [ ] **Step 3: Verify the playbook still parses and the tag is wired**

Run: `ansible-playbook -i inventory.yml playbook.yml --syntax-check`
Expected: no errors (prints the playbook path).
Run: `ansible-playbook -i inventory.yml playbook.yml --list-tags 2>/dev/null | grep -o 'postman-cli'`
Expected: prints `postman-cli`.

- [ ] **Step 4: Verify the Make target exists**

Run: `make help | grep postman-cli`
Expected: a line `play-postman-cli   Run only the postman_cli role`.

- [ ] **Step 5: Commit**

```bash
git add roles/bootstrap/tasks/main.yml Makefile
git commit -m "feat(bootstrap): wire postman_cli role with postman-cli tag + make target

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Resolve the `devtools` desktop-app symlink collision

**Files:**
- Modify: `roles/devtools/tasks/postman.yml`

**Interfaces:**
- Consumes: nothing new.
- Produces: desktop app symlink moved to `/usr/local/bin/postman-app`; stale CLI-name squatter removed only when it points into `/opt/Postman/`.

- [ ] **Step 1: Replace the symlink task in `roles/devtools/tasks/postman.yml`**

Find this block:

```yaml
- name: Create a symbolic link for Postman
  ansible.builtin.file:
    src: "/opt/Postman/Postman"
    dest: "/usr/local/bin/postman"
    state: link
```

Replace it with:

```yaml
- name: Inspect any existing /usr/local/bin/postman (CLI may own it)
  ansible.builtin.stat:
    path: "/usr/local/bin/postman"
  register: devtools_postman_existing

- name: Drop the stale desktop symlink that squatted the CLI name
  ansible.builtin.file:
    path: "/usr/local/bin/postman"
    state: absent
  when:
    - devtools_postman_existing.stat.exists | default(false)
    - devtools_postman_existing.stat.islnk | default(false)
    - (devtools_postman_existing.stat.lnk_target | default('')) is search('/opt/Postman/')

- name: Create a symbolic link for the Postman desktop app (postman-app)
  ansible.builtin.file:
    src: "/opt/Postman/Postman"
    dest: "/usr/local/bin/postman-app"
    state: link
```

> The `.desktop` entry below this block already invokes `/opt/Postman/Postman` directly — leave it unchanged; the GUI is unaffected.

- [ ] **Step 2: Lint the modified role**

Run: `ansible-lint roles/devtools`
Expected: `Passed`.

- [ ] **Step 3: Commit**

```bash
git add roles/devtools/tasks/postman.yml
git commit -m "fix(devtools): rename Postman desktop symlink to postman-app

Frees /usr/local/bin/postman for the Postman CLI; the desktop app is
launched via its .desktop entry, so renaming its symlink is harmless.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Document the new role and tag

**Files:**
- Modify: `README.md` (the *Available Tags* table + the *Project Structure* role list)

**Interfaces:**
- Consumes: tag `postman-cli` from Task 2.
- Produces: user-facing docs.

- [ ] **Step 1: Add the tag row to the *Available Tags* table**

After the `| `devtools` | ... |` row, add:

```markdown
| `postman-cli` | Install the pinned Postman CLI (`postman` command) |
```

- [ ] **Step 2: Add the role to the *Project Structure* list**

After the `- `devtools/`: Development tools (Postman, etc.)` bullet, add:

```markdown
  - `postman_cli/`: Postman **CLI** (`postman` collection runner) — pinned tarball from `dl-cli.pstmn.io`, owns `/usr/local/bin/postman` (the `devtools` role's desktop app is symlinked as `postman-app`)
```

- [ ] **Step 3: Lint the docs (whole pre-commit run)**

Run: `pre-commit run --files README.md`
Expected: all applicable hooks `Passed`/`Skipped`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document postman-cli tag and postman_cli role

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Verify on the smoke VM (install, idempotence, collision regression)

**Files:** none (verification only).

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: evidence the role works end-to-end.

- [ ] **Step 1: Boot the smoke VM (if not already up)**

Run: `make smoke-up`
Expected: VM boots, provisioning completes (~10 min first time).

- [ ] **Step 2: First replay of the role**

Run: `make smoke-replay TAGS=postman-cli`
Expected: play runs the `postman_cli` role; `changed` on download/extract/symlink; `failed=0`.

- [ ] **Step 3: Assert the binary works and resolves to the symlink**

Run: `cd test/smoke && vagrant ssh -c 'readlink -f $(command -v postman); postman --version'`
Expected: path resolves to `/opt/postman-cli/postman-cli`; version prints `1.40.0`.

- [ ] **Step 4: Idempotence — second replay must be no-change**

Run: `make smoke-replay TAGS=postman-cli`
Expected: `changed=0` for the `postman_cli` role tasks (download/extract skipped, symlink unchanged); `failed=0`.

- [ ] **Step 5: Collision regression — replay devtools, CLI must keep the name**

Run: `make smoke-replay TAGS=devtools`
Then: `cd test/smoke && vagrant ssh -c 'readlink -f $(command -v postman); readlink -f /usr/local/bin/postman-app'`
Expected: `/usr/local/bin/postman` still resolves to `/opt/postman-cli/postman-cli`; `/usr/local/bin/postman-app` resolves to `/opt/Postman/Postman`.

- [ ] **Step 6: Tear down (optional)**

Run: `make smoke-down`
Expected: VM destroyed.

- [ ] **Step 7: No commit** — this task produces no file changes. If any step failed, return to the relevant task, fix, and re-run.

---

## Post-implementation

After Task 5 passes, push `feat/postman-cli-role` and open a PR (only when the user asks):

```bash
git push -u origin feat/postman-cli-role
gh pr create --base main --head feat/postman-cli-role \
  --title "feat(postman_cli): install the Postman CLI via a pinned tarball role"
```

> **Note:** PR #43 (`docs/project-claude-md`) is independent and can merge in any order.

---

## Self-Review

**Spec coverage:**
- Role layout (defaults/meta/tasks) → Task 1 ✓
- Versioned URL + pinned `1.40.0` → Task 1 (defaults) ✓
- Idempotence via `postman --version` probe + purge-before-extract → Task 1 ✓
- Symlink `force: true`, always claims `postman` → Task 1 ✓
- Arch assert (x86_64) → Task 1 ✓
- Collision fix in `devtools` (rename to `postman-app` + drop stale squatter) → Task 3 ✓
- `bootstrap` include with `apply: tags:` → Task 2 ✓
- Makefile `play-postman-cli` → Task 2 ✓
- README tags table + structure → Task 4 ✓
- Smoke + idempotence + collision regression → Task 5 ✓
- Non-goals (no login/vault/man-page) respected — no tasks add them ✓

**Placeholder scan:** No TBD/TODO; every code step contains full content. ✓

**Type/name consistency:** `postman_cli_needs_install`, `postman_cli_install_dir`, `postman_cli_bin_link`, `postman_cli_version`, `postman_cli_download_url`, `postman_cli_tarball_dest`, `devtools_postman_existing` used consistently across tasks. ✓
