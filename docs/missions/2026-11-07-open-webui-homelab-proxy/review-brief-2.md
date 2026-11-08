# Review brief 2 — 2026-11-07-open-webui-homelab-proxy

Same objective, base (7311985), branch and evidence dir (E) as review-brief-1.md.
Laptop apply still follows this review. Changes since review 1: `git diff` of the
worktree vs the state you reviewed (roles/open_webui/tasks/firewall.yml,
tasks/firewall_absent.yml, templates/open-webui-firewall.service.j2, README.md,
BACKLOG.md, mission.md).

## Resolution of review-1 findings
- F1.1 [major] fail-open at boot — FIXED. Unit: `RequiredBy=docker.service`
  (+ Before, PartOf). Failed filter ⇒ `Dependency failed for docker.service`,
  nothing published. Because Requires propagates stop/restart, Ansible never
  restarts/stops the enabled unit: it `systemctl reenable`s when the unit file
  changes, `state: started`, and runs the script directly when the script changed
  or a probe fails; removal disables first (drops the requires link), then stops.
  Evidence: E/vm-failclosed-reboot.log (script → `exit 1`, `systemctl restart docker`
  → rc=1, docker inactive, unit failed, no listener, host 000; repair + start OK;
  clean reboot ordering firewall 23:50:43.12 < docker start 44.32 < container 45.04);
  E/vm-fix1-upgrade.log (wants→requires, docker ActiveEnterTimestamp unchanged,
  container untouched, rerun changed=0); E/vm-fix1-lifecycle.log (disable/re-enable,
  Docker ActiveEnterTimestamp unchanged throughout, sentinel kept, idempotent, --check 0).
- F1.2 [major] port-change window — FIXED. firewall.yml reads the container
  (`docker_container_info`) and runs `docker stop` before touching rules when its
  published host port differs. Evidence: E/vm-probe-portchange.log (118 probes on
  3030 and 3031 from a denied client during the 3030→3031 run: 0×200);
  E/vm-interrupted-2.log (3031→3030 with a missing image tag: run fails at pull,
  same container id stopped, `unless-stopped`, ports/mount intact, no listener, both
  ports 000; recovery run healthy; rerun changed=0).
  Found while testing: `docker_container state: stopped` with only `name` RECREATED
  the container with module defaults (E/vm-interrupted.log: `restart=no ports={}`);
  replaced by `docker stop`.
- F1.3 [minor] source evidence — FIXED. E/openwebui-v0.13.0-source.log: excerpts
  from the running laptop container (image id, build hash): `WEBUI_URL` default
  mapping, `Config.get` (DB row wins), `seed_defaults` (inserts missing keys at
  startup, called from `seed_registered_defaults`), `CORS_ALLOW_ORIGIN` default `*`
  and `SOCKETIO_CORS_ORIGINS`. Owner Admin Settings action remains explicit (README,
  BACKLOG).
- Reservations: hook-only probe → probe now also checks the DROP rule (not the
  RETURN lines; documented). Port-based scope documented under Limits. BACKLOG
  wording no longer says "done".

## Checks (post-fix)
ansible-lint production Passed (two documented `noqa` on the reenable command);
pre-commit and syntax rerun before this brief (E/pre-commit-2.log).

## What to review
The fixes above and any regression they introduce (Requires semantics, reenable,
removal order, docker stop condition, check mode), plus anything left from review 1.
Write docs/missions/2026-11-07-open-webui-homelab-proxy/review-2.md (§5.5 format),
nothing else. No laptop, network, Docker or iptables commands.
