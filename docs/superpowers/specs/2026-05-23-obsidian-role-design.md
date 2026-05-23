# Design — feat/obsidian-role

> **Status**: Approved 2026-05-23
> **Target branch**: `feat/obsidian-role`

## Problem

Obsidian is wanted on the laptop, but it does **not** fit any of the project's
existing install patterns:

- `bootstrap_software_list` (deb822) is for vendors that publish an **apt repo**
  — Obsidian has none.
- `bootstrap_packages` is for distro-repo packages — Obsidian is not in
  Debian/Ubuntu.
- `devtools/postman.yml` downloads a **tarball** into `/opt` — Obsidian ships a
  standalone `.deb` instead.

Obsidian is distributed as a single `.deb` attached to a GitHub release
(`obsidianmd/obsidian-releases`), downloaded directly. It needs its own
first-class, idempotent install path.

## Goals

- Provide a standalone `obsidian` role that installs a **pinned** version of the
  official `.deb` and is invoked by default during bootstrap.
- Be fully idempotent: a replay where the desired version is already installed
  reports **zero** `changed` tasks.
- Let dependencies be resolved by apt (use `ansible.builtin.apt: deb:`, not
  `dpkg -i`).
- Be runnable in isolation via a dedicated `obsidian` tag.

## Non-goals

- **No "latest" resolution.** The version is pinned in `defaults/` and bumped
  manually (explicit decision — reproducible, deterministic, no GitHub API
  rate-limit dependency at every run).
- **No manual `.desktop` entry / icon.** The Obsidian `.deb` ships and registers
  both itself (unlike the Postman tarball).
- **No checksum verification.** Consistent with the existing Postman download;
  fetched over HTTPS from GitHub releases. Can be added later as hardening.
- **No arm64 support.** The release publishes only an `amd64` `.deb`, which
  matches the x86 laptop target.
- **No ADR.** The change follows the existing role-per-concern pattern; no
  architectural decision worth recording.

## Architecture

One new role + one wiring edit. No new module, no new external system.

- **`roles/obsidian`** (new) owns the version check, the `.deb` download, the apt
  install, and the cleanup of the downloaded artifact.
- **`roles/bootstrap/tasks/main.yml`** invokes `obsidian` by default (always-on,
  like `docker`/`git`/`devtools`), placed near the `devtools` block.

Run order in `bootstrap/tasks/main.yml`:
`… → docker → devtools → obsidian → cleanup_legacy → cli_tools`.

```
defaults/obsidian_version (1.12.7)
        │
        ▼
[1] dpkg-query: installed version?  ──► already == 1.12.7 ? ──► no-op (0 changed)
        │ (absent or different)
        ▼
[2] get_url: download obsidian_1.12.7_amd64.deb → /tmp
        │
        ▼
[3] apt deb: <file>   (resolves deps, registers .desktop + icon)
        │
        ▼
[4] remove the downloaded .deb
```

## Component 1 — `roles/obsidian`

### Layout

```
roles/obsidian/
├── README.md
├── meta/main.yml
├── defaults/main.yml
└── tasks/main.yml
```

No `handlers/`, no `templates/`, no `files/`, no `vars/` — the role renders no
config and triggers no daemon reload. Version lives in `defaults/` (not `vars/`)
so it is overridable from `group_vars` and a bump is a one-line change.

### Defaults (`roles/obsidian/defaults/main.yml`)

```yaml
obsidian_version: "1.12.7"
obsidian_arch: "amd64"
obsidian_deb_url: >-
  https://github.com/obsidianmd/obsidian-releases/releases/download/v{{ obsidian_version }}/obsidian_{{ obsidian_version }}_{{ obsidian_arch }}.deb
obsidian_deb_dest: "/tmp/obsidian_{{ obsidian_version }}_{{ obsidian_arch }}.deb"
```

### Tasks (`roles/obsidian/tasks/main.yml`)

```yaml
- name: Query installed Obsidian version
  ansible.builtin.command:
    cmd: "dpkg-query -W -f='${Version}' obsidian"
  register: obsidian_installed
  changed_when: false
  failed_when: false

- name: Download Obsidian .deb (pinned version)
  ansible.builtin.get_url:
    url: "{{ obsidian_deb_url }}"
    dest: "{{ obsidian_deb_dest }}"
    mode: "0644"
  when: obsidian_installed.stdout | trim != obsidian_version

- name: Install Obsidian from .deb (apt resolves dependencies)
  ansible.builtin.apt:
    deb: "{{ obsidian_deb_dest }}"
    state: present
  when: obsidian_installed.stdout | trim != obsidian_version

- name: Remove downloaded .deb to keep things tidy
  ansible.builtin.file:
    path: "{{ obsidian_deb_dest }}"
    state: absent
  when: obsidian_installed.stdout | trim != obsidian_version
```

**Idempotence**: `dpkg-query` returns the installed version (`rc != 0` and empty
stdout when absent — swallowed by `failed_when: false`). The three following
tasks are gated on `installed != desired`, so a replay at the pinned version is a
clean no-op. A version bump flips the gate and re-runs the download + install.

### Meta (`roles/obsidian/meta/main.yml`)

`galaxy_info` mirroring the other roles (author, MIT, `min_ansible_version`,
Debian/Ubuntu platforms) with `dependencies: []`.

## Component 2 — `roles/bootstrap` wiring

`roles/bootstrap/tasks/main.yml` gets a new `include_role` block, mirroring the
other role blocks, placed near `devtools`:

```yaml
- name: Install Obsidian
  ansible.builtin.include_role:
    name: obsidian
    apply:
      tags:
        - obsidian
  tags:
    - obsidian
```

Targeted run: `ansible-playbook playbook.yml --tags obsidian`.

## Documentation

- `README.md` — add `obsidian/` under the `roles/` list with a one-line
  description (`Obsidian (pinned .deb from GitHub releases)`); update the ASCII
  tree.
- `roles/obsidian/README.md` — short role README following the format of
  `roles/bootstrap/README.md`. Document the version-bump workflow (edit
  `obsidian_version` in `defaults/main.yml`).

## Testing

- `pre-commit` (`ansible-lint`, `yamllint`) on the touched files.
- Smoke test via the existing `test/smoke/` Vagrant harness — replays the full
  playbook on a clean VM. Validates that:
  - the `obsidian` role installs the pinned version cleanly on a fresh host;
  - a second run reports **zero** changes (idempotence gate works);
  - `dpkg-query -W obsidian` reports the pinned version.

No new unit tests — the existing smoke harness exercises the full role chain.

## Out of scope / future work

- Optional checksum / signature verification of the downloaded `.deb`.
- "Latest" version resolution via the GitHub releases API (rejected for now;
  pinning chosen for determinism).
- arm64 asset support, should an arm64 laptop ever enter the fleet.
