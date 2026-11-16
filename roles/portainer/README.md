# portainer

Run [Portainer CE](https://docs.portainer.io/) on the laptop as a Docker
container: official `portainer/portainer-ce` image pinned to an LTS release, data in
a named volume, HTTPS UI published on loopback by default. Optionally published to
the LAN for a reverse proxy, behind the same DOCKER-USER source filter as
`open_webui` (role [`docker_port_filter`](../docker_port_filter/README.md)).

Managed with `community.docker` (`docker_volume`, `docker_container`). No compose
file, no Edge agent, no automatic update. The only systemd unit is the LAN filter,
installed only when the port leaves loopback.

## Prerequisites

- Docker Engine: the role depends on the `docker` role (`meta/main.yml`), so
  `--tags portainer` installs or checks Docker first, then runs `portainer`, nothing
  else (never `cleanup_legacy`, never `open_webui`).
- Host port `9443` free (`ss -ltn | grep 9443`).

## Install and update

```bash
make play-portainer   # = uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --tags portainer
```

The run ends by waiting for `GET /api/system/status` to answer 200 with the pinned
version (up to `portainer_health_timeout`, 120 s). A second run reports `changed=0`.

Open <https://127.0.0.1:9443> (self-signed certificate: accept the browser warning).

## The admin account

### From the vault (this laptop)

`portainer_admin_password_hash` holds the **bcrypt hash** of the admin password
(user `admin`). On this laptop it is the alias of
`vault_portainer_admin_password_hash` in the encrypted
`group_vars/all/vault/main.yml` (`group_vars/all/vars.yml`). The role passes it as
`--admin-password <hash>`: Portainer creates the admin **before** it starts its
HTTPS server (log: `created admin user with the given password`), so the instance
never serves a setup page and needs no setup token. `--admin-password-file` is not
used: it takes the plaintext password in a file.

Create the hash without the password on the command line or in the shell history
(`htpasswd` from `apache2-utils` prompts twice, without echo):

```bash
( umask 077; htpasswd -nBC 12 '' | tr -d ':\n' > "$XDG_RUNTIME_DIR/portainer-hash" )
make vault-edit   # add: vault_portainer_admin_password_hash: '<content of that file>' (single quotes)
shred -u "$XDG_RUNTIME_DIR/portainer-hash"
```

Behaviour:

| Instance state | What the hash does |
|---|---|
| New volume | Admin created at first start, then HTTPS starts |
| Existing volume without admin (setup never done) | The container is recreated with the flag (its arguments changed) and the admin is created at start |
| Existing admin | Ignored. Portainer logs `instance already has an administrator user defined, skipping admin password related flags`; the current password stays valid |

The hash only bootstraps the admin. Change the password later in the UI; changing
the vault value afterwards only recreates the container (its arguments change),
it does not change the password.

Where the hash is visible: the container's arguments (`docker inspect portainer`),
readable by root and the `docker` group, who can read Portainer's database (same
hash) anyway. Do not paste `docker inspect portainer` output anywhere. Ansible
never prints it: the container task and the filter's container probe are `no_log`
(also under `-vvv` and `--check --diff`), and the format check does not echo the value.

### By hand (no hash)

With `portainer_admin_password_hash: ""` (the role default) a new instance has no
administrator. Portainer then asks for a **setup token** (one-time, printed in the
container log, since 2.39.4/2.43) and stops its setup service if the admin is not
created within **5 minutes** of the start:

```bash
docker logs portainer 2>&1 | grep -o 'setup_token=[^ ]*'   # one-time token, valid until the admin exists
docker restart portainer   # after "timed out for security purposes": another 5 minutes
```

Create the admin on <https://127.0.0.1:9443>, then expose the port.

### Never exposed without an admin

With a non-loopback `portainer_bind_address`:

- before the firewall or the container is touched, the role asks the running
  container `GET /api/users/admin/check` and fails unless it answers 204 (admin
  exists) **or** a hash is set;
