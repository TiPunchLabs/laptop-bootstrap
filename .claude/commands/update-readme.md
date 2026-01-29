# Mise a jour du README

Met a jour le README.md pour refleter l'etat actuel du projet laptop-bootstrap.

**IMPORTANT** : Toujours demander confirmation avant de modifier le README.

---

## PHASE 1 : ANALYSE DE L'ETAT ACTUEL

### 1.1 Lister les roles existants

```bash
ls roles/
```

### 1.2 Lire la configuration actuelle

Analyser les fichiers de variables des roles :

```bash
# Variables par role
for role in $(ls roles/); do
  echo "=== $role ==="
  ls roles/$role/vars/ 2>/dev/null
done
```

### 1.3 Lire les tags disponibles

```bash
ansible-playbook playbook.yml --list-tags
```

---

## PHASE 2 : SECTIONS A METTRE A JOUR

### 2.1 Section "Roles disponibles"

Mettre a jour le tableau des roles :

```markdown
| Role | Description | Tags |
|------|-------------|------|
| local_laptop | Configuration systeme et packages | update, install, configure |
| docker | Docker et Docker Compose | docker |
| git | Configuration Git globale | git |
| kubectl | Installation kubectl | kubectl |
| devtools | Outils de developpement | devtools |
| hashicorp_software | Terraform et Vagrant | hashicorp |
| startship | Prompt Starship | starship |
```

**Regles :**
- Lister UNIQUEMENT les roles existants dans `roles/`
- Description basee sur les taches du role
- Tags extraits du playbook.yml

### 2.2 Section "Prerequis"

Verifier que les prerequis sont a jour :
- Version Python minimale
- Dependances (uv, direnv)
- Systeme d'exploitation (Debian/Ubuntu)

### 2.3 Section "Installation"

Mettre a jour les commandes d'installation :

```bash
# Cloner le repo
git clone <repo-url>
cd laptop-bootstrap

# Installer les dependances avec uv
uv sync

# Ou utiliser direnv
direnv allow

# Executer le playbook
./local_laptop.sh install
```

### 2.4 Section "Structure du projet"

Mettre a jour l'arborescence pour refleter les roles actuels :

```
laptop-bootstrap/
├── ansible.cfg
├── inventory.yml
├── playbook.yml
├── local_laptop.sh
├── pyproject.toml
├── uv.lock
├── .envrc
├── .pre-commit-config.yaml
├── roles/
│   ├── local_laptop/
│   ├── docker/
│   ├── git/
│   ├── kubectl/
│   ├── devtools/
│   ├── hashicorp_software/
│   └── startship/
├── group_vars/
│   └── all/
│       └── vault/
└── github/              # Terraform pour GitHub
```

### 2.5 Section "Utilisation"

Mettre a jour les commandes disponibles :

```bash
# Mise a jour systeme
./local_laptop.sh update

# Installation complete
./local_laptop.sh install

# Configuration uniquement
./local_laptop.sh configure

# Role specifique
ansible-playbook playbook.yml --tags docker
```

---

## PHASE 3 : RAPPORT DES MODIFICATIONS

Afficher un rapport clair avant modification :

```
Modifications proposees pour README.md
======================================

SECTION "Roles disponibles"
---------------------------
- Roles actuels : devtools, docker, git, hashicorp_software, kubectl, local_laptop, startship

SECTION "Structure du projet"
-----------------------------
- Mise a jour de l'arborescence

SECTION "Installation"
----------------------
- Commandes uv au lieu de pip

Confirmer les modifications ? (oui/non)
```

---

## PHASE 4 : APPLICATION DES MODIFICATIONS

**Demander confirmation explicite avant chaque section modifiee.**

### 4.1 Ordre des modifications

1. Section "Description/Overview"
2. Section "Prerequis"
3. Section "Installation"
4. Section "Utilisation"
5. Section "Roles disponibles"
6. Section "Structure du projet"
7. Section "Configuration" (group_vars, vault)

### 4.2 Conserver le style

- Garder le formatage Markdown
- Garder la structure des sections
- Ne pas modifier les sections non impactees (Contributing, License, etc.)

---

## PHASE 5 : VERIFICATION

Apres modification :

1. Verifier que le README est valide (pas de liens casses)
2. Verifier la coherence globale
3. Proposer un commit :

```
docs(readme): update documentation to match current state

- Update roles list
- Update installation instructions for uv
- Update project structure
```

---

## NOTES

- Ne jamais supprimer les sections generiques (Contributing, License, Author)
- Conserver le style et le ton du README existant
- Privilegier la modification a la reecriture complete
- En cas de doute, demander a l'utilisateur
