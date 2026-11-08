# Report — 2026-11-07-open-webui-homelab-proxy

## Executive summary

Objective: let the HomeLab Caddy (192.168.10.70) reach Open WebUI on this laptop
(192.168.10.217:3030) so MR !102 can publish it at https://openwebui.internal.

Verdict: PASS for the laptop-side scope. Two caveats:
- The laptop reboot was inspected, not executed.
- The owner still has to set WebUI URL in the admin UI.

End-to-end publication (HTTPS, browser login, streamed chat) is outside this
mission and stays pending until HomeLab deploys MR !102.

Accomplished:
- The open_webui role can publish on a LAN IPv4 address behind a persistent
  DOCKER-USER filter.
- The role is applied on this laptop.
- Caddy gets 200 and another LAN host is dropped.
- The filter survives a Docker restart, and the second run reports changed=0.
- Data and auth are intact.
- The work is committed and pushed (PR #66, not merged). CI is green, and the
  Codex final review is PASS_WITH_RESERVATIONS.

Remaining:
- Owner: set Admin Settings → General → WebUI URL.
- HomeLab: deploy MR !102.
- Laptop reboot test.
- Confirm the DHCP reservation on the router.

## Initial state and scope

- Repository: TiPunchLabs/laptop-bootstrap.
- Branch and worktree: feat/open-webui-homelab-proxy, at
  ../laptop-bootstrap-worktrees/open-webui-homelab-proxy, based on origin/main
  7311985. The main checkout was not touched (snapshot below).
- Laptop before the change:
  - Container a874108b, ghcr.io/open-webui/open-webui:v0.13.0, published on
    127.0.0.1:3030, restart unless-stopped, volume open-webui.
  - DOCKER-USER was empty.
  - Docker 29.9.3 with the iptables firewall backend (iptables-nft 1.8.11).
  - caddy-70 and dns-71 got connection refused.
- Excluded from scope:
  - merge, laptop reboot, HomeLab and MR !102, Ollama;
  - other services, direct DB edits;
  - the Open WebUI version change.

## Root cause and implementation

Root cause: the role published the container on 127.0.0.1 only. Docker-published
ports also bypass the host INPUT chain. A LAN bind therefore needs filtering in
DOCKER-USER (filter FORWARD), not in INPUT or ufw.

Implementation, in the open_webui role:
- Inputs:
  - open_webui_bind_address: IPv4 only; any non-127 address turns the filter on.
  - open_webui_host_port.
  - open_webui_allowed_sources (new): IPv4 addresses or CIDRs, at least one when
    the filter is on.
  - open_webui_url (new): sets WEBUI_URL when non-empty.
  - Loopback stays the default.
- /usr/local/sbin/open-webui-firewall:
  - Creates the dedicated chain OPEN-WEBUI-INGRESS, loaded atomically with
    `iptables-restore --noflush`.
  - Allowed sources go to RETURN. Traffic whose conntrack mapping is host port →
    8080 is dropped.
  - The jump from DOCKER-USER matches only `--ctstate DNAT --ctdir ORIGINAL`, so
    reply packets and host-local access are not affected.
  - DOCKER-USER is never flushed, so other rules in it are kept.
- open-webui-firewall.service: oneshot unit with RemainAfterExit, Before= and
  PartOf=docker.service, and [Install] RequiredBy=docker.service.
  - If the filter fails, Docker does not start (fail closed).
  - It reruns before dockerd on every Docker start.
- Ansible behavior:
  - The unit is never restarted or stopped while enabled, because Requires would
    restart Docker.
  - The script runs directly when it changed or a probe failed.
  - `systemctl reenable` runs when the unit file changes.
  - The container is stopped (`docker stop`) before the rules change when the
    published host port differs.
  - The filter is applied before the container is created or recreated.
- Back to loopback: the unit is disabled first, then stopped. Unit file, script,
  jump and chain are removed.
- This laptop (group_vars/all/vars.yml): bind 0.0.0.0, port 3030 (unchanged),
  allowed 192.168.10.70, open_webui_url https://openwebui.internal.

WEBUI_URL and CORS (from the v0.13.0 source, E/openwebui-v0.13.0-source.log):
- The setting is persisted per key, and the stored DB value takes precedence over
  the env var.
- seed_defaults stored `webui.url=""` at first start, so the env var has no effect
  on this install. The owner must set it in Admin Settings → General → WebUI URL.
- CORS_ALLOW_ORIGIN defaults to `*` and was left unchanged. The response echoes
  `Origin: https://openwebui.internal` with credentials allowed.

## Changed files and commits

Commits on feat/open-webui-homelab-proxy:
- 75c9ebc feat(open-webui): expose Open WebUI to the homelab Caddy behind a
  DOCKER-USER filter
- 5f763a3 docs(missions): record open-webui homelab proxy final review and evidence
- The commit adding this report follows.

Files:
- roles/open_webui:
  - defaults/main.yml
  - vars/main.yml (new)
  - meta/main.yml
  - tasks/main.yml
  - tasks/firewall.yml (new)
  - tasks/firewall_absent.yml (new)
  - templates/open-webui-firewall.sh.j2 (new)
  - templates/open-webui-firewall.service.j2 (new)
  - README.md
- group_vars/all/vars.yml
- README.md, CLAUDE.md, BACKLOG.md
- docs/missions/2026-11-07-open-webui-homelab-proxy/: mission, review briefs 1–3,
  reviews 1–3, this report.

PR: https://github.com/TiPunchLabs/laptop-bootstrap/pull/66. Open and mergeable,
not merged.

## Checks and reviews

Evidence directory E = ~/.local/share/laptop-bootstrap-agent/2026-11-07-open-webui-homelab-proxy/

- pre-commit at commit (E/commit.log): Passed for ansible-lint (production
  profile), yamllint, gitleaks, detect-private-key and yaml checks.
- Playbook syntax check: passed.
- The rendered script passed shellcheck, and the rendered unit passed
  systemd-analyze verify.
- CI on PR #66: lint and terraform both pass. CI does not prove the laptop state.
- Smoke VM (Ubuntu 24.04), logs E/vm-*.log:
  - allow/deny confirmed by counters;
  - a foreign DOCKER-USER rule was kept;
  - idempotence and --check;
  - Docker restart and reboot ordering;
  - port change under 118 denied probes, none succeeded;
  - interrupted run: container stopped, nothing listening;
  - fault injection: Docker refused to start and the port stayed closed;
  - disable and re-enable without a Docker restart.
- Codex reviews (Herdr pane w1Q:pP, now closed):
  - Review 1: CHANGES_REQUESTED, three findings, all fixed.
    - F1.1 fail-open at boot → RequiredBy.
    - F1.2 port-change window → docker stop first.
    - F1.3 source evidence.
  - Review 2: PASS_WITH_RESERVATIONS.
  - Review 3 (final, covering the final code and the deployment evidence):
    PASS_WITH_RESERVATIONS, no implementation regression.
    - F3.1 [minor]: evidence capture, fixed in 5f763a3.
    - Fix: the owner playbook outputs were saved from the session transcript
      (E/laptop-play-1-apply.log, E/laptop-play-2-idem.log).
    - Fix: the final main-tree comparison was saved
      (E/main-tree-snap-final.log, UNCHANGED).

## Deployment status and verification (laptop)

The owner applied the change with `make play-open-webui` from the worktree.

| What | Method | Result | Status |
|---|---|---|---|
| First apply | owner run, E/laptop-play-1-apply.log | ok=32 changed=6 failed=0; container 0c922985 on 0.0.0.0:3030, v0.13.0 | VERIFIED |
| Local health | curl 127.0.0.1 and 192.168.10.217 :3030/health | 200 / 200 | VERIFIED |
| Caddy reaches upstream | `ssh caddy-70 curl http://192.168.10.217:3030/health` | 200; RETURN counter 7 packets | VERIFIED |
| Other LAN source denied | same command from dns-71 | curl exit 28 (timeout); DROP counter 5 packets | VERIFIED |
| No IPv6 listener | `ss -ltn`, `ss -6 -ltn`, `docker port` | only 0.0.0.0:3030; ip6tables DOCKER-USER empty | VERIFIED |
| Data, auth, key, model connection, image | before/after read-only queries (E/laptop-baseline.log, E/laptop-after-apply.log) | 1 admin, 1 chat, alembic e42c8f710a36, key sha256 prefix, Ollama URLs and image id all identical; auth on, signup off, unauthenticated API returns 401 | VERIFIED |
| Persistence across a Docker restart | authorized `systemctl restart docker` (E/laptop-docker-restart.log) | unit re-ran 20:59:07 before dockerd; rules restored; caddy 200, dns-71 dropped | VERIFIED |
| Effect on other containers | same log | byenvini-dev-pg, mailpit, localstack (unless-stopped) restarted and were healthy within 15 s; stopped containers stayed stopped | VERIFIED |
| Idempotence | owner second run (E/laptop-play-2-idem.log, E/laptop-rerun-idem.log) | ok=29 changed=0; same container id and StartedAt; caddy 200 | VERIFIED |
| Reboot ordering | inspection (E/laptop-boot-ordering.log) | docker.service.requires/open-webui-firewall.service link; docker After= includes the unit; VM reboot test passed | VERIFIED by inspection; laptop reboot NOT_VERIFIED (not executed) |
| WEBUI_URL effective | read-only DB query | DB webui.url still "" | NOT_VERIFIED (owner UI action pending) |
| Main checkout untouched | snapshot (E/main-tree-snap-final.log) | 14021b4b… = baseline | VERIFIED |

Late Wi-Fi lease:
- The rules match on conntrack mapping and source only, with no destination
  address or interface, and the bind is 0.0.0.0.
- So the filter does not depend on when wlo1 gets its address.
- Not exercised on the laptop.

## Firewall persistence and rollback

- Persistence: the unit is enabled with RequiredBy=docker.service, so the rules
  are rebuilt before every Docker start (boot or restart).
- Fail closed: if the script fails, Docker and all containers stay down. Recovery:
  `sudo /usr/local/sbin/open-webui-firewall`, then `sudo systemctl start docker`.
  Never `systemctl stop` or `systemctl restart` the filter unit by hand.
- Rollback to loopback only:
  - Remove the three overrides from group_vars/all/vars.yml, or revert the PR.
  - Rerun `make play-open-webui`. The role recreates the container on
    127.0.0.1:3030 and removes the unit, script, jump and chain.
- Emergency: `docker stop open-webui`.
- Data backup: ~/Backups/open-webui-2026-11-07/open-webui-20261107-2356.tar.gz
  (root, 0600, contains webui.db and the secret key). Restore is described in the
  role README. A restore was not tested.

## Deviations, risks and limitations

- The backup pulled the `alpine:3` image onto the laptop.
- Docker availability now depends on the filter script. This is the deliberate
  fail-closed trade-off and is documented.
- The drift probe checks the jump and the DROP rule, not each allowed-source line.
- Rule scope is the host port → 8080 mapping, not the container identity.
- Other containers publish on 0.0.0.0 and [::] without a filter. They are out of
  scope and unchanged.
- DHCP:
  - 192.168.10.217 relies on the router's static lease. The router
    (192.168.10.1) is not accessible from here.
  - The wlo1 MAC b8:1e:a4:da:3e:4d matches the documented reservation, and 247
    DHCP events since 2026-07-20 all gave .217.
  - The reservation itself is NOT_VERIFIED.
- The smoke VM from this mission is still running.

## Manual actions (owner)

1. Open WebUI → Admin Settings → General → WebUI URL = `https://openwebui.internal`, then save.
2. Optional: confirm the 192.168.10.217 reservation on the router.
3. Optional: `make smoke-down` to remove the mission VM.
4. Review and merge PR #66.

## MR !102

The laptop side is ready. Caddy (192.168.10.70) gets 200 from
`http://192.168.10.217:3030/health`, and other LAN sources are dropped. The
upstream in MR !102 (`192.168.10.217:3030`) needs no change, because neither the
address nor the port changed. MR !102 can proceed.

After deployment, still to verify:
- DNS and internal TLS for openwebui.internal;
- browser login over HTTPS;
- WebSocket and streamed chat through Caddy.

If the laptop address ever changes: update the Caddy upstream in MR !102. If
Caddy's address changes: update open_webui_allowed_sources here and rerun.

## Recommended next action

Owner sets the WebUI URL (step 1 above), then merges PR #66 and MR !102. All of
these need owner approval. Nothing in this mission blocks them.
