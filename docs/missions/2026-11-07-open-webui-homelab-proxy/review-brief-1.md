# Review brief 1 — 2026-11-07-open-webui-homelab-proxy

## Objective (owner, summarized; verbatim requirements are tracked in mission.md)
Allow the HomeLab Caddy (192.168.10.70) to reach Open WebUI on this laptop
(192.168.10.217:3030) for https://openwebui.internal. IPv4 publication beyond
loopback with persistent filtering that admits Caddy and preserves local access,
installed before exposure; no unrestricted IPv6; lifecycle (rerun, Docker restart,
reboot, late Wi-Fi lease, disable/back to loopback, removal); WEBUI_URL through the
supported mechanism; CORS checked; docs; preserve data/auth/key/model connection/
image version. Laptop apply happens AFTER this review (owner runs it: the vault
password comes from `pass`, which agents never call).

- Base: origin/main 7311985. Branch: feat/open-webui-homelab-proxy (worktree, staged, not committed).
- Evidence: ~/.local/share/laptop-bootstrap-agent/2026-11-07-open-webui-homelab-proxy/ (E)
- Files: `git diff --cached --stat` (14 files). Core: roles/open_webui/{tasks/main.yml,
  tasks/firewall.yml, tasks/firewall_absent.yml, vars/main.yml, defaults/main.yml,
  templates/open-webui-firewall.{sh,service}.j2, README.md}, group_vars/all/vars.yml.

## Design (to challenge)
- Bind `0.0.0.0` (explicit IPv4 → no `[::]` binding; no dependency on the DHCP
  address, which binding to 192.168.10.217 would create at boot).
- Observed packet path on the laptop (E/laptop-baseline.log + mission Log): Docker
  29.9.3, backend iptables on iptables-nft 1.8.11, `FORWARD -j DOCKER-USER` first,
  then DOCKER-FORWARD; nat PREROUTING `--dst-type LOCAL -j DOCKER` with DNAT
  `--dport 3030 → <ctr>:8080`; loopback/own-IP access from the host goes through
  OUTPUT/docker-proxy, not FORWARD. ufw inactive, live-restore false.
- Rules: `DOCKER-USER: -m conntrack --ctstate DNAT --ctdir ORIGINAL -j OPEN-WEBUI-INGRESS`
  (constant hook); chain rebuilt atomically by `iptables-restore --noflush`:
  `-s <allowed> -j RETURN` per source, then
  `-p tcp -m conntrack --ctorigdstport <port> --ctreplsrcport 8080 -j DROP`.
- Persistence: oneshot `open-webui-firewall.service`, `Before=docker.service`,
  `PartOf=docker.service`, `WantedBy=docker.service` (not RequiredBy: Requires would
  restart Docker whenever Ansible restarts the unit). Script creates DOCKER-USER if
  absent (Docker keeps an existing one).
- Ansible order: assert → filter (firewall.yml) → container → removal
  (firewall_absent.yml, loopback only, after the container is back on 127.0.0.1).
  Self-heal: `iptables -C` probe; unit restarted if files changed or hook missing.
- WEBUI_URL: v0.13.0 `Config.seed_defaults` stores every default on first start;
  read-only query on the laptop shows `webui.url = '""'` → env cannot change it.
  Role passes `WEBUI_URL` when `open_webui_url` set (seeds fresh installs); owner
  sets it in Admin Settings → General. CORS left `*` (same origin via Caddy).

## Acceptance criteria (Claude Code statuses before laptop apply)
| ID | Status | Evidence |
|---|---|---|
| AC1 config vars, loopback default | VERIFIED (VM) | defaults; vm-run-1 (-e sources), vm-run-4 (port 3031), vm-run-5 (127.0.0.1) |
| AC2 IPv4 only | VERIFIED (VM) | vm-checks-1.log: `0.0.0.0:3030` only, `docker port` single IPv4 line; vm-run-9-assert6.log rejects `::` |
| AC3 allow/deny/local/replies | VERIFIED (VM) | vm-checks-1b-counters.log: host (allowed) RETURN 7 pkts + 200; other-network container DROP 5 pkts, timeout; vm-checks-3.log: host denied when only 192.168.10.70 allowed, loopback + own IP 200 |
| AC4 scoped, no flush, others kept | VERIFIED (VM) | sentinel `-s 203.0.113.9 ... sentinel -j DROP` kept through vm-run-3, docker restart, disable (vm-lifecycle.log), re-enable |
| AC5 lifecycle | VERIFIED (VM) / laptop pending | vm-run-2/6/11 changed=0; vm-run-10 --check changed=0; vm-docker-restart.log (unit rerun before dockerd, rules kept); vm-reboot.log (filter Finished 23:34:14.66 < docker Starting 16.26 < container 17.11); vm-lifecycle.log (port change, disable, re-enable) |
| AC6 WEBUI_URL/CORS | VERIFIED (code + read-only DB) | mission.md Log; owner UI action remains |
| AC7 laptop apply + Caddy/dns-71 | NOT_VERIFIED (after review) | — |
| AC8 data preserved | NOT_VERIFIED (laptop) | baseline E/laptop-baseline.log |
| AC9 docs | VERIFIED (inspection) | roles/open_webui/README.md "LAN access through a reverse proxy" |
| AC-SAFE | partial | dummy vault only; pre-commit-1.log all Passed (gitleaks included) |

## Checks run
- ansible-lint (production profile) Passed; yamllint OK; `--syntax-check` exit 0;
  pre-commit on staged files exit 0 (E/pre-commit-1.log); shellcheck on rendered
  script OK (E/rendered-open-webui-firewall.sh); `systemd-analyze verify` OK (E/rendered-unit.log).
- VM (bento/ubuntu-24.04, Docker CE via the docker role, 192.168.121.251), driven by
  E/run-vm.sh: logs vm-run-1..11, vm-checks-*.log, vm-docker-restart.log, vm-reboot.log, vm-lifecycle.log.
- Not run: laptop apply (next step), smoke-replay (community.docker unavailable in VM, BACKLOG).

## What to review
Correctness of the firewall rules against the packet path (direction handling,
scope, DNAT match, reply traffic, local access); boot/restart ordering and failure
modes; idempotence and removal; Ansible conventions in CLAUDE.md (tags, hard rules,
no --diff, hooks); docs accuracy; proportionality; whether each VERIFIED is backed.
Do not run anything against the laptop or the network; reading E is fine.

Write the review to docs/missions/2026-11-07-open-webui-homelab-proxy/review-1.md,
format of docs/agent-workflow.md §5.5, and nothing else.
