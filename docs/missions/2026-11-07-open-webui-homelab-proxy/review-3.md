# Review 3 — 2026-11-07-open-webui-homelab-proxy

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- F3.1 [minor] docs/missions/2026-11-07-open-webui-homelab-proxy/mission.md:73 — Evidence qualifications are missing from the final verification claims. `laptop-rerun-idem.log` contains only a post-run container ID/StartedAt, health and two HTTP results; it contains neither the Ansible recap/exit status nor a pre-rerun StartedAt for comparison. The brief supplies the owner's reported `ok=29 changed=0` result, but the referenced log does not independently substantiate it. Likewise, AC-SAFE at line 34 is `VERIFIED` while the supplied artifacts contain the baseline main-tree checksum and a narrative assertion of an unchanged prefix, without the final full checksum/comparison result. Preserve the available session output and comparison result if available, or qualify these as reported outcomes and mark the unsupported verification portions `NOT_VERIFIED`. No additional laptop execution is requested for this review.

No implementation regression found. F1.1–F1.3 remain resolved. F3.1 concerns evidence completeness, not an observed exposure or data-loss defect.

## AC check

`E` is the evidence directory named in the briefs. Laptop runtime conclusions below are based on recorded owner/implementer evidence; the reviewer ran no laptop checks.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Nine changed implementation/inventory files match the previously reviewed VM tree; configurable values and loopback defaults retained. Prior VM override/assertion evidence applies. |
| AC2 | VERIFIED (recorded laptop + VM) | Apply/after-apply logs show only `0.0.0.0:3030`, a single IPv4 Docker mapping, no IPv6 listener and an empty IPv6 DOCKER-USER chain. |
| AC3 | VERIFIED (code + recorded tests) | Installation ordering and fail-closed/port-transition fixes unchanged. Laptop local loopback and own-IP requests return 200, Caddy returns 200, dns-71 times out with exit 28; RETURN 7 and DROP 5 counters support the source filter. Reply-direction handling unchanged. |
| AC4 | VERIFIED | Same scoped rules and owned-chain transaction reviewed previously; VM sentinel preservation evidence remains applicable. Laptop rules show the intended DNAT/ORIGINAL hook and 3030→8080 mapping filter. |
| AC5 | VERIFIED for recorded lifecycle tests and boot configuration; laptop zero-change rerun reported, incompletely captured | Laptop restart exits 0; filter reruns before dockerd, rules and reachability restrictions return. Three unrelated previously running containers return healthy. Requires/Before/After wiring recorded. Laptop reboot explicitly not executed; VM reboot/removal/failure evidence remains applicable. See F3.1 for laptop rerun evidence. |
| AC6 | VERIFIED for mechanism and CORS assessment; UI action pending | Previously reviewed version-specific source remains applicable. Laptop environment includes the URL, persisted DB URL remains empty, and CORS response permits the public origin. This does not establish that the persisted public URL has been changed. |
| AC7 | VERIFIED (recorded laptop) | Local health 200, Caddy 200 and denied dns-71 exit 28 before and after the Docker restart. Runtime state supports successful application despite the first playbook transcript not being retained. |
| AC8 | VERIFIED for specified before/after measurements | In-memory comparison confirms identical image ID, key fingerprint prefix, users, chat count, migration revision and stored Ollama settings. Same named volume/path retained. Auth enabled, signup disabled and unauthenticated API returns 401. Browser login and model execution were not tested. |
| AC9 | VERIFIED | Reviewed configuration, limitations, lifecycle, recovery, verification and rollback documentation retained. |
| AC-SAFE | NOT_VERIFIED in full | Commit-hook log supports hooks running, including secret detection; this review's handoff snapshot matches. Final main-checkout preservation comparison is reported but not captured (F3.1). No secret value was read or written by this reviewer. |

## Commands run

- `cat` on review-brief-3.md, review-2.md, mission.md, the six named deployment logs, commit.log and the previously inspected snapshot helper → exit 0; reviewed final claims and recorded deployment evidence.
- `git status --short`, `git log -4 --oneline`, `git diff HEAD`, `git diff 7311985 75c9ebc -- roles group_vars` → exit 0 each; HEAD is `75c9ebc`, tracked worktree clean, new brief untracked. Inspected committed implementation against the base.
- `python3 -B -` to list immediate E filenames, plus `nl -ba mission.md` → exit 0; checked available evidence artifacts and claim locations.
- `python3 -B -` with in-memory comparisons → exit 0: all nine changed implementation/inventory files match the VM tree reviewed in cycle 2; baseline/after-apply image ID, key fingerprint prefix, users, chats, migration revision, Ollama settings and persisted URL match. No secret-file contents accessed.
- `git diff 7311985 75c9ebc --check` → exit 0, no whitespace diagnostics.
- `git diff --exit-code HEAD -- roles group_vars` → exit 0, no uncommitted implementation changes.
- `cat E/main-tree-snap-baseline.txt` → exit 0; complete baseline hash available, matching the documented prefix. E expanded to its absolute path.
- Sourced inspected `E/snap.sh`, computed the worktree snapshot excluding review-3.md, and compared with `E/snap-before-3.txt` → exit 0, `reviewed tree unchanged from handoff snapshot`.

## Not checked

- No laptop, Docker, iptables, systemd, VM, network or secret-retrieval commands executed. No live validation or laptop reboot performed by this reviewer.
- No network documentation lookup, including Context7, under the explicit no-network restriction.
- No fresh lint/syntax/hook reruns: implementation unchanged since review 2. `commit.log` records Ansible-lint, yamllint and secret detection Passed at commit creation; these are recorded results, not reviewer executions.
- No independent main-checkout snapshot comparison, full first/second laptop playbook transcript, pre-rerun StartedAt capture, backup restore test, browser login, streamed model response, or homelab HTTPS/DNS/TLS test.
- Commit existence verified locally. Push, remote PR state and CI not independently checked; no network access permitted.

## Reservations

- **The laptop-side prerequisite for MR !102 is satisfied by the recorded reachability and filtering tests.** The homelab can use `http://192.168.10.217:3030` from Caddy `192.168.10.70`. This review neither authorizes nor verifies homelab deployment or merge.
- Owner still needs to set **Admin Settings → General → WebUI URL** to `https://openwebui.internal`. After homelab deployment, verify DNS/internal TLS, HTTPS browser login, WebSockets and streamed chat. Current evidence proves upstream HTTP reachability, not end-to-end publication.
- Resolve or explicitly qualify F3.1 in the final report; do not present the missing captured comparisons as independently verified. This is the final scheduled review cycle, not a request for a fourth cycle.
- Laptop reboot ordering is inspected configuration backed by a successful VM reboot and laptop Docker restart, not a tested laptop boot. Actual late Wi-Fi acquisition and the router reservation remain unverified.
- Prior documented operational limits remain: filter startup failure blocks Docker startup, updates use the script directly, drift probing does not reconcile allowed-source lines, and rule scope identifies the mapping by port pair rather than container identity.
