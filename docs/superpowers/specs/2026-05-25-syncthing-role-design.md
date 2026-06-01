# Design — feat/syncthing-role

> **Status**: Approved 2026-05-25
> **Target branch**: `feat/syncthing-role`

## Problem

Syncthing is already installed on the laptop (`1.27.2~ds4`, from the Ubuntu
`universe` repo) and **actively used** — there is a live device identity and
configuration under `~/.local/state/syncthing/` (`cert.pem`/`key.pem`,
`config.xml` with paired devices and shared folders). But:

- The install is **not reproducible** — nothing in the playbook installs
  Syncthing, so a freshly provisioned laptop would lack it.
- The systemd **user** service `syncthing.service` is present but `disabled` and
  `inactive` — Syncthing is started manually, so it does **not** survive a
  reboot and is not managed declaratively.
- The GUI configuration (listen address, authentication) is set by hand.

The goal is a first-class, idempotent role that installs Syncthing, enables its
user service on boot, and manages **only** the GUI settings — **without ever
disturbing the existing device identity or pairings**.

## Goals

- Provide a standalone `syncthing` role, invoked by default during bootstrap and
  runnable in isolation via a dedicated `syncthing` tag.
- Install Syncthing from the distro repo (`apt`, idempotent).
- Enable + start the systemd **user** service with **lingering**, so it runs on
  boot without an active login session.
- Manage **only** the `<gui>` subtree of `config.xml`: listen `address` and
  authentication (`user` + `password`).
- Be fully idempotent: a replay where everything already matches reports **zero**
  `changed` tasks and never restarts a running daemon needlessly.
- Work on **both** a fresh host (no config yet) and the current host (live
  config) with identical, safe behaviour.

## Non-goals — the "don't break anything" guarantees

These are explicit, load-bearing constraints, not just omissions:

- **Never touch `cert.pem` / `key.pem`.** The device identity (and therefore the
  device ID other peers know) is preserved. `syncthing generate` runs **only**
  when `config.xml` is absent (fresh host); on the current host it never runs.
- **Never touch `<device>` / `<folder>` nodes.** All XML edits are scoped to
  `/configuration/gui/*`, so existing pairings and shared folders are untouched —
  sync from other devices keeps working.
- **Never touch relays / discovery / NAT toggles.** They stay at Syncthing's
  defaults, so remote (off-LAN) peers keep connecting.
- **Never rewrite `config.xml` wholesale** from a template — surgical node edits
  only.
- **No declarative management of folders or devices.** Out of scope by decision
  (see "Options globales uniquement" choice).
- **No `ansible-galaxy requirements.yml`.** `community.general` (12.2.0, ships the
  `xml` module) is already present in the venv.
- **No ADR.** Follows the existing role-per-concern pattern.

## Architecture

One new role + one wiring edit. No new collection, no new external system.

- **`roles/syncthing`** (new) owns: package install (root), linger enablement
  (root), and the user-scoped config + service management.
- **`roles/bootstrap/tasks/main.yml`** invokes `syncthing` by default
  (always-on, like `docker`/`obsidian`), placed near the `obsidian` block.

Run order in `bootstrap/tasks/main.yml`:
`… → obsidian → syncthing → cleanup_legacy → cli_tools`.

The package install runs as **root** (`become: true`, inherited). Everything
that touches the user's home (`~/.local/state/syncthing/`) or the user systemd
manager runs as the **deploy user** via `become_user: "{{ bootstrap_local_user }}"`
— a fact already set by the bootstrap role (`whoami` on localhost, `tags: always`).

