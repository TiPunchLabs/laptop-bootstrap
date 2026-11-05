# Backlog — laptop-bootstrap

Open work, cleanup and deferred improvements. GitHub issues are disabled on this
repo, so this file is the single place to track them. Remove an entry once it is
done (git history keeps the trace).

Last review: 2026-11-05.

## In progress

### Dependabot PR #45 — `actions/setup-python` 6 → 7
- **Status**: open since 2026-07-23
- **Next step**: rebase via `@dependabot rebase`, check CI, merge.

## Cleanup

### Delete `fix/pnpm-home-after-mise`
- **Status**: stale branch, local + remote
- **Context**: PR #50 was squash-merged as `5a7fcfd`; the branch tree is
  identical to that commit, but git does not see it as merged, so `-d` refuses.
- **Command**:
  `git branch -D fix/pnpm-home-after-mise && git push origin --delete fix/pnpm-home-after-mise`

## Deferred improvements

Optional; none of these blocks anything.

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

### Ubuntu 26.04 package renames
- `qemu-kvm` became a virtual package on 26.04 (fixed in PR #53). Other
  transitional package names may disappear the same way; prefer concrete
  package names in `vars/`.
- GitHub's `ubuntu-latest` runner moves to Ubuntu 26 from 2026-10-19, so CI
  now matches the laptop's release.

### `ansible.cfg` pins the venv to Python 3.12
- `collections_path = ./.venv/lib/python3.12/site-packages/ansible_collections`.
  A `.venv` built on another Python (uv picked 3.14 for a fresh worktree on
  2026-11-04) leaves the pre-commit ansible-lint hook unable to resolve
  `community.general.xml`. Workaround: `uv sync --python 3.12`. Fix if it bites
  again: pin `.python-version` or derive the path.

### `pnpm setup` (pnpm ≥ 11) is not neutralized
- It writes `export PATH="$PNPM_HOME/bin:$PATH"` (prefix-only guard) and installs
  its own `pnpm` in `$PNPM_HOME/bin`, which would shadow mise's. The `cli_tools`
  `replace` task only rewrites the pnpm ≤ 10 `"$PNPM_HOME:$PATH"` line; README says
  not to run `pnpm setup`. Handle it in the role if it ever appears in `~/.bashrc`.
  Source: `docs/missions/2026-11-05-pnpm-global-bin-path/`.
