# Report — 2026-11-05-open-webui

## Verdict

PASS. All acceptance criteria VERIFIED on lint and on a mission-owned VM; Codex
review 1 PASS_WITH_RESERVATIONS (1 minor finding, fixed), review 2 PASS. Not
applied to the laptop (owner step, commands below). AC11 is verified against an
Ollama stub plus a read-only network probe of the real laptop Ollama; Open WebUI
against the real Ollama is owner validation.

## Architecture and configuration

- New role `roles/open_webui`, included from `roles/bootstrap/tasks/main.yml`
  with tag `open-webui` (task + `apply`), `make play-open-webui`.
- Mechanism: `community.docker.docker_volume` + `docker_container` (5.0.4, from
  the venv's `ansible` package; target needs only `python3-requests`). No compose
  file, no systemd unit, no second mechanism.
- Docker prerequisite: meta dependency on `docker` (precedent `vagrant` →
  `libvirt`). The `docker` role now installs `python3-debian` itself (its
  `deb822_repository` task needs it; before, only the untagged full run did, so
  `--tags docker` failed on a host without a prior full run — reproduced on the VM).
- Image `ghcr.io/open-webui/open-webui:v0.13.0` (latest stable, 2026-11-03, notes
  announce security fixes); assert rejects anything not `vX.Y.Z`. `pull: missing`,
  no auto-update.
- Data: named volume `open-webui` → `/app/backend/data`.
- Secret key: `WEBUI_SECRET_KEY_FILE=/app/backend/data/.webui_secret_key`; the
  image's `start.sh` generates the key there on first start. Survives recreation;
  nothing in repo, vault or logs.
- Restart `unless-stopped`; health check = the image's `/health` test (30 s,
  120 s start period); the task uses `state: healthy`, so a broken start fails.
- Exposure: `127.0.0.1:3030` → 8080. Loopback because Docker's port publishing
  bypasses ufw; 3000 avoided (the `brain-rag` compose publishes `0.0.0.0:3000`).
- Ollama: `OLLAMA_BASE_URL=http://host.docker.internal:11434`,
  `host.docker.internal: host-gateway` (upstream Linux method). Only seeds the
  first start: Open WebUI then keeps it in its database (verified), later changes
  go through Admin Settings → Connections (documented).
- Auth: upstream defaults untouched (first account admin, sign-up then closed).
- Variables: `open_webui_{image,version,container_name,volume_name,bind_address,host_port,ollama_base_url,health_timeout}`.

## Existing-installation findings (laptop, read-only)

- No Open WebUI container. Image `open-webui:main` (2026-06-02), unused.
- Volume `brain-rag_open-webui` (compose project `~/Workspace/brain-rag`, RAG
  front-end, `ENABLE_OLLAMA_API=false`): `webui.db` 606 208 B, 1.0 G with caches.
  Another project's data: left untouched (mtime/creation unchanged at the end),
  not migrated. The role uses its own names.
- `~/Workspace/07-local/openWebUI/docker-compose.yml` (v0.8.3): its volume does not exist.
- Ollama 0.12.10 on the host, `ollama.service`, drop-in `OLLAMA_HOST=0.0.0.0`
  (listens on every interface — BACKLOG Watch entry).
- A transient container with `host-gateway` reached the real Ollama
  (`172.17.0.1:11434`, version and model list): the chosen method works on this laptop.

No migration was needed, so no owner decision blocked the work.

## Tests executed

Lint (worktree venv, dummy vault, cleaned env): `pre-commit run --files <changed>`
exit 0 (gitleaks Passed), ansible-lint exit 0 (production), yamllint exit 0,
`--syntax-check` exit 0, `bin/check_make_venv_tools.sh` exit 0.

VM (`bento/ubuntu-24.04`, venv Ansible over SSH, vault-free copy; evidence in
`~/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`):

| Check | Result |
|---|---|
| Fresh VM, `--tags open-webui` | Docker CE + Open WebUI installed, healthy; tasks limited to facts, docker, apt_keyring, open_webui |
| Idempotence | every second run changed=0 (incl. `--check`, after reboot, combined `docker,open-webui`) |
| Fresh empty volume, final code | changed=2 → changed=0 |
| HTTP | `/` 200 HTML "Open WebUI", `/health` `{"status":true}`, version 0.13.0 |
| Exposure | only `127.0.0.1:3030`; VM LAN IP refused; override to LAN IP/3031 works |
| Auth | `auth: true`; throwaway `@example.invalid` admin; sign-up then off, 2nd sign-up 403, anonymous 401 |
| Recreation | new container id; same key fingerprint, user, old session token 200 |
| Restart | after VM reboot, container back and healthy without Ansible |
| Update | v0.12.5 → v0.13.0 by the role: alembic `0bd252b206fb` → `e42c8f710a36`, data kept |
| Backup → update → rollback (README procedure) | archive 0600; back on v0.12.5 with `0bd252b206fb`, user kept, sign-in 200 |
| Ollama | stub on VM host: container → `host.docker.internal` (172.17.0.1) OK; Open WebUI `/ollama/api/version` and `/api/models` return the stub's model |
| Assert | `open_webui_version=main` rejected |
| Socket / privileges | no `docker.sock` mount, `privileged=false` |

## Remaining limitations

