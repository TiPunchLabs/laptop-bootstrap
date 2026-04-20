# CLI Tools Migration to mise — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all user-space CLI tools (`uv`, `fzf`, `direnv`, `zoxide`, `eza`, `bat`, `chezmoi`, `starship`, `kubectl`, `terraform`, `awscli`) to `mise` as the single version manager, keep `vagrant` system-managed, and clean up obsolete installations.

**Architecture:** A new `cli_tools` role installs `mise` and renders a `~/.config/mise/config.toml`; a new `cleanup_legacy` role removes pre-migration artifacts (apt packages/repos, `/usr/local/bin` binaries); the `hashicorp_software` role is renamed to `vagrant` and stripped of terraform; `starship`, `kubectl`, and `devops` (aws-cli) roles are removed.

**Tech Stack:** Ansible 2.14+ (roles, `ansible.builtin.apt`, `apt_repository`, `file`, `template`, `lineinfile`, `shell`), mise (single install script), TOML config.

**Decision reference:** [`docs/adr/0001-unified-cli-tool-management-with-mise.md`](../../adr/0001-unified-cli-tool-management-with-mise.md).

---

## File Structure

**Created:**
- `roles/cli_tools/tasks/main.yml` — install mise + render config + activate in .bashrc
- `roles/cli_tools/vars/main.yml` — list of tools + versions to manage via mise
- `roles/cli_tools/templates/mise.config.toml.j2` — Jinja2 template for `~/.config/mise/config.toml`
- `roles/cleanup_legacy/tasks/main.yml` — remove old apt packages, repos, keys, binaries
- `roles/cleanup_legacy/vars/main.yml` — list of artifacts to remove
- `roles/vagrant/tasks/main.yml` — vagrant + libvirt + vagrant-libvirt plugin (ex-`hashicorp_software`, terraform removed)
- `roles/vagrant/vars/main.yml` — vagrant HashiCorp repo + libvirt dependencies

**Modified:**
- `roles/bootstrap/tasks/main.yml` — drop `starship`/`kubectl`/`devops` includes, rename `hashicorp_software` → `vagrant`, add `cleanup_legacy` before `cli_tools`
- `README.md` — update project structure + tags table

**Deleted:**
- `roles/hashicorp_software/` (replaced by `roles/vagrant/`)
- `roles/starship/` (replaced by mise-managed starship)
- `roles/kubectl/` (replaced by mise-managed kubectl)
- `roles/devops/` (replaced by mise-managed awscli)

---

### Task 1: Rename `hashicorp_software` role to `vagrant`

**Files:**
- Move: `roles/hashicorp_software/` → `roles/vagrant/`
- Modify: `roles/vagrant/tasks/main.yml`
- Modify: `roles/vagrant/vars/main.yml`

- [ ] **Step 1: Rename the role directory with `git mv`**

Run:
```bash
git mv roles/hashicorp_software roles/vagrant
```
Expected: directory moved, git tracks the rename.

- [ ] **Step 2: Remove terraform from the packages list**

Edit `roles/vagrant/vars/main.yml` — replace the whole file with:

```yaml
---
# HashiCorp apt repo (kept for vagrant only — terraform moved to mise)
vagrant_hashicorp_gpg:
  key_path: /usr/share/keyrings/hashicorp-archive-keyring.gpg
  key_url: https://apt.releases.hashicorp.com/gpg
  repo: "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com {{ ansible_facts['distribution_release'] }} main"

vagrant_packages:
  - vagrant

vagrant_libvirt_dependencies:
  - libvirt-dev
  - qemu-kvm
  - libvirt-daemon-system
  - libvirt-clients
  - bridge-utils
  - virt-manager
  - nfs-common
  - nfs-kernel-server
  - build-essential
  - zlib1g-dev
  - ruby-dev
  - libxml2-dev
  - libxslt-dev
  - libguestfs-tools
```

- [ ] **Step 3: Rewrite `roles/vagrant/tasks/main.yml` with renamed variables**

