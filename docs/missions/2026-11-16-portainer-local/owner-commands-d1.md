# Owner commands — D1 (Portainer admin from a vault bcrypt hash), laptop LAN exposure

Mission 2026-11-16-portainer-local. Code: commit 21b839f4c8548dcbaa067265b8bfda2d3511ee27
(branch feat/portainer-local). These commands are run by the owner, on the laptop,
from the worktree. Report back only the outputs marked "REPORT". Never paste the
password, the hash, or the vault content.

Current laptop state (2026-11-16): `portainer` on 127.0.0.1:9443, no admin. Its
setup window has timed out (`/api/users/admin/check` answers 303). This is
harmless: the apply below stops it, creates the admin on `portainer_data` with a
one-shot `portainer-bootstrap` container (no published port, removed at once), then
starts `portainer` again on 0.0.0.0:9443. The real container never receives the hash.

## 0. Go to the worktree

```bash
cd /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/portainer
git log --oneline -1          # REPORT: 7-char SHA (21b839f or a later docs commit)
```

## 1. Generate the bcrypt hash (password never echoed, never on a command line)

`htpasswd` (apache2-utils, already installed) prompts twice without echo. Choose
the admin password, user name `admin`; keep it in your password manager.

```bash
( umask 077; htpasswd -nBC 12 '' | tr -d ':\n' > "$XDG_RUNTIME_DIR/portainer-hash" )
wc -c < "$XDG_RUNTIME_DIR/portainer-hash"      # REPORT: must be 60
cut -c1-7 "$XDG_RUNTIME_DIR/portainer-hash"; echo   # REPORT: $2y$12$
```

## 2. Store it in the vault

```bash
make vault-edit
```

In the editor, add one top-level line with the hash between single quotes. In vim:
`:r $XDG_RUNTIME_DIR/portainer-hash` inserts the hash on a new line; edit that line to

```yaml
vault_portainer_admin_password_hash: '<the 60-character hash>'
```

Save and quit. Then remove the temporary file:

```bash
shred -u "$XDG_RUNTIME_DIR/portainer-hash"
git status --short group_vars/all/vault/main.yml   # REPORT: " M group_vars/all/vault/main.yml"
head -c 14 group_vars/all/vault/main.yml; echo     # REPORT: $ANSIBLE_VAULT  (still encrypted)
```

If gpg fails with "Cannot allocate memory": `gpgconf --kill all`, then
`./bin/ansible-vault-pass.sh >/dev/null`, then retry.

Do not commit the vault change yourself unless you want it on the branch; tell the
pilot, who handles the commit (the vault file stays encrypted; pre-commit checks it).

## 3. Preview (no change)

```bash
uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --tags portainer --check
```

REPORT: the `PLAY RECAP` line (expected `failed=0 changed=4`) and the names of the
tasks shown as `changed` (expected, as replayed on the smoke VM from the same state:
"Start the one-shot admin bootstrap container", "Install the LAN filter script",
"Install the LAN filter unit", "Run the Portainer container"; `no_log` tasks show a
censored result). Nothing is started or published by `--check`.
No `--diff` (hard rule for roles touching secrets).

## 4. Apply (portainer tag only), then idempotence

```bash
make play-portainer
make play-portainer
```

REPORT: the two `PLAY RECAP` lines (expected, as replayed on the smoke VM from the same state: first `changed=9 failed=0`, second
`changed=0`). If the first run fails, REPORT the failed task name and its `msg`
line (the role never prints the hash).

## 5. Checks — REPORT all outputs

```bash
docker ps --filter name=portainer --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}'
#   expect: portainer portainer/portainer-ce:2.45.3 Up … 0.0.0.0:9443->9443/tcp (no [::])
curl -ks -o /dev/null -w 'admin_check=%{http_code}\n' https://127.0.0.1:9443/api/users/admin/check   # 204
curl -ks https://127.0.0.1:9443/api/system/status | jq -r .Version                                   # 2.45.3
docker logs portainer 2>&1 | grep -c 'setup_token='                                                  # 0
docker inspect portainer --format '{{json .Args}}'                                                   # ["--http-disabled"]
docker ps -a --format '{{.Names}}' | grep -c bootstrap                                               # 0
ss -ltnH | awk '{print $4}' | grep -E ':(9443|9000|8000)$'                                            # 0.0.0.0:9443 only
sudo iptables -S DOCKER-USER
sudo iptables -S PORTAINER-INGRESS
sudo iptables -S OPEN-WEBUI-INGRESS        # unchanged: 192.168.10.70 RETURN + 3030/8080 DROP
systemctl is-enabled portainer-firewall.service open-webui-firewall.service   # enabled enabled
systemctl show docker -p Requires          # lists both *-firewall.service
sha256sum /usr/local/sbin/open-webui-firewall /etc/systemd/system/open-webui-firewall.service
#   expect ab2e1a0b… and e835d061… (unchanged)
docker inspect open-webui --format '{{.Id}} {{.State.StartedAt}} {{.State.Health.Status}}'
#   expect 96ee79d99b4e… 2026-11-15T14:37:36… healthy (Open WebUI untouched)
```

LAN matrix (aliases as in roles/open_webui/README.md):

```bash
ssh caddy-70 "curl -ks -o /dev/null -w '%{http_code}\n' https://192.168.10.217:9443/"   # 200 (allowed)
ssh dns-71   "curl -k -m 5 -o /dev/null -w '%{http_code}\n' https://192.168.10.217:9443/" # 000/timeout (dropped)
sudo iptables -v -n -L PORTAINER-INGRESS   # REPORT: pkts on RETURN (Caddy) and DROP (dns-71) > 0
```

Then log in at https://127.0.0.1:9443 as `admin` with the chosen password and
REPORT only "login OK" or "login failed".

## Rollback (if needed)

```bash
docker stop portainer                  # closes the port at once
# then comment the two portainer_* lines in group_vars/all/vars.yml and:
make play-portainer                    # back to 127.0.0.1:9443, filter removed
```
