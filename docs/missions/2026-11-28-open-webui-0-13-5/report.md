# Report — 2026-11-28-open-webui-0-13-5 — Upgrade Open WebUI to v0.13.5

## Verdict

PARTIAL, pending review. All acceptance criteria that this executor can verify are
VERIFIED: AC1-AC5 and AC-SAFE. AC6 (the owner runbook) is written. Running it on the
laptop is an owner action and has not been executed. The Codex review, routed by the
pilot, has not run yet, so PASS cannot be claimed (docs/agent-workflow.md §7).

## Executive summary

- Target: v0.13.5. It is the latest stable release, published 2026-11-25. No newer
  stable release exists, so there was no reason to stop.
- Change: `open_webui_version` goes from "v0.13.0" to "v0.13.5" in
  `roles/open_webui/defaults/main.yml`. Docs and BACKLOG are updated. No task,
  template or other variable changed.
- Release notes v0.13.1 to v0.13.5 require no change to the role: env vars,
  healthcheck, port 8080, volume path and image name all stay valid.
- Database migrations exist and only go forward: 7 Alembic revisions, including
  the v0.13.5 conversion of chat history into per-message rows. A volume backup
  taken before the update is the only way back.
- Smoke VM results:
  - Update from v0.13.0 to v0.13.5: `changed=1`, the container task only.
  - Second run: `changed=0`.
  - Data kept: same user, same secret key, the old session token still works, and
    the chat with its messages survived the migration.
  - Rollback from the backup back to v0.13.0, then the update again: both work.
- This laptop's Open WebUI was not touched: still v0.13.0, same container ID, never
  restarted.

## Initial state and scope

- Worktree: `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui-0-13-5`.
- Branch: `feat/open-webui-0-13-5`, base `f8299e9` (origin/main).
- Main checkout: `feat/mise-act-pinact` at `1bed8a3`, not touched.
  - Snapshot `6c87c520…d056a8` was taken before and after the mission and is
    unchanged (`E/main-tree-snap-baseline.txt`).
- Laptop baseline, read-only (`E/laptop-baseline.log`):
  - Container `open-webui` `96ee79d99b4e…`, image `ghcr.io/open-webui/open-webui:v0.13.0`,
    `Up 2 days (healthy)`.
  - Published on `192.168.10.217:3030`.
  - Filter unit `open-webui-firewall` enabled and active.
  - Local image `v0.13.0` only.
  - Volume `open-webui` is 1.118 GB. The owner is in the `docker` group.
- Drift, observed and not changed:
  - The live container is bound to `192.168.10.217:3030`, created 2026-11-09.
  - The repo, both in this worktree and the main checkout, sets
    `open_webui_bind_address: "0.0.0.0"` (commit `75c9ebc`, 2026-11-07).
  - The portainer-local report already notes this.
  - Consequence: the owner's apply will also republish the port on `0.0.0.0:3030`,
    IPv4 only and behind the existing filter. Caddy's upstream
    `http://192.168.10.217:3030` stays reachable.
- `curl http://127.0.0.1:3030/api/config` in the plan's step 1 fails on this laptop:
  the port is not on loopback. The runbook uses the published address.
- Evidence directory: `E=~/.local/share/laptop-bootstrap-agent/2026-11-28-open-webui-0-13-5/`.

## Work performed

Modified:
- `roles/open_webui/defaults/main.yml`: `open_webui_version: "v0.13.5"`.
- `roles/open_webui/README.md`: the default in the variables table, the expected
  image in "Owner validation", and the "verified on a VM" sentence under Updating.
- `README.md`: Open WebUI section, `v0.13.0` changed to `v0.13.5`.
- `BACKLOG.md`: "In progress" entry for this mission, `Last review: 2026-11-28`.

Created:
- `docs/missions/2026-11-28-open-webui-0-13-5/report.md` (this file).
- `mission.md`: state and log updated.

Left unchanged on purpose:
- `roles/open_webui/tasks/main.yml:14` keeps "such as v0.13.0". It is an example
  in an assert message, not the default (AC3 "role default only").
- Historical mentions of v0.13.0 in older missions and the role spec.
- README "Since v0.13.0 every setting is a row of the `config` table" stays: it is
  still true.

Executed, outside the repo:
- `uv sync --frozen --python 3.12` in the worktree. The default interpreter cannot
  build `rpds-py`; 3.12 is the main checkout's venv version.
