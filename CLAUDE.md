# laptop-bootstrap — LLM orientation

LLM cheat-sheet for fast onboarding. The [`README.md`](README.md) is the
human-facing source of truth (full tag table, migration notes, prerequisites);
this file is the map a future Claude session reads **instead of** re-exploring
the tree. When they disagree, the code wins — update both.

> ⚠️ **Scope** — This is an **independent** Ansible project. It is **not** part of
> the "homelab trio" described in the parent
> [`../../CLAUDE.md`](../../CLAUDE.md), which explicitly declares `local/` (this
> directory) **out of scope**. Do not import homelab/GitOps/Komodo context here.

------

## What this is

Ansible playbook that provisions a personal **Debian/Ubuntu laptop** (essential
packages, vendor apps, dev/container tooling, CLI tools). Single host `local`
(`inventory.yml`: `ansible_connection: local`), run with `become: true` (root).
`playbook.yml` applies exactly **one** role — `bootstrap` — which is the
orchestrator; everything else hangs off it via `include_role`/`include_tasks`,
each gated by a tag.

## Mental Model

```
playbook.yml ── hosts: local, become: true
   └─ role: bootstrap                         (roles/bootstrap/tasks/main.yml)
        ├─ facts: os_family assert, hostname, bootstrap_local_user (whoami),
        │         dpkg arch  → bootstrap_apt_arch
        ├─ apt update/upgrade .................. tag: update
        ├─ install bootstrap_packages (essentials)
        ├─ include_tasks: update_hosts / internal_dns / sudo / journald
        │         tags: internal-dns | sudo | journald
        ├─ loop bootstrap_software_list → install_software.yml   (PATTERN A)
        │         deb822 vendor apt repos: brave, typora, nvidia-container-toolkit,
        │         dbeaver-ce, vscode(code), google-chrome, opera, trivy
        └─ include_role (each gated by its own tag):             (PATTERN B-ish)
             libvirt · vagrant · git · docker · devtools · obsidian ·
             syncthing · cleanup_legacy(+cli-tools) · cli_tools(mise, +mise)
```

Tag reference lives in README "Available Tags". Do **not** invent tags/roles not
present there. Commented-out future roles in `main.yml`: `dbeaver`,
`nvidia_container_toolkit` (the *packages* ship via Pattern A already).

------

## The two installation patterns (key reusable knowledge)

### (A) Vendor apt repo via deb822 — data-driven

Use when the vendor ships a **signed apt repository**. Add a dict entry to
`bootstrap_software_list` in `roles/bootstrap/vars/main/software.yml`; the loop
runs `roles/bootstrap/tasks/install_software.yml` per entry, then a single
`flush_handlers` + one batched `apt` install. Entry schema:

```yaml
- name: "vscode"              # logical id → keyring + .sources filename
  package: "code"             # apt package actually installed
  key_url: "https://packages.microsoft.com/keys/microsoft.asc"
  key_format: "ascii"         # "ascii" (.asc → gpg --dearmor) | "gpg" (download as-is)
  key_id: "132C13A8A330F403"  # OPTIONAL — triggers re-export of just this key id
  deb822:
    uris: "https://packages.microsoft.com/repos/code"
    suites: "stable"          # "./" or "/" for flat repos (typora, nvidia, dbeaver)
    components: ["main"]      # omit for flat repos
    architectures: ["{{ bootstrap_apt_arch }}"]   # optional; silences i386 warns
    append_arch_to_uri: true  # optional (nvidia) → appends /amd64 into the URI
```

Keyrings land in `/etc/apt/keyrings/<name>.gpg`; deb822 source in
`/etc/apt/sources.list.d/<name>.sources` (`signed_by` the keyring). The task
deletes any legacy `.list` first to avoid duplicate-source conflicts.

### (B) Standalone role — vendor without an apt repo

Use when there is no apt repo. One role per app, included from `main.yml`.

- **`obsidian`** — pinned upstream `.deb` from GitHub releases
  (`obsidian_version` in `defaults/main.yml`). Idempotence trick:
  `dpkg-query -W -f='${Version}'` (with `changed_when: false`,
  `failed_when: false`) → download + `apt deb:` + cleanup **only when** the
  installed version `!= obsidian_version`. Pure data role, `dependencies: []`.
- **`syncthing`** — distro package + systemd **user** service. Enables linger,
  resolves the user uid via `getent`, `syncthing generate` on a fresh host only
  (`creates:` + `no_log: true` because GUI creds are passed), then reconciles
  **only** GUI address/user via `community.general.xml` (needs `python3-lxml`).
  Deliberately never touches device identity or pairings.
- **`devtools`** — installs **Postman desktop GUI app** (NOT the CLI/newman):
  downloads `dl.pstmn.io/.../linux_64` tarball → `/opt/Postman`, symlinks
  `/usr/local/bin/postman`, writes a `.desktop` entry. (`tasks/postman.yml`.)

