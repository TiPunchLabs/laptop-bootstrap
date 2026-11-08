# Mission 2026-11-07-open-webui-homelab-proxy — Open WebUI reachable by the homelab Caddy

## Objective
Allow HomeLab's Caddy reverse proxy (192.168.10.70) to reach the Open WebUI instance
on this laptop, enabling publication at https://openwebui.internal. Implement and
apply the laptop-side prerequisite. HomeLab DNS and Caddy configuration are prepared
in MR !102, not deployed. (Full objective: owner prompt of 2026-11-07, summarized
here; requirements 1–6, validation and delivery lists are tracked as ACs below.)

## Authorizations
Default (worktree + smoke VM) plus, from the objective: modify laptop-bootstrap,
apply the targeted open_webui configuration on this laptop (brief Open WebUI
interruption), one targeted Docker restart to validate persistence, commit, push,
open a PR. Not authorized: merge, laptop reboot, HomeLab changes, MR !102, Ollama
changes, cleanup of unrelated services, direct DB edits.

## Scope
In: roles/open_webui (bind/port/allowed sources/WEBUI_URL, DOCKER-USER filter and
its lifecycle), group_vars for this laptop, docs, BACKLOG.
Out: homelab repo, Caddy/Pi-hole, Ollama, other containers, Open WebUI version.

## Acceptance criteria
| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Configurable bind address, port, allowed sources, WEBUI_URL; loopback default kept | defaults + assert; VM runs with overrides | VERIFIED |
| AC2 | IPv4-only publication, no IPv6 listener | `ss -ltn`, `docker port` on VM and laptop | VERIFIED |
| AC3 | Filter installed before exposure; allowed source passes, other sources dropped, local access kept, replies not dropped | task order; VM + laptop curl matrix; conntrack/counters | VERIFIED |
| AC4 | Rules scoped (DNAT + ORIGINAL + port mapping), no flush of DOCKER-USER, other DOCKER-USER rules kept | VM sentinel rule across install/rerun/removal | VERIFIED |
| AC5 | Lifecycle (laptop reboot by inspection only): rerun changed=0, Docker restart, reboot ordering, disable → loopback with unit/rules removed | VM: idempotence, docker restart, reboot, disable/re-enable; laptop: idempotence, docker restart, reboot ordering by inspection | VERIFIED |
| AC6 | WEBUI_URL via supported mechanism, persisted settings accounted for, CORS assessed (owner UI step pending) | code reading of v0.13.0 + read-only DB query; owner UI action reported | VERIFIED |
| AC7 | Laptop applied: local health OK, Caddy reaches :3030/health, other LAN host denied | owner `make play-open-webui`; curl from caddy-70 / dns-71 | VERIFIED |
| AC8 | Data, auth, secret key, model connection, image version preserved | before/after: users, chats, alembic, key fingerprint, ollama urls, image | VERIFIED |
| AC9 | Docs: config, restrictions, lifecycle, verification, rollback | role README | VERIFIED |
| AC-SAFE | Main tree preserved; no secret read or written; hooks not bypassed | §6 snapshot, gitleaks | VERIFIED |

## Plan
1. Inspect packet path, Docker backend, Open WebUI config handling (done).
2. Role: assert inputs; firewall.yml (script + oneshot unit, before container);
   firewall_absent.yml (after container); WEBUI_URL env; laptop group_vars.
3. VM: install, allow/deny matrix, sentinel, idempotence, docker restart, reboot,
   disable/re-enable.
4. Codex review 1; fix.
5. Laptop: backup volume, owner runs `make play-open-webui`, verify, docker restart, rerun.
6. Commit, push, PR; final Codex review; report.

## State
- Phase: deliver (commit, PR, review-3)
- Branch / worktree: feat/open-webui-homelab-proxy / ../laptop-bootstrap-worktrees/open-webui-homelab-proxy
- Base commit: 7311985 (origin/main; local main fbaa44e, behind 6, docs-only commits)
- Evidence dir: ~/.local/share/laptop-bootstrap-agent/2026-11-07-open-webui-homelab-proxy/
- Main-tree snapshot: main-tree-snap-baseline.txt (14021b4b…)
- Reviewer: herdr agent lb-review, pane w1Q:pP
- Review cycle: 2 of 3

