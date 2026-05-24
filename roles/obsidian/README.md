# obsidian

Install [Obsidian](https://obsidian.md/) from the official upstream `.deb`
attached to the GitHub releases of `obsidianmd/obsidian-releases`.

There is **no upstream apt repository**, so the version is pinned and the `.deb`
is downloaded directly. Dependencies are resolved by apt (`ansible.builtin.apt:
deb:`), not `dpkg -i`. The `.deb` registers its own `.desktop` entry and icon.

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `obsidian_version` | `1.12.7` | Pinned Obsidian version (without the `v` prefix). |
| `obsidian_arch` | `amd64` | Debian architecture of the asset (only `amd64` is published upstream). |
| `obsidian_deb_url` | derived | Full GitHub release download URL. |
| `obsidian_deb_dest` | `/tmp/obsidian_<version>_<arch>.deb` | Local download path. |

## Upgrading

Bump `obsidian_version` in `defaults/main.yml`, then re-run:

```bash
ansible-playbook playbook.yml --tags obsidian
```

The role compares the installed version (`dpkg-query`) to the pinned one and only
downloads + installs when they differ — a replay at the pinned version is a no-op.

## Requirements

- Debian 12+ / Ubuntu 22.04+ (`amd64`)

## Dependencies

None.

## Example

```yaml
- hosts: localhost
  become: true
  roles:
    - role: obsidian
```
