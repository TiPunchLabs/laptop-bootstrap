# Report — 2026-11-28-open-webui-0-13-5 — Upgrade Open WebUI to v0.13.5

## Verdict

PARTIAL, pending review 3, the last cycle.

- Review 1 (F1.1, F1.2 major; F1.3 minor) and review 2 (F2.1 major; F2.2 minor,
  plus one over-broad sentence) both returned CHANGES_REQUESTED. All their findings
  are fixed in this revision (see Reviews).
- VERIFIED: AC1-AC5 and AC-SAFE.
- AC6: every published update and rollback procedure is now one guarded block. The
  exact documented blocks were run on the VM with failing backups, failing
  restores, a refused restart and a failed swap. Running them on the laptop is a
  later step, after a review with no blocker or major finding.
- PASS needs review 3 (docs/agent-workflow.md §7).

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
- Fix 1, after review 1:
  - New `bin/open-webui-volume.sh` (`backup` / `restore`). It stops at the first
    failure.
  - The backup checks the exact archive it wrote and gates the apply (`&&`).
  - The restore validates the archive and extracts it into a staging volume before
    the live volume is touched. It keeps the previous content in a `prerestore`
    volume and puts it back if the swap fails.
  - Rehearsed on the VM: 3 backup failures, 3 restore failures, a closed gate,
    rollback to v0.13.0, then a gated update and `changed=0`.
- Fix 2, after review 2:
  - The README update block is now one `( set -euo pipefail … )` subshell, so
    neither apply can run after a failed backup. The same guard is used for the
    report's update block (the checks and second run were folded in) and for both
    rollback blocks.
  - A refused restart after a good backup now exits 1.
  - Restore failure states are documented per stage.
  - The four documented blocks were extracted verbatim and run on the VM: no apply
    was reached after any failure. The put-back branch is now exercised (fault
    injection).
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
- Fix 1: `bin/open-webui-volume.sh`, backup/restore of the Open WebUI volume
  (F1.1, F1.2).

Modified in fix 2:
- `bin/open-webui-volume.sh`: the backup's EXIT trap returns 1 when the restart
  fails (F2.2), and the header documents it.
- `roles/open_webui/README.md`:
  - "Install and update" points to Updating for a version change.
  - Updating: steps renumbered; step 3 is one guarded block (backup, apply,
    checks, second apply); health-timeout note.
  - Backup and restore: restart-failure exit, failure state per restore stage,
    kept volumes, quoted placeholder.
  - Rollback: one guarded block (`archive`/`old` set first, restore, pin, apply).
- `report.md`: the runbook update and rollback blocks are guarded subshells, and the
  restore failure states are listed per stage (the review-2 sentence).

Modified in fix 1:
- `roles/open_webui/README.md`, sections "Updating" step 1 and deploy snippet,
  "Backup and restore", "Rollback": they now use the script. The old commands had
  the same flaws as the runbook.
- `BACKLOG.md`: Cleanup entry for the same restore pattern in
  `roles/portainer/README.md` (out of scope here).
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
| AC6 | VERIFIED as written and VM-rehearsed (fixes 1 and 2); NOT_VERIFIED as executed on the laptop | Owner runbook below. Every update and rollback block is one guarded subshell; the documented blocks ran verbatim on the VM with failing backups, failing restores, a refused restart and a failed swap: no apply reached after a failure ("Verification of fix 2"). Ollama visibility was not testable on the VM (no Ollama there) |
| AC-SAFE | VERIFIED | Main snapshot unchanged. Laptop `open-webui` before and after: same ID `96ee79d99b4e…`, image `v0.13.0`, started `2026-11-25T22:56:03Z`, restarts 0, healthy (`E/laptop-baseline.log`, `E/laptop-final.log`, after fix 1 `E/laptop-final-fix1.log` and fix 2 `E/laptop-final-fix2.log`: same values, volumes `open-webui` and `brain-rag_open-webui` only). Laptop access was read-only: `docker inspect`, `docker ps`, `docker image ls`, `docker system df -v`, `systemctl is-*`, `ss`. No `make play*`, no `pass`, no vault, no `--diff`, no hook bypassed |

## Verification of fix 1 (review 1, F1.1 and F1.2)

