# Review 2 — 2026-11-07-remove-caddy-postgresql

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- F2.1 [minor] mission.md:192 — The deferred deletion condition, "once the quarantine shows no client," remains underspecified. A stopped server cannot record PostgreSQL sessions, and absence of reported breakage alone does not identify the September clients. Expected fix: describe a later owner decision based on a defined observation period, attempted-connection/application evidence and an explicit assessment of the remaining uncertainty; require a fresh backup/identity review before final deletion. This deferred action is outside this review's approval and does not block the four current steps.
- F2.2 [minor] mission.md:139 — The local-change table says the untracked Caddy directory was "Backed up, then trashed," whereas both briefs and the runtime plan say trashing is still pending. Expected fix: change this to "backed up; trashing pending review/execution" and update it only after execution. The later quarantine decision clearly supersedes the earlier PostgreSQL removal decision, but the final report should consistently describe PostgreSQL as retained under quarantine.

Resolution of review 1:

- F1.1: resolved for the revised mission. Unidentified September clients remain explicitly unresolved and block deletion. The recorded owner decision authorizes stopping PostgreSQL and disabling restart while retaining its container, volume and configuration. No inference of disuse is needed to approve that reversible action.
- F1.2: resolved. The rebuilt manifest has absolute paths for all 13 artifacts, including all five logical PostgreSQL backups. Independent `sha256sum -c` succeeds for every entry. The mission names `pg-dumpall.sql` and `pg-mokreyol.dump` as the restore inputs; metadata is consistent with their recorded creation time. Checksums establish current integrity against this manifest, not an independently captured checksum at restore time.
- F1.3: resolved. Independent comparison of `vol-pre.txt` and `vol-final.txt` exits 0; `vol-final-diff.txt` is empty. The extra anonymous volume was present only in the intermediate inventory. This supports the corrected cleanup claim.
- F1.4: resolved for the reviewed targets. `runtime-identity.txt` identifies the exact generic PostgreSQL container, Compose paths, published port, restart policy and dedicated mount; only that container uses the named volume. It records no container mounts under the directory targets, no Caddy container/image/listener and no detected startup integration. The plan requires fresh identity/attachment checks before acting.
- F1.5: resolved. `ca-evidence.txt` supplies full public-root fingerprints and dates for both laptop paths and the two Caddy roots in the system bundle. Their fingerprints differ. The mission now limits its trust statement to the present and labels ownership of the older trusted root as inferred. Trust-store files remain excluded.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED, scoped | Saved sanitized runtime identity plus repository evidence from review 1 supports ownership of the action targets. Older trusted CA ownership remains explicitly inferred and is outside the action scope. |
| AC2 | VERIFIED | Matrix retains the unresolved clients and acknowledges possible LAN clients through the published port. Quarantine replaces deletion; no claim that the nine-minute sample settles historical use. |
| AC3 | VERIFIED, limited | Bundle verification records exit 0 with feature head 3e29b22 and required base 3bc15a4; archive checks report 79/76/2 entries and valid gzip. Directory/file modes remain 0700/0600. All 13 checksums independently match; unrelated patch still applies to unchanged cleanup HEAD. Base-patch restoration remains a reported check rather than an independent rerun. |
| AC4 | VERIFIED, limited | Source/restored roles, databases, tables and counts/version/enums remain byte-identical. Logical backups are now included in the verified manifest. Review 1's limits concerning password-hash/custom-restore assertion output remain; no live data is being deleted under this revised plan. |
| AC5 | VERIFIED | Cleanup HEAD remains 65c5de2, clean, with no active tracked Caddy references outside CHANGELOG. Review 1's accepted code and supplied lint/syntax evidence remain applicable. |
| AC6 | VERIFIED | Unchanged accepted commit and branch classification from review 1; generic PostgreSQL support remains outside both local remote-tracking main trees. Feature branch/history and unrelated edits remain preserved. |
| AC7 | NOT_VERIFIED | Four runtime actions are pending. After execution, record stopped state and restart=no, both absent Caddy paths, and continued presence of the PostgreSQL container, volume and configuration directory. |
| AC8 | NOT_VERIFIED | Requires post-action retained-app health and unrelated-resource comparison. Final restore-check volume inventory now matches baseline. |
| AC9 | VERIFIED | This second independent review precedes the proposed actions and accepts their revised scope. The AC's verification reference should point to review 2 rather than the rejected review 1. |
| AC10 | NOT_VERIFIED | Separate PRs and CI reporting remain later work; no network access used. |
| AC-SAFE | NOT_VERIFIED, whole mission | Reviewed evidence contains no credential values; backups have restrictive modes and valid checksums. No shared resource, homelab or trust-store action is proposed. Complete owner-snapshot comparison and whole-session conduct are not independently audited. |

## Deletion plan verdict