```
[root] apt: syncthing present ──► already installed ? ──► no-op (0 changed)
        │
[root] loginctl enable-linger <user>   (guard: creates /var/lib/systemd/linger/<user>)
        │
[user] stat ~/.local/state/syncthing/config.xml
        │ absent (fresh host)            │ present (current host)
        ▼                                ▼
[user] syncthing generate          (skip generate — identity + password preserved)
       --gui-user --gui-password           │
        │ (password hashed here)           │
        └──────────────┬─────────────────┘
                       ▼
[user] read current <gui> address + user
                       ▼
        desired address == current  AND  desired user == current ? ──► no-op
                       │ (drift detected)
                       ▼
[user] systemd --user: stop syncthing   (only when an edit is needed)
                       ▼
[user] community.general.xml: set /configuration/gui/{address,user}
                       ▼
[user] systemd --user: enable + start syncthing   (idempotent)
```

## Component 1 — `roles/syncthing`

### Layout

```
roles/syncthing/
├── README.md
├── meta/main.yml
├── defaults/main.yml
└── tasks/main.yml
```

No `templates/` (no full-file render), no `files/`, no `handlers/` — the
stop/start is sequenced inline because it must bracket the edit deterministically
(a handler would fire too late, after Syncthing could re-read the file).

### Defaults (`roles/syncthing/defaults/main.yml`)

```yaml
syncthing_config_dir: "/home/{{ bootstrap_local_user }}/.local/state/syncthing"
syncthing_gui_address: "127.0.0.1:8384"   # local-only by default
syncthing_gui_user: "{{ bootstrap_local_user }}"
# syncthing_gui_password is NOT defaulted here — it lives in the vault (see below).
```

> ⚠️ **Note**: the config dir is `~/.local/state/syncthing` on this host (the
> modern XDG location used by the distro package). The role reads it from
> `syncthing_config_dir` so it can be overridden if a host uses the legacy
> `~/.config/syncthing`.

### Secrets (vault — `group_vars/all`)

`syncthing_gui_password` follows the project's public-alias-over-vault pattern: a
public alias in `group_vars/all/vars.yml`
(`syncthing_gui_password: "{{ vault_syncthing_gui_password | default('changeme') }}"`)
backed by the **ansible-vault**-encrypted `vault_syncthing_gui_password` in
`group_vars/all/vault/main.yml`. The `| default(...)` keeps the playbook runnable
when the vault is absent (the smoke harness excludes it from rsync).

**Password application (resolves the deferred hashing detail):** the password is
set **only at `syncthing generate` time on a fresh host** —
`syncthing generate --gui-password=…` writes a correct bcrypt hash. On an existing
host the password is **never touched** (no re-hash churn, no pairing risk).
Rotation is a manual action in the Syncthing GUI — out of scope for the role.

### Tasks (`roles/syncthing/tasks/main.yml`) — behaviour

1. **Install package** (root): `ansible.builtin.apt: name=syncthing state=present`
   — idempotent; reports `ok` on the current host.

2. **Resolve user uid** (for `XDG_RUNTIME_DIR`): `getent passwd` →
   `syncthing_user_uid`. Needed so user-scoped `systemctl --user` tasks can reach
   the user's systemd manager.

3. **Enable linger** (root): `loginctl enable-linger {{ bootstrap_local_user }}`
   with `creates: /var/lib/systemd/linger/{{ bootstrap_local_user }}` so it is a
   one-time, idempotent action. Lets the user service run without an active login.

4. **Stat config** (user): `ansible.builtin.stat` on
   `{{ syncthing_config_dir }}/config.xml`.

5. **Generate identity + config + credentials if absent** (user, fresh host
   only): `syncthing generate --home {{ syncthing_config_dir }}
   --gui-user={{ syncthing_gui_user }} --gui-password={{ syncthing_gui_password }}`
   with `creates: {{ syncthing_config_dir }}/config.xml` and `no_log: true`. This
   correctly bcrypt-hashes the password. On the current host this is **skipped** →
   certs, pairings, and existing password preserved.

6. **Read current GUI state** (user) via `community.general.xml` (read mode):
   current `/configuration/gui/address` text and `/configuration/gui/user` text.
   Register into facts. (The password is not read/reconciled — see step 5.)

