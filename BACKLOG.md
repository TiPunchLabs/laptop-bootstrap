# Backlog — laptop-bootstrap

Open work, cleanup and deferred improvements. GitHub issues are disabled on this
repo, so this file is the single place to track them. Remove an entry once it is
done (git history keeps the trace).

Last review: 2026-11-07.

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

## Deferred improvements

Optional; none of these blocks anything.

### open-webui — homelab reverse proxy `openwebui.internal`
- Belongs to the homelab (Pi-hole record, Caddy, internal TLS), not this repo.
  On the laptop side it will need: a reachable bind (`open_webui_bind_address` =
  LAN address, or a proxy on the laptop), a `WEBUI_URL` variable in `open_webui`,
  and a CORS check. Details: `roles/open_webui/README.md` → Future homelab
  integration. Source: `docs/missions/2026-11-05-open-webui/`.

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

### cli_tools — `kubectl-convert`
- Dropped during the mise migration (not in the mise registry). Reinstate as a
  `get_url` task in `cli_tools` only if actually needed.
- Source: `docs/adr/0001-unified-cli-tool-management-with-mise.md:65`

## Watch

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
