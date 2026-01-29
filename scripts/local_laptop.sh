#!/bin/bash

# Activer le mode strict pour bash
set -euo pipefail
# Internal Field Separator (IFS).
IFS=$'\n\t'

# Déterminer le répertoire du script et le répertoire du projet
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
PROJECT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# se positionner dans le rep de travail (racine du projet)
cd "$PROJECT_DIR"

# Chemin vers l'environnement virtuel
VENV_PATH="$PROJECT_DIR/.venv"
# Liste des tags valides
readonly VALID_TAGS=("update" "install" "configure")
# Version minimum de Python requise
readonly MIN_PYTHON_VERSION="3.8"

# Fonction pour vérifier la version de Python
check_python_version() {
	local python_version
	python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')

	if ! awk -v ver="$python_version" -v min="$MIN_PYTHON_VERSION" 'BEGIN {exit (ver >= min)}'; then
		echo "Erreur: Python $MIN_PYTHON_VERSION ou supérieur est requis (version actuelle: $python_version)" >&2
		exit 1
	fi
}

# Fonction pour vérifier si un tag est valide
is_valid_tag() {
	local tag=$1
	for valid_tag in "${VALID_TAGS[@]}"; do
		if [[ $valid_tag == "$tag" ]]; then
			return 0
		fi
	done
	return 1
}

# Fonction pour afficher l'aide
show_help() {
	cat <<EOF
Usage: $(basename "$0") [options] [tag]

Description:
    Ce script configure un environnement virtuel Python, installe Ansible
    si nécessaire, et exécute un playbook Ansible avec des tags optionnels.

Options:
    -h, --help    Affiche ce message d'aide
    -v, --version Affiche la version du script
    -d, --debug   Active le mode debug

Arguments:
    tag           Tag pour filtrer l'exécution du playbook (tags valides: ${VALID_TAGS[*]})

Exemples:
    $(basename "$0") update     # Exécute le playbook avec le tag 'update'
    $(basename "$0")           # Exécute le playbook sans tags

Note:
    Assurez-vous de bien comprendre ce que fait ce script avant de l'exécuter ;-)
EOF
}

# Fonction pour nettoyer à la sortie
cleanup() {
	if [[ -n ${VIRTUAL_ENV:-} ]]; then
		deactivate 2>/dev/null || true
	fi
}

# Fonction pour gérer les erreurs
handle_error() {
	local line=$1
	local command=$2
	echo "Erreur à la ligne $line lors de l'exécution de: $command" >&2
	cleanup
	exit 1
}

# Configuration du gestionnaire d'erreurs
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR
trap cleanup EXIT

# Parsing des arguments
DEBUG=0
while [[ $# -gt 0 ]]; do
	case $1 in
	-h | --help)
		show_help
		exit 0
		;;
	-v | --version)
		echo "Version 1.0.0"
		exit 0
		;;
	-d | --debug)
		DEBUG=1
		shift
		;;
	*)
		TAG=$1
		shift
		;;
	esac
done

# Activer le mode debug si demandé
[[ $DEBUG -eq 1 ]] && set -x

# Vérifier la version de Python
check_python_version

# Créer l'environnement virtuel s'il n'existe pas
if [ ! -d "$VENV_PATH" ]; then
	echo "Création de l'environnement virtuel Python..."
	python3 -m venv "$VENV_PATH"
fi

# Activer l'environnement virtuel
# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

# Mettre à jour pip
pip install --upgrade pip

# Vérifier si Ansible est installé, l'installer si nécessaire
if ! command -v ansible-playbook &>/dev/null; then
	echo "Ansible non trouvé, installation en cours..."
	pip install ansible
fi

# Vérifier l'existence du playbook
PLAYBOOK="$PROJECT_DIR/playbook.yml"
if [ ! -f "$PLAYBOOK" ]; then
	echo "Erreur: Le fichier playbook.yml n'existe pas dans $PROJECT_DIR" >&2
	exit 1
fi

# Exécuter le playbook avec ou sans tags
if [ -n "${TAG:-}" ]; then
	if is_valid_tag "$TAG"; then
		echo "Exécution du playbook avec le tag: $TAG"
		ansible-playbook "$PLAYBOOK" --tags "$TAG"
	else
		echo "Erreur: Tag invalide '$TAG'. Tags valides: ${VALID_TAGS[*]}" >&2
		exit 1
	fi
else
	echo "Exécution du playbook sans tags"
	ansible-playbook "$PLAYBOOK"
fi
