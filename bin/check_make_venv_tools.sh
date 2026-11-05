#!/usr/bin/env bash
# Regression check: the Makefile targets and the ansible-lint pre-commit hook must
# run the project's .venv tools, never a same-named binary found first on PATH
# (e.g. a pipx ansible-lint or ansible that cannot see the venv's collections).
# Needs a synced .venv and ANSIBLE_VAULT_PASSWORD_FILE (a dummy file is enough).
set -euo pipefail

cd "$(dirname "$0")/.."
tools="ansible ansible-config ansible-galaxy ansible-lint ansible-playbook ansible-vault pre-commit"
run="uv run --no-sync .venv/bin"

# Static: `make -n` only prints the recipes, it runs nothing (no laptop, no vault).
# Each tool word must be the command of a `uv run --no-sync .venv/bin/<tool>` call,
# and each target must contain at least one such call.
status=0
for target in play uninstall-opera lint lint-ansible vault-edit vault-view clean; do
	recipe=$(make -n --no-print-directory "$target")
	found=0
	while IFS= read -r line; do
		read -ra words <<<"$line"
		for i in "${!words[@]}"; do
			tool=${words[i]##*/}
			case " $tools " in
			*" $tool "*) ;;
			*) continue ;;
			esac
			if [ "$i" -ge 3 ] && [ "${words[*]:i-3:4}" = "$run/$tool" ]; then
				found=1
			else
				echo "make $target: '${words[i]}' is not called as '$run/$tool': $line" >&2
				status=1
			fi
		done
	done <<<"$recipe"
	if [ "$found" -eq 0 ]; then
		echo "make $target: no '$run/<tool>' call" >&2
		status=1
	fi
done
[ "$status" -eq 0 ] || exit 1

# Runtime: failing decoys first on PATH, the real .venv/bin after them (the shape
# of a shell where ~/.local/bin precedes an activated venv). The read-only lint
# entry points must pass without ever reaching a decoy.
decoys=$(mktemp -d)
trap 'rm -r -- "$decoys"' EXIT
for tool in $tools; do
	printf '#!/bin/sh\necho "decoy %s from PATH ran instead of .venv/bin/%s" >&2\nexit 97\n' \
		"$tool" "$tool" >"$decoys/$tool"
	chmod +x "$decoys/$tool"
done
export PATH="$decoys:$PWD/.venv/bin:$PATH"
unset VIRTUAL_ENV

make --no-print-directory lint-ansible
.venv/bin/pre-commit run ansible-lint --all-files
echo "OK: Makefile targets and the ansible-lint hook use .venv/bin"