- after the container starts, it asks again; anything but 204 stops the container
  (it stays stopped, `unless-stopped`) and fails the run.

## Variables

| Variable | Default | Description |
|---|---|---|
| `portainer_image` | `portainer/portainer-ce` | Official CE image, without tag |
| `portainer_version` | `2.45.3` | Release tag. Must match `X.Y.Z`: `lts`, `sts`, `latest` are rejected |
| `portainer_container_name` | `portainer` | Container name |
| `portainer_volume_name` | `portainer_data` | Named volume mounted on `/data` (upstream's name) |
| `portainer_bind_address` | `127.0.0.1` | Host IPv4 address the port is published on. Not `127.*` → admin check + LAN filter |
| `portainer_host_port` | `9443` | Host port (container port 9443, HTTPS) |
| `portainer_allowed_sources` | `[]` | IPv4 addresses/CIDRs allowed to reach the port when it is not on loopback (required then) |
| `portainer_admin_password_hash` | `""` | bcrypt hash of the `admin` password (secret, vault only), see [The admin account](#the-admin-account) |
| `portainer_health_timeout` | `120` | Seconds the run waits for the API |

Fixed by the role: restart policy `unless-stopped` (upstream uses `always`; with
`unless-stopped` a `docker stop` survives a Docker restart, which the port-change
and emergency procedures rely on); command `--http-disabled` (plus
`--admin-password` when a hash is set); mounts below.

## Ports and protocol

| Port | Upstream role | Here |
|---|---|---|
| 9443 | HTTPS UI and API, self-signed certificate (default) | published |
| 9000 | HTTP UI, "for legacy reasons" | disabled (`--http-disabled`), not published |
| 8000 | TCP tunnel for Edge agents, optional | not published (no Edge agents) |

The reverse proxy uses **HTTPS to 9443**. The alternative, HTTP 9000, would carry
the admin password and the session token (which controls Docker, so root on the
laptop) in clear over the Wi-Fi LAN between Caddy and the laptop. Over 9443 that hop
is encrypted. Caddy cannot verify Portainer's self-signed certificate against a CA,
so the Caddy site needs `tls_insecure_skip_verify` (or the certificate pinned with
`tls_trusted_ca_certs`, at the cost of updating Caddy whenever Portainer
regenerates it). The browser ↔ Caddy hop uses the homelab internal CA as for
`openwebui.internal`.

## Docker socket: risk and mitigations

The documented CE install mounts exactly two things, and so does the role:

- `/var/run/docker.sock` → `/var/run/docker.sock` (bind): Portainer manages the
  local Docker through it.
- the `portainer_data` volume → `/data`.

**Access to the Docker socket is root on this laptop**: anyone who controls
Portainer can start a privileged container that mounts `/`. Portainer's own
login is therefore what stands between the network and root. Mitigations:

- Loopback by default; LAN exposure only by explicit variables, and only for
  the listed sources (the homelab Caddy), enforced in DOCKER-USER.
- The setup page is never exposed: admin from the vault hash at first start, and
  admin checks before and after the container start (above). It also needs the
  log-printed setup token.
- HTTPS on every hop: browser → Caddy (internal CA), Caddy → laptop (9443).
- HTTP 9000 and the Edge tunnel 8000 are not published.
- Use a strong admin password; do not create extra users without need.

Limits: the filter trusts the source address (a LAN host spoofing
`192.168.10.70` would reach the login page). Portainer sees every container on
the laptop, including Open WebUI and Ollama-related ones: do not use it to modify
containers managed by this repository (the next run would revert or conflict).

## Owner validation (after `make play-portainer`)

```bash
docker ps --filter name=portainer --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}'
#   expect: portainer portainer/portainer-ce:2.45.3 Up … 127.0.0.1:9443->9443/tcp
curl -ks https://127.0.0.1:9443/api/system/status        # {"Version":"2.45.3",…}
docker inspect portainer --format '{{.HostConfig.RestartPolicy.Name}} {{json .Mounts}}'
ss -ltn | grep 9443                                      # 127.0.0.1:9443 only
make play-portainer                                      # second run: changed=0
```

## LAN access through a reverse proxy

For `https://portainer.internal` (homelab Caddy `192.168.10.70`, upstream
`https://<laptop IPv4>:9443`), with the vault hash set or the admin created by hand
(this laptop's `group_vars/all/vars.yml` has these lines):

```yaml
# group_vars/all/vars.yml
portainer_bind_address: "0.0.0.0"          # IPv4 only, every interface
portainer_allowed_sources: ["192.168.10.70"]
```

Then `make play-portainer`. The filter is the one described in the
[`open_webui` README](../open_webui/README.md#how-the-filter-works), with its own
chain, unit and script:

```
-A DOCKER-USER -m conntrack --ctstate DNAT --ctdir ORIGINAL -j PORTAINER-INGRESS
-A PORTAINER-INGRESS -s 192.168.10.70/32 -j RETURN
-A PORTAINER-INGRESS -p tcp -m conntrack --ctorigdstport 9443 --ctreplsrcport 9443 -j DROP
```

`portainer-firewall.service` runs `/usr/local/sbin/portainer-firewall` before
Docker at boot and on every Docker restart; Docker requires it (fail closed). The
two filters are independent: each chain drops only its own port mapping and
returns everything else, so Open WebUI's rules are not touched. Same warnings as
Open WebUI: never `systemctl stop|restart portainer-firewall` while Docker runs
(it stops or restarts Docker); rerun `sudo /usr/local/sbin/portainer-firewall`
instead.

Verify:

```bash
sudo iptables -S DOCKER-USER; sudo iptables -v -n -L PORTAINER-INGRESS
systemctl is-enabled portainer-firewall.service           # enabled
ssh caddy-70 curl -ks -o /dev/null -w '%{http_code}\n' https://192.168.10.217:9443/   # 200
ssh dns-71 curl -k -m 5 https://192.168.10.217:9443/       # other host: timeout
```

Back to loopback: remove the two lines, `make play-portainer`. The container is
recreated on `127.0.0.1:9443` first, then the unit, script, hook and chain are
removed; Open WebUI's filter stays. Emergency: `docker stop portainer`.

To change the host port while exposed, go back to loopback first, change the
port, then expose again: the admin check probes the new port.

## Updating

1. Back up the volume (below). Portainer migrates its database forward on start;
   the backup is the only way back.
2. Read the release notes between the two versions
   (<https://github.com/portainer/portainer/releases>). Stay on an LTS line.
3. Set `portainer_version` (role default through a PR, or
   `group_vars/all/vars.yml` for this laptop), then `make play-portainer`
   (pulls the tag, recreates the container on the same volume, waits for the API),
   and again for `changed=0`.

No Watchtower, `pull: missing`: nothing changes until the version variable
changes. Remove the old image with `docker image rm portainer/portainer-ce:<old>`.

## Backup and restore

```bash
docker stop portainer
docker run --rm -v portainer_data:/data:ro -v "$PWD":/backup alpine:3 \
  sh -c 'umask 077 && tar czf /backup/portainer-$(date +%Y%m%d-%H%M).tar.gz -C /data .'
docker start portainer
```

The archive holds the database, the encryption key and the TLS private key:
store it like a secret. Restore: container stopped,
`find /data -mindepth 1 -delete && tar xzf …` in the same way, then start.

The 2026-11-07 archive of the former, unmanaged installation
(`~/Backups/portainer-2026-11-07/`) is not restored by this role.

## Removal

Not automated. Set the bind address back to loopback (removes the filter), then
`docker rm -f portainer`; the data stays in `portainer_data` until
`docker volume rm portainer_data` (irreversible).