- `virsh -c qemu:///system net-start vagrant-libvirt` and `start smoke_default`.
  - The existing smoke VM's Vagrant state lives in the portainer worktree (BACKLOG
    "Smoke VM domain name is shared by every worktree").
  - Starting the domain directly touches no other worktree's files.
  - `vagrant up` would have started the same network.
- VM runs used the worktree venv's Ansible over SSH (`E/run-vm.sh`, adapted from
  the portainer mission):
  - It rsyncs the worktree, without `.git`, `.venv` or the vault, to `E/tree/`, then
    runs `ansible-playbook -i E/inventory-vm.yml playbook.yml --tags open-webui`
    with the dummy vault password file.
  - `make smoke-replay TAGS=open-webui` cannot resolve `community.docker` in the
    VM (BACKLOG "Smoke VM cannot run roles that use `community.*` modules").

## Release analysis (AC1, AC2)

Target:
- Source: <https://github.com/open-webui/open-webui/releases>, queried with
  `gh release list -R open-webui/open-webui` (`E/releases-list.log`) and
  `gh api repos/open-webui/open-webui/releases/latest`.
- Result: `v0.13.5 2026-11-25T09:37:55Z prerelease=false`, marked Latest.
- Releases between the current and the target version:
  - v0.13.1 (2026-11-08T11:07Z)
  - v0.13.2 (2026-11-08T11:53Z)
  - v0.13.3 (2026-11-08T23:48Z)
  - v0.13.4 (2026-11-17)
  - v0.13.5 (2026-11-25)
- Full notes: `E/release-v0.13.{1..5}.json`. Topic extraction:
  `E/release-notes-analysis.md` (delegated, see Delegations). Key quotes were
  re-checked against the raw notes in this session.

Links:
- <https://github.com/open-webui/open-webui/releases/tag/v0.13.1>
- <https://github.com/open-webui/open-webui/releases/tag/v0.13.2>
- <https://github.com/open-webui/open-webui/releases/tag/v0.13.3>
- <https://github.com/open-webui/open-webui/releases/tag/v0.13.4>
- <https://github.com/open-webui/open-webui/releases/tag/v0.13.5>

Database migrations:
- v0.13.1: "Database Migrations: This release includes database schema changes; we
  strongly recommend backing up your database … before upgrading".
- v0.13.5: "Open WebUI 0.13.5 stores each chat message separately, so upgrading
  converts the history in your existing database. Back up the database … the old
  and new versions use incompatible formats." It adds: "The conversion runs in
  batches and can resume after an interruption."
- Observed on the VM (`docker logs`, `E/vm-after-1-data.log`): 7 Alembic revisions
  ran, from `e42c8f710a36` to `5e7a2c9d4b13`:
  - renewable auth sessions
  - per-user chat views
  - channel indexes
  - `terminal` grant renamed to `machine`
  - `resource_tag`
  - per-user folder views
  - "Keep chat messages only in chat_message rows"
- One-way: going back needs the pre-update backup. Rolling back by changing the
  tag on a migrated database is unsupported (role README → Rollback).

Breaking or behaviour changes that matter to this laptop. None needs a role change;
some may need admin attention:
- v0.13.1, "Preload files off by default": with native function calling, attached
  files are no longer injected. Models without tool support, or without the Files
  built-in tool, no longer see attachments until "Preload files" is turned on. In
  v0.13.4 the model's Capabilities section is renamed "Features".
- v0.13.1, retrieval defaults: unless saved values exist, `RAG_TOP_K` and
  `RAG_TOP_K_RERANKER` go from 3 to 10 and `CHUNK_SIZE` from 1000 to 1024. Existing
  knowledge keeps its chunks until reindexed; there is no forced reindex.
- v0.13.1 adds a full-text threshold: files under 50,000 characters are included in
  full rather than retrieved. In v0.13.5 the variables are
  `RAG_FULL_TEXT_THRESHOLD` and `RAG_FULL_TEXT_THRESHOLD_TYPE`; v0.13.1 named
  `RAG_FULL_TEXT_CHAR_THRESHOLD`.
- v0.13.4:
  - Direct Connections and Integrations are removed (moved to Tether), along with
    `ENABLE_DIRECT_*`.
  - Image env vars are converted to image connections on the first start.
  - Coding-agent model IDs changed.
  - Terminals 0.4.0 is required.
- v0.13.5:
  - Terminals become "Machines" (old env names still work).
  - Arena becomes routers.
  - Chat history API: read `chat.history`.
  - OpenAI connections default to the Responses API (not Ollama).
  - Docling switches to background jobs.
  - Admin Settings are reorganized.
