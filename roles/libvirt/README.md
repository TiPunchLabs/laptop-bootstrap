# libvirt

Install the KVM/libvirt user stack and configure `libvirtd`:

- Packages: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `bridge-utils`, `virtinst`, `virt-manager`, `ovmf`
- Adds the bootstrapping user (`bootstrap_local_user`) to the `libvirt` and `kvm` groups
- Enables and starts the `libvirtd` service

## Requirements

- Debian 12+ / Ubuntu 22.04+
- The variable `bootstrap_local_user` must be defined (set by the `bootstrap` role)

## Dependencies

None. Consumed transitively by `roles/vagrant` via `meta/main.yml`.

## Post-install

Group membership only takes effect for **new** sessions. To pick it up in
the current shell:

```bash
newgrp libvirt
newgrp kvm
```

…or simply log out and back in.

## Example

```yaml
- hosts: localhost
  become: true
  roles:
    - role: libvirt
```
