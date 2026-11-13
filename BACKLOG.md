# Backlog — laptop-bootstrap

Open work, cleanup and deferred improvements. GitHub issues are disabled on this
repo, so this file is the single place to track them. Remove an entry once it is
done (git history keeps the trace).

Last review: 2026-11-12.

## In progress

Nothing in progress.

## Cleanup

### `.claude/commands/*.md` call bare Ansible tools
- `lint.md`, `quality.md`, `clean.md`, `update-readme.md` run `ansible-playbook`
  / `pre-commit` by bare name, which can resolve to a pipx copy without the venv's
  collections. They are synced from global commands (`/sync-commands`), so adapt
  them there or switch them to `make` targets / `uv run --no-sync .venv/bin/<tool>`.
  Source: `docs/missions/2026-11-05-make-venv-tools/`.

### Smoke VM cannot run roles that use `community.*` modules
- `test/smoke/Vagrantfile` installs the distro `ansible-core`, which ships no
  collections: `make smoke-replay TAGS=open-webui` (community.docker) and
  `TAGS=syncthing` (community.general) cannot resolve their modules in the VM.
  The open-webui mission drove the VM over SSH with the venv's Ansible instead.
  Options: install the matching collections in the VM provisioner, or run the
  replay from the host venv. Source: `docs/missions/2026-11-05-open-webui/`.

### `vagrant` role relies on the untagged run for `python3-debian`
- Its `deb822_repository` task needs `python3-debian`, installed only by the
  untagged `bootstrap_packages`; `--tags vagrant` fails on a host that never had a
  full run. The `docker` role now installs it itself. Source: `docs/missions/2026-11-05-open-webui/`.

### Smoke VM domain name is shared by every worktree
- libvirt names the VM `smoke_default` from the directory name, so a second
  worktree's `make smoke-up` collides with an existing VM. The pin-mise mission
  reused the VM by copying `test/smoke/.vagrant/`, which made `vagrant up` run the
  full provisioner (no provision sentinel) and filled the host disk. Options: a
  per-checkout `lv.default_prefix` in `test/smoke/Vagrantfile`, or document the reuse.
  Source: `docs/missions/2026-11-12-pin-mise-seed-versions/`.

## Deferred improvements

Optional; none of these blocks anything.

### CI — least-privilege `GITHUB_TOKEN`
- `ci.yml` has no `permissions:` block and the repository default workflow
  permission is `write`; `actions/checkout` keeps its default
  `persist-credentials: true`. No job runs git after checkout, so
  `permissions: contents: read` and `persist-credentials: false` would cost nothing.
- Source: `docs/missions/2026-11-05-checkout-v7/` (not a v7 change; out of that scope).

### libvirt — assert hardware KVM support
- Add an early check (e.g. `/dev/kvm` exists, `kvm_amd` or `kvm_intel` loaded)
  so the role fails fast on hosts without virtualization.
- Source: `docs/superpowers/specs/2026-04-26-libvirt-role-design.md:174`

### syncthing — declarative folders/devices and global options
- Add-only management of folders and devices through the REST API.
- Global relay / discovery / bandwidth toggles (defaults kept today).
- Source: `docs/superpowers/specs/2026-05-25-syncthing-role-design.md:254-255`

### obsidian — verify the downloaded release
- Checksum or signature verification of the `.deb` fetched from GitHub releases.
- Source: `docs/superpowers/specs/2026-05-23-obsidian-role-design.md:40`

### postman-cli — install man pages
- Source: `docs/superpowers/specs/2026-06-28-postman-cli-role-design.md:166`

### cli_tools — retry a failed first `mise install`
- The install task runs only when the seed copy reports `changed`. If it fails
  after the copy, later runs skip it and the tools stay missing; the documented
  recovery is `~/.local/bin/mise install` by hand. A retry condition (e.g. probe
  `mise ls --missing`) would make it self-healing without reconciling the config.
  Source: `docs/missions/2026-11-12-pin-mise-seed-versions/`.

### cli_tools — `kubectl-convert`
- Dropped during the mise migration (not in the mise registry). Reinstate as a
  `get_url` task in `cli_tools` only if actually needed.
- Source: `docs/adr/0001-unified-cli-tool-management-with-mise.md:65`

## Watch

### Seed pins age; kubectl follows the cluster minor
- `roles/cli_tools/files/config.toml` pins 12 tools exactly (2026-11-12). Newer
  patches already existed (uv 0.13.7, fzf 0.75.0, chezmoi 2.74.1, terraform 1.17.2,
  awscli 2.40.0); promote validated versions line by line.