Script checks:
- `pre-commit run shellcheck` and `shfmt` on `bin/open-webui-volume.sh`: Passed.
  One file-level `SC2016` disable, because the single-quoted strings are scripts
  for the helper container.
- `bash -n`: OK.
- Copied to the VM as `/tmp/open-webui-volume.sh` after the last lint fix. sha256
  prefix `a4b8fb5fa41eef5c` is identical on the host and the VM, before and after
  the rehearsal (`E/script-sha256.txt`): the rehearsed script is the committed one.

The VM's 2.0 GB of free space was too little for staging plus prerestore, so
`apt-get clean` was run on the VM (4.3 GB free afterwards).

| Case | Log | Observed | Status |
|---|---|---|---|
| Backup (a): missing destination | `vm-fix1-backup-failures.log` | `FAILED: destination … does not exist`, exit 1; container `StartedAt` unchanged (never stopped) | VERIFIED |
| Backup (b): 100 MB tmpfs destination | same | `FAILED: not enough space … 102400 KiB free, volume 1092292 KiB`, exit 1, before any stop; destination empty | VERIFIED |
| Backup (c): failure after stop (test container `owui-t`, volume without a secret key) | same | Archive written as `.partial`; check `.webui_secret_key: Not found in archive` → `FAILED: archive check failed`, exit 1. Trap restarted the container (new `StartedAt`). No final `.tar.gz`. Test container and volume removed | VERIFIED |
| Backup, success, gate open | `vm-fix1-backup-ok.log` | `archive checked: gzip complete, webui.db integrity ok, secret key present`; only the path on stdout; archive `-rw------- root` 1,009,903,622 bytes; container restarted | VERIFIED |
| Gate closed | `vm-fix1-gate-closed.log` | `archive=$(… backup /root/does-not-exist) && run-vm.sh …` → chain exit 1; the apply log was never created | VERIFIED |
| Restore (a): `<archive>` placeholder | `vm-fix1-restore-failures.log` | `FAILED: replace the <archive> placeholder`, exit 1 | VERIFIED |
| Restore (b): missing file | same | `FAILED: archive … does not exist`, exit 1 | VERIFIED |
| Restore (c): truncated archive (first 200 MB) | same | `gzip: … unexpected end of file` → `FAILED: archive check failed, nothing changed`, exit 1 | VERIFIED |
| Restore failures: live data untouched | same | Before and after: container running, same `StartedAt`, `webui.db` sha256 prefix `c1bbac3054d86e8f`, only the `open-webui` volume | VERIFIED |
| Restore, success → rollback | `vm-fix1-restore-ok.log`, `vm-fix1-rb-v0130.log`, `vm-fix1-rb-probe.log`, `vm-fix1-rb-data.log` | Archive checked, staging extracted and checked, container stopped and left stopped, `prerestore` volume kept, staging removed. Role at v0.13.0: `changed=1`, healthy, version 0.13.0, alembic `e42c8f710a36`, sign-in OK, chat intact | VERIFIED |
| Gated update, then idempotence | `vm-fix1-gated-upgrade.log`, `vm-fix1-upgrade.log`, `vm-fix1-idempotence.log`, `vm-fix1-final.log` | `archive=$(backup) && apply`: `GATE OPEN`, `changed=1`; second run `changed=0`; v0.13.5 healthy, alembic `5e7a2c9d4b13` | VERIFIED |
| Restore: put-back after a failed swap (live content replaced, then the check fails) | — | Not executed in fix 1; executed in fix 2 (T9) | see fix 2 |

## Verification of fix 2 (review 2, F2.1 and F2.2)

Method:
- Each documented block was extracted verbatim from the files by a fenced-block
  parser (`E/blocks/`, sha256 in `E/blocks/blocks-sha256.txt`):
  - `roles/open_webui/README.md`: the update block (Updating step 3) and the
    rollback block;
  - `report.md`: the update block and the rollback block.
- Only edit for the VM: the report blocks' absolute `cd` path became
  `/tmp/lbtest/repo` (`vm-report-*.sh`; diff limited to that line). The README
  blocks are byte-identical.
- They ran on the smoke VM as root, with `bash -s < block`, from a test checkout:
  the script plus a copy of the public `group_vars/all/vars.yml`.