Replace the whole file with:

```yaml
---
- name: Ensure apt-transport-https is installed
  ansible.builtin.apt:
    name: apt-transport-https
    state: present

- name: Check if HashiCorp GPG key exists
  ansible.builtin.stat:
    path: "{{ vagrant_hashicorp_gpg.key_path }}"
  register: vagrant_hashicorp_key_exists

- name: Download HashiCorp GPG key
  ansible.builtin.get_url:
    url: "{{ vagrant_hashicorp_gpg.key_url }}"
    dest: /tmp/hashicorp-archive-keyring.gpg
    mode: '0644'
  when: not vagrant_hashicorp_key_exists.stat.exists

- name: Install HashiCorp GPG key
  ansible.builtin.command: >
    gpg --dearmor -o {{ vagrant_hashicorp_gpg.key_path }} /tmp/hashicorp-archive-keyring.gpg
  args:
    creates: "{{ vagrant_hashicorp_gpg.key_path }}"
  when: not vagrant_hashicorp_key_exists.stat.exists

- name: Add HashiCorp apt repository (vagrant)
  ansible.builtin.apt_repository:
    repo: "{{ vagrant_hashicorp_gpg.repo }}"
    filename: hashicorp
    state: present

- name: Install vagrant
  ansible.builtin.apt:
    pkg: "{{ vagrant_packages }}"
    state: present

- name: Install libvirt dependencies
  ansible.builtin.apt:
    pkg: "{{ vagrant_libvirt_dependencies }}"
    state: present

- name: Install the vagrant-libvirt plugin
  ansible.builtin.command:
    cmd: vagrant plugin install vagrant-libvirt
  args:
    creates: "/home/{{ bootstrap_local_user }}/.vagrant.d/gems/*/gems/vagrant-libvirt-*"
  become_user: "{{ bootstrap_local_user }}"

- name: Ensure the current user is added to the libvirt group
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

- [ ] **Step 4: Lint the renamed role**

Run: `ansible-lint roles/vagrant/`
Expected: no errors.

---

### Task 2: Delete obsolete roles (`starship`, `kubectl`, `devops`)

**Files:**
- Delete: `roles/starship/`
- Delete: `roles/kubectl/`
- Delete: `roles/devops/`

- [ ] **Step 1: Remove the three role directories with `trash`**

Run (`trash` sends to ~/.local/share/Trash, recoverable):
```bash
trash roles/starship roles/kubectl roles/devops
```
Expected: directories moved to trash; `ls roles/` no longer shows `starship`, `kubectl`, `devops`.

- [ ] **Step 2: Stage deletions**

Run:
```bash
git add -A roles/starship roles/kubectl roles/devops
```
Expected: `git status` shows `deleted: roles/starship/...`, etc.

---

### Task 3: Rewrite `cli_tools` role — variables

**Files:**
- Modify: `roles/cli_tools/vars/main.yml`

- [ ] **Step 1: Replace the existing vars file**

Write `roles/cli_tools/vars/main.yml`:

```yaml
---
# mise install script (single bootstrap entry point)
cli_tools_mise_install_url: https://mise.run

# Path to the mise binary once installed (per-user)
cli_tools_mise_bin: "/home/{{ bootstrap_local_user }}/.local/bin/mise"

# Path to the global mise config
cli_tools_mise_config_dir: "/home/{{ bootstrap_local_user }}/.config/mise"
cli_tools_mise_config_file: "{{ cli_tools_mise_config_dir }}/config.toml"

# Tools declared in mise config.toml. Use "latest" unless a pinned version is needed.
cli_tools_mise_tools:
  uv: latest
  fzf: latest
  direnv: latest
  zoxide: latest
  eza: latest
  bat: latest
  chezmoi: latest
  starship: latest
  kubectl: latest
  terraform: latest
  awscli: latest