- Not run on the laptop. Not tested: Open WebUI against the real Ollama, model inference, browser UI.
- `make smoke-replay TAGS=open-webui` cannot work today: the VM's distro
  ansible-core has no `community.*` collections (BACKLOG Cleanup). The VM was
  driven from the host venv instead.
- With `docker` and `open-webui` both selected (and in a full run) the `docker`
  role runs twice; idempotent (changed=0). The version assert runs after the
  `docker` dependency.
- Changing `open_webui_ollama_base_url` after the first start has no effect on
  the app (upstream persistent config); documented.
- Image tags are mutable upstream; pinned by tag, not digest.

## Deviations and incidents

- `pre-commit install` run in the worktree repointed the shared `.git/hooks`
  `INSTALL_PYTHON` at the worktree venv; restored immediately from the main checkout.
- The host's libvirt dnsmasq for `vagrant-libvirt` (`192.168.121.1:53`) stopped
  answering mid-mission. Not repaired (host resource, needs root); the mission VM
  alone used a resolved drop-in (`1.1.1.1`, `9.9.9.9`). The owner may want to
  check `virsh net-destroy/net-start vagrant-libvirt` before the next smoke run.
- Scope addition: one line in `roles/docker` (`python3-debian`), needed for the
  Docker prerequisite; no-op on the laptop (already installed).

## Reviews

- Review 1: PASS_WITH_RESERVATIONS. F1.1 [minor] rollback could restart the newer
  image on the restored DB → fixed (4-step rollback, restore without start).
  Its "not checked" items were then executed (rollback round trip, Ollama URL change).
- Review 2: PASS, no findings. Reservations: laptop and real-Ollama validation
  are the owner's; duplicate docker run disclosed.

## Safety

Main checkout snapshot `22cb4cf2…35d2e5` unchanged; stashes unchanged; no
secret read (dummy vault only, `pass` never called); hooks not bypassed; laptop:
no container, volume or config created; Codex pane `w1Q:pF` closed; VM destroyed.

## Git state

Branch `feat/open-webui` (worktree `../laptop-bootstrap-worktrees/open-webui`),
upstream unset before push. Commit, push and PR: see the PR description; the
final head SHA and CI status are given in the closing message (this file is part
of the PR, so it cannot name its own commit).

## Owner deployment and validation

```bash
cd ~/Workspace/02-infrastructure/local/laptop-bootstrap
git switch main && git pull           # after merge
make play-open-webui                  # docker + open_webui only
docker ps --filter name=open-webui --format '{{.Names}} {{.Image}} {{.Status}} {{.Ports}}'
curl -fsS http://127.0.0.1:3030/health
docker inspect open-webui --format '{{.HostConfig.RestartPolicy.Name}}'
docker exec open-webui curl -fsS http://host.docker.internal:11434/api/version
ss -ltn | grep 3030                   # 127.0.0.1:3030 only
make play-open-webui                  # expect changed=0
```

Then open <http://127.0.0.1:3030>, create the admin account at once (first account
wins), check the Ollama models in the selector and send one prompt.
Preview without changes: `uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --tags open-webui --check` (no `--diff`).

## For the later homelab integration (`openwebui.internal`)

- Upstream: container port 8080, published `127.0.0.1:3030` on the laptop.
- A Caddy on another host cannot reach loopback: set `open_webui_bind_address` to
  the laptop's LAN IP (Docker bypasses ufw: restrict at the network level) or run
  the proxy on the laptop.
- `reverse_proxy <laptop>:3030`, WebSockets required (Caddy default).
- `WEBUI_URL=https://openwebui.internal` needs a new role variable; persistent
  setting, so on an existing install set it in Admin Settings → General. Check
  `CORS_ALLOW_ORIGIN`.
- Pi-hole record → proxy host; TLS from the homelab internal CA.
- Recorded in `BACKLOG.md` (Deferred) and `roles/open_webui/README.md`.

## Post-merge record (2026-11-06)

Added by the closeout mission `docs/missions/2026-11-06-open-webui-closeout/`.

- Merge: PR #62 merged by the owner on 2026-11-06T01:25:15Z, merge commit
  `67db4bcf4fab47e9a0dd9044e8e0c1a0807b0746` on `main`; head `2356c04` is an
  ancestor of `origin/main`.
- Owner-confirmed (the owner's statement, quoted as given, not re-executed by the
  agent): "Open WebUI is operational on the laptop." The statement is general: it
  does not itemise the browser UI, the admin account, the real Ollama or model
  inference, so those individual checks are recorded as not separately confirmed.
- Agent read-only probe of the laptop (2026-11-06, no change made): container
  `open-webui` runs `ghcr.io/open-webui/open-webui:v0.13.0`, `Up (healthy)`,
  published `127.0.0.1:3030->8080/tcp` only (`ss`: `127.0.0.1:3030`), restart
  `unless-stopped`, volume `open-webui` on `/app/backend/data`; `/health`
  `{"status":true}`; `/api/config` version `0.13.0`. The `brain-rag_open-webui`
  volume is still present (this closeout did not touch it).
- Not executed by the agent on the laptop, and not individually confirmed by the
  owner: second `make play-open-webui` for `changed=0`, Ollama reachability from
  the container, model selector, inference.