## Log
- 2026-11-07 inspect: Docker 29.9.3, firewall backend iptables (iptables-nft 1.8.11); FORWARD → DOCKER-USER (empty) → DOCKER-FORWARD; nat DOCKER DNAT `-d 127.0.0.1 --dport 3030 → 172.17.0.3:8080`; raw PREROUTING drops 127.0.0.1:3030 from non-lo; ufw inactive; live-restore false.
- 2026-11-07 inspect: Open WebUI v0.13.0 stores config per key; `seed_defaults` inserted `webui.url = ""` on first start → env WEBUI_URL ignored on this install (read-only query). CORS_ALLOW_ORIGIN unset → `*`, socket.io accepts any origin.
- 2026-11-07 inspect: DHCP server 192.168.10.1 (router, not accessible); wlo1 uses hardware MAC b8:1e:a4:da:3e:4d (no permaddr), = MAC of the static lease documented in homelab docs/references/ip-addresses.md; journal since 2026-07-20: 247 wlo1 DHCP events, all 192.168.10.217. Reservation itself NOT_VERIFIED.
- 2026-11-07 inspect: baseline from caddy-70 and dns-71: `curl 192.168.10.217:3030` → connection refused (loopback bind).
- 2026-11-07 verify: VM run 1 failed on stale apt cache of the box (404 apt-transport-https); `apt-get update` in VM, rerun.
- 2026-11-07 verify (VM, pre-review): vm-run-1..11 — install, allow/deny counters, sentinel kept, idempotence, --check, docker restart (unit rerun before dockerd), reboot ordering, port change, disable/re-enable, asserts.
- 2026-11-07 review-1: Codex (pane w1Q:pP, agent lb-review) CHANGES_REQUESTED — F1.1 fail-open at boot, F1.2 port-change window, F1.3 missing source evidence. All three confirmed against the code.
- 2026-11-07 fix-1: F1.1 → `RequiredBy=docker.service`; Ansible never restarts the unit (Requires propagates restart to Docker): it runs the script directly, `systemctl reenable` when the unit file changes, disable-before-stop on removal. F1.2 → `docker stop` before rule change when the published host port differs. F1.3 → E/openwebui-v0.13.0-source.log.
- 2026-11-07 fix-1 finding: `docker_container state=stopped` with only a name recreated the container (restart=no, no ports, no mount; volume untouched) — replaced by `docker stop` (vm-interrupted.log vs vm-interrupted-2.log).
- 2026-11-07 verify (VM, post-fix): upgrade wants→requires without Docker restart (vm-fix1-upgrade.log); port change under 118 denied probes, 0×200 (vm-probe-portchange.log); interrupted run leaves container stopped, nothing listening (vm-interrupted-2.log); fault injection: Docker refuses to start, port closed, repair documented (vm-failclosed-reboot.log); reboot ordering; disable/re-enable without Docker restart, idempotence, --check (vm-fix1-lifecycle.log).
- 2026-11-07 review-2: Codex PASS_WITH_RESERVATIONS (review-2.md).
- 2026-11-07 backup: `~/Backups/open-webui-2026-11-07/open-webui-20261107-2356.tar.gz` (root 0600, webui.db + key) via a throwaway `alpine:3` container; Open WebUI healthy afterwards.
- 2026-11-07 deploy: owner ran `make play-open-webui` from the worktree at 20:56 → ok=32 changed=6 failed=0 (script, unit, reenable, enable, rules, container). Container 0c922985… on `0.0.0.0:3030`, v0.13.0, same volume, WEBUI_URL set (E/laptop-apply-checks.log).
- 2026-11-07 verify (laptop): 127.0.0.1 and 192.168.10.217 → 200; caddy-70 → 200 (RETURN 7 pkts); dns-71 → curl exit 28 (DROP 5 pkts); only `0.0.0.0:3030`, no IPv6 listener; ip6tables DOCKER-USER empty (E/laptop-apply-checks.log).
- 2026-11-07 verify (laptop): users/chats/alembic/key prefix/ollama urls/image id identical to baseline; auth on, signup off, unauthenticated API 401; DB `webui.url` still `""` (owner UI action pending); CORS echoes `Origin: https://openwebui.internal` (E/laptop-after-apply.log).
- 2026-11-07 verify (laptop): authorized `systemctl restart docker` at 20:59:03 — firewall unit stopped with Docker, re-ran at 20:59:07 before dockerd; rules re-created; caddy-70 200, dns-71 dropped. byenvini-dev-pg, mailpit, localstack restarted and healthy after 15 s (E/laptop-docker-restart.log).
- 2026-11-07 inspect (laptop, no reboot): `docker.service.requires/open-webui-firewall.service` link, docker After= includes the unit; `critical-chain` reflects the previous boot (unit not yet installed) — reboot NOT executed (E/laptop-boot-ordering.log).
- 2026-11-07 verify (laptop): owner rerun of `make play-open-webui` at 21:41 → ok=29 changed=0; container id and StartedAt unchanged; caddy-70 still 200 (E/laptop-rerun-idem.log). Main-tree snapshot still 14021b4b….