- `make` and `ssh` were stubs that only record the call (`apply.log`). A
  `docker` shim (`SHIM_MODE`) refused `docker start`, or ran the swap command and
  then reported failure.
- Fault tests used a throwaway container `owui-t` (image v0.13.5, `sleep`) with a
  small volume (SQLite db + key), selected through `OPEN_WEBUI_CONTAINER` and
  `OPEN_WEBUI_VOLUME`. Tests T1, T2, T6, T7 and T8 ran against the real VM
  `open-webui`.
- Script on the VM: sha256 prefix `a071da8b919466f9`, identical to the committed
  file.
- Logs: `vm-fix2-setup.log`, `vm-fix2-tests.log`, `vm-fix2-tests-t9-t10.log`,
  `vm-fix2-cleanup.log`, `vm-fix2-final.log`.

| Test | Block / call | Fault | Observed | Status |
|---|---|---|---|---|
| T1 | README update | backup destination is a 100 MB tmpfs | `FAILED: not enough space`; block exit 1; applies reached 0; `open-webui` `StartedAt` unchanged | VERIFIED |
| T2 | report update | same | the image pull ran, then the same `FAILED`; block exit 1; applies 0; `open-webui` unchanged | VERIFIED |
| T3a | report update (`owui-t`) | `docker start` refused after a good backup | archive checked, `FAILED: docker start owui-t; start it by hand`; block exit 1; applies 0; the valid archive is present (0600); `owui-t` stopped | VERIFIED (F2.2) |
| T3b | direct `backup` (`owui-t`) | same | script exit 1, stdout = the archive path | VERIFIED (F2.2) |
| T4 | README update (`owui-t` backup) | none | `validated backup …`, apply 1, image and version checks, apply 2; block exit 0; applies 2 | VERIFIED |
| T5 | README rollback, unchanged | `old=vX.Y.Z` left as is | `set old= to the previous tag`; block exit 1; applies 0; `vars.yml` sha unchanged, no pin | VERIFIED |
| T6 | README rollback, `old=v0.13.0` | `<archive>` left as is | `FAILED: replace the <archive> placeholder`; exit 1; applies 0; `vars.yml` unchanged; `open-webui` unchanged | VERIFIED |
| T7 | report rollback, unchanged | `<archive>` left as is | same refusal; exit 1; applies 0; `vars.yml` unchanged | VERIFIED |
| T8 | report rollback | truncated archive (200 MB) | `gzip: unexpected end of file`, `FAILED: archive check failed, nothing changed`; exit 1; applies 0; `vars.yml` unchanged; `open-webui` db sha `84a850a0c2f40762` before and after, `StartedAt` unchanged | VERIFIED |
| T9 | direct `restore` (`owui-t`) | swap runs, then reported failed | `replacing the live content failed; putting the previous content back`; exit 1; live db sha `9a251e19607f6c93` (pre-restore state) before and after, not the archive's `9a930c809f131229`; container stopped; staging and prerestore volumes kept | VERIFIED (was NOT_VERIFIED in fix 1) |
| T10 | report rollback (`owui-t`, valid archive) | none | restore OK, container left stopped, pin `open_webui_version: "v0.13.0"` written, apply 1 reached; block exit 0; live db sha = archive's `9a930c809f131229` | VERIFIED |

- T9 and T10 first ran with an empty archive variable: the harness expanded a
  `/root` glob as the unprivileged user. The script refused with its usage error,
  and nothing changed (`vm-fix2-tests.log`). They were rerun with the glob
  expanded under sudo (`vm-fix2-tests-t9-t10.log`).
- After the tests, `owui-t`, its volumes, `/root/backups` and `/tmp/lbtest` were
  removed from the VM.
- The VM `open-webui` is still v0.13.5, healthy, alembic `5e7a2c9d4b13`, with
  `StartedAt` unchanged since fix 1's gated update.

Other copies of the procedure, checked for an apply reachable after a failure:
- Role README "Install and update": a bare `make play-open-webui` for installs. It
  now says to use the guarded Updating block for a version change.
- Role README "Owner validation" (line ~109) and "LAN access → Verify" (line ~354):
  checklists after an install or a bind change, with no version change and no
  backup step to bypass. Left as is.
