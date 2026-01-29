# Nettoyage du projet

Analyse et nettoie les fichiers orphelins et obsoletes du projet laptop-bootstrap.

**IMPORTANT** : Cette commande analyse et propose des actions. Toujours demander confirmation avant de supprimer quoi que ce soit.

---

## PHASE 1 : ANALYSE DES ROLES EXISTANTS

Lister les roles disponibles :

```bash
ls roles/
```

Stocker cette liste comme reference pour toutes les verifications.

---

## PHASE 2 : DETECTION DES INCOHERENCES

### 2.1 Roles references dans playbook.yml

Extraire les roles references dans `playbook.yml` :

```bash
grep -E "role:" playbook.yml | awk '{print $NF}'
```

Pour chaque role reference :
- Verifier si `roles/<role>/` existe
- Si non : marquer comme reference orpheline

### 2.2 Fichiers group_vars orphelins

Comparer les fichiers dans `group_vars/all/` avec les roles existants :

```bash
# Fichiers group_vars (hors main.yml)
ls group_vars/all/*.yml 2>/dev/null | grep -v main.yml

# Fichiers vault (hors main.yml)
ls group_vars/all/vault/*.yml 2>/dev/null | grep -v main.yml
```

Pour chaque fichier :
- Verifier si un role correspondant existe
- Si non : marquer comme orphelin

### 2.3 Variables dans les roles

Verifier la coherence des variables dans chaque role :

```bash
# Lister les fichiers de variables par role
for role in $(ls roles/); do
  echo "=== $role ==="
  ls roles/$role/vars/ 2>/dev/null || echo "Pas de vars/"
done
```

---

## PHASE 3 : FICHIERS TEMPORAIRES

Detecter les fichiers a nettoyer :

```bash
# Fichiers de backup
find . -name "*.bak" -o -name "*~" -o -name "*.swp" 2>/dev/null

# Fichiers __pycache__ (hors .venv et venv)
find . -path ./.venv -prune -o -path ./venv -prune -o -name "__pycache__" -type d -print 2>/dev/null

# Retry files Ansible
find . -name "*.retry" 2>/dev/null

# Fichiers .pyc (hors .venv et venv)
find . -path ./.venv -prune -o -path ./venv -prune -o -name "*.pyc" -print 2>/dev/null

# Fichiers Terraform temporaires
find github/ -name "*.tfstate.backup" 2>/dev/null
find github/ -name ".terraform.lock.hcl" 2>/dev/null
```

---

## PHASE 4 : RAPPORT D'ANALYSE

Afficher un rapport clair :

```
Analyse de nettoyage du projet
==============================

ROLES EXISTANTS
---------------
- devtools/
- docker/
- git/
- hashicorp_software/
- kubectl/
- local_laptop/
- startship/

REFERENCES ORPHELINES DANS PLAYBOOK.YML
---------------------------------------
[!] playbook.yml : example  -> role example/ ABSENT

FICHIERS GROUP_VARS ORPHELINS
-----------------------------
[!] group_vars/all/example.yml       -> role example/ ABSENT
[!] group_vars/all/vault/example.yml -> role example/ ABSENT

FICHIERS TEMPORAIRES
--------------------
[~] X fichiers .retry trouves
[~] X dossiers __pycache__ trouves

ENVIRONNEMENTS VIRTUELS
-----------------------
[~] .venv/ existe (uv)
[~] venv/ existe (ancien, a supprimer ?)

ACTIONS PROPOSEES
-----------------
1. Supprimer les references orphelines dans playbook.yml
2. Supprimer les fichiers group_vars orphelins
3. Nettoyer les fichiers temporaires
4. Supprimer l'ancien venv/ si .venv/ est utilise

Confirmer chaque action ? (oui/non)
```

---

## PHASE 5 : ACTIONS DE NETTOYAGE

**Demander confirmation explicite avant chaque action.**

### 5.1 Nettoyage playbook.yml

Supprimer les blocs de roles inexistants.

### 5.2 Suppression fichiers group_vars orphelins

```bash
# Exemple - NE PAS EXECUTER SANS CONFIRMATION
rm group_vars/all/<role>.yml
rm group_vars/all/vault/<role>.yml
```

### 5.3 Nettoyage fichiers temporaires

```bash
# Fichiers retry Ansible
find . -name "*.retry" -delete

# Cache Python (hors .venv et venv)
find . -path ./.venv -prune -o -path ./venv -prune -o -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null

# Fichiers backup
find . -name "*.bak" -delete
find . -name "*~" -delete
```

### 5.4 Nettoyage ancien venv

Si l'utilisateur confirme :

```bash
rm -rf venv/
rm -f pyvenv.cfg
```

---

## PHASE 6 : VERIFICATION POST-NETTOYAGE

Apres le nettoyage, verifier :

```bash
# Syntaxe Ansible
ansible-playbook playbook.yml --syntax-check

# Pre-commit
pre-commit run --all-files

# Terraform (si applicable)
cd github && terraform validate && cd ..
```

---

## PHASE 7 : VERIFICATION README.md

Verifier la coherence du README avec les roles existants :

### 7.1 Roles documentes

- Comparer avec les roles existants dans `roles/`
- Detecter les roles documentes mais absents

### 7.2 Structure du projet

Verifier que la section "Project Structure" est a jour :
- Les roles listes existent-ils ?
- Les fichiers documentes existent-ils ?

---

## CHECKLIST DE COHERENCE

```
[ ] Chaque role dans roles/ a une entree dans playbook.yml
[ ] Chaque fichier dans group_vars/all/ correspond a un role existant (ou est main.yml)
[ ] Chaque fichier dans group_vars/all/vault/ correspond a un role existant (ou est main.yml)
[ ] README.md correspond a l'arborescence reelle
[ ] Un seul environnement virtuel (.venv/ avec uv)
[ ] Pas de fichiers temporaires
```

---

## REGLES DE SECURITE

1. **JAMAIS supprimer sans confirmation explicite**
2. **JAMAIS supprimer les fichiers vault chiffres sans backup**
3. **Toujours verifier la syntaxe apres modification**
4. **Proposer un commit apres le nettoyage**

---

## NOTES

- Les fichiers `main.yml` ne sont jamais consideres comme orphelins
- Les fichiers dans `.venv/` et `venv/` sont ignores
- Toujours faire un `git status` avant de nettoyer
- En cas de doute, demander a l'utilisateur
