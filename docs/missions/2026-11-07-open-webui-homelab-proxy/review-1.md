# Review 1 — 2026-11-07-open-webui-homelab-proxy

VERDICT: CHANGES_REQUESTED

## Findings

- F1.1 [major] roles/open_webui/templates/open-webui-firewall.service.j2:18 — Boot protection fails open. `WantedBy=docker.service` pulls in the filter and `Before=` orders it, but neither makes successful filtering a prerequisite for Docker startup. If the script fails on a fresh boot, Docker can restore `0.0.0.0:3030` with no restriction. The README explicitly acknowledges this exposure; the successful VM boot does not test this failure mode. This contradicts AC3's requirement to install filtering before exposure and AC5's persistence requirement. Make successful filter installation a prerequisite for publication, preserving targeted filter updates without unnecessarily restarting unrelated containers. Verify a deliberately failed filter startup in the disposable VM: the published service must remain inaccessible to denied clients, then recover safely after repair.

- F1.2 [major] roles/open_webui/templates/open-webui-firewall.sh.j2:23 — A host-port change removes protection from the running container before replacing it. For example, changing 3030 to 3031 atomically replaces the DROP with a rule for 3031, while `tasks/main.yml` has not yet recreated the container still publishing 3030. Denied clients can reach 3030 in that interval; if container reconciliation fails before removing the old container, exposure can persist. Atomic chain replacement does not make the firewall/container transition atomic. Preserve protection for the existing mapping until it is withdrawn, or stop publication before changing the rules, with safe behavior on failure. Verify denied access throughout the transition and when interrupted between filter application and container reconciliation. `vm-lifecycle.log` records only the successful final state and cannot establish this guarantee.

- F1.3 [minor] docs/missions/2026-11-07-open-webui-homelab-proxy/review-brief-1.md:51 — AC6 is marked `VERIFIED (code + read-only DB)`, but the supplied evidence does not include the claimed v0.13.0 source inspection. `laptop-baseline.log` confirms the stored empty `webui.url`; it does not establish `Config.seed_defaults` behavior, environment precedence, or the WebSocket CORS default. `mission.md` repeats the conclusions without quoting the supporting code. Supply version-specific source excerpts and their provenance for those claims, or mark the unsupported portions `NOT_VERIFIED`. The owner's pending Admin Settings action must remain explicit.

## AC check

Statuses below distinguish evidence for the VM from completion on the laptop. `E` means the evidence directory named in the brief.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED (code + recorded VM evidence) | Loopback role default retained; inventory opts into LAN mode; bind, port, sources and URL configurable. VM lifecycle log records port override, loopback and re-enable; empty sources and IPv6 fail assertions with exit 2. |
| AC2 | VERIFIED (recorded VM); NOT_VERIFIED (laptop after apply) | `vm-checks-1.log` shows only `0.0.0.0:3030` and a single IPv4 Docker mapping. IPv6 bind rejected. No new laptop publication inspected. |
| AC3 | NOT_VERIFIED as a complete criterion | VM HTTP 200 responses, denied probes and RETURN/DROP counters support steady-state allow/deny/local access; ORIGINAL direction avoids filtering replies. Initial Ansible installation orders filter before container. F1.1 and F1.2 break the protection guarantee during lifecycle events. |
| AC4 | VERIFIED for tested mapping and sentinel preservation | DNAT/ORIGINAL hook plus TCP original destination port and translated destination port scope the DROP. Only the owned chain is replaced/flushed. Sentinel survives restart, disable and re-enable in the supplied logs. |
| AC5 | NOT_VERIFIED as a complete criterion | Runs 2, 6 and 11 report `changed=0 failed=0`; run 10 check mode also reports zero changes. Restart/reboot logs put successful filter execution before Docker startup. Removal leaves loopback publication and preserves the sentinel. Failure and port-transition safety remain unresolved (F1.1/F1.2). Binding wildcard IPv4 avoids dependence on acquiring a particular interface address; actual late Wi-Fi lease behavior was not exercised. |
| AC6 | NOT_VERIFIED in full | URL environment construction inspected; baseline confirms stored empty URL. Supporting upstream source evidence missing (F1.3); owner UI action pending. |
| AC7 | NOT_VERIFIED | Laptop apply and Caddy/dns-71 matrix intentionally deferred until after review. |
| AC8 | NOT_VERIFIED on laptop | Same image version, volume, key-file path and Ollama variable retained in code. Baseline exists, but no post-apply comparison. |
| AC9 | VERIFIED for documentation coverage; corrections required | Configuration, filtering, lifecycle, verification and rollback documented. Update the lifecycle account after F1.1/F1.2; current boot-failure warning accurately describes an unacceptable exposure gap. |
| AC-SAFE | VERIFIED for this review's write scope; NOT_VERIFIED in full for mission | Handoff snapshot matches before review output. Only this review file created. Recorded pre-commit log includes secret detection Passed; main-checkout preservation over the whole mission not independently rechecked. |

