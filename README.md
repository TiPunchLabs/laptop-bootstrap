# Automated Laptop Setup and Configuration with Ansible

## Description ![Stars](https://img.shields.io/github/stars/TiPunchLabs/laptop-bootstrap?style=social) ![Last Commit](https://img.shields.io/github/last-commit/TiPunchLabs/laptop-bootstrap) ![Status](https://img.shields.io/badge/Status-Active-brightgreen)

This project uses Ansible to automate the installation and configuration of a laptop running Debian or Ubuntu. It includes essential software installation, system configuration, and the management of development and containerization tools.

## Project Structure

- `ansible.cfg`: Global Ansible configuration
- `inventory.yml`: Defines hosts and groups for Ansible
- `playbook.yml`: Main playbook orchestrating the role execution
- `Makefile`: Daily-use targets (`make help` to discover them)
- `bin/`: Shell scripts
  - `local_laptop.sh`: Bootstrap script to run the playbook
  - `ansible-vault-pass.sh`: Vault password helper (reads from `pass`)
  - `check_ansible_vault.sh`: Pre-commit hook for vault encryption
  - `add-yaml-document-start.sh`: Pre-commit hook for YAML formatting
- `roles/`: Contains the Ansible roles
  - `bootstrap/`: Entry-point role that orchestrates the others; owns the apt sources for vendor packages (`bootstrap_software_list`, deb822)
  - `cli_tools/`: Unified CLI tool manager via [mise](https://mise.jdx.dev/) — installs uv, fzf, direnv, zoxide, eza, bat, chezmoi, starship, kubectl, terraform, awscli; manages an atomic `~/.bashrc` block
  - `cleanup_legacy/`: Removes pre-migration apt packages / binaries / repos superseded by mise
  - `devtools/`: Development tools (Postman, etc.)
  - `docker/`: Docker engine + compose plugin (deb822 source, atomic GPG dearmor)
  - `git/`: Git configuration
  - `libvirt/`: KVM + libvirt user stack (qemu-kvm, virt-manager, virtinst, ovmf, ...) — also consumed by `vagrant/` as a meta-dependency
  - `vagrant/`: Vagrant + libvirt + vagrant-libvirt plugin (system-managed per ADR-0001)
- `test/smoke/`: Vagrant + libvirt smoke harness for replaying the playbook on a clean VM
- `docs/`:
  - `guide-daily-usage.md`: End-to-end day-to-day workflow
  - `guide-smoke-test-vagrant.md`: Smoke-test walkthrough
  - `adr/`: Architecture Decision Records
  - `superpowers/specs/`: Approved design docs for non-trivial role changes
- `github/`, `terraform/`: Terraform configuration for GitHub resources (TiPunchLabs)

```
.
├── ansible.cfg
├── .envrc
├── .pre-commit-config.yaml
├── Makefile
├── playbook.yml
├── inventory.yml
├── pyproject.toml
├── uv.lock
├── README.md / CONTRIBUTING.md / SECURITY.md / CODE_OF_CONDUCT.md
├── bin/                        # vault helper + pre-commit hook scripts
├── group_vars/all/             # vault + clear group vars
├── github/  ·  terraform/      # IaC for the GitHub repo + adjacent infra
├── docs/
│   ├── guide-daily-usage.md
│   ├── guide-smoke-test-vagrant.md
│   ├── adr/                    # Architecture Decision Records
│   └── superpowers/specs/      # Approved design docs
├── roles/
│   ├── bootstrap/              # entry point + vendor apt sources
│   ├── cli_tools/              # mise-managed user CLI tools + shell hooks block
│   ├── cleanup_legacy/         # pre-mise eviction
│   ├── devtools/  ·  docker/  ·  git/  ·  libvirt/  ·  vagrant/
└── test/smoke/                 # Vagrant + libvirt replay harness
```

## Prerequisites

- Debian-based system (Debian 12, Ubuntu...)
- Python 3.10 or higher
- [uv](https://docs.astral.sh/uv/) - Python package manager
- [direnv](https://direnv.net/) (optional, for automatic environment activation)

## Installation

### 1. Clone the Repository

```sh
git clone https://github.com/TiPunchLabs/laptop-bootstrap.git
cd laptop-bootstrap
```

### 2. Install Dependencies

Using direnv (recommended):

```sh
direnv allow
```

Or manually with uv:

```sh
uv sync
source .venv/bin/activate
```

### 3. Configure Ansible Vault

If files are encrypted with `ansible-vault`, the password is automatically configured via `.envrc` using `pass`:

```sh
# The .envrc file exports ANSIBLE_VAULT_PASSWORD from pass
export ANSIBLE_VAULT_PASSWORD=$(pass ansible/vault)
```

### 4. Run the Playbook

The Makefile is the recommended entry point — `make help` lists every target:

```sh
make play                       # full playbook
make play-cli-tools             # only the cli_tools role
make play TAGS=docker,git       # arbitrary tag combination
```

Equivalent low-level invocation:

```sh
uv run ansible-playbook -i inventory.yml playbook.yml --tags update
./bin/local_laptop.sh update    # legacy wrapper, same effect
```

For the daily edit → verify → ship loop, see [`docs/guide-daily-usage.md`](docs/guide-daily-usage.md).

## Available Tags

| Tag | Description |
|-----|-------------|
| `update` | Update and upgrade system packages |
| `docker` | Install Docker and Docker Compose |
| `git` | Configure Git |
| `devtools` | Install development tools (Postman) |
| `libvirt` | Install KVM + libvirt user stack (qemu-kvm, virt-manager, virtinst, ovmf, ...) |
| `vagrant` | Install Vagrant + the vagrant-libvirt plugin (depends on `libvirt`) |
| `cleanup-legacy` | Remove pre-mise installations |
| `cli-tools` | Install/update all CLI tools via mise |
| `mise` | Alias for `cli-tools` |

## Migrating from a Pre-mise Laptop

If you are upgrading a laptop that was provisioned before [ADR-0001](docs/adr/0001-unified-cli-tool-management-with-mise.md), run the two tags **in this order**:

```sh
uv run ansible-playbook playbook.yml --tags cleanup-legacy
uv run ansible-playbook playbook.yml --tags cli-tools
exec bash   # reload PATH so mise shims take precedence over /usr/local/bin
```

> ⚠️ **Transition window** — between `cleanup-legacy` and `cli-tools`, the following tools are **temporarily absent**: `starship`, `direnv`, `uv`, `eza`, `bat`, `fzf`, `kubectl`, `terraform`. This is expected. Do not close the terminal or rely on those commands until `cli-tools` completes. Running the two tags back-to-back keeps the window to a few minutes.

> 💡 **Note on `exec bash`** — `cli_tools` adds `eval "$(mise activate bash)"` to `~/.bashrc`, but the current shell only picks it up after re-reading the file. Without `exec bash` (or opening a new terminal), `which kubectl` may still resolve to the old `/usr/local/bin/kubectl` binary instead of the mise shim.

### Manual `.bashrc` cleanup (one-time)

`cli_tools` installs its shell hooks as a marker-bounded block (`ANSIBLE MANAGED: cli_tools shell hooks`). If your `.bashrc` already contains standalone copies from pre-mise installs, the role does **not** auto-remove them (doing so would corrupt the managed block on subsequent runs — see the design note in [`docs/superpowers/specs/2026-04-21-cli-tools-shell-hooks-design.md`](docs/superpowers/specs/2026-04-21-cli-tools-shell-hooks-design.md)). Delete these literal lines by hand, once per laptop:

```sh
# Lines to remove from ~/.bashrc if present outside the `ANSIBLE MANAGED` block:
eval "$(~/.local/bin/mise activate bash)"
eval "$(starship init bash)"
eval "$(direnv hook bash)"
```

### `kvm` group membership (one-time, post-libvirt-role)

On the first playbook run after the `libvirt` role landed, your user is added to the `kvm` group (in addition to `libvirt`). The new membership only takes effect for **new** sessions — run `newgrp kvm` in the current shell or simply log out and back in.

After deletion, re-run `make play-cli-tools` to regenerate a clean managed block.

## Security & Code Quality

The project uses `pre-commit` to enforce code quality and security checks.

### Hooks configured

- **YAML**: yamllint, check-yaml, document start marker
- **Shell**: shellcheck, shfmt
- **Ansible**: ansible-lint, vault encryption check
- **Terraform**: terraform_fmt, terraform_validate, terraform_tflint
- **Python**: flake8
- **General**: trailing-whitespace, end-of-file-fixer, detect-private-key

### Usage

```sh
# Install hooks (run once)
pre-commit install

# Run all hooks on all files
make lint
# or directly:
pre-commit run --all-files

# Run only ansible-lint (faster feedback while editing a role)
make lint-ansible

# Run a specific hook
pre-commit run ansible-lint --all-files

# Update hooks to latest versions
pre-commit autoupdate
```

## Architecture Decisions

See [`docs/adr/`](docs/adr/) for the list of Architecture Decision Records. Notably:

- [ADR-0001](docs/adr/0001-unified-cli-tool-management-with-mise.md) — Unified CLI tool management with mise

## Testing

A smoke-test harness replays the playbook inside a clean Ubuntu VM via Vagrant + libvirt, so you can validate changes without touching your real laptop:

```sh
make smoke-up                   # boot VM, install ansible, run playbook (~10 min first time)
make smoke-replay               # rsync code + replay
make smoke-replay TAGS=docker   # replay only one tag
make smoke-down                 # clean up
```

See [`test/smoke/README.md`](test/smoke/README.md) for the cheatsheet and [`docs/guide-smoke-test-vagrant.md`](docs/guide-smoke-test-vagrant.md) for the full walkthrough (architecture, troubleshooting, vault handling).

## Contributors

- **Author**: Xavier GUERET [![GitHub followers](https://img.shields.io/github/followers/xgueret?style=social)](https://github.com/xgueret) [![Twitter Follow](https://img.shields.io/twitter/follow/xgueret?style=social)](https://x.com/hixmaster) [![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/xavier-gueret-47bb3019b/)

## Contributing

Contributions are welcome! Please feel free to submit a [Pull Request](https://github.com/TiPunchLabs/laptop-bootstrap/pulls).

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/TiPunchLabs/laptop-bootstrap/blob/main/LICENSE) file for details.
