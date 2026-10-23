# Laptop Bootstrap

Ansible project that keeps a Debian/Ubuntu developer laptop reproducible: system packages, vendor apt repositories, desktop apps, container/virtualization stacks and user CLI tools are all declared in this repository and applied with one playbook.

## Architecture

Three layers, each with a distinct job:

| Layer | Responsible for | Where it is declared |
|---|---|---|
| **Ansible** | Orchestration and system configuration: hostname, `/etc/hosts`, systemd drop-ins (DNS, sudo, journald), roles for Docker, libvirt, Vagrant, Git, Syncthing, etc. Every change goes through a playbook run, so a laptop can be rebuilt from Git. | `playbook.yml` → `roles/bootstrap/` (entry point, includes the other roles) |
| **APT** | System components and apps that ship as Debian packages (Docker, Chrome, VS Code, Brave, DBeaver, Trivy, libvirt, …), plus their deb822 sources and signing keyrings. | `roles/bootstrap/vars/main/essentials.yml`, `roles/bootstrap/vars/main/software.yml`, per-role vars |
| **mise** | User-level CLI tools that have a mise backend: version selection, installation, activation in interactive shells. | `cli_tools_mise_tools` in `roles/cli_tools/vars/main.yml` |

mise is **not** a universal package manager here. Anything that needs system integration (daemons, kernel modules, desktop entries, apt-maintained security updates) stays on APT on purpose. The reasoning is in [ADR-0001](docs/adr/0001-unified-cli-tool-management-with-mise.md).

```
.
├── playbook.yml / inventory.yml / ansible.cfg   # single local host, vault via bin/ansible-vault-pass.sh
├── Makefile                                     # daily entry point (`make help`)
├── group_vars/all/                              # vars.yml (public aliases) + vault/ (encrypted)
├── roles/
│   ├── bootstrap/        # entry point, base packages, vendor apt sources, system drop-ins
│   ├── apt_keyring/      # vendor signing keyrings, re-synced every run
│   ├── cli_tools/        # mise install + config + managed ~/.bashrc block
│   ├── cleanup_legacy/   # removes pre-mise installs (destructive, see below)
│   └── devtools · docker · git · libvirt · obsidian · postman_cli · syncthing · vagrant
├── test/smoke/           # Vagrant + libvirt VM to replay the playbook safely
├── uninstall-opera.yml   # one-shot maintenance playbook
├── github-terraform/     # Terraform for the GitHub repository settings
└── docs/                 # guides + ADRs
```

## Quick Start

### 1. Prerequisites