7. **Stop service before editing** (user, scope user), **only when** the current
   address or user differs from the desired value — prevents a running daemon from
   overwriting our on-disk edit. Uses `ansible.builtin.systemd_service:
   scope=user state=stopped` with
   `environment: XDG_RUNTIME_DIR=/run/user/{{ syncthing_user_uid }}`.

8. **Apply GUI edits** (user) via `community.general.xml`, each guarded by its own
   drift check:
   - set `/configuration/gui/address` text → `syncthing_gui_address` (only when it
     differs)
   - set `/configuration/gui/user` text → `syncthing_gui_user` (only when it
     differs)
   The `<password>` node is **never** edited on an existing host.

9. **Enable + start service** (user, scope user):
   `ansible.builtin.systemd_service: scope=user name=syncthing enabled=true
   state=started` with the same `XDG_RUNTIME_DIR` env. Idempotent: a
   reboot-surviving, already-running daemon reports `ok`.

**Idempotence**: on a replay where address and user already match (the current
host's case — both already equal the defaults), steps 7–8 are skipped entirely
(no stop, no edit), and step 9 reports `ok` — **zero `changed`**, and the running
daemon is never disrupted.

### Meta (`roles/syncthing/meta/main.yml`)

`galaxy_info` mirroring the other roles (author `xgueret`, MIT,
`min_ansible_version: "2.14"`, Debian/Ubuntu platforms) with `dependencies: []`.

## Component 2 — `roles/bootstrap` wiring

`roles/bootstrap/tasks/main.yml` gets a new `include_role` block, mirroring the
others, placed right after the `obsidian` block:

```yaml
- name: Install and configure Syncthing
  ansible.builtin.include_role:
    name: syncthing
    apply:
      tags:
        - syncthing
  tags:
    - syncthing
```

> The `apply: tags:` wrapper is mandatory — without it, the outer tag gates the
> include but the role's inner tasks run untagged, making a `--tags syncthing`
> run look green while silently skipping the work.

Targeted run: `ansible-playbook playbook.yml --tags syncthing`.

## Component 3 — Makefile + README

- **`Makefile`**: add `play-syncthing` to the `.PHONY` line and the two target
  blocks, mirroring `play-obsidian` (`TAGS := syncthing` + `play` dependency +
  `## Run only the syncthing role`).
- **Top-level `README.md`**: add `syncthing/` under the `roles/` list, add it to
  the ASCII tree, and add a `syncthing` row to the "Available Tags" table.
- **`roles/syncthing/README.md`**: short role README following
  `roles/obsidian/README.md`. Documents the GUI variables, the vault password,
  the local-only-vs-LAN address choice, that the password is set only on a fresh
  host (rotation is manual in the GUI), and the explicit "never touches
  identity/pairings" guarantee.

## Testing

- `pre-commit` (`ansible-lint`, `yamllint`, vault-encryption check) on touched
  files.
- Smoke test via the existing `test/smoke/` Vagrant harness:
  `make smoke-replay TAGS=syncthing` on a clean VM. Validates that on a **fresh**
  host the role:
  - installs the package;
  - generates a fresh identity + config;
  - sets the GUI address/auth;
  - leaves the service `enabled` + `active`;
  - a second run reports **zero** changes (idempotence gate works).
- **On the real laptop** (manual, post-merge): confirm the device ID is unchanged
  (`syncthing cli show system` or compare `cert.pem` mtime) and that paired
  devices/folders are still present in the GUI after the run.

## Out of scope / future work

- Declarative management of folders/devices (add-only via REST API) — deferred.
- Global relay/discovery/bandwidth toggles — deferred; defaults kept.
- Exposing the GUI on the LAN (`0.0.0.0:8384`) — supported by the
  `syncthing_gui_address` variable but defaulted to local-only.
- TLS hardening of the GUI beyond Syncthing's self-signed default.