## Commands run

All commands below ran locally without network access, Docker/iptables execution, secret retrieval or laptop application.

- `git status --short`, `git diff HEAD --stat`, scoped `git diff HEAD`, and `git rev-parse --short HEAD` → exit 0 each; inspected all 15 changed files, base `7311985`. Brief's count of 14 is stale.
- `cat`, `rg --files`, `rg -n`, `nl -ba` and `sed -n` inspections of repository instructions, mission files, changed code, Docker dependency/tag wiring and selected E logs/scripts → exit 0 each. Inspected VM allow/deny counters, restart/reboot ordering, lifecycle results, idempotence recaps, pre-commit results, rendered script/unit and the baseline DB-result excerpt. Evidence scripts were read, not executed, except the inspected read-only snapshot helper below.
- `git diff HEAD --check` → exit 0, no whitespace errors.
- `.venv/bin/yamllint roles/open_webui group_vars/all/vars.yml` → exit 0, no diagnostics.
- `sh -n E/rendered-open-webui-firewall.sh` → exit 0, shell syntax accepted (E expanded to its absolute path).
- `shellcheck E/rendered-open-webui-firewall.sh` → exit 0, no diagnostics (same expansion).
- `python3 -B -` with an in-memory byte comparison of changed role/inventory files against `E/tree` → exit 0, all 10 files match the VM evidence tree.
- Sourced inspected `E/snap.sh`, ran `snap "$PWD" docs/missions/2026-11-07-open-webui-homelab-proxy/review-1.md`, and compared with `E/snap-before-1.txt` → exit 0, `reviewed tree unchanged from handoff snapshot`.

## Not checked

- No laptop apply, Docker restart, reboot, network probes, smoke VM execution or live firewall manipulation: prohibited for this reviewer. F1.1/F1.2 follow from code and task ordering, not newly executed fault injection.
- No network documentation lookup, including Context7, under the review's explicit no-network restriction. Upstream Open WebUI behavior needs reviewable offline evidence as described in F1.3.
- Ansible-lint, playbook syntax check, pre-commit and systemd verification were not rerun. Reviewed the supplied pre-commit log (Ansible-lint and yamllint Passed) and rendered-unit log (`verify_ok`); these are implementer evidence, not independent executions. Shell hooks were skipped for templates in pre-commit; rendered-script checks above cover shell syntax/lint separately.
- Main checkout snapshot comparison, post-apply data/auth/key/model preservation, actual Caddy access, denied dns-71 access and browser login/streaming remain unverified here.

## Reservations

- Existing evidence supports successful steady-state operation and ordinary lifecycle paths, not continuous protection through failures. Resolve F1.1/F1.2 before laptop publication.
- The filter matches any forwarded DNAT mapping with the configured original TCP port and translated port 8080; it does not identify a container or original destination address. Keep that scope explicit if other forwarding arrangements are added.
- The probe checks hook presence only. A manually emptied owned chain with its hook intact is not repaired by an unchanged role rerun; avoid describing this as general rule reconciliation.
- BACKLOG's “Laptop side done” is premature while laptop application and preservation checks remain pending. Carry those pending outcomes into the final report rather than treating VM results as laptop proof.
