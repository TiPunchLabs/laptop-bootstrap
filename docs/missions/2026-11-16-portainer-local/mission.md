# Mission 2026-11-16-portainer-local — Portainer on the laptop, published at portainer.internal

## Objective

Owner request, 2026-11-16, verbatim: « prendre en charge l'installation de portainer en local sur mon poste un peu comme on a pris en charge l'installation d'openwebui il faut qu'il soit accessible via portainer.internal aussi »

Optimized brief (pilot): manage a reproducible, Docker-based Portainer CE installation on this laptop through laptop-bootstrap, following the `open_webui` role and the two Open WebUI missions (`2026-11-05-open-webui`, `2026-11-07-open-webui-homelab-proxy`), then publish it at `https://portainer.internal` through HomeLab's Caddy (192.168.10.70) and Pi-hole, as done for `openwebui.internal` (homelab commit `954cb6a`).

## Context the executor must take into account

- Portainer was deliberately removed from this laptop and repository on 2026-11-07 (`docs/missions/2026-11-07-remove-portainer/`). This mission reinstalls it on the owner's new request. Old data backup: `~/Backups/portainer-2026-11-07/portainer-07-local.tar.gz` — **not restored** (fresh install, assumption A1); leave it untouched. BACKLOG item "`ansible-docker-apps` still ships the Portainer role" stays as is: do not use or modify that other repository.
- Main checkout `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap` is on another branch (`feat/mise-act-pinact`): do not touch it. Work in this worktree: `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/portainer`, branch `feat/portainer-local` from `origin/main` `0b892c6` (run `uv sync --frozen` here as `docs/agent-workflow.md` §3 requires).
- Follow `docs/agent-workflow.md` (isolation, snapshots, smoke VM, review format) and `AGENTS.md`/`CLAUDE.md`.

## Requirements (laptop-bootstrap)

1. Dedicated role `portainer`, same conventions as `open_webui`: official `portainer/portainer-ce` image with an explicit, current **LTS** release tag (verify with context7/official docs; no `latest`); existing Docker management mechanism only; data in a named volume; automatic restart; a supported health check; dedicated tag that runs nothing else (not `cleanup_legacy`, not `open_webui`); Docker prerequisite explicit; no automatic image updates.
2. Exposure like Open WebUI: configurable bind address, host port(s), allowed sources; default loopback only; for this laptop, publish to the LAN only for `192.168.10.70` (Caddy) with the same kind of scoped DOCKER-USER filter and its lifecycle (installed before exposure, survives Docker restart/reboot ordering, removed on disable). Reuse or minimally generalize the existing mechanism; no second competing firewall mechanism; Open WebUI's rules and behaviour must stay unchanged (prove it). IPv4 only.
3. Choose the upstream protocol Caddy will use (Portainer HTTPS 9443 with its self-signed cert vs HTTP 9000) from the pinned version's documentation; justify; expose only what is needed.
4. Docker socket: Portainer needs `/var/run/docker.sock` (root-equivalent on this host). Mount only what the documented CE install needs, and state the risk and the mitigations (exposure limited to loopback + Caddy, HTTPS end to end at Caddy, admin auth) in the role README.
5. Admin account: Portainer locks the initial-setup page a few minutes after first start, and an exposed setup page is a takeover risk. Do not expose the instance to the LAN before the admin exists. Apply decision D1 (below); no credential in the repo, logs or diffs.
6. Docs: role README, `group_vars` for this laptop with comments like Open WebUI's, BACKLOG updated (remove/adjust the Portainer-removal notes only where they become wrong).

## Requirements (homelab) — step S3, separate executor session in the homelab repo

7. Pi-hole: `portainer.internal` → Caddy, same pattern as `openwebui.internal` (`pihole/ansible/group_vars/pihole/all/main.yml`).
8. Caddy: site `portainer` → laptop `192.168.10.217:<port>` per item 3, `tls_internal: true`, comment like the openwebui entry (laptop-only availability, 502 when off LAN). `tls_insecure_skip_verify` only if the HTTPS upstream requires it, justified.
9. Homelab branch + MR; deployment of Caddy/Pi-hole is decision D2 (reserved).

## Acceptance criteria

| ID | Criterion | Verification |
|---|---|---|
| AC1 | Role installs a pinned Portainer CE LTS with named volume, restart policy, health check, dedicated tag; rerun `changed=0` | smoke VM + laptop apply, recap lines |
| AC2 | Default loopback; laptop config publishes only to 192.168.10.70; other LAN sources dropped; local access works; IPv4 only | VM curl matrix + laptop `ss -ltn`, `docker port`, filter counters |
| AC3 | Filter lifecycle: before exposure, Docker restart, reboot ordering (inspection on laptop), disable → loopback with rules/unit removed; Open WebUI rules unchanged | VM tests incl. Open WebUI sentinel; laptop before/after `iptables -S DOCKER-USER` |
| AC4 | Admin created per D1 before any LAN exposure; no secret in repo/logs/diffs | ordered tasks, logs, gitleaks |
| AC5 | Socket risk documented; nothing beyond the documented CE install mounted | README, `docker inspect` mounts |
| AC6 | homelab MR: DNS + Caddy entries correct and consistent with the laptop port/protocol; homelab lint/CI green | MR diff, pipeline |
| AC7 | After D2: `https://portainer.internal` reachable from the LAN through Caddy with the internal CA, login page served, 502 documented when laptop off | curl from LAN host / Caddy host |
| AC8 | Open WebUI, Ollama and unrelated containers untouched | before/after `docker ps`, Open WebUI health |
| AC-SAFE | No merge, no laptop reboot, no unrelated cleanup, no restore of old Portainer data, no change to the main checkout | git/worktree state, evidence |

