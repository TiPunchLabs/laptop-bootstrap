# Review 1 — 2026-11-07-remove-caddy-postgresql

VERDICT: CHANGES_REQUESTED

## Findings

- F1.1 [blocker] mission.md:106 — The September clients remain explicitly unresolved, but are classified as non-blocking despite the objective's requirement of no unresolved consumer (lines 20–21). Fifty-four zero-client samples over nine minutes establish only that observation window. An existing database can serve an intermittent client without new DDL, and a backup does not prevent a service interruption. The recorded owner decision resolves mo-kreyol-platform's intended use; it does not document an informed exception for unidentified clients. Expected fix: resolve these clients with evidence, or document an explicit owner exception covering this uncertainty if one was granted; otherwise retain the generic PostgreSQL runtime.
- F1.2 [major] mission.md:148 — `backup-sha256.txt` contains no checksum for `pg-dumpall.sql`, `pg-globals.sql`, or any of the three custom dumps. Consequently the restore comparison cannot be tied by checksum to the logical artifacts retained for recovery before deleting the only live volume. Its unrelated-patch entry also uses a literal `~/` path, so ordinary `sha256sum -c` fails. Expected fix: include all logical backups with usable paths, identify the artifact used for the successful restore, and record a successful complete checksum verification before deletion. All eight existing entries match when the tilde is expanded explicitly.
- F1.3 [major] mission.md:157 — The claim that the post-restore volume list equals baseline is contradicted by the supplied files: `diff -u vol-pre.txt vol-now.txt` finds an added anonymous volume, `2ef379cce928a3fee22dd9fcdd7e6abc3136c17d9738e84e2762afeb664eaa38`. These files might precede final cleanup, but no later inventory establishes the claimed result. Expected fix: supply the actual final inventory and account for this volume; correct the claim if cleanup is incomplete. Do not remove an unidentified volume or prune.
- F1.4 [major] mission.md:175 — AC1 is marked VERIFIED, but the supplied inventory contains names/images and network membership, not the container labels, bind mounts, published ports, restart policy, or volume attachment evidence supporting the ownership table and exclusive deletion targets. The reference sweep supplies filenames rather than rendered configuration evidence. My Docker verification attempts were denied by the sandbox. Expected fix: retain sanitized inspect output showing the generic container's exact ID, Compose owner/path, mounts, ports and policy; all containers using its volume; and any container mounts under the three directory targets. Supply the relevant sanitized startup/listener checks, or downgrade the unsupported portions of AC1 and withhold their deletion approval.
- F1.5 [minor] mission.md:115 — Comparing current CA fingerprints cannot establish that these CAs were *never* trusted, and a matching source filename does not establish ownership of `caddy-root.crt`. Only `caddy-internal.crt` was independently readable; its fingerprint matches the mission. The second trust-store certificate and both laptop root paths were inaccessible, and no complete fingerprint command output is retained in the evidence directory. Expected fix: provide public-certificate fingerprints and dates with exact paths, distinguish observed identity from inferred ownership, and limit the statement to present trust evidence. Keep all trust-store certificates out of the deletion plan.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | NOT_VERIFIED | Repository ownership mapping is plausible; runtime attachment/identity evidence is incomplete (F1.4). |
| AC2 | VERIFIED | Consumer matrix exists and names unresolved cases; all 54 authoritative samples report zero clients/TCP sessions. This does not satisfy the deletion prerequisite (F1.1). |
| AC3 | NOT_VERIFIED | Backup directory is 0700 and listed files are 0600; eight manifest entries match after path expansion. Unrelated patch applies to 65c5de2 and preserves exactly the unrelated hunks. Bundle/base-patch recoverability and archive completeness have only narrative assertions, without saved verification output. |
| AC4 | VERIFIED, limited | Four source/restore files are byte-identical: roles, databases, tables and counts/version/enums. Restore log contains the two disclosed postgres-role errors and no other ERROR. Retained-artifact integrity and restore cleanup remain findings F1.2–F1.3; password-hash and custom-restore assertions lack retained output. |
| AC5 | VERIFIED | 65c5de2 removes the complete Caddy role, flag, encrypted vault file and playbook entries; no tracked Caddy reference remains outside CHANGELOG. Current documentation changes agree. Supplied syntax/lint/hook logs support the reported checks. |
| AC6 | VERIFIED | Both repositories' local `origin/main` trees have no generic PostgreSQL role. The two feature commits remain on `feature/postgresql`; cleanup starts from 3bc15a4 and introduces no PostgreSQL deployment support. Semaphore's project database remains intact. |
| AC7 | NOT_VERIFIED | Runtime deletion is intentionally pending; steps 1–3 must remain pending under F1.1. |
| AC8 | NOT_VERIFIED | Baseline records healthy retained apps; no post-deletion comparison exists. Volume evidence currently differs (F1.3). |
| AC9 | VERIFIED | This independent review precedes the planned runtime deletion; it does not approve the full plan. |
| AC10 | NOT_VERIFIED | PRs/CI are later work; no network checks performed. |
| AC-SAFE | NOT_VERIFIED | Reviewed commit deletes encrypted vault bytes without decryption and changes no unrelated roles. Hook logs show checks passed. Unrelated edits remain in the owner checkout and applicable patch. Whole-session conduct and preservation snapshots were not independently re-established. |

