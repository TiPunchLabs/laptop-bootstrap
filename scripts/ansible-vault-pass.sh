#!/bin/bash
# Ansible Vault password retrieval script
# Priority: ANSIBLE_VAULT_PASSWORD env var > pass password manager

if [[ -n ${ANSIBLE_VAULT_PASSWORD} ]]; then
	echo "${ANSIBLE_VAULT_PASSWORD}"
else
	pass show ansible/vault
fi
