# open_webui role — design

Date: 2026-11-05. Mission: `docs/missions/2026-11-05-open-webui/`.
Operations (install, update, backup, rollback): `roles/open_webui/README.md`.

## Goal

Run Open WebUI on the laptop reproducibly from this repository: pinned official
image, persistent data, automatic restart, health check, a dedicated tag, nothing
exposed beyond what is needed.

## Context found on the laptop (2026-11-05, read-only)

- Docker Engine 29.9.0 (managed by the `docker` role).
- Ollama 0.12.10 installed on the host (`ollama.service`, `OLLAMA_HOST=0.0.0.0`).
- Open WebUI leftovers, none managed by this repository:
  - volume `brain-rag_open-webui` (compose project `~/Workspace/brain-rag`, a RAG
    front-end with Ollama disabled), 1.0 G, holds a `webui.db`; no container;
  - image `ghcr.io/open-webui/open-webui:main` (2026-06-02);
  - `~/Workspace/07-local/openWebUI/docker-compose.yml` (v0.8.3), its volume absent.

## Decisions

| Topic | Decision | Rejected |
|---|---|---|
| Mechanism | `community.docker.docker_volume` + `docker_container` (collection already in the venv's `ansible` package, like `community.general` for syncthing; needs only `python3-requests` on the target) | compose file + `docker_compose_v2` (one more file to template, two sources of truth); systemd unit running `docker run` (not idempotent) |
| Image | `ghcr.io/open-webui/open-webui:v0.13.0`, asserted `vX.Y.Z` | `main`/`latest` (moving), `-ollama` variant (Ollama is on the host), `-cuda` (no GPU need stated) |
| Updates | manual: bump `open_webui_version`; `pull: missing` | Watchtower or `pull: always` (silent upgrades with irreversible DB migrations) |
| Data | named volume `open-webui` on `/app/backend/data` | bind mount in `$HOME` (root-owned files in the user's tree); reusing `brain-rag_open-webui` (another project's data) |
| Secret key | `WEBUI_SECRET_KEY_FILE` in the volume; `start.sh` generates it | vault variable (owner action, a secret to rotate, would show in `docker inspect`); unset (key lost on every recreation → sessions and encrypted tokens invalid) |
| Exposure | `127.0.0.1:3030` | `0.0.0.0` (Docker bypasses ufw → LAN exposure); `3000` (used by `brain-rag`); `network_mode: host` (exposes 8080 on every interface) |
| Ollama | `OLLAMA_BASE_URL=http://host.docker.internal:11434` + `host-gateway`; seeds the first start only (persistent setting), later changes in Admin Settings | Ollama in Docker (already on the host); `network_mode: host`; `ENABLE_PERSISTENT_CONFIG=False` (env would override every admin setting) |
| Auth | upstream defaults, no override | `WEBUI_AUTH=False` (forbidden by the objective) |
| Restart | `unless-stopped` | `always` (a deliberate `docker stop` would be undone at boot) |
| Health | image's own test (`/health` → `status == true`), 30 s interval, 120 s start period; the run waits for `healthy` | no wait (a broken start would report green) |
| Docker | meta dependency on `docker` (as `vagrant` → `libvirt`) | assert only (fresh laptop would need two commands) |
| Socket | not mounted | — (forbidden) |

The `docker` role gains `python3-debian` in its prerequisite packages: its
`deb822_repository` task needs it, and until now only the untagged full run
installed it, so `--tags docker` (and therefore `--tags open-webui`) failed on a
host that never had a full run.

## Out of scope

Homelab reverse proxy and DNS (`openwebui.internal`), Ollama configuration,
migration of the `brain-rag` data, GPU variants, removal automation.
