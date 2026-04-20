#!/usr/bin/env bash
# Retrieves the Ansible vault password from `pass` (password-store).
# Override the entry path via the ANSIBLE_VAULT_PASS_PATH env var.
set -euo pipefail
pass show "${ANSIBLE_VAULT_PASS_PATH:-ansible/vault}"