- Security: v0.13.1 and v0.13.5 both carry unlisted security fixes ("strongly
  recommend updating"). No CVE or GHSA IDs are published yet.

Settings and env vars the role sets:
- `OLLAMA_BASE_URL`, `WEBUI_SECRET_KEY_FILE`, `WEBUI_URL`, `/health`,
  `HEALTHCHECK`, `DATA_DIR`, port and `start.sh`: no mention in v0.13.1-v0.13.5.
  A grep of the raw notes finds one hit, `TERMINALS_OPEN_WEBUI_URL`, a substring
  of `WEBUI_URL` and not a variable the role sets.
- `ENABLE_PERSISTENT_CONFIG` appears only for image env vars, which the role does
  not set.
- The role's healthcheck (`curl … /health | jq`) works on the v0.13.5 image: the
  container reached `healthy` on the VM.

Knowledge bases, embeddings, hybrid search, native tool calling (for the `wiki-tech` plan, D7):
- Knowledge:
  - v0.13.3: searches containing punctuation now match ("Art. 40").
  - v0.13.4: knowledge uploads use at most half of `THREAD_POOL_SIZE`;
    OpenAI-compatible vector stores can be external sources.
  - v0.13.5: batch knowledge imports keep page numbers; per-file choice between
    full text and retrieval; citation-to-claim default prompt.
- Embeddings:
  - No change to the default model, no forced reindex, no Chroma format change.
  - v0.13.4 fixes saving a local embedding-model folder.
  - v0.13.5 logs a Chroma embedding-dimension mismatch so admins know when to
    rebuild.
- Hybrid search, BM25: no mention in any of the five releases. Reranking: only the
  `RAG_TOP_K_RERANKER` default.
- Native tool calling: native calling is the default (v0.13.1).
  - Context arrives as hidden tool results.
  - Ollama tool-call fixes in v0.13.1 and v0.13.4.
  - v0.13.5 adds `TOOL_OUTPUT_MAX_CHARS` and on-demand tool discovery
    (`TOOL_SEARCH_LIST_TOOLS`).

## Verification and evidence

Checks of §4.2 for role changes (AC4). The dummy vault (§4.1) was used for every
Ansible command, and secret env vars were unset.

| Check | Command | Result | Status |
|---|---|---|---|
| ansible-lint | `uv run --no-sync .venv/bin/ansible-lint` | exit 0, "0 failure(s), 0 warning(s) in 96 files", profile production. Vault `Decryption failed` warnings are expected (`E/ansible-lint.log`) | VERIFIED |
| yamllint | `uv run --no-sync .venv/bin/yamllint .` | exit 0 (`E/yamllint.log`) | VERIFIED |
| syntax-check | `uv run --no-sync .venv/bin/ansible-playbook -i inventory.yml playbook.yml --syntax-check` | exit 0 (`E/syntax-check.log`) | VERIFIED |
| pre-commit | `pre-commit run --files <staged files>` (gitleaks included), plus the hooks at commit time | see the Git state section | VERIFIED at commit |

Smoke VM `smoke_default` (Ubuntu, 192.168.121.9), all with `--tags open-webui` (AC5):

| Step | Log | Result |
|---|---|---|
| Before | `vm-before.log` | v0.13.0 container already present from earlier missions; alembic `e42c8f710a36`; 0 users |
| 0. Baseline at v0.13.0 | `vm-00-baseline-v0130.log` (`-e open_webui_version=v0.13.0`) | `changed=2`: filter script and rules only. The sources moved from the portainer mission's `192.168.121.1` to this tree's `192.168.10.70`. Container unchanged |
| Seed | `vm-seed.log` | Throwaway admin created by signup (password generated in the VM, never printed). Chat `smoke-chat-v0130` with 2 messages |
| Backup (README) | `vm-backup.log` | `docker stop`, `alpine:3` tar, `docker start`. Archive `-rw------- root` 1,009,897,297 bytes |
| 1. Update | `vm-01-upgrade.log`, `vm-after-1.log` | exit 0, `ok=31 changed=1 failed=0`. The only changed task is "Run the Open WebUI container and wait until it is healthy". Image `:v0.13.5`, healthy, `/health` `{"status":true}`, `/api/config` version `0.13.5`, alembic `5e7a2c9d4b13`, 1 user, key sha256 prefix `e7c24f514b548474` unchanged |
| Data after update | `vm-after-1-data.log` | Old token: HTTP 200. Sign-in OK. Chat listed; `chat.history` holds both messages unchanged. Log: "moved the messages of 1 chats into chat_message" |
| 2. Idempotence | `vm-02-idempotence.log`, `vm-after-2.log` | exit 0, `changed=0`, same container `71d2d4557245` |
| Rollback rehearsal | `vm-rb-1-restore.log`, `vm-rb-2-v0130.log`, `vm-rb-2-probe.log`, `vm-rb-2-data.log` | Stop, then restore without start, then a role run at v0.13.0: `changed=1`, image v0.13.0, healthy, version 0.13.0, alembic `e42c8f710a36`, sign-in OK, chat intact |
| 3. Update again, 4. idempotence | `vm-03-reupgrade.log`, `vm-04-idempotence.log`, `vm-final.log` | `changed=1`, then `changed=0`. Final state v0.13.5, healthy, alembic `5e7a2c9d4b13` |

Note: the image pull took about 10 minutes on the VM (step 1 started 02:36Z, the
container was recreated at 02:46Z). The old container kept serving during the
pull. The recreation and migration took about 30 s with a tiny database.

Acceptance criteria:

| ID | Status | Evidence |
|---|---|---|
| AC1 | VERIFIED | v0.13.5, 2026-11-25T09:37:55Z, Latest, not a prerelease. URL above (`E/releases-list.log`) |
| AC2 | VERIFIED | Release analysis section, with links. Raw notes in `E/release-v0.13.*.json` |
| AC3 | VERIFIED | `git diff origin/main --stat`: defaults (1 line), role README, README, BACKLOG, mission files. No task or template change |
| AC4 | VERIFIED | ansible-lint, yamllint and syntax-check all exit 0 |
| AC5 | VERIFIED | VM update `changed=1`, second run `changed=0`; image `:v0.13.5` and `/api/config` `0.13.5` on the VM |
| AC6 | VERIFIED as written; NOT_VERIFIED as executed on the laptop | Owner runbook below. Backup, restore and rollback steps rehearsed on the VM. Ollama visibility was not testable on the VM (no Ollama there) |
| AC-SAFE | VERIFIED | Main snapshot unchanged. Laptop `open-webui` before and after: same ID `96ee79d99b4e…`, image `v0.13.0`, started `2026-11-25T22:56:03Z`, restarts 0, healthy (`E/laptop-baseline.log`, `E/laptop-final.log`). Laptop access was read-only: `docker inspect`, `docker ps`, `docker image ls`, `docker system df -v`, `systemctl is-*`, `ss`. No `make play*`, no `pass`, no vault, no `--diff`, no hook bypassed |

## Owner runbook — this laptop (AC6)

Run from this worktree, or from main after merge, as the owner. Notes:
- `docker` works without sudo (owner is in the `docker` group).
- `make play-open-webui` needs:
  - the vault password through `pass` (`ansible.cfg` → `bin/ansible-vault-pass.sh`;
    gpg may prompt);
  - sudo for `become: true` (`ANSIBLE_FLAGS` has no `-K`, so sudo must be usable
    without a prompt, or run `sudo -v` first).
- If the vault decrypt fails with "Cannot allocate memory": run
  `gpgconf --kill all`, then `./bin/ansible-vault-pass.sh >/dev/null`.

```bash
cd /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui-0-13-5

# 0. Optional: pull the image first, so the downtime does not include the ~1-2 GB pull
docker pull ghcr.io/open-webui/open-webui:v0.13.5

# 1. Backup (README "Backup and restore"). Stopping briefly is required for a consistent SQLite copy.
#    Keep the archive somewhere private; it holds the secret key and all user data.
mkdir -p ~/backups/open-webui && cd ~/backups/open-webui
docker stop open-webui
docker run --rm -v open-webui:/data:ro -v "$PWD":/backup alpine:3 \
  sh -c 'umask 077 && tar czf /backup/open-webui-v0.13.0-$(date +%Y%m%d-%H%M).tar.gz -C /data .'
docker start open-webui
ls -l ~/backups/open-webui            # expect ~1 GB, -rw------- root
cd -

# 2. Apply (vault via pass + sudo). Recreates the container on v0.13.5 and waits for healthy.
#    It also moves the port from 192.168.10.217:3030 to 0.0.0.0:3030 (repo value, filter unchanged).
make play-open-webui                  # expect failed=0; changed includes the container task

# 3. Checks
docker inspect open-webui --format '{{.Config.Image}}'                   # ghcr.io/open-webui/open-webui:v0.13.5
docker ps --filter name=open-webui --format '{{.Status}} {{.Ports}}'      # Up … (healthy) 0.0.0.0:3030->8080/tcp
curl -fsS http://127.0.0.1:3030/health                                    # {"status":true}
curl -fsS http://127.0.0.1:3030/api/config | jq -r .version               # 0.13.5
docker logs open-webui 2>&1 | grep -E 'Running upgrade|Migration progress'   # 7 revisions, ends at 5e7a2c9d4b13
docker exec open-webui curl -fsS http://host.docker.internal:11434/api/version   # Ollama reachable
sudo iptables -S OPEN-WEBUI-INGRESS                                       # 192.168.10.70 RETURN + DROP
ssh caddy-70 curl -fsS http://192.168.10.217:3030/health                  # via the homelab proxy path
make play-open-webui                  # second run: changed=0

# 4. UI: sign in at https://openwebui.internal (or http://127.0.0.1:3030) with the existing account;
#    check old chats open, and that the Ollama models appear in the model selector.
```

If step 2 fails on the health timeout (300 s): the v0.13.5 chat conversion runs at
start, in batches, and resumes after an interruption. Do not roll back right away.
- Watch `docker logs -f open-webui` for "Migration progress".
- Once `docker ps` shows `healthy`, rerun `make play-open-webui`.

Rollback (README "Rollback"). Only with the backup from step 1:

```bash
docker stop open-webui
cd ~/backups/open-webui
docker run --rm -v open-webui:/data -v "$PWD":/backup:ro alpine:3 \
  sh -c 'find /data -mindepth 1 -delete && tar xzf /backup/<archive>.tar.gz -C /data'
# do NOT docker start (v0.13.5 would migrate the restored database again)
cd -
# Pin the old tag for this laptop:
#   add  open_webui_version: "v0.13.0"  to group_vars/all/vars.yml
#   (or run from a checkout where the default is v0.13.0)
make play-open-webui                  # recreates on v0.13.0 from the restored data
curl -fsS http://127.0.0.1:3030/api/config | jq -r .version               # 0.13.0
```

After a successful update, optional cleanup:
`docker image rm ghcr.io/open-webui/open-webui:v0.13.0`, once rollback is no longer
wanted.

Post-update admin review, optional and not part of this mission:
- "Preload files", now under the model's "Features": needed if a model has no tool
  support and should still see attachments.
- Retrieval Top K and chunk size: the defaults changed.
- Reindex existing knowledge only if the new chunk size is wanted.

## Deviations, risks and limitations

- Smoke used SSH plus the worktree venv's Ansible, not `make smoke-replay`. This is
  the known VM collection gap, the same method as the previous Open WebUI and
  Portainer missions.
- The VM was started with `virsh`, not `vagrant up`, because its Vagrant state
  belongs to the portainer worktree.
- The VM is left running on v0.13.5, with a throwaway admin, a test chat and a
  backup archive in `/root/owui-backup/` (~1 GB). No `smoke-down` (needs approval).
  The libvirt network `vagrant-libvirt` was started.
- The VM database is tiny (1 user, 1 chat). Migration time on the laptop's real
  history is unknown. If it exceeds the 300 s health timeout, the run fails while
  the migration continues (see the runbook).
- Not verifiable on the VM: Ollama models (no Ollama there), the LAN path through
  Caddy, and the laptop's own history (stored settings, knowledge bases).
- Security advisories for v0.13.1 and v0.13.5 have no published details. Their
  content was not assessed.
- Laptop bind drift (`192.168.10.217` vs `0.0.0.0`): pre-existing, its cause is not
  investigated. The apply will align the laptop with the repo.

## Delegations (model economy)

- One `general-purpose` subagent on Sonnet:
  - Task: topic extraction from the five release-note bodies, written to
    `E/release-notes-analysis.md`.
  - Cross-checked in this session: grep of the raw notes for the migration,
    security and retrieval quotes and for the role's env vars.
- Everything else was done in this session: inspection, implementation, lint, VM
  runs, rollback rehearsal, report.

## Git state

- Branch `feat/open-webui-0-13-5`, one commit on top of `f8299e9`. The hash is
  given at the end of the executor's turn: "Version".
- Commit authorized by the mission. Not pushed, no PR, no merge.
- pre-commit ran on the staged files and again as the commit hook. Not bypassed.

## Decisions required

- D1, after the Codex review: the owner chooses when to run the runbook above. It
  is mutating: brief downtime, a one-way migration, vault and sudo.
- Then push and PR (not authorized in this mission).

## Recommended next action

Codex review of this branch, routed by the pilot. Then the owner runs the runbook.
