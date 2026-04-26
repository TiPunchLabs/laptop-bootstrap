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

## Post-provision assertions

After `vagrant up` completes, verify the managed shell-hooks block is in place:

```sh
vagrant ssh -c "grep -c 'ANSIBLE MANAGED: cli_tools shell hooks' ~/.bashrc"
# Expected: 2  (one BEGIN marker, one END marker)

vagrant ssh -c "sed -n '/BEGIN ANSIBLE MANAGED: cli_tools/,/END ANSIBLE MANAGED: cli_tools/p' ~/.bashrc"
# Expected: four eval lines in order — mise activate, fzf --bash, starship init, direnv hook
```
