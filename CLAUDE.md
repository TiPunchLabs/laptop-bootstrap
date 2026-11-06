# laptop-bootstrap — project instructions for Claude Code

Map and rules for a Claude Code session. [`README.md`](README.md) is the
human-facing source of truth (full tag table, migration notes, prerequisites).
When this file and the code disagree, the code wins: update both.

> ⚠️ **Scope** — Independent Ansible project. The parent
> `02-infrastructure/CLAUDE.md` describes the homelab trio and declares `local/`
> (this repository) out of scope: do not import homelab/GitOps/Komodo context here.

------

## Agent workflow and hard rules

Objectives are handled with the Claude Code → Codex (via Herdr) loop described in
[`docs/agent-workflow.md`](docs/agent-workflow.md): the user gives an objective,
Claude Code inspects, plans, implements, verifies, gets an independent Codex
review, fixes, and writes a final report under `docs/missions/`. Read that file
at the start of every objective.

Three targets, three permission levels:

| Target | What it is | Allowed without asking |
|---|---|---|
| Repository | files on a feature branch or worktree | yes (never on `main`, never over the user's uncommitted work) |
| Smoke VM | `test/smoke/` Vagrant VM, disposable | `smoke-status`, `smoke-up`, `smoke-replay`, `smoke-ssh`; `smoke-down` needs approval |
| Real laptop | this machine: `make play*`, `ansible-playbook` without `--syntax-check`, `mise use/unuse/upgrade`, `~/.bashrc`, `~/.config/*`, apt | **never** — the owner runs it after approving the exact command |

Hard rules:

- **No secrets**: never run `pass`, `make vault-view`/`vault-edit`, `ansible-vault`,
  `bin/ansible-vault-pass.sh`, never print `ANSIBLE_VAULT_PASSWORD` or `TF_VAR_*`
  (direnv may have exported them into this shell). Run every Ansible command with
  the dummy password file (see the workflow doc), as CI does.
- **No `--diff`** on a role that touches files that may hold secrets (`~/.bashrc`,
  `.envrc`, vault, syncthing config). Use `--check` alone, and treat it as a preview.
- **mise owns its config**: Ansible seeds `~/.config/mise/config.toml` once (only when
  absent) and never rewrites it. Do not add tasks that reconcile, install into or
  prune it. The reference for fresh laptops is `roles/cli_tools/files/config.toml`.
- **`mise` ≠ `cli-tools`**: tag `mise` runs `cli_tools` only. Tag `cli-tools` (and
  `make play-cli-tools`, and an untagged `make play`) also runs `cleanup_legacy`,
  which purges packages and binaries. Recommend `TAGS=mise` for CLI-tool changes.
- **Hooks are not optional**: pre-commit (gitleaks, vault-encryption check, lint)
  is never skipped (`--no-verify`, `SKIP=`) and its config is not weakened to pass.
- **CI is not a laptop proof**: CI runs yamllint, ansible-lint, `--syntax-check` and
  Terraform validate only. Never report a green CI as "applied" or "works on the laptop".
- **Git**: commit, push, PR, merge and branch deletion only when the objective or
  the user explicitly authorizes them; merge is always the owner's. GitHub Flow,
  Conventional Commits, `git switch` (not `checkout`). GitHub issues are disabled:
  `BACKLOG.md` is the tracker.

------

## What this is

Ansible playbook that provisions a personal **Debian/Ubuntu laptop**. Single host
`local` (`ansible_connection: local`), `become: true`. `playbook.yml` applies one
role, `bootstrap`, which includes everything else, each include gated by a tag.

```
playbook.yml ── hosts: local, become: true
   └─ role: bootstrap                         (roles/bootstrap/tasks/main.yml)
        ├─ facts: os_family assert, hostname, bootstrap_local_user (whoami, tags: always),
        │         dpkg arch → bootstrap_apt_arch
        ├─ apt update/upgrade ................. tag: update
        ├─ bootstrap_packages, /etc/hosts ...... untagged (full run only)
        ├─ internal_dns / sudo / journald ...... tags: internal-dns | sudo | journald
        ├─ loop bootstrap_software_list → install_software.yml      (PATTERN A, untagged)
        │         keyring via role apt_keyring, deb822 source, one batched apt install
        └─ include_role, one tag each:                               (PATTERN B)
             libvirt · vagrant · git · docker · open_webui (open-webui) · devtools ·
             postman_cli (postman-cli) ·
             obsidian · syncthing · cleanup_legacy (cleanup-legacy, cli-tools) ·
             cli_tools (cli-tools, mise)
```

Tag reference: README "Available Tags". Do not invent tags or roles.

## Installation patterns

**(A) Vendor apt repo** — add an entry to `bootstrap_software_list` in
`roles/bootstrap/vars/main/software.yml` (`name`, `package`, `key_url`,
`key_format: ascii|gpg`, optional `key_id`, `deb822: {uris, suites, components,
architectures, append_arch_to_uri}`). `apt_keyring` rebuilds the keyring under
`/etc/apt/keyrings/<name>.gpg` each run and installs it only when bytes differ;
`deb822_repository` writes `/etc/apt/sources.list.d/<name>.sources`. Chrome's own
keyring under `/usr/share/keyrings/` is never deleted (README → APT keyrings).

**(B) Standalone role** — no apt repo:
- `obsidian`: pinned GitHub `.deb`; `dpkg-query` probe, install only on version change.
- `postman_cli`: pinned tarball → `/opt/postman-cli`, link `/usr/local/bin/postman`.
- `devtools`: Postman **desktop** app → `/opt/Postman`, link `postman-app`.
- `syncthing`: distro package + user service; `generate` once (`no_log`), then only
  GUI address/user via `community.general.xml`. Never touches device identity or pairings.
- `open_webui`: pinned image `ghcr.io/open-webui/open-webui:vX.Y.Z` via
  `community.docker` (volume + container, `127.0.0.1:3030`), depends on `docker`.
  Never touches the `brain-rag_open-webui` volume. Ops: `roles/open_webui/README.md`.
- `libvirt`, `vagrant` (depends on libvirt), `git`, `docker`, `cli_tools` (mise +
  marker-bounded `~/.bashrc` block), `cleanup_legacy` (destructive, see README).

### Adding a role

1. `roles/<name>/{tasks,defaults,meta}/main.yml` (`obsidian/` is a good template).
2. `include_role` in `roles/bootstrap/tasks/main.yml` with the tag **both** on the
   task and under `apply: tags:` — the outer tag alone makes a tagged run green
   while inner tasks silently skip.
3. `play-<name>` target pair in the `Makefile`, tag row in README "Available Tags".

### Idempotence conventions

- `changed_when: false` on probes; `failed_when: false` when absence is a normal branch.
- `check_mode: false` on facts needed under `--check` (the `whoami` task).
- `creates:` guards on non-idempotent commands; atomic write (`.new` then copy) for keyrings.
- A second run of the same scope must report `changed=0`.

## Commands

```sh
make help                        # every target
make lint                        # all pre-commit hooks on the tree
make lint-ansible                # ansible-lint only
make smoke-up / smoke-replay TAGS=<tag> / smoke-ssh / smoke-down / smoke-status
make play TAGS=<tag>             # REAL LAPTOP — owner only
```

Targets run tools as `uv run --no-sync .venv/bin/<tool>` (never a bare name from
PATH, which may be a pipx copy without the venv's collections);
`bin/check_make_venv_tools.sh` (CI) enforces it.

The smoke VM excludes the vault from rsync and stubs `vault_*` vars in
`test/smoke/Vagrantfile`; it skips the `vagrant` tag by default (nested virt).

## Secrets

- Encrypted vault `group_vars/all/vault/main.yml`; public aliases with defaults in
  `group_vars/all/vars.yml` (roles use the unprefixed names, never `vault_*`).
- `ansible.cfg` → `vault_password_file = ./bin/ansible-vault-pass.sh` → `pass show
  ansible/vault`. `.envrc` also exports `ANSIBLE_VAULT_PASSWORD` and
  `TF_VAR_github_token` from `pass` for other tools.
- `bin/check_ansible_vault.sh` (pre-commit) blocks a decrypted vault file.
- gpg "Cannot allocate memory" during a vault decrypt is an owner-side fix:
  `gpgconf --kill all`, then prime with `./bin/ansible-vault-pass.sh`.

## Conventions

- English everywhere. Conventional Commits. GitHub Flow, feature branch per change.
- Design records: ADRs in `docs/adr/`, specs and plans in `docs/superpowers/`.
  Write a spec before a non-trivial role change.
- Guides: `docs/guide-daily-usage.md`, `docs/guide-smoke-test-vagrant.md`.