- Top-level `README.md` Open WebUI paragraph: prose only, no commands.
- Mission report: update and rollback blocks guarded (T2, T3a, T7, T8, T10).

## Owner runbook — this laptop (AC6)

Fail-safe since fix 2. Each procedure is one block run in a subshell with
`set -euo pipefail`, which stops at the first failing command without closing the
terminal. No `make play-open-webui` (first or second) can run after a failed
backup, and no apply can run after a failed restore. Paste each block whole, never
in parts.

Who runs what:
- `bin/open-webui-volume.sh` and `docker` need no sudo: the owner is in the
  `docker` group.
- `make play-open-webui` needs:
  - the vault password through `pass` (`ansible.cfg` → `bin/ansible-vault-pass.sh`;
    gpg may prompt);
  - sudo for `become: true`. `ANSIBLE_FLAGS` has no `-K`, so the block runs
    `sudo -v` first.
- If the vault decrypt fails with "Cannot allocate memory": run
  `gpgconf --kill all`, then `./bin/ansible-vault-pass.sh >/dev/null`.

Update:

```bash
(
  set -euo pipefail
  cd /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui-0-13-5   # or main after merge
  mkdir -p ~/backups/open-webui
  sudo -v                                   # cache sudo for the play
  docker pull ghcr.io/open-webui/open-webui:v0.13.5   # before any stop; the old container keeps serving

  # 1. Backup: stops the container, writes and checks the archive, starts the container again.
  #    Any failure (including a failed restart) ends the block here.
  archive=$(bin/open-webui-volume.sh backup ~/backups/open-webui)
  echo "validated backup (the only way back, keep it): $archive"

  # 2. Apply (vault via pass + sudo): v0.13.5 on 0.0.0.0:3030, waits for healthy.
  make play-open-webui

  # 3. Checks, then the second run.
  docker inspect open-webui --format '{{.Config.Image}}'                  # ghcr.io/open-webui/open-webui:v0.13.5
  docker ps --filter name=open-webui --format '{{.Status}} {{.Ports}}'     # Up … (healthy) 0.0.0.0:3030->8080/tcp
  curl -fsS http://127.0.0.1:3030/health; echo                             # {"status":true}
  curl -fsS http://127.0.0.1:3030/api/config | jq -r .version              # 0.13.5
  make play-open-webui                                                     # second run: changed=0

  # 4. Further checks.
  docker logs open-webui 2>&1 | grep -E 'Running upgrade|Migration progress'   # 7 revisions, ends at 5e7a2c9d4b13
  docker exec open-webui curl -fsS http://host.docker.internal:11434/api/version; echo   # Ollama reachable
  sudo iptables -S OPEN-WEBUI-INGRESS                                      # 192.168.10.70 RETURN + DROP
  ssh caddy-70 curl -fsS http://192.168.10.217:3030/health; echo           # homelab proxy path
)
```

Then sign in at <https://openwebui.internal> (or <http://127.0.0.1:3030>) with the
existing account. Check that old chats open and that the Ollama models appear in the
model selector.

If the block stops at step 2 on the health timeout (300 s): the v0.13.5 chat
conversion runs at start, in batches, and resumes after an interruption. Do not roll
back right away.
- Watch `docker logs -f open-webui` for "Migration progress".
- Once `docker ps` shows `healthy`, run `make play-open-webui` again, then the
  checks.

If the block stops at step 1:
- No archive is printed: nothing was upgraded. The container was restarted, or
  `FAILED: docker start` says it was not; then run `docker start open-webui` once
  the cause is fixed.
- If the only failure is the restart, an archive is printed and valid. The block
  still stops, so start the container, then run the block again.

Rollback, only with the archive printed at step 1. Set `archive` on the block's
first line:

```bash
(
  set -euo pipefail
  archive="$HOME/backups/open-webui/<archive>.tar.gz"   # the path printed at step 1
  cd /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui-0-13-5
  # Checks the archive, extracts and checks it in a staging volume, keeps the current
  # content in open-webui-prerestore-<ts>, then swaps. The container is left STOPPED:
  # never `docker start` it after a successful restore, v0.13.5 would migrate again.
  bin/open-webui-volume.sh restore "$archive"
  # Pin the old tag for this laptop, then let the role start it.
  if grep -q '^open_webui_version:' group_vars/all/vars.yml; then
    sed -i 's/^open_webui_version:.*/open_webui_version: "v0.13.0"/' group_vars/all/vars.yml
  else
    echo 'open_webui_version: "v0.13.0"' >> group_vars/all/vars.yml
  fi
  make play-open-webui
  curl -fsS http://127.0.0.1:3030/api/config | jq -r .version            # 0.13.0
)
```

Left unchanged, the `<archive>` placeholder is refused by the script before anything
is touched, and the block stops. Once v0.13.0 works, remove the prerestore volume
(`docker volume ls -q | grep prerestore`, then `docker volume rm` that name). Remove
the pin from `vars.yml` when the role default is meant to apply again.

A restore needs about 2.2 GB free in Docker's storage (staging and prerestore
copies of the 1.1 GB volume). Each `FAILED` leaves this state:
- Before the stop (placeholder, missing file, archive check, extraction or staging
  check): nothing changed, and the container keeps running.
- After the stop, before the swap (stop not confirmed, prerestore copy failed): the
  volume is untouched, but the container may be stopped. `docker start open-webui`
  is safe: the data was not changed.
- Swap or post-swap check failed: the previous content is put back from the
  prerestore volume, and the container is left stopped. `docker start open-webui`
  is safe again.
- If the put-back itself fails, the script says so. Copy the prerestore volume back
  by hand, and do not start the container.

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
- The VM is left running on v0.13.5. Left on it:
  - a throwaway admin and a test chat;
  - backup archives in `/root/owui-backup/` and `/root/owui-backup2/` (~1 GB each);
  - the script in `/tmp/`.
  No `smoke-down` (needs approval). The libvirt network `vagrant-libvirt` was
  started. Fix 1 ran `apt-get clean` on the VM to free space.
- The put-back branch was exercised by fault injection: a `docker` shim made the
  swap report failure after running. A real disk or I/O failure during the swap,
  or a failure of the put-back itself, was not reproduced.
- The blocks were tested with stub `make` and `ssh`. The real applies and checks
  inside them were exercised separately (fix 1 gated update, initial smoke runs).
  The `pass` and sudo prompts of the real `make play-open-webui` cannot be
  exercised on the VM.
- The script trusts the container's own image to provide `tar`, `gzip` and
  `python3`. This is true for v0.13.0 and v0.13.5 (rehearsed on both); a future
  image could drop one of them, and the script would then fail closed.
- The VM database is tiny (1 user, 1 chat). Migration time on the laptop's real
  history is unknown. If it exceeds the 300 s health timeout, the run fails while
  the migration continues (see the runbook).
- Not verifiable on the VM: Ollama models (no Ollama there), the LAN path through
  Caddy, and the laptop's own history (stored settings, knowledge bases).
- Security advisories for v0.13.1 and v0.13.5 have no published details. Their
  content was not assessed.
- Laptop bind drift (`192.168.10.217` vs `0.0.0.0`): pre-existing, its cause is not
  investigated. The apply will align the laptop with the repo.

## Reviews

Review 1, by Codex, routed by the pilot (`review-1.md`): CHANGES_REQUESTED.

- F1.1 [major]: the backup did not gate the apply. FIXED.
  - `bin/open-webui-volume.sh backup` checks space before any stop, then stops the
    container and verifies the stop.
  - It writes a uniquely named `.partial`, then checks that exact file (gzip
    stream, `webui.db` integrity, secret key present, contents never printed).
  - Only then does it rename the file and print its path.
  - The container is restarted on every exit.
  - The runbook runs as one `set -euo pipefail` block, so the apply runs only
    after the validated backup.
  - The image pull is done before the stop. The helper is the container's own
    image, so no helper pull is needed.
  - Evidence: "Verification of fix 1", rows backup (a)-(c), success and gate
    closed.
- F1.2 [major]: the restore deleted data before validating the archive. FIXED.
  - It refuses placeholders and missing files, checks the archive, then extracts
    it into a staging volume and checks the extracted data. Up to that point the
    live data is untouched.
  - Only then does it stop the container, copy the current content to a
    `prerestore` volume, swap, and re-check, putting the previous content back on
    failure.
  - The container is left stopped. The never-start-v0.13.5-on-restored-data rule
    is kept.
  - The role README's "Backup and restore" and "Rollback" sections are aligned.
  - Evidence: rows restore (a)-(c) and the restore → rollback row.
