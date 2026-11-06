# open_webui

Run [Open WebUI](https://github.com/open-webui/open-webui) on the laptop as a
Docker container: official image pinned to a release tag, data in a named volume,
UI published on loopback only, talking to the Ollama service that runs on the host.

Managed with `community.docker` (`docker_volume`, `docker_container`), shipped by
the `ansible` package in the project venv. No compose file, no systemd unit.

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
| `open_webui_bind_address` | `127.0.0.1` | Host address the port is published on |
| `open_webui_host_port` | `3030` | Host port (container port is 8080) |
| `open_webui_ollama_base_url` | `http://host.docker.internal:11434` | `OLLAMA_BASE_URL`, read on the **first start only** (see [Ollama](#ollama)) |
| `open_webui_health_timeout` | `300` | Seconds the run waits for `healthy` |

Override in `group_vars/all/vars.yml` (or `-e` for a one-off). None of them is a secret.

Fixed by the role: restart policy `unless-stopped`; health check
`curl /health | jq 'status == true'` (the image's own test) every 30 s with a 120 s
start period; `host.docker.internal` mapped to `host-gateway`;
`WEBUI_SECRET_KEY_FILE=/app/backend/data/.webui_secret_key`.

### Network exposure

`127.0.0.1:3030` makes the UI reachable from this laptop only. Docker publishes
ports with its own iptables rules, which bypass `ufw`: binding to loopback is what
keeps it off the LAN. Port 3000 (upstream's example) is avoided because the
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

1. Back up the volume (below).
2. Read the release notes between the current and the new tag
   (<https://github.com/open-webui/open-webui/releases>), in particular
   "Database Migrations".
3. Bump `open_webui_version` (in `defaults/main.yml` through a PR, or override it).
4. `make play-open-webui`: the new image is pulled, the container recreated on the
   same volume, migrations run at start, and the run waits for `healthy`.

There is no automatic update (no Watchtower, `pull: missing`): a tag already present
is never re-pulled, and nothing changes until the version variable changes.

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
3. Set `open_webui_version` back to the previous tag.
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

## Future homelab integration (`openwebui.internal`)

Not implemented here; it belongs to the homelab (Pi-hole + Caddy). What it will need:

- Caddy on another host cannot reach `127.0.0.1:3030`. Either set
  `open_webui_bind_address` to the laptop's LAN address (and restrict who can reach
  it), or run the reverse proxy on the laptop and keep loopback.
- Reverse proxy: `reverse_proxy <laptop>:3030` with WebSocket support (Caddy
  forwards it by default); Open WebUI streams over WebSockets.
- Set `WEBUI_URL=https://openwebui.internal` (this role would need a variable for
  it; like `OLLAMA_BASE_URL` it is a persistent setting, so on an existing install
  set it in Admin Settings → General), and check CORS (`CORS_ALLOW_ORIGIN`).
- DNS: a Pi-hole record `openwebui.internal` → the proxy host; TLS from the
  homelab's internal CA.
