# Automated Laptop Setup and Configuration with Ansible

## Description ![Stars](https://img.shields.io/github/stars/TiPunchLabs/laptop-bootstrap?style=social) ![Last Commit](https://img.shields.io/github/last-commit/TiPunchLabs/laptop-bootstrap) ![Status](https://img.shields.io/badge/Status-Active-brightgreen)

This project uses Ansible to automate the installation and configuration of a laptop running Debian or Ubuntu. It includes essential software installation, system configuration, and the management of development and containerization tools.

## Project Structure

- `ansible.cfg`: Global Ansible configuration
- `inventory.yml`: Defines hosts and groups for Ansible
- `playbook.yml`: Main playbook orchestrating the role execution
- `scripts/`: Shell scripts
  - `local_laptop.sh`: Bootstrap script to run the playbook
  - `ansible-vault-pass.sh`: Vault password helper
  - `check_ansible_vault.sh`: Pre-commit hook for vault encryption
  - `add-yaml-document-start.sh`: Pre-commit hook for YAML formatting
- `roles/`: Contains various Ansible roles
  - `bootstrap/`: Main role for laptop installation and configuration (orchestrates other roles)
  - `devops/`: DevOps tools installation (AWS CLI v2)
  - `devtools/`: Development tools installation (e.g., Postman)
  - `docker/`: Docker and Docker Compose installation
  - `git/`: Git configuration
  - `hashicorp_software/`: Terraform, Vagrant and libvirt installation
  - `kubectl/`: `kubectl` and `kubectl-convert` installation
  - `starship/`: Starship prompt installation
- `github/`: Terraform configuration for GitHub resources (from [TiPunchLabs](https://github.com/TiPunchLabs) project)

```
.
├── ansible.cfg
├── .envrc
├── group_vars
│   └── all
├── github
│   ├── data_sources.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── variables.tf
├── terraform
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── variables.tf
├── img
│   └── local_laptop.png
├── inventory.yml
├── playbook.yml
├── pyproject.toml
├── uv.lock
├── README.md
├── scripts
│   ├── add-yaml-document-start.sh
│   ├── ansible-vault-pass.sh
│   ├── check_ansible_vault.sh
│   └── local_laptop.sh
└── roles
    ├── bootstrap
    ├── devops
    ├── devtools
    ├── docker
    ├── git
    ├── hashicorp_software
    ├── kubectl
    └── starship
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

```sh
./scripts/local_laptop.sh
```

Or with a specific tag:

```sh
./scripts/local_laptop.sh update
```

Or directly with ansible-playbook:

```sh
uv run ansible-playbook playbook.yml --tags update
```

## Available Tags

- `update`: Update and upgrade system packages

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

# Run on all files
pre-commit run --all-files

# Run a specific hook
pre-commit run ansible-lint --all-files

# Update hooks to latest versions
pre-commit autoupdate
```

## Contributors

- **Author**: Xavier GUERET [![GitHub followers](https://img.shields.io/github/followers/xgueret?style=social)](https://github.com/xgueret) [![Twitter Follow](https://img.shields.io/twitter/follow/xgueret?style=social)](https://x.com/hixmaster) [![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/xavier-gueret-47bb3019b/)

## Contributing

Contributions are welcome! Please feel free to submit a [Pull Request](https://github.com/TiPunchLabs/laptop-bootstrap/pulls).

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/TiPunchLabs/laptop-bootstrap/blob/main/LICENSE) file for details.
