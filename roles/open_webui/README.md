# open_webui

Run [Open WebUI](https://github.com/open-webui/open-webui) on the laptop as a
Docker container: official image pinned to a release tag, data in a named volume,
UI published on loopback by default, talking to the Ollama service that runs on the
host. Optionally published to the LAN for a reverse proxy, behind a source filter
(see [LAN access through a reverse proxy](#lan-access-through-a-reverse-proxy)).

Managed with `community.docker` (`docker_volume`, `docker_container`), shipped by
the `ansible` package in the project venv. No compose file. The only systemd unit is
the LAN filter, installed only when the port leaves loopback.

## Prerequisites

- Docker Engine: the role depends on the `docker` role (`meta/main.yml`), so
  `--tags open-webui` installs or checks Docker first. The user does not need to
  be in the `docker` group: Ansible talks to the daemon as root (`become: true`).
- Ollama on the host, listening on an address the Docker bridge can reach (see
  [Ollama](#ollama)). Without it Open WebUI still starts, with no local models.
- First start: the container downloads its embedding models from Hugging Face
  (internet access, a few minutes, about 1 GB in the volume).

## Install and update

```bash
make play-open-webui   # = uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --tags open-webui
```

The tag runs `docker` then `open_webui`, nothing else (never `cleanup_legacy`).
The run ends by waiting for the container health check (up to
`open_webui_health_timeout`, 300 s): a green run means the UI answered `/health`.

Open <http://127.0.0.1:3030>. **The first account created becomes the
administrator** and further sign-ups are switched off (upstream default). Create it
right after the first install.

## Variables

| Variable | Default | Description |
|---|---|---|
| `open_webui_image` | `ghcr.io/open-webui/open-webui` | Official image, without tag |
| `open_webui_version` | `v0.13.0` | Release tag. Must match `vX.Y.Z`: `main`, `latest`, `dev` are rejected |
| `open_webui_container_name` | `open-webui` | Container name |
| `open_webui_volume_name` | `open-webui` | Named volume mounted on `/app/backend/data` |
| `open_webui_bind_address` | `127.0.0.1` | Host IPv4 address the port is published on. Not `127.*` → LAN filter installed |
| `open_webui_host_port` | `3030` | Host port (container port is 8080) |
| `open_webui_allowed_sources` | `[]` | IPv4 addresses/CIDRs allowed to reach the port when it is not on loopback (required then) |
| `open_webui_url` | `""` | `WEBUI_URL` when not empty, read on the **first start only** (see [Public URL](#public-url-webui_url)) |
| `open_webui_ollama_base_url` | `http://host.docker.internal:11434` | `OLLAMA_BASE_URL`, read on the **first start only** (see [Ollama](#ollama)) |
| `open_webui_health_timeout` | `300` | Seconds the run waits for `healthy` |

Override in `group_vars/all/vars.yml` (or `-e` for a one-off; not for
`open_webui_version`, see [Updating](#updating)). None of them is a secret. This
laptop's `group_vars/all/vars.yml` sets the homelab values (`0.0.0.0`,
`192.168.10.70`, `https://openwebui.internal`).

Fixed by the role: restart policy `unless-stopped`; health check
`curl /health | jq 'status == true'` (the image's own test) every 30 s with a 120 s
start period; `host.docker.internal` mapped to `host-gateway`;
`WEBUI_SECRET_KEY_FILE=/app/backend/data/.webui_secret_key`.

### Network exposure

With the default `127.0.0.1:3030` the UI is reachable from this laptop only. Docker
publishes ports with its own iptables rules, which bypass `ufw`: binding to loopback
is what keeps it off the LAN, unless the LAN filter below is used. Port 3000 (upstream's example) is avoided because the
`~/Workspace/brain-rag` compose project publishes `0.0.0.0:3000`.

### Ollama

Ollama runs on the host (`ollama.service`). Inside the container, `localhost` is
the container itself; `host.docker.internal` resolves to the Docker bridge gateway
(`172.17.0.1` on the default bridge), the upstream method on Linux without Docker
Desktop. Ollama must therefore listen on that address: the laptop's drop-in
`/etc/systemd/system/ollama.service.d/override.conf` sets `OLLAMA_HOST=0.0.0.0`.
If Ollama is ever restricted to `127.0.0.1`, the container loses it; then set
`OLLAMA_HOST=172.17.0.1` (bridge only, not the LAN). This role does not manage Ollama.

`OLLAMA_BASE_URL` is an Open WebUI *persistent* setting: the first start copies it
into the database, and from then on the database wins. Changing
`open_webui_ollama_base_url` afterwards recreates the container with the new
variable but **does not change the URL Open WebUI uses** (verified on v0.12.5,
mission `2026-11-05-open-webui`). Change it in Admin Settings → Connections →
Ollama instead. The role does not set `ENABLE_PERSISTENT_CONFIG=False`: that would
make every environment variable override the admin settings at each start.

### Authentication and the secret key

Authentication stays at upstream defaults: login required, first account is admin,
sign-ups closed after it, new accounts `pending`. The role sets no credential.

`WEBUI_SECRET_KEY` signs sessions and encrypts stored tokens. It is not set: the
image's `start.sh` generates one on first start and writes it to
`WEBUI_SECRET_KEY_FILE`, which the role points into the volume. The key therefore
survives container recreation (updates) and never appears in the repository, the
vault or Ansible output. It is part of the volume: back it up with the rest.

## Owner validation (after `make play-open-webui`)

```bash
docker ps --filter name=open-webui --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}'
#   expect: open-webui ghcr.io/open-webui/open-webui:v0.13.0 Up … (healthy) 127.0.0.1:3030->8080/tcp
curl -fsS http://127.0.0.1:3030/health                       # {"status":true}
docker inspect open-webui --format '{{.HostConfig.RestartPolicy.Name}}'   # unless-stopped
docker exec open-webui curl -fsS http://host.docker.internal:11434/api/version   # Ollama reachable
ss -ltn | grep 3030                                          # 127.0.0.1:3030 only
make play-open-webui                                         # second run: changed=0
```

Then open <http://127.0.0.1:3030>, create the admin account, and check that the
Ollama models appear in the model selector.

## Updating

`open_webui_version` is the only input that selects the release: the role runs the
image `{{ open_webui_image }}:{{ open_webui_version }}`. Changing it and rerunning the
role pulls that tag and recreates the container on the same volume; the database,
uploads and the secret key file stay in the volume. A second run with the same
version reports `changed=0`. Verified on a VM, v0.12.5 → v0.13.0 (mission
`2026-11-05-open-webui`).

1. Back up the volume (below). An update is a one-way database migration: this
   backup is the only way back (see [Rollback](#rollback)).
2. Read the release notes between the current and the new tag
   (<https://github.com/open-webui/open-webui/releases>), in particular
   "Database Migrations".
3. Set the new tag where every later run will see it. Use one of these:
   - Through a PR, for every laptop: edit `open_webui_version` in
     `roles/open_webui/defaults/main.yml`.
   - For this laptop only, without changing the role: add
     `open_webui_version: "vX.Y.Z"` to `group_vars/all/vars.yml`. It overrides the
     role default, so remove it when the default catches up.
4. Deploy and check:

   ```bash
   make play-open-webui    # pulls vX.Y.Z, recreates the container, waits for healthy
   docker inspect open-webui --format '{{.Config.Image}}'    # …/open-webui:vX.Y.Z
   curl -fsS http://127.0.0.1:3030/api/config | jq -r .version  # X.Y.Z
   make play-open-webui    # second run: changed=0
   ```

   Sign in again with an existing account: your account and its chats must still be
   there.

Do not use `-e open_webui_version=…` for a lasting update, for example
`uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --tags open-webui -e open_webui_version=vX.Y.Z`.
`make` targets do not pass `-e`, so the next `make play-open-webui` or `make play`
goes back to the default tag. That is a downgrade on a database that is already
migrated, which is the unsupported case described under [Rollback](#rollback).

There is no automatic update (no Watchtower, `pull: missing`): a tag already present
is never re-pulled, and nothing changes until the version variable changes. The
previous image stays on disk, which makes a rollback faster. Remove it with
`docker image rm ghcr.io/open-webui/open-webui:<old tag>` once you no longer need it.

## Backup and restore

Everything (database, uploads, vector store, secret key, model cache) is in the volume.

```bash
# Backup — stop first so SQLite is consistent. The archive is created mode 0600
# (owned by root): it holds the secret key and every user's data.
docker stop open-webui
docker run --rm -v open-webui:/data:ro -v "$PWD":/backup alpine:3 \
  sh -c 'umask 077 && tar czf /backup/open-webui-$(date +%Y%m%d-%H%M).tar.gz -C /data .'
docker start open-webui

# Restore into the same volume (replaces its content), container stopped
docker stop open-webui
docker run --rm -v open-webui:/data -v "$PWD":/backup:ro alpine:3 \
  sh -c 'find /data -mindepth 1 -delete && tar xzf /backup/<archive>.tar.gz -C /data'
docker start open-webui   # plain restore only; for a rollback, see below
```

Store the archive like a secret.

## Rollback

Open WebUI migrates its database forward at start; **setting an older tag does not
reverse those migrations**, and an older version may refuse or corrupt a database
written by a newer one. A rollback needs the backup taken *before* the update:

1. `docker stop open-webui`.
2. Restore that backup with the restore command above, **without** the final
   `docker start`: starting the current (newer) image would migrate the restored
   database forward again.
3. Set `open_webui_version` back to the previous tag, where you set it in step 3 of
   [Updating](#updating) (role default through a PR, or `group_vars/all/vars.yml`).
4. `make play-open-webui`: the role recreates the container on the previous
   image, which starts on the restored database.

Without that backup, rolling back is not supported (upstream offers manual Alembic
downgrades, at the risk of data loss).

## Removal

Not automated. `docker rm -f open-webui` removes the container; the data stays in
the `open-webui` volume until `docker volume rm open-webui` (irreversible).

## Other Open WebUI data on the laptop

The role never touches the `brain-rag_open-webui` volume (compose project
`~/Workspace/brain-rag`, a separate RAG front-end) nor the `:main` image it used.
To move that data under this role instead, back it up and restore it into the
`open-webui` volume while the managed container is stopped; this is an owner
decision, not something the role does.

## LAN access through a reverse proxy

Used on this laptop for `https://openwebui.internal`: the homelab Caddy
(`192.168.10.70`) proxies to `http://192.168.10.217:3030`. Enabled by any
non-loopback `open_webui_bind_address`:

```yaml
# group_vars/all/vars.yml
open_webui_bind_address: "0.0.0.0"          # IPv4 only, every interface
open_webui_allowed_sources: ["192.168.10.70"]
open_webui_url: "https://openwebui.internal"
```

### Why `0.0.0.0` and not the Wi-Fi address

Binding to `192.168.10.217` would make the container depend on the DHCP lease:
at boot Docker starts the container before Wi-Fi is up and the bind fails. `0.0.0.0`
has no such dependency, publishes **IPv4 only** (an explicit IPv4 address never
creates the `[::]` binding Docker adds for an empty host IP), and the filter does
the restriction. The role rejects IPv6 or empty bind addresses.

### How the filter works

Packet path (Docker 29, iptables backend on nf_tables, checked on this laptop):

```
LAN client ──► nat PREROUTING ─► DOCKER: DNAT :3030 → <container>:8080
           ──► filter FORWARD ─► DOCKER-USER ─► OPEN-WEBUI-INGRESS ─► DOCKER-FORWARD … ACCEPT
laptop itself (127.0.0.1 or its own LAN IP) ─► OUTPUT / docker-proxy: never FORWARD, never filtered
```

`ufw` and the INPUT chain never see this traffic, so the filter lives in
`DOCKER-USER`, the chain Docker reserves for user rules and never flushes:

```
-A DOCKER-USER -m conntrack --ctstate DNAT --ctdir ORIGINAL -j OPEN-WEBUI-INGRESS
-A OPEN-WEBUI-INGRESS -s 192.168.10.70/32 -j RETURN          # one per allowed source
-A OPEN-WEBUI-INGRESS -p tcp -m conntrack --ctorigdstport 3030 --ctreplsrcport 8080 -j DROP
```

- Only port-forwarded packets in the client → container direction enter the chain.
  Replies (`REPLY` direction) never do, so an allowed connection is not cut.
- The `DROP` matches the mapping itself: original destination port 3030 translated
  to container port 8080. Other published ports and other Docker traffic return
  untouched. Allowed sources `RETURN` to Docker's own rules, which accept them.
- Other containers reaching `<laptop IP>:3030` through a Docker network are dropped
  too (their source is not allowed); the laptop itself is not affected.

`/usr/local/sbin/open-webui-firewall` writes these rules; the chain is replaced in
one `iptables-restore --noflush` transaction, so a change of sources never leaves
it empty. `open-webui-firewall.service` (oneshot) runs it, `Before=docker.service`
and `RequiredBy=docker.service`: **if the filter fails, Docker does not start**, so
the port is never published unfiltered (fail closed, at the cost of every container
on the laptop until it is fixed).

| Event | What happens |
|---|---|
| First run / change of sources | The role writes script + unit, runs the script **before** recreating the container |
| Change of `open_webui_host_port` | The role `docker stop`s the container first (the old port leaves with it), then changes the rules, then recreates it. A failure in between leaves it stopped, and `unless-stopped` keeps it stopped |
| Rerun, nothing changed | `iptables -C` probes find the hook and the `DROP`: `changed=0` |
| Hook or `DROP` removed by hand | A probe fails, the role reruns the script (it does not check the allowed-source lines) |
| Boot | The unit runs before Docker publishes anything. No network dependency, so a late Wi-Fi lease is irrelevant |
| `systemctl restart docker` | Docker keeps `DOCKER-USER`; `PartOf=docker.service` also reruns the unit first |
| Back to loopback | The role recreates the container on `127.0.0.1` first, then disables (Docker no longer requires it), stops and removes the unit, the script, the hook and the chain. Docker is not restarted; other `DOCKER-USER` rules stay |

`Requires=` propagates stop and restart: `systemctl stop|restart
open-webui-firewall` **stops or restarts Docker** and all its containers. To
reapply the rules, run `sudo /usr/local/sbin/open-webui-firewall` (or the role)
instead. If Docker refuses to start with `Dependency failed for docker.service`:

```bash
systemctl status open-webui-firewall.service   # why the script failed
sudo /usr/local/sbin/open-webui-firewall        # fix, rerun until it exits 0
sudo systemctl start docker
```

Limits: the filter trusts the source address (anyone on the LAN who can spoof
`192.168.10.70` passes it, then still meets Open WebUI's login). It identifies the
mapping by ports (original 3030, translated 8080), not by container. It requires
Docker's `iptables` firewall backend; the role fails with any other.

### Public URL (`WEBUI_URL`)

`WEBUI_URL` is used for links in notifications, OAuth redirects and the search
descriptor. Since v0.13.0 every setting is a row of the `config` table, seeded from
the environment at the **first** start: on an existing install `webui.url` is
already stored (empty) and `open_webui_url` changes nothing. Set it once in
**Admin Settings → General → WebUI URL** (`https://openwebui.internal`). The role
does not set `ENABLE_PERSISTENT_CONFIG=False` (see [Ollama](#ollama)).

CORS is left at the upstream default (`CORS_ALLOW_ORIGIN=*`, which the WebSocket
server also accepts): through Caddy the browser talks to one origin,
`https://openwebui.internal`. Restricting it would require listing every origin,
`http://127.0.0.1:3030` included. Caddy forwards WebSockets by default.

### Verify

```bash
docker ps --filter name=open-webui --format '{{.Ports}}'   # 0.0.0.0:3030->8080/tcp, no [::]
ss -ltn | grep ':3030'                                       # 0.0.0.0:3030 only
sudo iptables -S DOCKER-USER; sudo iptables -S OPEN-WEBUI-INGRESS
systemctl is-enabled open-webui-firewall.service             # enabled
curl -fsS http://127.0.0.1:3030/health                       # local access
ssh caddy-70 curl -fsS http://192.168.10.217:3030/health     # allowed: {"status":true}
ssh dns-71 curl -m 5 http://192.168.10.217:3030/health        # other host: timeout
systemctl show docker -p Requires | grep -o open-webui-firewall.service
make play-open-webui                                         # second run: changed=0
```

### Roll back to loopback only

Remove the three lines from `group_vars/all/vars.yml` (or set
`open_webui_bind_address: "127.0.0.1"`), then `make play-open-webui`: container on
`127.0.0.1:3030`, unit, script and rules removed. Data, accounts and the secret
key are in the volume and are not touched. Emergency, without Ansible:

```bash
docker stop open-webui                         # closes the port at once
# then fix the variables and rerun make play-open-webui
```

The homelab side (Pi-hole record, Caddy site, internal TLS) lives in the homelab
repository. If the laptop address or port changes, update the Caddy upstream
there (`http://<laptop IPv4>:<open_webui_host_port>`). The address relies on the
router's static DHCP lease for the Wi-Fi MAC.