## Deletion plan verdict

- step 1: reject — F1.1 leaves the consumer prerequisite unmet; runtime identity evidence also needs F1.4. Recheck exact identity immediately before any subsequently authorized action.
- step 2: reject — depends on step 1, complete logical-backup integrity evidence and exclusive volume ownership (F1.1, F1.2, F1.4).
- step 3: reject — retain the rendered generic PostgreSQL configuration while its consumer/deletion decision remains open.
- step 4: reject — target is appropriately narrow and its archive checksum matches, but provide the missing mount/ownership evidence before runtime directory removal (F1.4). This is independent of the PostgreSQL consumer issue.
- step 5: reject — same missing attachment evidence as step 4; the directory is also still listed as untracked owner work. Its archive checksum matches, but deletion must follow the documented evidence gate.

The repository Caddy removal itself is acceptable. The plan correctly retains `local_network`, `postgres:17-alpine`, all other project databases and trust-store CAs, and includes no prune or shared-resource deletion. Existing Portainer code/defaults are inherited unchanged from main; the unrelated patch preserves the owner's `deploy_portainer: false` and `remove_orphans: true` edits. Deployment remains an owner action.

## Commands run

Paths below abbreviate the exact roots used: `E=/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-07-remove-caddy-postgresql`, `A=/home/xgueret/Workspace/02-infrastructure/local/ansible-docker-apps-worktrees/remove-caddy`, `O=/home/xgueret/Workspace/02-infrastructure/local/ansible-docker-apps`, `B=/home/xgueret/Backups/caddy-postgresql-2026-11-07`, `M=docs/missions/2026-11-07-remove-caddy-postgresql`. Grouped reads below summarize the actual file arguments; they are not claims of rerunning the recorded checks.