- kubectl is pinned to 1.34.13 for the 1.34 clusters (`vagrant` context: server
  v1.34.3, tested; homelab `kubecluster` 1.34, dormant). Skew policy allows kubectl
  ±1 minor: move the pin when a cluster leaves 1.33-1.35. The laptop's live config
  was aligned to 1.34.13 on 2026-11-12.
  Source: `docs/missions/2026-11-12-pin-mise-seed-versions/`.

### `openwebui.internal` end to end
- Laptop side: `0.0.0.0:3030` behind a DOCKER-USER filter admitting only Caddy
  (`192.168.10.70`). Pending: owner sets Admin Settings → General → WebUI URL to
  `https://openwebui.internal` (the env var cannot override the stored empty value);
  HomeLab deploys MR !102; then HTTPS, browser login and streamed chat through Caddy.
  The upstream `192.168.10.217` relies on the router's static DHCP lease (not
  verifiable from the laptop). Source: `docs/missions/2026-11-07-open-webui-homelab-proxy/`.

### Generic PostgreSQL quarantined (`ansible-docker-apps`, not this repo)
- Container `postgresql` (5432) stopped with `restart=no` on 2026-11-07; volume
  `postgresql_postgresql-data` and `~/Workspace/07-local/postgresql/` kept.
  Unidentified clients used it in September 2026. Final deletion is an owner
  decision after the observation period (suggested 2026-12-07); criteria,
  rollback and exact commands: `docs/missions/2026-11-07-remove-caddy-postgresql/mission.md`
  → Runtime plan. Backups: `~/Backups/caddy-postgresql-2026-11-07/`.

### `ansible-docker-apps` still ships the Portainer role
- Decision D1 of `docs/missions/2026-11-07-remove-portainer/report.md`, still
  open: `roles/portainer`, `deploy_portainer: true` on its main. Its branch
  `feature/postgresql` (role never merged) stays until the owner deletes it.

### Ollama listens on every interface
- `ollama.service` drop-in sets `OLLAMA_HOST=0.0.0.0`, so the unauthenticated
  Ollama API is reachable from the LAN. Open WebUI's container needs it on the
  Docker bridge only (`172.17.0.1`); narrowing it is an owner decision (the host
  `ollama` CLI then needs `OLLAMA_HOST` too). Not managed by this repo. Source: `docs/missions/2026-11-05-open-webui/`.

### Unmanaged Open WebUI leftovers on the laptop
- Volume `brain-rag_open-webui` (1.0 G, holds a `webui.db`, compose project
  `~/Workspace/brain-rag`), image `ghcr.io/open-webui/open-webui:main`, and
  `~/Workspace/07-local/openWebUI/` (v0.8.3, no volume). The `open_webui` role
  ignores them; keep, migrate (backup/restore into `open-webui`) or delete is the
  owner's call. Source: `docs/missions/2026-11-05-open-webui/`.

### A fresh `uv sync` picks the newest Python (3.15)
- No `.python-version`; `requires-python >=3.10` lets uv choose 3.15.1, for which
  `rpds-py` 0.30.0 (via ansible-lint) has no wheel and fails to build (PyO3 max
  3.14). Existing `.venv`s (3.12) are unaffected; new worktrees need `--python`.
  Pinning or capping Python is an owner decision. Source:
  `docs/missions/2026-11-05-make-venv-tools/`.

### Ubuntu 26.04 package renames
- `qemu-kvm` became a virtual package on 26.04 (fixed in PR #53). Other
  transitional package names may disappear the same way; prefer concrete
  package names in `vars/`.
- GitHub's `ubuntu-latest` runner moves to Ubuntu 26 from 2026-10-19, so CI
  now matches the laptop's release.

### `pnpm setup` (pnpm ≥ 11) is not neutralized
- It writes `export PATH="$PNPM_HOME/bin:$PATH"` (prefix-only guard) and installs
  its own `pnpm` in `$PNPM_HOME/bin`, which would shadow mise's. The `cli_tools`
  `replace` task only rewrites the pnpm ≤ 10 `"$PNPM_HOME:$PATH"` line; README says
  not to run `pnpm setup`. Handle it in the role if it ever appears in `~/.bashrc`.
  Source: `docs/missions/2026-11-05-pnpm-global-bin-path/`.
