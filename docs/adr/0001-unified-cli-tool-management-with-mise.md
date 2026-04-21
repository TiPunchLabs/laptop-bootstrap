# ADR-0001: Unified CLI tool management with mise

- **Status**: Accepted
- **Date**: 2026-04-19
- **Deciders**: @xgueret

------

## Context

The `laptop-bootstrap` project installs CLI tools through four different mechanisms:

| Mechanism         | Tools concerned                                      | Role                   |
| ----------------- | ---------------------------------------------------- | ---------------------- |
| `apt` (Ubuntu)    | `fzf`, `direnv`                                      | `bootstrap_packages`   |
| `apt` (third-party repo) | `terraform`, `vagrant` (HashiCorp), `kubectl` (Kubernetes) | `hashicorp_software`, `kubectl` |
| Upstream install script | `starship`, `uv`                               | `starship`, previous `cli_tools` draft |
| Manual binary unpack | `aws-cli` v2                                     | `devops`               |

This fragmentation causes real pain:

- **Versioning drift** — `apt` ships whatever Ubuntu packaged (often stale), install scripts always pull the latest, manual binaries freeze at install time. No single place defines "what version of what is installed here."
- **PATH ambiguity** — the same binary may exist in `/usr/bin`, `/usr/local/bin`, and `~/.local/bin`. `which terraform` becomes unpredictable after migration.
- **Cleanup cost** — removing a tool means hunting down the right mechanism: apt repo file, GPG key, install-dir symlink, `~/.local/bin` binary.
- **Per-tool Ansible boilerplate** — every new tool duplicates the same pattern (fetch latest version from GitHub API, compare, download, install). Each role reimplements version management.

The draft `cli_tools` role (`docs/superpowers/plans/2026-04-17-cli-tools-role.md`) proposed combining apt + install scripts for eight tools. It improved organisation but perpetuated the same structural problem: *N* installation mechanisms for *N* tools.

------

## Decision

**We adopt [`mise`](https://mise.jdx.dev/) as the single tool manager for user-space CLI tooling, declared in `~/.config/mise/config.toml`.**

Scope:

- **In scope (mise-managed):** `uv`, `fzf`, `direnv`, `zoxide`, `eza`, `bat`, `chezmoi`, `starship`, `kubectl`, `terraform`, `awscli`.
- **Out of scope (system-managed):** `vagrant`.
  - Vagrant depends on the `vagrant-libvirt` gem plugin, which links against `libvirt-dev` system headers. The plugin is installed via `vagrant plugin install` and resolves the `vagrant` binary through system `PATH`. Using a mise-shimmed `vagrant` breaks plugin discovery and complicates the libvirt group membership model. Keeping vagrant on the HashiCorp apt repo keeps the plugin + `libvirt` group wiring stable.

The `hashicorp_software` role is therefore renamed to `vagrant`, since terraform moves out to mise and only vagrant-plus-libvirt remains.

------

## Consequences

### Positive

- **One source of truth**: `~/.config/mise/config.toml` declares every tool version. `mise ls` shows the full inventory.
- **Uniform upgrades**: `mise upgrade` replaces every custom `uri | from_json | version is version(...)` block that each role had to reinvent.
- **Shell hooks simplification**: a single `eval "$(mise activate bash)"` replaces the per-tool `direnv hook`, `zoxide init`, `starship init` lines.
- **Trash-friendly cleanup**: removing a tool is a single TOML edit + `mise prune`.
- **Project-local overrides** become possible (per-repo `.mise.toml`) without re-running Ansible.

### Negative

- **New dependency on mise itself**. Must be installed via its upstream script (bootstrap-of-the-bootstrap). Mitigation: mise is a single static binary with a stable install.sh, and this is the only remaining install-script in the project.
- **Shell startup cost**: `mise activate` adds ~10 ms to interactive shells. Acceptable on a laptop.
- **Shims vs PATH**: mise uses shims by default. Scripts that hard-code `/usr/bin/terraform` will break. Audit required on existing scripts and CI.
- **Debugging indirection**: `which terraform` now returns a shim path. `mise which terraform` gives the real path.

### Neutral

- Vagrant stays on apt — intentional asymmetry, documented here to prevent "let's move it too" churn later.
- `kubectl-convert` is not in the mise registry and is dropped. If needed later, reinstate as a `get_url` task inside `cli_tools`.

------

## Alternatives considered

### A. Keep the current per-tool mechanisms, just consolidate roles

- **Why rejected**: addresses organisation but not the core fragmentation. Still *N* mechanisms for *N* tools. The draft `cli_tools` plan (apt + install scripts mixed) embodied this, and the version-drift / cleanup pain remained.

### B. `asdf` instead of mise

- **Why rejected**: mise is a drop-in superset of asdf with a faster Rust core, native Taskfile support, `.envrc`-like env handling (redundant with direnv but harmless), and a larger built-in registry. No behavioural gap versus asdf.

### C. Nix / home-manager

- **Why rejected**: much larger blast radius. Forces the whole user environment into Nix. Team has no Nix expertise. Overkill for "I want pinned CLI versions."

### D. Migrate *everything* including vagrant to mise

- **Why rejected**: breaks `vagrant-libvirt` plugin discovery and the `libvirt` group workflow. The coupling with system libraries and the libvirtd daemon makes vagrant system-native, not user-space.

------

## Cleanup required (migration side-effects)

Because several tools were previously installed by other means, the migration must actively remove stale artifacts to avoid PATH ambiguity:

- `apt` packages: `fzf`, `bat`, `direnv`, `eza`, `kubectl`, `terraform`
- `apt` repositories + GPG keys: Kubernetes (HashiCorp is kept — still used by vagrant)
- Binaries under `/usr/local/bin/`: `starship`, `aws`, `aws_completer`, `kubectl-convert`
- `/usr/local/aws-cli/` directory
- `~/.local/bin/uv` (from the old `uv` install script, if present before the mise-managed version takes over)

This cleanup is implemented in a dedicated `cleanup_legacy` Ansible role, ordered **before** `cli_tools` in the bootstrap play.

### Operational migration steps

On a pre-mise laptop, the two tags must be run back-to-back in order:

```sh
uv run ansible-playbook playbook.yml --tags cleanup-legacy
uv run ansible-playbook playbook.yml --tags cli-tools
exec bash
```

- **Transition window**: between the two tag runs, `starship`, `direnv`, `uv`, `eza`, `bat`, `fzf`, `kubectl`, `terraform` are uninstalled and not yet reinstalled. Any shell or tooling that depends on them will fail during that gap. Do not interleave other work.
- **`exec bash` is mandatory**: `cli_tools` writes `eval "$(mise activate bash)"` into `~/.bashrc`. The running shell keeps the old `PATH` (including `/usr/local/bin` where stale binaries may still live on partially-cleaned systems) until the rc file is re-sourced. `exec bash` replaces the current shell in place — opening a new terminal is equivalent.

------

## References

- mise home: <https://mise.jdx.dev/>
- Implementation plan: `docs/superpowers/plans/2026-04-17-cli-tools-role.md`
