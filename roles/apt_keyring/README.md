# apt_keyring

Keeps an apt signing keyring in sync with its upstream.

## Why

Every previous keyring implementation in this repo gated the download on
`creates:` or a `stat` of the target file. That makes the fetch a one-shot:
once the file exists it is never looked at again. The day a vendor rotates
its signing key, `apt update` starts failing with `NO_PUBKEY` and replaying
the playbook cannot fix it — the file is still there, so the task still
skips. HashiCorp rotated in September 2026 and that is exactly what happened.

This role rebuilds the keyring in a tempdir on every run and installs it only
when the bytes differ, so a rotation heals on the next replay with no
variable to edit.

## Usage

```yaml
- name: Install the HashiCorp signing key
  ansible.builtin.include_role:
    name: apt_keyring
  vars:
    apt_keyring_name: hashicorp
    apt_keyring_path: /etc/apt/keyrings/hashicorp.gpg
    apt_keyring_url: https://apt.releases.hashicorp.com/gpg
    apt_keyring_format: ascii
```

| Variable | Required | Default | Meaning |
|---|---|---|---|
| `apt_keyring_name` | yes | — | Short vendor identifier, names the staging dir |
| `apt_keyring_path` | yes | — | Where the keyring lands; what `signed_by` points at |
| `apt_keyring_url` | yes | — | URL serving the vendor key |
| `apt_keyring_format` | no | `ascii` | `ascii` for armored, `gpg` for an already dearmored keyring |
| `apt_keyring_key_id` | no | `""` | Re-export only this key id from a multi-key bundle |

The role notifies `Refresh apt cache after keyring rotation`, so a caller that
installs packages right after its own `flush_handlers` picks the new key up in
the same run.

## Guards

A download is only installed once `gpg --show-keys` confirms it holds at least
one public key, so an HTML error page or a captive-portal redirect fails the
run instead of overwriting a working keyring. When `apt_keyring_key_id` is
set, the role also asserts that id is present and fails with the rotation
hint if it is not.