- step 1: approve — `docker update --restart=no postgresql` matches the recorded quarantine decision. Recheck the exact container identity as specified; preserve the existing container, mount and image.
- step 2: approve — stopping that same container implements the authorized quarantine without removing its data or configuration. Record the resulting stopped state and restart policy.
- step 3: approve — the exact `~/Workspace/07-local/caddy` directory is an obsolete laptop runtime target with a checksummed archive and no recorded container attachment. Perform the stipulated fresh mount check before trashing it.
- step 4: approve — the exact owner-checkout `caddy/` directory is separately classified as rendered runtime and has its own checksummed archive. Perform the stipulated fresh mount check and retain unrelated tracked edits.

The deferred PostgreSQL container/volume/configuration deletion is **not approved** by this review. All four approvals apply to the plan and recorded authorization; this reviewer executes no runtime action. Shared network/image, other project databases, homelab, DNS and trust-store CAs remain excluded.

## Commands run

Exact roots abbreviated below: `E=/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-07-remove-caddy-postgresql`, `A=/home/xgueret/Workspace/02-infrastructure/local/ansible-docker-apps-worktrees/remove-caddy`, `B=/home/xgueret/Backups/caddy-postgresql-2026-11-07`, `M=docs/missions/2026-11-07-remove-caddy-postgresql`. These abbreviations describe the full paths used, not environment variables read from the shell.

- `cat "$M/review-brief-2.md"`; `cat "$M/mission.md"`; `nl -ba "$M/mission.md"` → each exit 0, reviewed resolutions, authorization and exact plan/line references.
- `cat "$E/runtime-identity.txt" "$E/ca-evidence.txt"` → exit 0, reviewed sanitized runtime and public CA evidence.
- `cat "$E/backup-sha256.txt" "$E/backup-sha256-check.txt" "$E/ada-bundle-verify.txt" "$E/tar-check.txt"` → exit 0, reviewed manifest and saved verification output. Bundle/tar commands themselves were not independently rerun.
- `sha256sum -c "$E/backup-sha256.txt"` → exit 0, 13 of 13 artifacts OK, including every logical database backup.
- `ls -la "$B/"` → exit 0, directory 0700 and all 13 files 0600; expected artifact names and sizes present.
- `diff -u "$E/vol-pre.txt" "$E/vol-final.txt"` → exit 0, identical inventories; repeated standalone with the same result.
- `cat "$E/vol-final-diff.txt"` → exit 0, empty saved comparison output.
- `git -C "$A" rev-parse HEAD` → exit 0, 65c5de2e23ac89b5e8bebad829a3f75517a13b18, unchanged from review 1.
- `git -C "$A" status --short` → exit 0, clean cleanup worktree.
- `git status --short --untracked-files=all` → exit 0, mission records untracked; no tracked modifications listed before this review file was created.
- `git diff HEAD --stat` → exit 0, no tracked diff in this worktree.
- `git -C "$A" diff --check origin/main..HEAD` → exit 0, no whitespace errors.
- `git -C "$A" apply --check "$B/ada-unrelated-local-changes.patch"` → exit 0, unrelated patch remains applicable without changing any file/index.
- `git -C "$A" grep -in caddy HEAD -- ':!CHANGELOG.md'` → exit 1, no active tracked Caddy references.
- `python3 -c <compare src/rst roles, dbs, tables and counts byte-for-byte; assert empty vol-final-diff.txt>` → exit 0, all four catalog pairs identical and saved final volume diff empty.

## Not checked

- Live Docker operations: socket access was denied in review 1; per brief 2, reviewed the new saved evidence instead of repeating denied calls. No escalation requested.
- Runtime quarantine, directory trashing or retained-app health afterward: intentionally pending independent review; no laptop mutation performed.
- Private backup payloads: only authorized metadata/checksums and read-only patch applicability checked; no database dump, secret patch or archive contents printed.
- New restore/container execution, direct reads of protected CA files and independent bundle/tar restoration: prohibited or inaccessible. Used sanitized retained outputs and the catalog comparison.
- Independent lint/syntax/hooks: unchanged accepted commit; relied on the logs inspected in review 1. No cache-writing tools or file-fixing hooks rerun.
- Owner decision dialog transcript, historical-client source attribution and full owner-tree snapshots: relied on the documented decision and retained evidence; unknown clients remain unresolved.
- Remote refs beyond locally available state, PRs/CI, network services, smoke VM and laptop Ansible deployment: outside this review's permissions/scope.

## Reservations

- Quarantine can interrupt an unidentified intermittent client; the recorded owner decision explicitly chooses this reversible experiment. Preserve all PostgreSQL recovery resources until a later owner decision.
- `docker start postgresql` restores availability but leaves restart=no. Full rollback also requires restoring the previously recorded restart policy, unless the owner intends to keep manual startup.
- A later application database on PostgreSQL 16 is not validated by the PostgreSQL 17 restore comparison. This review approves neither that migration nor final generic-database deletion.
- Checksums and saved comparisons support the revised plan. Execution must still produce fresh identity, attachment, quarantine-state and retained-app evidence; this pre-action verdict is not evidence that cleanup has happened.
