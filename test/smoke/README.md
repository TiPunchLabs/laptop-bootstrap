# Smoke Test — Vagrant + libvirt

Minimal harness that replays the playbook inside a clean Ubuntu VM.

## One-liner

```sh
cd test/smoke
vagrant up        # boots VM, installs ansible, runs playbook
vagrant destroy   # tear down
```

## Common overrides (env vars)

| Variable                    | Default              | Example                                        |
| --------------------------- | -------------------- | ---------------------------------------------- |
| `LAPTOP_BOOTSTRAP_BOX`      | `bento/ubuntu-24.04` | `LAPTOP_BOOTSTRAP_BOX=debian/bookworm64`       |
| `LAPTOP_BOOTSTRAP_TAGS`     | *(all)*              | `LAPTOP_BOOTSTRAP_TAGS=cleanup-legacy,cli-tools` |
| `LAPTOP_BOOTSTRAP_SKIP_TAGS`| `vagrant`            | `LAPTOP_BOOTSTRAP_SKIP_TAGS=vagrant,docker`    |
| `LAPTOP_BOOTSTRAP_VERBOSE`  | `false`              | `LAPTOP_BOOTSTRAP_VERBOSE=true`                |

## Re-running after code changes

```sh
vagrant rsync      # resync /vagrant/
vagrant provision  # re-run ansible without reboot
```

## Why `vagrant` tag is skipped by default

The `vagrant` role installs libvirt + vagrant inside the VM. Running this inside a libvirt-hosted VM requires nested virtualization, which is fragile. Keep it skipped unless explicitly testing the vagrant role.

See [`docs/guide-smoke-test-vagrant.md`](../../docs/guide-smoke-test-vagrant.md) for the full walkthrough.