- `cat AGENTS.md "$M/review-brief-1.md" CLAUDE.md docs/agent-workflow.md` → exit 0, read scope and rules.
- `cat "$M/mission.md"`; `nl -ba "$M/mission.md"` → each exit 0, reviewed criteria and cited lines.
- `git status --short`; `git diff HEAD --stat`; `git diff HEAD` → each exit 0, mission directory untracked; no tracked diff in this worktree.
- `git -C "$A" diff --stat origin/main..HEAD`; `git -C "$A" show HEAD` → each exit 0, reviewed 13-file removal, 10 insertions/252 deletions, commit 65c5de2.
- `git -C "$A" status --short` → exit 0, clean.
- `git -C "$A" grep -in caddy HEAD -- ':!CHANGELOG.md'` → exit 1, no active tracked references (also rerun separately with the same result).
- `git -C "$A" ls-tree -r --name-only origin/main`; `git ls-tree -r --name-only origin/main -- roles group_vars playbook.yml` → each exit 0, no generic PostgreSQL role on either local remote-tracking main.
- `git -C "$A" apply --check "$B/ada-unrelated-local-changes.patch"` → exit 0, applies without editing any checkout/index.
- `git -C "$O" diff -- group_vars/all/main.yml roles/portainer/tasks/main.yml`; `cat "$B/ada-unrelated-local-changes.patch"` → each exit 0, unrelated hunks preserved exactly; this patch is the brief's explicit nonsecret exception.
- `git -C "$O" log --oneline origin/main..feature/postgresql` → exit 0, exactly 04021f9 and 3e29b22.
- `git -C "$O" show feature/postgresql:roles/postgresql/templates/docker-compose.yml.j2`; `git -C "$O" show feature/postgresql:roles/postgresql/vars/main.yml` → each exit 0, reviewed deployment mapping and credential variable references, not credential values.
- `cat "$A/deploy.yml" "$A/uninstall.yml" "$A/ansible.cfg"` → exit 0, role references consistent; no playbook execution.
- `git -C "$A" diff --check origin/main..HEAD`; `git -C "$A" show --format=fuller --stat HEAD`; `git -C "$A" diff origin/main..HEAD -- CLAUDE.md` → each exit 0, clean whitespace and consistent focused change.
- `rg -n -i 'postgresql|caddy' roles group_vars/all/vars.yml playbook.yml --glob '!vault/**'` → exit 0, only explanatory homelab Caddy references in the Open WebUI README; no generic PostgreSQL deployment reference.
- `ls -la "$E/"`; `cat "$E/pre-inventory.txt" "$E/ref-sweep-5432.txt" "$E/session-sampling-3.txt"` → each exit 0, inspected available evidence.
- `cat` of `E/restore-psql.log`, all eight `src-*`/`rst-*` catalog files → exit 0, reviewed restored catalog and disclosed errors.
- `python3 -c <byte-compare the four src/rst pairs and count/check authoritative samples>` → exit 0, all four pairs identical; 54 samples, all zero.
- `cat` of `E/backup-sha256.txt`, `ada-ansible-lint.log`, `ada-pre-commit.log`, `ada-commit.log`, both `ada-syntax-*.log` → exit 0, inspected supplied check output; reported tool exit statuses are from the brief, not independent reruns.
- `ls -la "$B/"` → exit 0, expected files and restrictive modes.
- `sha256sum -c "$E/backup-sha256.txt"` → exit 1, seven matches and literal-tilde patch path unreadable.
- `python3 -c <expanduser manifest paths and compare SHA256 using hashlib>` → exit 0, all eight listed artifacts match; logical dumps absent from manifest.
- `diff -u "$E/vol-pre.txt" "$E/vol-now.txt"` → exit 1, one added anonymous volume (F1.3).
- `docker ps -a --format '{{.ID}} {{.Names}} {{.Status}}'` → exit 1, Docker socket permission denied.
- `docker inspect postgresql --format '{{.Id}} {{.HostConfig.RestartPolicy.Name}} {{json .Config.Labels}} {{json .Mounts}} {{json .NetworkSettings.Networks}}'` → exit 1, Docker socket permission denied; no environment values requested.
- `docker ps -a --filter volume=postgresql_postgresql-data --format '{{.ID}} {{.Names}}'` → exit 1, Docker socket permission denied.
- `ls -l` of both `/usr/local/share/ca-certificates/caddy-{internal,root}.crt` and both runtime `data/caddy/pki/authorities/local/root.crt` paths → exit 2, trust-store metadata visible; runtime roots inaccessible.
- `openssl x509 -in /usr/local/share/ca-certificates/caddy-internal.crt -noout -fingerprint -sha256 -dates` → exit 0, fingerprint 08:D4:CD:80:…:6F:FA matches; valid from 2026-03-30.

## Not checked

- Live Docker state, exact mounts/labels and exclusive ownership: socket denied. No permission escalation requested.
- `caddy-root.crt` contents and laptop CA roots: permissions prevent comparison; no elevation or private-key reads.
- Backup payload contents, bundle/base-patch restoration and tar extraction: private contents prohibited by the brief, except the named unrelated patch. Only metadata and authorized checksums read.
- PostgreSQL writes or a new restore container: forbidden for this reviewer. The recorded restore comparison is the available evidence.
- Independent lint/syntax/pre-commit reruns: used supplied logs; tools/hooks may create caches or modify files, whereas this review may write only its output file. No hook configuration changed.
- Laptop Ansible execution, smoke VM, remote hosts, network/PR/CI checks: prohibited or explicitly outside this review.
- Full owner-checkout preservation snapshots and prior session conduct: reviewed recorded claims and relevant current hunks, not a complete forensic audit.

## Reservations

- Empty application tables do not establish absence of intended use. The owner's recorded mo-kreyol decision supports retiring that specific consumer; its Compose database uses PostgreSQL 16, so the PostgreSQL 17 restore check does not validate migration into that project database.
- A successful `psql` exit without stop-on-error is not sufficient alone. Here the catalog comparisons support the limited restore result, while two expected errors are disclosed. Retain the exact restore command and remaining assertion outputs in the next evidence package.
- No defect found in the Caddy removal commit requiring a repository-code change. This verdict concerns the unmet runtime deletion gate and evidence claims; it grants no runtime authorization.
