# Design — `postman_cli` role

> **Status**: Approved (brainstorming)
> **Date**: 2026-06-28
> **Author**: xgueret
> **Scope**: Add a dedicated Ansible role that installs the **Postman CLI**
> (the `postman` command-line collection runner), distinct from the Postman
> **desktop app** already installed by the `devtools` role.

------

## Mental Model

```
playbook.yml → role bootstrap
                 └── include_role postman_cli            (tag: postman-cli)
                       │
   download versioned tarball ─────────▶ /opt/postman-cli/
   https://dl-cli.pstmn.io/download/version/{{ postman_cli_version }}/linux64
                       │                   ├── postman-cli   (ELF, the real binary)
                       │                   ├── lib/          (JS app, resolved via /proc/self/exe)
                       │                   └── postman.1     (man page, not installed — YAGNI)
                       ▼
        symlink  /usr/local/bin/postman ──▶ /opt/postman-cli/postman-cli
```

------

## Problem & Context

The user wants the laptop-bootstrap project to install and configure the
**Postman CLI**. Postman does **not** ship an apt repository for the CLI; the
official method is `curl -o- "https://dl-cli.pstmn.io/install/linux64.sh" | sh`,
which downloads a `latest` tarball and copies it under `/usr/local/bin`.

Two findings shaped the design:

1. **A versioned (undocumented) download URL exists** — verified empirically:
   `https://dl-cli.pstmn.io/download/version/<X.Y.Z>/linux64` serves the exact
   requested version (e.g. `version/1.18.0/linux64` →
   `postman-cli-1.18.0-linux-x64.tar.gz`). `latest` currently resolves to
   `1.40.0`. The `v` prefix is **not** accepted (404). This makes version
   pinning possible, consistent with the `obsidian` role.

2. **Path collision with the `devtools` role** — `roles/devtools/tasks/postman.yml`
   installs the Postman **desktop GUI** and symlinks
   `/opt/Postman/Postman → /usr/local/bin/postman`. The CLI's command name is
   also `postman`. Both cannot own `/usr/local/bin/postman`. Decision: the **CLI
   owns `postman`** (its canonical name per upstream docs); the desktop symlink
   is renamed to `postman-app`. The desktop `.desktop` launcher already invokes
   `/opt/Postman/Postman` directly, so the GUI is unaffected.

3. **The binary resolves `lib/` via its real path** — verified empirically: the
   `postman-cli` ELF locates its sibling `lib/` directory through
   `/proc/self/exe` (symlink-resolved), **not** through `argv[0]`. Running it
   via a symlink in a different directory works (`postman --version` → `1.40.0`,
   exit 0). This lets us extract everything into `/opt/postman-cli/` and symlink
   the binary into `PATH`, avoiding the official script's habit of dumping a
   `lib/` directory into `/usr/local/bin/lib`.

------

## Decisions

| Question | Decision |
|---|---|
| Path collision (devtools desktop vs CLI) | CLI owns `/usr/local/bin/postman`; devtools symlink renamed to `postman-app` |
| Configuration scope | **Binary only** — no `postman login`, no API key, no vault secret |
| Integration | **Dedicated role** `postman_cli`, tag `postman-cli`, Makefile `play-postman-cli` |
| Versioning | **Pinned** via `postman_cli_version` (versioned URL confirmed to exist) |
| Architecture guard | Explicit `assert` on `amd64` — fail clean on arm64 (Postman ships `linux64` only) |

------

## Components

### 1. `roles/postman_cli/` (mirrors the `obsidian` role layout)

- **`defaults/main.yml`**
  - `postman_cli_version: "1.40.0"`
  - `postman_cli_download_url: "https://dl-cli.pstmn.io/download/version/{{ postman_cli_version }}/linux64"`
  - `postman_cli_install_dir: "/opt/postman-cli"`
  - `postman_cli_bin_link: "/usr/local/bin/postman"`
  - `postman_cli_tarball_dest: "/tmp/postman-cli-{{ postman_cli_version }}.tar.gz"`
- **`meta/main.yml`** — `galaxy_info` (Ubuntu jammy/noble, Debian bookworm/trixie), `dependencies: []`.
- **`tasks/main.yml`** — see logic below.