# Shell hooks to append to .bashrc (in this order)
cli_tools_bashrc_lines:
  - 'eval "$(~/.local/bin/mise activate bash)"'
  - 'eval "$(~/.local/bin/mise exec -- starship init bash)"'
```

- [ ] **Step 2: Validate YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('roles/cli_tools/vars/main.yml'))"`
Expected: no output (valid YAML).

---

### Task 4: Create mise config template

**Files:**
- Create: `roles/cli_tools/templates/mise.config.toml.j2`

- [ ] **Step 1: Create the Jinja2 template**

Write `roles/cli_tools/templates/mise.config.toml.j2`:

```jinja
# Managed by Ansible — edits will be overwritten.
# Source of truth: roles/cli_tools/vars/main.yml (cli_tools_mise_tools)

[tools]
{% for tool, version in cli_tools_mise_tools.items() %}
{{ tool }} = "{{ version }}"
{% endfor %}
```

- [ ] **Step 2: Verify the template renders**

Run (quick dry-render with Python):
```bash
python3 -c "
from jinja2 import Template
import yaml
vars = yaml.safe_load(open('roles/cli_tools/vars/main.yml'))
tpl = Template(open('roles/cli_tools/templates/mise.config.toml.j2').read())
print(tpl.render(cli_tools_mise_tools=vars['cli_tools_mise_tools']))
"
```
Expected output includes `[tools]` and each tool on its own line with `"latest"`.

---

### Task 5: Rewrite `cli_tools` role — tasks

**Files:**
- Modify: `roles/cli_tools/tasks/main.yml`

- [ ] **Step 1: Replace the existing tasks file**

Write `roles/cli_tools/tasks/main.yml`:

```yaml
---
- name: Check if mise is installed
  ansible.builtin.stat:
    path: "{{ cli_tools_mise_bin }}"
  register: cli_tools_mise_stat

- name: Install mise via upstream script  # noqa: command-instead-of-module
  ansible.builtin.shell:
    cmd: "set -o pipefail && curl -fsSL {{ cli_tools_mise_install_url }} | sh"
    executable: /bin/bash
    creates: "{{ cli_tools_mise_bin }}"
  environment:
    HOME: "/home/{{ bootstrap_local_user }}"
  become_user: "{{ bootstrap_local_user }}"
  when: not cli_tools_mise_stat.stat.exists

- name: Ensure mise config directory exists
  ansible.builtin.file:
    path: "{{ cli_tools_mise_config_dir }}"
    state: directory
    owner: "{{ bootstrap_local_user }}"
    group: "{{ bootstrap_local_user }}"
    mode: '0755'

- name: Render mise global config
  ansible.builtin.template:
    src: mise.config.toml.j2
    dest: "{{ cli_tools_mise_config_file }}"
    owner: "{{ bootstrap_local_user }}"
    group: "{{ bootstrap_local_user }}"
    mode: '0644'
  register: cli_tools_mise_config

- name: Install/update all tools declared in mise config
  ansible.builtin.command:
    cmd: "{{ cli_tools_mise_bin }} install --yes"
  environment:
    HOME: "/home/{{ bootstrap_local_user }}"
  become_user: "{{ bootstrap_local_user }}"
  register: cli_tools_mise_install
  changed_when: "'installed' in cli_tools_mise_install.stdout or 'installed' in cli_tools_mise_install.stderr"

- name: Add mise activation + starship init to .bashrc
  ansible.builtin.lineinfile:
    path: "/home/{{ bootstrap_local_user }}/.bashrc"
    line: "{{ item }}"
    state: present
    create: true
    mode: '0644'
  become_user: "{{ bootstrap_local_user }}"
  loop: "{{ cli_tools_bashrc_lines }}"
```

- [ ] **Step 2: Lint the role**

Run: `ansible-lint roles/cli_tools/`
Expected: no errors.

---

### Task 6: Create `cleanup_legacy` role — variables

**Files:**
- Create: `roles/cleanup_legacy/vars/main.yml`

- [ ] **Step 1: Declare artifacts to remove**