- Debian or Ubuntu (the playbook asserts a Debian-family OS), sudo rights
- [uv](https://docs.astral.sh/uv/), `make`, `git`
- [`pass`](https://www.passwordstore.org/) holding the vault password at `ansible/vault`
- [direnv](https://direnv.net/) (optional, recommended)

### 2. Clone and install dependencies

```sh
git clone https://github.com/TiPunchLabs/laptop-bootstrap.git
cd laptop-bootstrap
direnv allow                 # creates .venv and runs `uv sync`
# or, without direnv:
uv sync && source .venv/bin/activate
pre-commit install
```

### 3. Secrets

`ansible.cfg` sets `vault_password_file = ./bin/ansible-vault-pass.sh`, which runs `pass show ansible/vault` (override the entry with `ANSIBLE_VAULT_PASS_PATH`). No password is stored in the repo. Check that it resolves without printing it:

```sh
./bin/ansible-vault-pass.sh >/dev/null && echo "vault password OK"
make vault-view              # decrypts group_vars/all/vault/main.yml to the terminal
```

Without the vault, `group_vars/all/vars.yml` falls back to placeholder values.

### 4. Check before applying

```sh
make help
ansible-playbook -i inventory.yml playbook.yml --tags docker --check --diff
```

> ⚠️ `--check` is a preview, not a guarantee: tasks that depend on commands run earlier (mise listing, downloads) are skipped or approximated. `--diff` can print file contents; don't use it on a role that touches files holding secrets (for example `~/.bashrc`).

### 5. First run

```sh
make play                    # full playbook, see the scope below
```

A full run (no tags) does all of this: `apt upgrade`, sets the hostname, rewrites `/etc/hosts`, installs base packages and vendor apps, configures DNS/sudo/journald drop-ins, runs every role, **including `cleanup_legacy`**, and finally `cli_tools`. On an already provisioned laptop, prefer a targeted tag (see [Daily Operations](#daily-operations)).

### 6. Validate

```sh
exec bash                    # reload ~/.bashrc so mise activation applies
mise ls                      # every declared tool, no "missing"
make play TAGS=<tag>         # second run of the same scope: expect changed=0
```

## Daily Operations

| Kind | Command | Effect |
|---|---|---|
| Diagnostic | `make help`, `make lint`, `make lint-ansible`, `make vault-view`, `make smoke-status` | Read-only on the laptop |
| Diagnostic | `ansible-playbook -i inventory.yml playbook.yml --tags <tag> --check` | Preview (the Makefile has no check target) |
| Modifies the system | `make play TAGS=<tags>`, `make play-<role>` | Applies the selected roles |
| **Removes components** | `make play-cleanup-legacy`, `make play-cli-tools`, `make play` (no tags), `make uninstall-opera` | Purges packages, repos, keyrings, binaries |
| Local cleanup | `make clean` | Deletes `*.retry` and local `.ansible`/pre-commit caches |

### Available Tags

| Tag | Scope |
|---|---|
| `mise` | `cli_tools` only. **Safe default for CLI tool changes.** |
| `cli-tools` | `cleanup_legacy` **then** `cli_tools` (also what `make play-cli-tools` runs) |
| `cleanup-legacy` | `cleanup_legacy` only |
| `update` | `apt update` + `apt upgrade` |
| `docker`, `git`, `devtools`, `postman-cli`, `obsidian`, `syncthing`, `libvirt`, `vagrant` | The role of the same name (`vagrant` pulls in `libvirt`) |
| `internal-dns`, `sudo`, `journald` | The matching systemd/sudo drop-in from `bootstrap` |

Base packages, vendor apps (`software.yml`), hostname and `/etc/hosts` have no tag: they only run in a full, untagged run.

### Managing CLI tools with mise

There are three distinct operations:

| Goal | How | What happens |
|---|---|---|
| Change the declaration (add/remove/pin a tool) | Edit `cli_tools_mise_tools`, then `make play TAGS=mise` | Re-renders `~/.config/mise/config.toml`, installs missing tools, **uninstalls tools no longer declared** |
| Install declared tools on a fresh machine | `make play TAGS=mise` | `mise install --yes` runs only when the config changed or a tool is missing |
| Upgrade tools already installed | `mise upgrade` (or `mise upgrade <tool>`) | Ansible never does this: `latest` is resolved at install time and **not** refreshed by later playbook runs |

Node.js and pnpm are pinned to a major version (`node: "22"`, `pnpm: "10"`), because `latest` would track Node's non-LTS line. `mise upgrade node pnpm` stays within those majors. To change the major, edit the value and run `make play TAGS=mise`.

### Testing in a VM

```sh
make smoke-up                       # create the VM (~10 min the first time)
make smoke-replay TAGS=mise         # rsync code + replay; run twice, expect changed=0
make smoke-ssh / make smoke-down
```

The smoke VM skips the `vagrant` tag by default (nested virtualization). Full walkthrough: [`docs/guide-smoke-test-vagrant.md`](docs/guide-smoke-test-vagrant.md), cheatsheet: [`test/smoke/README.md`](test/smoke/README.md).

## Safety & Compatibility

### `cleanup_legacy`

This role purges the apt packages `fzf bat direnv eza kubectl terraform k9s`, the Kubernetes apt source, old keyrings under `/usr/share/keyrings/`, `/usr/local/bin/{starship,aws,aws_completer,kubectl-convert}`, `/usr/local/aws-cli`, `~/.local/bin/uv`, `~/.tool-versions`, and a few orphan `~/.bashrc` lines (full list in `roles/cleanup_legacy/vars/main.yml`). It is idempotent, but it **deletes things**, and it runs with both `cleanup-legacy` and `cli-tools`. Use `mise` when you only mean to touch mise tools.

Run it only after `docker` and `vagrant` have run at least once since the keyring move (a full run does this in the right order). Otherwise their sources may still point at the keyrings it removes: `make play TAGS=docker,vagrant` first.

### APT keyrings

`apt_keyring` rebuilds each vendor keyring under `/etc/apt/keyrings/` on every run and installs it only when the bytes differ, so an upstream key rotation heals on the next run instead of leaving apt on `NO_PUBKEY` ([`roles/apt_keyring/README.md`](roles/apt_keyring/README.md)).

**Chrome is the exception.** Google's package (postinst + `/etc/cron.daily/google-chrome`) owns `/usr/share/keyrings/google-chrome.gpg` and rewrites `google-chrome.sources` to sign with it. Never delete that file: `apt update` breaks until the cron recreates it. Because the playbook and Chrome's cron both write that source, a full run may report a change on it.

### Node.js / pnpm and older installs

The NodeSource `nodejs` apt package and the standalone pnpm under `~/.local/share/pnpm` are **kept on purpose**. The pnpm global packages still live in `PNPM_HOME`.

- **Interactive shells** (`~/.bashrc` → `mise activate`): the mise `node`/`pnpm` come first. `cli_tools` moves the pnpm installer's `PNPM_HOME` entry to the end of `PATH` so it can't shadow mise.
- **Non-interactive contexts** (cron, systemd units, `bash -c`, IDE tasks that don't read `~/.bashrc`): mise is not activated, so `/usr/bin/node` and the standalone pnpm still resolve.

```sh
type -a node pnpm            # first hit under ~/.local/share/mise/installs/
mise current node pnpm
```

**Rollback:** remove the `node`/`pnpm` lines from `cli_tools_mise_tools` and run `make play TAGS=mise`. The prune step uninstalls them from mise, and the older binaries resolve again after `exec bash`.

### Manual `.bashrc` cleanup (one-time)

`cli_tools` owns a marker-bounded block (`ANSIBLE MANAGED: cli_tools shell hooks`). Only laptops provisioned before that block existed may still have stray copies of `eval "$(~/.local/bin/mise activate bash)"`, `eval "$(starship init bash)"` or `eval "$(direnv hook bash)"` outside it. The role does not remove those lines (see [the design note](docs/superpowers/specs/2026-04-21-cli-tools-shell-hooks-design.md)); delete them by hand, then run `make play TAGS=mise`.

### Other one-time notes

- After the first `libvirt` run, your user joins the `kvm`/`libvirt` groups: log out and back in (or `newgrp kvm`).
- Migrating a pre-mise laptop is just a `cli-tools` run (cleanup then install), followed by `exec bash`. Between the two steps the purged tools are briefly missing. Already-migrated laptops don't need any of this.
- `bin/local_laptop.sh` is a legacy wrapper with an outdated tag list; use the Makefile.

## Documentation

- [Daily usage guide](docs/guide-daily-usage.md): what to edit for each intent, the edit → verify → apply loop, troubleshooting
- [Smoke-test guide](docs/guide-smoke-test-vagrant.md): VM harness in depth
- [Architecture Decision Records](docs/adr/): notably [ADR-0001](docs/adr/0001-unified-cli-tool-management-with-mise.md) (mise)
- [CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

## Security

- Secrets live only in `group_vars/all/vault/main.yml` (Ansible Vault). Edit them with `make vault-edit`. The vault password comes from `pass`, and `.envrc` reads its tokens from `pass` too, so nothing is stored in plain text.
- `pre-commit` (run by `make lint`) enforces yamllint, ansible-lint, shellcheck/shfmt, Terraform fmt/validate/tflint, flake8, `detect-private-key` and a vault-encryption check that blocks plaintext vault files.
- Vendor keyrings are validated with `gpg --show-keys` before installation (an HTML error page fails the run).
- Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

## License

MIT, see [LICENSE](LICENSE). Author: Xavier Gueret ([@xgueret](https://github.com/xgueret)).
