# Commit des modifications

Cree un commit Git avec un message conventionnel bien formate pour le projet laptop-bootstrap.

## Etapes

1. **Analyser les changements**
   ```bash
   git status
   git diff --stat
   git diff --staged --stat
   ```

2. **Verifier la qualite du code**
   ```bash
   pre-commit run --all-files
   ```

3. **Resoudre les erreurs** si necessaire avant de commiter

4. **Generer le message de commit**
   - Format : `type(scope): description`
   - Types :
     - `feat` : nouvelle fonctionnalite (nouveau role, nouvelle config)
     - `fix` : correction de bug
     - `infra` : changement d'infrastructure (Terraform, GitHub)
     - `config` : modification de configuration Ansible
     - `refactor` : restructuration sans changement de comportement
     - `docs` : documentation
     - `chore` : maintenance (mise a jour deps, nettoyage)
     - `security` : correctif de securite
   - Scopes (roles et modules) :
     - `local_laptop` : role principal d'orchestration
     - `docker` : installation Docker
     - `git` : configuration Git
     - `kubectl` : installation kubectl
     - `devtools` : outils de developpement (Postman, etc.)
     - `hashicorp` : Terraform et Vagrant
     - `starship` : prompt Starship
     - `github` : configuration Terraform GitHub
     - `vault` : secrets Ansible Vault
     - `deps` : dependances Python (uv, pyproject.toml)
   - Description : courte, en francais ou anglais, a l'imperatif

5. **Creer le commit**
   - Ajouter les fichiers pertinents
   - Exclure les fichiers sensibles (vault non chiffre, .env, credentials)
   - Utiliser le format avec signature Claude Code

## Format du commit

```
type(scope): description courte

Description detaillee si necessaire (optionnel)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Exemples

```
feat(docker): add Docker and Docker Compose installation

infra(github): update Terraform provider versions

fix(local_laptop): correct package installation order

config(git): update global git aliases

chore(deps): update ansible and ansible-lint versions

docs(readme): add troubleshooting section

security(vault): rotate encrypted credentials
```

## Regles

- Ne JAMAIS commiter de fichiers vault non chiffres
- Verifier que les fichiers vault sont chiffres (`$ANSIBLE_VAULT`)
- Lancer pre-commit avant de commiter si modifications importantes
- Regrouper les modifications liees dans un seul commit
- Separer les commits par role/fonctionnalite distinct