Write `roles/cleanup_legacy/vars/main.yml`:

```yaml
---
# Apt packages to purge (previously managed by other roles — now mise-managed)
cleanup_legacy_apt_packages:
  - fzf
  - bat
  - direnv
  - eza
  - kubectl
  - terraform

# Apt source files to remove (kept only if their only reason to exist was a purged package)
cleanup_legacy_apt_sources:
  - /etc/apt/sources.list.d/kubernetes.list

# Apt GPG keyrings to remove alongside the sources
cleanup_legacy_apt_keyrings:
  - /usr/share/keyrings/kubernetes-apt-keyring.gpg

# Binaries and directories installed manually under /usr/local
cleanup_legacy_paths:
  - /usr/local/bin/starship
  - /usr/local/bin/aws
  - /usr/local/bin/aws_completer
  - /usr/local/bin/kubectl-convert
  - /usr/local/aws-cli

# Stale legacy binaries under the user's ~/.local/bin that pre-date mise
cleanup_legacy_user_paths:
  - "/home/{{ bootstrap_local_user }}/.local/bin/uv"
```

> **Note:** The HashiCorp apt repo is **not** removed — vagrant still uses it (see `roles/vagrant/`).

- [ ] **Step 2: Validate YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('roles/cleanup_legacy/vars/main.yml'))"`
Expected: no output.

---

### Task 7: Create `cleanup_legacy` role — tasks

**Files:**
- Create: `roles/cleanup_legacy/tasks/main.yml`

- [ ] **Step 1: Write the tasks file**

Write `roles/cleanup_legacy/tasks/main.yml`:

```yaml
---
- name: Purge legacy apt packages (now mise-managed)
  ansible.builtin.apt:
    pkg: "{{ cleanup_legacy_apt_packages }}"
    state: absent
    purge: true
    autoremove: true

- name: Remove legacy apt source lists
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop: "{{ cleanup_legacy_apt_sources }}"

- name: Remove legacy apt GPG keyrings
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop: "{{ cleanup_legacy_apt_keyrings }}"

- name: Refresh apt cache after source cleanup
  ansible.builtin.apt:
    update_cache: true

- name: Remove legacy binaries and directories under /usr/local
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop: "{{ cleanup_legacy_paths }}"

- name: Remove stale user-level binaries from ~/.local/bin
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop: "{{ cleanup_legacy_user_paths }}"
```

- [ ] **Step 2: Lint the role**

Run: `ansible-lint roles/cleanup_legacy/`
Expected: no errors.

---

### Task 8: Update `bootstrap/tasks/main.yml`

**Files:**
- Modify: `roles/bootstrap/tasks/main.yml` (lines ~67-117 in the current file)

- [ ] **Step 1: Replace the role-include block**

In `roles/bootstrap/tasks/main.yml`, locate the block that currently contains the includes for `hashicorp_software`, `git`, `starship`, `docker`, `kubectl`, `devtools`, `devops`, `cli_tools` (lines ~67-117).

Replace that entire block with:

```yaml
- name: Install vagrant + libvirt
  ansible.builtin.include_role:
    name: vagrant
  tags:
    - vagrant

- name: Install And Configure Git
  ansible.builtin.include_role:
    name: git
  tags:
    - git

- name: Install Docker
  ansible.builtin.include_role:
    name: docker
  tags:
    - docker

- name: Install devtools
  ansible.builtin.include_role:
    name: devtools
  tags:
    - devtools

- name: Cleanup legacy installations before mise takes over
  ansible.builtin.include_role:
    name: cleanup_legacy
  tags:
    - cleanup-legacy
    - cli-tools

- name: Install CLI tools via mise
  ansible.builtin.include_role:
    name: cli_tools
  tags:
    - cli-tools
    - mise
```

- [ ] **Step 2: Lint the bootstrap role**

Run: `ansible-lint roles/bootstrap/`
Expected: no errors.

---

### Task 9: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the roles list (lines ~17-27)**

