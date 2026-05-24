# laptop-bootstrap — daily-use targets.
# `make help` lists all targets. Add new ones with a `## description`
# trailing comment so they auto-register in help output.

SHELL := /usr/bin/env bash

PLAYBOOK  ?= playbook.yml
INVENTORY ?= inventory.yml
VAULT     ?= group_vars/all/vault/main.yml
TAGS      ?=
SMOKE_DIR ?= test/smoke

# Deferred (=) so target-specific `TAGS := ...` assignments propagate.
ANSIBLE_FLAGS = $(if $(strip $(TAGS)),--tags $(TAGS),)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS=":.*?## "; printf "Usage: make <target>\n\nTargets:\n"} \
		/^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables: TAGS (e.g. make play TAGS=cli-tools,docker)"

# ——— Playbook ———

.PHONY: play
play: ## Run the full playbook (use TAGS=... to scope)
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK) $(ANSIBLE_FLAGS)

.PHONY: play-cli-tools play-docker play-git play-vagrant play-devtools play-cleanup-legacy play-obsidian
play-cli-tools:      TAGS := cli-tools
play-docker:         TAGS := docker
play-git:            TAGS := git
play-vagrant:        TAGS := vagrant
play-devtools:       TAGS := devtools
play-cleanup-legacy: TAGS := cleanup-legacy
play-obsidian:       TAGS := obsidian
play-cli-tools:      play ## Run only the cli_tools role
play-docker:         play ## Run only the docker role
play-git:            play ## Run only the git role
play-vagrant:        play ## Run only the vagrant role
play-devtools:       play ## Run only the devtools role
play-cleanup-legacy: play ## Run only the cleanup_legacy role
play-obsidian:       play ## Run only the obsidian role

# ——— Lint ———

.PHONY: lint lint-ansible
lint: ## Run all pre-commit hooks on the whole tree
	pre-commit run --all-files

lint-ansible: ## Run ansible-lint only
	ansible-lint

# ——— Smoke test (Vagrant + libvirt) ———

.PHONY: smoke-up smoke-replay smoke-ssh smoke-down smoke-status
smoke-up: ## Boot the smoke VM (first-time create, or after destroy)
	cd $(SMOKE_DIR) && vagrant up

smoke-replay: ## rsync code + replay playbook on smoke VM (use TAGS=...)
	cd $(SMOKE_DIR) && vagrant rsync && LAPTOP_BOOTSTRAP_TAGS=$(TAGS) vagrant provision

smoke-ssh: ## SSH into the smoke VM
	cd $(SMOKE_DIR) && vagrant ssh

smoke-down: ## Destroy the smoke VM
	cd $(SMOKE_DIR) && vagrant destroy -f

smoke-status: ## Show the smoke VM state
	cd $(SMOKE_DIR) && vagrant status

# ——— Vault ———

.PHONY: vault-edit vault-view
vault-edit: ## Edit the encrypted vault file
	ansible-vault edit $(VAULT)

vault-view: ## View the encrypted vault file
	ansible-vault view $(VAULT)

# ——— Cleanup ———

.PHONY: clean
clean: ## Remove retry files and local ansible/pre-commit caches
	find . -name '*.retry' -delete
	rm -rf .ansible/tmp .ansible/cp
	pre-commit clean >/dev/null 2>&1 || true