- F1.3 [minor]: authorization not reconciled. FIXED (accepted in review 2).
  - "Authorizations and decisions" below quotes the owner's conditional grant from
    the mission log.
  - Review 1 had major findings, so the condition is not met yet: no push, PR,
    merge or laptop apply was done.

Review 2, by Codex (`review-2.md`): CHANGES_REQUESTED. It accepted F1.2 and F1.3.

- F2.1 [major]: in the README update example, only the first apply was behind
  `&&`; the second `make play-open-webui` ran after a failed backup. FIXED.
  - The README Updating step 3 is one `( set -euo pipefail … )` subshell: backup,
    apply, checks, second apply. A subshell is used because a bare `set -e` pasted
    into an interactive shell would close it.
  - The same guard is used in the README Rollback (new block) and in the report's
    update block, where the formerly separate checks block with its second apply
    is now inside. The report's rollback block is guarded too.
  - Fixed on the way: an unquoted `<archive>` / `<timestamp>` placeholder is shell
    redirection syntax, not a literal word. The placeholders are now quoted, and
    the archive path is a variable on the block's first line.
  - Evidence: the complete documented blocks were run with a failing backup (T1,
    T2), a refused restart (T3a) and failing restores (T5-T8): applies reached 0.
    T4 and T10 show the success paths.
- F2.2 [minor]: a failed restart after a successful backup exited 0. FIXED.
  - The EXIT trap keeps an existing failure status, and sets 1 when the restart
    fails.
  - Documented in the script header and the README; the archive stays valid.
  - Evidence: T3b, exit 1 with the archive path on stdout.
- Report sentence ("if the failure came before the swap, nothing changed and the
  container keeps running"): too broad. FIXED.
  - The report runbook and the README now list the state per stage. Before the
    stop: nothing changed, the container is running. After the stop, before the
    swap: the volume is untouched, the container may be stopped, and
    `docker start` is safe. Swap failure: put back, the container is stopped.
    Put-back failure: by hand.
- Reservation on put-back not being exercised: now exercised (T9).

## Delegations (model economy)

- One `general-purpose` subagent on Sonnet:
  - Task: topic extraction from the five release-note bodies, written to
    `E/release-notes-analysis.md`.
  - Cross-checked in this session: grep of the raw notes for the migration,
    security and retrieval quotes and for the role's env vars.
- Everything else was done in this session: inspection, implementation, lint, VM
  runs, rollback rehearsal, report.

## Git state

- Branch `feat/open-webui-0-13-5` on top of `f8299e9`:
  - `c318c0b`: the version bump.
  - `c364acb`: fix 1.
  - The fix-2 commit, whose hash is given at the end of the executor's turn
    ("Version").
- Not pushed, no PR, no merge.
- pre-commit ran on the staged files and as the commit hook. Not bypassed.

## Authorizations and decisions

- Mission header: commit on the branch only.
- Owner grant, recorded in the mission log on 2026-11-28 ("tu es autorisé à faire :
  il te restera à pousser, ouvrir la PR, fusionner, et appliquer la mise à jour sur
  ton portable"). It applies to this mission only, and only after a Codex review
  with no blocker or major finding:
  - push `feat/open-webui-0-13-5`;
  - open a PR to `main`;
  - merge, keeping the commits, once CI is green;
  - then the laptop apply per the runbook above.
- Steps that need the real vault (`pass`) or an interactive sudo password stay with
  the owner. The pilot routes these steps; the executor does not start them.
- Status: reviews 1 and 2 had major findings, so the condition is not met. Nothing
  beyond the commits was done. Review 3, the last cycle, decides.

## Recommended next action

Codex review 3 of this branch, the last cycle, routed by the pilot.

- If it has no blocker or major finding, the owner's grant applies: push, PR,
  merge once CI is green, then the laptop runbook. The `pass` and sudo prompts stay
  with the owner.
- If findings remain open after review 3, the workflow requires a BLOCKED or
  PARTIAL report listing them.
