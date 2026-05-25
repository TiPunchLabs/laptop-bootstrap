# syncthing

Install [Syncthing](https://syncthing.net/) from the distro repository, enable
its **systemd user service** (with lingering, so it survives reboot without an
active login), and manage **only** the web GUI settings.

## What it does — and what it never touches

Manages:

- the `syncthing` package (`apt`, idempotent);
- the systemd **user** service `syncthing.service` (enabled + started);
- the `<gui>` listen `address` and `user` in `config.xml` (surgical XML edits).

**Never touches** (so your setup keeps working):

- `cert.pem` / `key.pem` — the device identity / device ID;
- `<device>` / `<folder>` nodes — your pairings and shared folders;
- relays / discovery / NAT toggles — remote peers keep connecting;
- the GUI **password** on an existing host (see below).

`syncthing generate` runs **only** when `config.xml` is absent (a fresh host), so
on an already-configured machine the identity and pairings are preserved
untouched.

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `syncthing_config_dir` | `/home/<user>/.local/state/syncthing` | Syncthing home (XDG state dir used by the package). |
| `syncthing_gui_address` | `127.0.0.1:8384` | GUI listen address. Set `0.0.0.0:8384` to expose on the LAN (only with auth). |
| `syncthing_gui_user` | `<deploy user>` | GUI username. |
| `syncthing_gui_password` | vault (`group_vars/all`) | GUI password. Applied **only** when generating a fresh config. |

## GUI password

The password is set with a correct bcrypt hash by `syncthing generate
--gui-password` **only on a fresh host**. On an existing host the role never
re-writes it (no re-hash churn, no risk to the running config). To rotate it,
change it in the Syncthing GUI (Actions → Settings → GUI).

## Requirements

- Debian 12+ / Ubuntu 22.04+ with `systemd --user` available.
- `community.general` collection (ships the `xml` module) — already vendored.

## Dependencies

None. (Relies on `bootstrap_local_user`, set by the `bootstrap` role.)

## Example

```bash
ansible-playbook playbook.yml --tags syncthing
# or
make play-syncthing
```