Replace the `roles/` bullet list with:

```markdown
- `roles/`: Contains various Ansible roles
  - `bootstrap/`: Main role for laptop installation and configuration (orchestrates other roles)
  - `cli_tools/`: Unified CLI tool manager via [mise](https://mise.jdx.dev/) — installs uv, fzf, direnv, zoxide, eza, bat, chezmoi, starship, kubectl, terraform, awscli
  - `cleanup_legacy/`: Removes pre-migration apt packages / binaries / repos superseded by mise
  - `devtools/`: Development tools installation (e.g., Postman)
  - `docker/`: Docker and Docker Compose installation
  - `git/`: Git configuration
  - `vagrant/`: Vagrant + libvirt + vagrant-libvirt plugin (kept system-managed per ADR-0001)
```

- [ ] **Step 2: Update the ASCII tree (lines ~57-66)**

Replace the `roles` subtree with:

```
└── roles
    ├── bootstrap
    ├── cli_tools
    ├── cleanup_legacy
    ├── devtools
    ├── docker
    ├── git
    └── vagrant
```

- [ ] **Step 3: Replace the tags table (lines ~128-142)**

Replace the Available Tags table with:

```markdown
| Tag | Description |
|-----|-------------|
| `update` | Update and upgrade system packages |
| `docker` | Install Docker and Docker Compose |
| `git` | Configure Git |
| `devtools` | Install development tools (Postman) |
| `vagrant` | Install Vagrant + libvirt stack |
| `cleanup-legacy` | Remove pre-mise installations |
| `cli-tools` | Install/update all CLI tools via mise |
| `mise` | Alias for `cli-tools` |
```

- [ ] **Step 4: Add an ADR reference section**

Append to the end of `README.md`:

```markdown
## Architecture Decisions

See [`docs/adr/`](docs/adr/) for the list of Architecture Decision Records. Notably:

- [ADR-0001](docs/adr/0001-unified-cli-tool-management-with-mise.md) — Unified CLI tool management with mise
```

---

### Task 10: Full-project lint

- [ ] **Step 1: Run ansible-lint on the whole project**

Run: `ansible-lint`
Expected: no errors. If errors appear in *unchanged* roles (pre-existing issues), note them but do not fix in this plan — out of scope.

- [ ] **Step 2: Run yamllint on new/modified YAML**

Run:
```bash
yamllint roles/cli_tools roles/cleanup_legacy roles/vagrant roles/bootstrap/tasks/main.yml
```
Expected: no errors.

---

### Task 11: Dry-run validation

- [ ] **Step 1: Run ansible check mode on the cli-tools flow**

Run: `uv run ansible-playbook playbook.yml --tags cli-tools --check --diff`
Expected: shows which tasks *would* change. Cleanup tasks show removals; `cli_tools` tasks show mise install + config render.

- [ ] **Step 2: Run ansible check mode on vagrant**

Run: `uv run ansible-playbook playbook.yml --tags vagrant --check --diff`
Expected: idempotent — no changes for an already-provisioned vagrant (only the role path changed, not the declared state).

---

## Notes

- **Shell hooks design**: `mise activate` is sufficient for most tools' shims; starship requires its own `init bash` eval, which we run through `mise exec --` so the starship binary is resolved via mise without needing a duplicate PATH entry.
- **fzf key-bindings**: not re-added here. Users who want them can add `source "$(mise where fzf)/shell/key-bindings.bash"` to their `~/.bashrc.local`. Out of scope for this plan.
- **`vagrant plugin install` task**: unchanged from the `hashicorp_software` role except for renamed variables. The plugin path glob (`vagrant-libvirt-*`) already matches any version.
- **Commits**: this plan does not prescribe commits. The executing agent should follow the user's `commit-policy.md` (never auto-commit — only on explicit user request).
- **Order matters**: `cleanup_legacy` runs **before** `cli_tools` so that old binaries are out of `PATH` before mise installs its own shims.