### 2. Edit `roles/devtools/tasks/postman.yml` (collision fix)

- Change the desktop symlink dest `/usr/local/bin/postman` → `/usr/local/bin/postman-app`.
- Add a task to remove a stale `/usr/local/bin/postman` **only if** it is a
  symlink pointing into `/opt/Postman/` (so re-running `--tags devtools` after the
  CLI is installed never clobbers the CLI). Use a `stat` + conditional `file:
  state: absent`.

### 3. Wiring

- **`roles/bootstrap/tasks/main.yml`** — new `include_role: postman_cli` block,
  placed after `devtools`, with `apply: tags: [postman-cli]` **and** an outer
  `tags: [postman-cli]` (mandatory `apply: tags` pattern — outer tag alone makes
  the include look green while inner tasks silently skip).
- **`Makefile`** — add `play-postman-cli` to the `.PHONY` list, the
  `TAGS := postman-cli` assignment, and the `play-postman-cli: play ## ...` target
  row.
- **`README.md`** — add the `postman-cli` row to the *Available Tags* table and
  list the role under *Project Structure*.

------

## Install logic (`roles/postman_cli/tasks/main.yml`)

Idempotence modeled on `obsidian` (version-gated download/install):

1. **Arch guard** — `assert` that `ansible_facts['architecture'] == 'x86_64'`,
   `msg:` explaining Postman ships `linux64` only. (Self-contained: when run via
   `--tags postman-cli`, the `bootstrap` pre-tasks that compute `bootstrap_apt_arch`
   are untagged and skip, so the role relies on the gathered fact, not that var.)
2. **Query installed version** — `stat` `<dir>/postman-cli`; only if it exists,
   run **the real binary directly** `<dir>/postman-cli --version`
   (`changed_when: false`, `failed_when: false`). **Never** probe through
   `postman_cli_bin_link`: that symlink may still point at the Postman desktop
   app (`/opt/Postman/Postman`) when this role runs before the `devtools`
   migration, and the Electron GUI ignores `--version`, opens a window and never
   exits — which hangs the play.
3. **When** the binary is absent, the probe failed, or the reported version ≠ `postman_cli_version`:
   - remove `postman_cli_install_dir` (purge stale files from any previous version),
   - recreate the directory (`mode: 0755`),
   - `get_url` the versioned tarball → `postman_cli_tarball_dest`,
   - `unarchive` (`remote_src: true`) into `postman_cli_install_dir`,
   - ensure the binary is executable (`mode: 0755` on `<dir>/postman-cli`).
4. **Always** ensure the symlink `postman_cli_bin_link → <dir>/postman-cli`
   (`state: link`, `force: true`) so the CLI deterministically owns `postman`
   regardless of which tags ran.
5. **Cleanup** — remove the downloaded tarball.

------

## Error handling

- Non-amd64 host → fail fast with a clear assert message (step 1).
- Download failure → `get_url` fails the play (no silent skip); the symlink step
  is gated on a successful extract.
- Interrupted previous run → the version probe + purge-before-extract makes the
  next run self-healing (no half-extracted dir left claiming the version).

------

## Testing

- **Smoke harness** — `make smoke-up` then `make smoke-replay TAGS=postman-cli`
  on the throwaway Vagrant+libvirt VM; assert `postman --version` reports the
  pinned version and resolves to `/usr/local/bin/postman`.
- **Idempotence** — second `--tags postman-cli` replay reports `ok`/no change
  (download + extract skipped, symlink unchanged).
- **Collision regression** — replay `--tags devtools` after `postman-cli`:
  confirm `/usr/local/bin/postman` still points at the CLI and
  `/usr/local/bin/postman-app` launches the desktop app.

------

## Non-goals (YAGNI)

- No `postman login` / API-key configuration / vault secret (config scope =
  binary only).
- No man-page install (`postman.1` left in the extract dir, not symlinked into
  `/usr/local/share/man/`). Can be added later if wanted.
- No arm64 support (upstream provides `linux64` only).

------

> **Document created on**: 2026-06-28
> **Author**: xgueret
> **Version**: 1.0