## Authorizations (owner request of 2026-11-16 read as for the Open WebUI missions)

Authorized: laptop-bootstrap worktree + smoke VM; targeted apply of the `portainer` role (and its filter) on this laptop; commit, push, open a PR (laptop-bootstrap) and an MR (homelab branch). Not authorized without a recorded owner decision: merges, HomeLab deployment (D2), laptop reboot, changes to Open WebUI/Ollama/other containers, restoring the 2026-11-07 backup.

## Assumptions

- A1 fresh install; the old backup stays untouched.
- A2 LAN address and Caddy source as for Open WebUI (`192.168.10.217`, `192.168.10.70`).
- A3 model economy (pilot CLAUDE.md §2.3): the executor delegates mechanical/verification work to cheaper subagents on its own judgment and lists delegations in `report.md`.

## Decisions for the owner

- D1 Admin bootstrap. Recommendation: bcrypt hash of the admin password stored in Ansible Vault (owner runs `ansible-vault edit`, the role passes it with `--admin-password-file`), so the instance is never reachable without an admin. Alternative: first start loopback-only, the owner creates the admin locally in the browser, then the LAN exposure is applied. Consequence: the recommendation is fully reproducible; the alternative needs one manual step on each reinstall.
- D2 HomeLab deployment of the Pi-hole + Caddy change (and merge of the homelab MR). Asked when the MR is ready.

## Steps

- S1 executor (laptop-bootstrap): role, filter, docs, smoke VM tests, laptop apply up to loopback-only exposure until D1 is applied; `report.md`.
- S2 Codex review of the laptop-bootstrap change (max 3).
- S3 executor (homelab): Pi-hole + Caddy branch and MR; evidence.
- S4 after D2: deploy, end-to-end check AC7, final report.

## State

- Phase: S1 + D1 implementation done (executor); waiting for the S2 review and the owner's vault edit + laptop apply
- Branch / worktree: feat/portainer-local (no upstream) / ../laptop-bootstrap-worktrees/portainer
- Base commit: 0b892c6; code verified at 21b839f4c8548dcbaa067265b8bfda2d3511ee27 (laptop runs a61f35f)
- Evidence dir: ~/.local/share/laptop-bootstrap-agent/2026-11-16-portainer-local/
- Main-tree snapshot baseline: evidence dir, main-tree-snap-baseline.txt (unchanged at the end of S1)
- Laptop: portainer 2.45.3 on 127.0.0.1:9443, no admin yet (setup timed out), no LAN exposure
- Review cycle: 1 of 3 (review-1 CHANGES_REQUESTED, answered in 21b839f)
- Next step: pilot dispatches S2; owner runs owner-commands-d1.md (vault hash, make play-portainer) and reports outputs

## Log

- 2026-11-16 S1: role portainer + shared docker_port_filter (Open WebUI filter extracted, rendered files byte-identical); smoke VM lifecycle tests; laptop apply --tags portainer, loopback only (changed=2, rerun changed=0). Report: report.md.

## Log

- 2026-11-16 (owner decision D1): « Hash dans Vault (Recommandé) » — the bcrypt hash of the Portainer admin password is stored in Ansible Vault by the owner (`ansible-vault edit`), and the role passes it to Portainer with `--admin-password-file` (or the documented equivalent for the pinned version) so the instance never runs without an admin. Agents have no Vault access: the executor implements and tests it with a throwaway hash on the VM, then hands the owner the exact sanitized commands (generate the hash, `ansible-vault edit`, targeted apply) that ask only for recap/status output.
- 2026-11-16 D1 implemented: --admin-password <vault bcrypt hash> (5de0c8a), check-mode fix in docker_port_filter (2962443); VM tests with a throwaway hash (existing admin kept, fresh/laptop-like instance gets the admin at start, no leak at -vvv/--check --diff); laptop --check without vault refused, no change. Owner commands: owner-commands-d1.md. Report updated.
- 2026-11-16 fix-1: review-1 F1.1/F1.2 fixed in 21b839f (admin proven on the mounted volume; hash only in a one-shot unpublished bootstrap container; unconditional no_log); VM scenarios incl. the reviewer's, poller 0 x 404, leak scans 0; laptop --check refused, no change.
- 2026-11-16 (owner decision D2, verbatim): « fusion MR !108 et maj le local ». Authorizes merging homelab MR !108 (Pi-hole + Caddy for portainer.internal) and fast-forwarding the owner's local homelab `main` checkout. Context: the owner had already run the two playbooks from `main` 0b0a342, before the merge, so they deployed nothing for Portainer; he re-runs them after the merge.
