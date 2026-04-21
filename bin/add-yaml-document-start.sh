#!/usr/bin/env bash
set -e

# Itère sur tous les arguments passés au script (les fichiers)
for file in "$@"; do
	# Ignore les fichiers dans un dossier vault à tous les niveaux
	if [[ $file =~ /vault/ ]]; then
		echo "Ignoré: $file (dans un dossier vault)"
		continue
	fi

	# Vérifie que le fichier existe et n'est pas vide
	if [[ ! -f $file || ! -s $file ]]; then
		echo "Ignoré: $file (fichier inexistant ou vide)"
		continue
	fi

	# Vérifie si c'est un fichier YAML (normalement déjà filtré par pre-commit)
	if [[ $file =~ \.ya?ml$ ]]; then
		# Vérifie si le premier non-commentaire commence par ---
		if ! grep -vE '^\s*#' "$file" | head -n 1 | grep -q '^---'; then
			echo "Ajout de '---' au début de $file"
			sed -i '1i---' "$file"
		else
			echo "Document YAML déjà correct: $file"
		fi
	fi
done
