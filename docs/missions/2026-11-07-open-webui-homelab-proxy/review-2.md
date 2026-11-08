# Review 2 — 2026-11-07-open-webui-homelab-proxy

VERDICT: PASS_WITH_RESERVATIONS

## Findings

No new blocking findings. All three review-1 findings are resolved for the implementation and recorded VM tests reviewed here:

- **F1.1 resolved:** `RequiredBy=docker.service` plus `Before=` makes successful filter startup a prerequisite for Docker. `vm-failclosed-reboot.log` records restart exit 1, failed filter, inactive Docker, no listener and client status 000; restoration recovers successfully. Its subsequent clean reboot records filter completion before Docker and container startup. Ansible uses direct script application rather than restarting the required unit. `reenable` refreshes installation links when the unit changes. Upgrade and removal/re-enable logs preserve Docker's activation timestamp; removal disables the dependency before stopping the unit.
- **F1.2 resolved:** `tasks/firewall.yml:22` reads existing port bindings and stops the container on a host-port mismatch before changing the script or rules. The stop command preserves the existing container configuration. All 118 recorded denied-client probes return status 000 during the port change. `vm-interrupted-2.log` records the failed image pull (exit 2), unchanged container ID, stopped state, retained volume/mapping and `unless-stopped` policy, no listeners on either port, then successful recovery and an unchanged rerun. This closes the ordering gap identified in review 1.
- **F1.3 resolved:** `openwebui-v0.13.0-source.log` identifies the running image and build and quotes the environment/default mapping, persistent DB read precedence, missing-key seeding, admin route mapping, and HTTP/WebSocket CORS configuration. Together with the previously inspected empty DB value, this supports the existing-install URL instructions. The owner UI action remains pending explicitly.

## AC check

`E` denotes the evidence directory named in the briefs. VM statuses use recorded implementer evidence, not reviewer execution against the VM.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED (code + recorded VM) | Configurable values and loopback default retained. New stop condition compares actual host-port bindings with the configured port. Prior assertion/override evidence remains applicable. |
| AC2 | VERIFIED (recorded VM); NOT_VERIFIED (laptop after apply) | Explicit IPv4 publication unchanged from review 1; no IPv6 publication introduced. |
| AC3 | VERIFIED (code + recorded VM); NOT_VERIFIED (laptop) | Prior allow/deny/local/counter evidence plus dependency failure test and stop-before-port-change ordering resolve the exposure gaps. ORIGINAL-direction hook continues to exclude replies. |
| AC4 | VERIFIED (code + recorded VM) | Owned chain and DNAT/port scope unchanged. New lifecycle evidence preserves the unrelated sentinel on disable/re-enable. |
| AC5 | VERIFIED for tested VM paths; NOT_VERIFIED (laptop) | Upgrade, restart failure/recovery, successful reboot ordering, port change/interruption/recovery, disable/re-enable, unchanged reruns and check mode supported by supplied logs. Actual late Wi-Fi acquisition was not exercised; wildcard binding and interface-independent rules avoid requiring its address. |
| AC6 | VERIFIED for mechanism/CORS assessment; owner action pending | Version-specific source excerpts now support persistent URL precedence and CORS defaults. Existing DB setting still requires the documented Admin Settings action. |
| AC7 | NOT_VERIFIED | Laptop apply and Caddy/dns-71 checks intentionally follow this review. |
| AC8 | NOT_VERIFIED on laptop | Data volume, image version, key-file path and model connection configuration retained in code. Interrupted VM run preserves the volume mount. Laptop before/after evidence remains pending. |
| AC9 | VERIFIED (inspection) | README explains required-unit failure impact, direct-script updates, port-change interruption, removal, limited drift probing and port-based scope. |
| AC-SAFE | VERIFIED for reviewer write scope; NOT_VERIFIED in full for mission | Review tree matches handoff snapshot; only review-2.md written. Recorded pre-commit secret detection Passed. Whole-mission main-checkout preservation not independently checked. |

## Commands run

- `cat` on review-brief-2.md, review-1.md and the seven named post-fix evidence logs → exit 0; inspected the resolutions, fault/recovery/lifecycle results, source excerpts and pre-commit results.
- `git diff HEAD -- roles/open_webui`, `git status --short`, `git diff HEAD -- BACKLOG.md docs/missions/2026-11-07-open-webui-homelab-proxy/mission.md`, `git diff HEAD --stat` → exit 0 each; reviewed implementation, documentation and mission changes.
- `git diff HEAD --check` → exit 0, no whitespace diagnostics.
- `.venv/bin/yamllint roles/open_webui group_vars/all/vars.yml` → exit 0, no diagnostics.
- `sh -n E/rendered-open-webui-firewall.sh` and `shellcheck E/rendered-open-webui-firewall.sh` → exit 0 each, no diagnostics; E expanded to its absolute path.
- `nl -ba` on firewall.yml and firewall_absent.yml, and `cat` on the unit template → exit 0 each; checked condition, update and removal ordering.
- First `python3 -B -` byte-comparison check against `E/tree` → exit 1 at README mismatch, before probe counting. Follow-up in-memory comparison → exit 0: all nine changed implementation/inventory files match; only README differs, by the reviewed lifecycle documentation updates. The follow-up also confirms 118 probe records, all status 000.
- Sourced the previously inspected `E/snap.sh`, computed the worktree snapshot excluding review-2.md, and compared with `E/snap-before-2.txt` → exit 0, `reviewed tree unchanged from handoff snapshot`.

## Not checked

- No laptop, network, Docker, iptables, VM execution or fault injection commands: prohibited by this review's scope. Runtime conclusions rely on the supplied logs and matching implementation files.
- No Context7/network lookup under the explicit no-network restriction; upstream behavior assessed using supplied offline source excerpts.
- Did not rerun Ansible-lint, playbook syntax check, pre-commit or systemd verification. `pre-commit-2.log` records Ansible-lint, yamllint and secret detection Passed, but does not itself contain a separate playbook syntax-check result. Shell hooks skip templates; rendered-script checks were independently rerun above.
- No laptop data/auth/key/model before/after comparison, main-checkout snapshot comparison, Caddy/dns-71 matrix, owner URL-setting action, or browser login/streaming verification.

## Reservations

- This verdict covers readiness of the reviewed implementation for the owner's targeted apply; it does not establish completed laptop deployment or AC7/AC8.
- Filter startup failure now prevents all Docker containers from starting. This is the documented availability tradeoff for fail-closed publication. Keep the direct-script recovery instructions and avoid manually stopping/restarting the required filter unit during normal operation.
- Drift detection checks the hook and DROP, not exact allowed-source rules. Matching remains by DNAT direction and port pair rather than container identity. Both limitations are documented.
- Check-mode evidence covers an unchanged configuration. A hypothetical port transition in check mode does not execute the stop/apply commands and is not a runtime safety test.
