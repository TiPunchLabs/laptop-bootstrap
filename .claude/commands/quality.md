# Analyse Qualite Infrastructure

Commande d'analyse de qualite pour le projet laptop-bootstrap (Ansible/Terraform).

## Arguments

| Argument | Description |
|----------|-------------|
| (aucun) | Analyse complete du projet |
| `<role>` | Analyse ciblee sur un role specifique |
| `--fix` | Analyse + corrections automatiques |

---

## PHASE 1 : ANALYSE DE LA STRUCTURE

### 1.1 Verification de l'arborescence

Scanner la structure du projet et verifier :
- Presence des fichiers essentiels (playbook.yml, inventory.yml, ansible.cfg)
- Structure des roles (tasks/, vars/, templates/, handlers/)
- Configuration des variables (group_vars/)
- Documentation (README.md)

### 1.2 Configuration des outils

Verifier la presence et configuration de :
- `.pre-commit-config.yaml` : hooks de qualite
- `ansible.cfg` : configuration Ansible
- `pyproject.toml` : dependances Python (gere par uv)
- `.envrc` : configuration direnv pour uv

---

## PHASE 2 : ANALYSE QUALITE TECHNIQUE

### 2.1 Executer les linters

```bash
# Pre-commit (tous les hooks)
pre-commit run --all-files

# Validation syntaxe Ansible
ansible-playbook playbook.yml --syntax-check
```

### 2.2 Verification des roles

Pour chaque role dans `roles/` :

| Element | Verification |
|---------|--------------|
| **tasks/main.yml** | Existe et syntaxe valide |
| **vars/main.yml** ou **vars/main/** | Variables documentees |
| **templates/** | Templates Jinja2 valides (si present) |
| **handlers/** | Handlers definis si necessaire |
| **defaults/** | Valeurs par defaut (optionnel) |

Roles existants :
- `local_laptop` : role principal d'orchestration
- `docker` : installation Docker et Docker Compose
- `git` : configuration Git globale
- `kubectl` : installation kubectl
- `devtools` : outils de developpement
- `hashicorp_software` : Terraform et Vagrant
- `startship` : prompt Starship

### 2.3 Analyse de securite

| Dimension | Elements verifies |
|-----------|-------------------|
| **Vault** | Fichiers sensibles chiffres (`$ANSIBLE_VAULT`) |
| **Secrets** | Pas de mots de passe en clair dans le code |
| **Permissions** | Fichiers sensibles avec droits restreints |

### 2.4 Bonnes pratiques Ansible

- [ ] Utilisation de FQCN (Fully Qualified Collection Names)
- [ ] Pas de `command`/`shell` quand un module existe
- [ ] Handlers pour les redemarrages de services
- [ ] Variables avec prefixe du role
- [ ] Idempotence des taches

---

## PHASE 3 : SCORING ET RAPPORT

### Systeme de scoring

| Categorie | Poids | Criteres |
|-----------|-------|----------|
| Linters | 30% | ansible-lint, yamllint, shellcheck |
| Structure | 25% | Arborescence, fichiers requis |
| Securite | 25% | Vault, secrets, permissions |
| Documentation | 20% | README, commentaires, vars documentees |

### Format de sortie console

```
Rapport Qualite Infrastructure
================================

Projet : laptop-bootstrap
Analyse : {date}
Score global : {X}/100

+---------------------------------------------------------------+
| LINTERS (30%)                                     Score: X/30 |
+---------------------------------------------------------------+
| ansible-lint : X erreurs, Y warnings                          |
| yamllint     : X erreurs, Y warnings                          |
| shellcheck   : X erreurs, Y warnings                          |
| terraform    : X erreurs, Y warnings                          |
+---------------------------------------------------------------+

+---------------------------------------------------------------+
| STRUCTURE (25%)                                   Score: X/25 |
+---------------------------------------------------------------+
| Roles complets     : X/7                                      |
| Fichiers manquants : [liste]                                  |
| Arborescence       : Conforme / Non conforme                  |
+---------------------------------------------------------------+

+---------------------------------------------------------------+
| SECURITE (25%)                                    Score: X/25 |
+---------------------------------------------------------------+
| Fichiers vault     : X/Y chiffres                             |
| Secrets en clair   : X detectes                               |
| Permissions        : OK / A corriger                          |
+---------------------------------------------------------------+

+---------------------------------------------------------------+
| DOCUMENTATION (20%)                               Score: X/20 |
+---------------------------------------------------------------+
| README.md          : Present / Absent                         |
| Variables doc      : X/Y documentees                          |
| Commentaires       : Suffisant / Insuffisant                  |
+---------------------------------------------------------------+

================================================================

ACTIONS PRIORITAIRES
--------------------
1. [CRITIQUE] ...
2. [IMPORTANT] ...
3. [MINEUR] ...

================================================================
```

---

## PHASE 4 : MODE --fix

Si `--fix` est passe, appliquer les corrections automatiques :

### Corrections automatiques

```bash
# Formatage YAML
pre-commit run yamllint --all-files

# Formatage Terraform
cd github && terraform fmt && cd ..

# Corrections trailing whitespace
pre-commit run trailing-whitespace --all-files
pre-commit run end-of-file-fixer --all-files
```

### Corrections manuelles suggerees

1. Chiffrer les fichiers vault non chiffres
2. Ajouter les handlers manquants
3. Completer la documentation des variables

### Jamais corrige automatiquement

- Logique des playbooks
- Architecture des roles
- Suppression de code fonctionnel

---

## CHECKLIST ROLES

Pour chaque role, verifier :

```
roles/<role_name>/
  tasks/
    main.yml        # Taches principales
  vars/
    main.yml ou main/  # Variables (documentees)
  templates/        # Templates Jinja2 (si besoin)
  handlers/         # Handlers (si besoin)
  defaults/         # Valeurs par defaut (optionnel)
  files/            # Fichiers statiques (optionnel)
```

---

## NOTES

- Toujours verifier le vault avant de commiter
- Prioriser les erreurs de securite
- La documentation est essentielle pour la maintenabilite
- Tester les playbooks en mode check avant apply
