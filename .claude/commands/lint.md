# Verification complete du code

Effectue un check complet du code suite aux modifications recentes.

## Commandes

Executer pre-commit sur tous les fichiers :

```bash
pre-commit run --all-files
```

## Outils verifies

1. **Ansible Lint** - Bonnes pratiques Ansible et syntaxe des playbooks
2. **YAML Lint** - Validation syntaxe et formatage YAML
3. **ShellCheck** - Analyse statique des scripts shell (local_laptop.sh)
4. **Terraform fmt/validate/tflint** - Formatage et validation Terraform (github/)
5. **Gitleaks** - Detection de secrets dans le code
6. **Commitizen** - Validation des messages de commit (conventional commits)
7. **check-toml** - Validation syntaxe des fichiers TOML (pyproject.toml)
8. **Vault Check** - Verification chiffrement des fichiers vault
9. **Trailing Whitespace / EOF** - Nettoyage fichiers

## Analyse des resultats

Fournis un rapport de :

- Nombre d'erreurs et warnings par outil
- Fichiers concernes
- Etat global du projet (propre et stable ou non)
- Recommandations si necessaire

## Verification manuelle supplementaire

Si besoin de verifications plus poussees :

```bash
# Validation syntaxe Ansible
ansible-playbook playbook.yml --syntax-check

# Dry run (check mode)
ansible-playbook playbook.yml --check --diff

# Liste des tags disponibles
ansible-playbook playbook.yml --list-tags

# Liste des taches
ansible-playbook playbook.yml --list-tasks

# Validation Terraform
cd github && terraform validate && cd ..

# Formatage Terraform
cd github && terraform fmt -check && cd ..
```

## Verification des fichiers vault

```bash
# Verifier que les fichiers vault sont chiffres
for f in $(find . -path "*/vault/*" -name "*.yml"); do
  head -1 "$f" | grep -q "^\$ANSIBLE_VAULT" || echo "NON CHIFFRE: $f"
done
```