Other standalone roles: `libvirt` (KVM stack, also a `vagrant` dep),
`vagrant`, `git`, `docker` (deb822 + atomic GPG dearmor), `cli_tools`
(mise-managed user CLI tools + marker-bounded `~/.bashrc` block), `cleanup_legacy`
(evicts pre-mise installs). See README for what each ships.

------

## How to add a new role (recipe)

1. `roles/<name>/{tasks,defaults,meta}/main.yml` (copy `obsidian/` as a template).
2. Add an `include_role` block in `roles/bootstrap/tasks/main.yml`:
   ```yaml
   - name: Install <name>
     ansible.builtin.include_role:
       name: <name>
       apply:
         tags: [<tag>]      # ← REQUIRED, see gotcha
     tags: [<tag>]
   ```
3. Add the `play-<name>` target **pair** in the `Makefile`
   (`play-<name>: TAGS := <tag>` and `play-<name>: play ## ...`).
4. Add the tag row to the README "Available Tags" table.

> ⚠️ **CRITICAL gotcha** — a tag-gated `include_role`/`include_tasks` MUST repeat
> the tag via `apply: tags:` **inside** the include, not only on the outer task.
> The outer tag alone makes a tagged run report green while the inner tasks
> silently skip. Every include in `main.yml` follows this; keep the pattern.

------

## Idempotence / check-mode conventions (observed, follow them)

- `changed_when: false` on read-only commands (`whoami`, `dpkg --print-architecture`,
  `dpkg-query`, gpg probes, xml reads).
- `check_mode: false` on facts that **must** resolve under `--check` — the
  `whoami` → `bootstrap_local_user` task (`tags: always`); downstream roles
  (syncthing, paths) depend on it even in dry-run.
- `creates:` guards on non-idempotent commands (gpg dearmor, `syncthing generate`,
  `loginctl enable-linger`, Postman unarchive).
- **Atomic write dance** for GPG keys: dearmor to `<key>.gpg.new`, then
  `copy remote_src` into place, then delete staging — avoids a half-written
  keyring that `creates:` would later skip while apt chokes.
- `failed_when: false` for pure probes (installed-version query, keyring key-id
  probe) so absence is a normal branch, not a failure.
- Key-id re-export is skipped when the keyring already holds `key_id` (avoids
  4 spurious `changed` tasks per replay).

------

## Run / verify workflow

```sh
make help                       # discover every target (auto-generated)
make play                       # full playbook
make play-<role>                # e.g. make play-obsidian (single role via its tag)
make play TAGS=docker,git       # arbitrary tag combo
make lint                       # all pre-commit hooks (yamllint, shellcheck, tf, flake8…)
make lint-ansible               # ansible-lint only (fast role-edit feedback)
```

Smoke harness — replay on a **throwaway Vagrant + libvirt VM**, never your real
laptop (`test/smoke/`, design in [`docs/guide-smoke-test-vagrant.md`](docs/guide-smoke-test-vagrant.md)):

```sh
make smoke-up                   # boot + first provision
make smoke-replay [TAGS=...]    # rsync code + re-run
make smoke-down                 # destroy
```

Day-to-day edit→verify→ship loop: [`docs/guide-daily-usage.md`](docs/guide-daily-usage.md).

------

## Secrets

- Encrypted vault: `group_vars/all/vault/main.yml` (`vault_*` values).
- Public aliases in `group_vars/all/vars.yml` map `vault_*` → unprefixed names
  with `| default(...)` fallbacks so the play (and smoke harness, which excludes
  the vault from rsync) still runs without the vault. **Roles reference the
  unprefixed names**, never `vault_*` directly.
- Vault password comes from `pass` via `.envrc`:
  `export ANSIBLE_VAULT_PASSWORD=$(pass ansible/vault)`. `make vault-edit` /
  `vault-view` wrap `ansible-vault`.
- Never commit plaintext secrets. Pass secrets to tasks with `no_log: true`
  (see syncthing `generate`). A pre-commit hook (`bin/check_ansible_vault.sh`)
  fails if the vault file is left decrypted.

> 🔧 If a `make play`/pre-commit run dies with gpg "Cannot allocate memory"
> during vault decrypt: `gpgconf --kill all`, then prime with
> `./bin/ansible-vault-pass.sh`.

------

## Conventions

- **English** everywhere (code, comments, docs, commits).
- **Conventional Commits** (`feat:`, `fix:`, `chore:`…). **Never auto-commit.**
- **GitHub Flow** — every change diverging from `origin/main` lives on a feature
  branch → PR; never commit to local `main`. Use `git switch` / `git switch -c`,
  not `git checkout`.
- Design records: ADRs in [`docs/adr/`](docs/adr/) (`0001-unified-cli-tool-management-with-mise.md`);
  approved specs in [`docs/superpowers/specs/`](docs/superpowers/specs/)
  (cli-tools shell hooks, libvirt role, obsidian role, syncthing role). Write a
  spec before non-trivial role changes.
