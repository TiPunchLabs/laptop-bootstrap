# Synchroniser les commandes Claude

Meta-commande pour mettre a jour les commandes `.claude/commands/` d'un projet en s'inspirant d'un projet source de reference.

## Argument

$ARGUMENTS : Chemin vers le projet cible (optionnel, defaut: projet courant)

---

## PROMPT REUTILISABLE

Copier ce prompt pour l'utiliser sur d'autres projets :

```

En t'inspirant des commandes du projet source `/home/xgueret/Workspace/01-projets/pwa/good-points/.claude/commands`, mets a jour le dossier `.claude/commands/` du projet courant.


## INSTRUCTIONS


### PHASE 1 : ANALYSE DU PROJET SOURCE (Reference)


1. Lister les commandes dans le projet source :

```

   ls /home/xgueret/Workspace/01-projets/pwa/good-points/.claude/commands/

```


2. Lire chaque commande pour comprendre :

   - Le pattern de structure (sections, format)

   - Les types de commandes (validation, commit, quality, deploy, etc.)

   - Le style d'ecriture (langue, ton, niveau de detail)


### PHASE 2 : ANALYSE DU PROJET CIBLE


1. Identifier le type de projet :

   - Stack technique (lire package.json, pyproject.toml, requirements.txt, go.mod, Cargo.toml, etc.)

   - Framework principal

   - Outils de build/test/lint configures


2. Analyser la structure :

   - Arborescence des dossiers

   - Fichiers de configuration

   - Pre-commit hooks (.pre-commit-config.yaml)

   - Documentation existante (README, CLAUDE.md)


3. Identifier les workflows existants :

   - Comment valider le code ?

   - Comment deployer ?

   - Comment tester ?

   - Quelles conventions de commit ?


### PHASE 3 : MAPPING DES COMMANDES


Creer un tableau de correspondance :


| Commande source | Applicable ? | Adaptation necessaire |

|-----------------|--------------|----------------------|

| lint.md | Oui/Non | Description |

| commit.md | Oui/Non | Description |

| quality.md | Oui/Non | Description |

| ... | ... | ... |


Regles de mapping :

- `lint.md` -> Adapter aux linters du projet (eslint, pylint, golint, ansible-lint, etc.)

- `commit.md` -> Adapter les types de commit au domaine

- `quality.md` -> Adapter les metriques et outils

- `deploy.md` -> Adapter au workflow de deploiement

- `implement.md` -> Adapter au pattern d'implementation


### PHASE 4 : GENERATION DES COMMANDES


Pour chaque commande a creer :


1. Conserver la structure du template source

2. Remplacer les outils specifiques :

   - pnpm -> npm/yarn/pip/go/cargo/terraform/ansible selon le projet

   - ESLint -> linter du projet

   - TypeScript -> langage du projet

   - etc.


3. Adapter les sections :

   - Commandes bash reelles et testables

   - Chemins de fichiers corrects

   - Conventions du projet


4. Ajouter des commandes specifiques au domaine si necessaire


### PHASE 5 : NETTOYAGE


1. Supprimer les anciennes commandes non adaptees

2. Verifier la coherence entre les commandes

3. S'assurer que chaque commande est autonome et executable


### PHASE 6 : RAPPORT


Afficher un resume :

- Commandes creees/mises a jour

- Commandes supprimees

- Commandes specifiques ajoutees


## TYPES DE PROJETS SUPPORTES


### Frontend (React, Vue, Angular, Svelte)

- validate.md : eslint, typescript, build

- commit.md : feat/fix/refactor/style/docs

- quality.md : lint, types, tests, coverage

- deploy.md : build, preview, production


### Backend (Node, Python, Go, Rust)

- validate.md : lint, types, tests

- commit.md : feat/fix/refactor/perf/docs

- quality.md : lint, tests, coverage, security

- deploy.md : build, migrate, deploy


### Infrastructure (Terraform, Ansible, Kubernetes)

- validate.md : fmt, validate, lint

- commit.md : infra/config/feat/fix/docs

- quality.md : validation, security, documentation

- deploy.md : plan, apply, configure


### Mobile (React Native, Flutter, Swift, Kotlin)

- validate.md : lint, types, build

- commit.md : feat/fix/refactor/ui/docs

- quality.md : lint, tests, build

- deploy.md : build, test, release


### Data/ML (Python, Jupyter, R)

- validate.md : lint, types, notebooks

- commit.md : feat/fix/data/model/docs

- quality.md : lint, tests, data validation

- deploy.md : train, evaluate, deploy


## EXEMPLE D'EXECUTION


Pour un projet Python FastAPI :


1. Detecte : Python, FastAPI, pytest, black, mypy, pre-commit

2. Cree :

   - validate.md : black --check, mypy, pytest

   - commit.md : types Python (feat, fix, api, db, etc.)

   - quality.md : scoring black/mypy/pytest/coverage

   - deploy.md : docker build, migrate, deploy

   - test.md : pytest avec options

```

---

## NOTES

- Toujours analyser le projet AVANT de generer les commandes
- Ne pas copier betement : ADAPTER au contexte
- Privilegier les outils deja configures dans le projet
- Garder le meme style que le projet source (langue, format)
- Les commandes doivent etre executables immediatement
