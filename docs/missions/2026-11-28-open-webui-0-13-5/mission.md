# Mission 2026-11-28-open-webui-0-13-5 — Upgrade Open WebUI to v0.13.5

## Objective
Owner, 2026-11-28 (French): « cadre la mission de maj de d'openwebui ». Context: the LLM Wiki scoping mission (`/home/xgueret/Workspace/99-temp/2026-11-27-llm-wiki-local/proposition-llm-wiki-local.md`, decision D7) recommends Open WebUI v0.13.5 before building the knowledge base `wiki-tech` (0.13.1 and 0.13.3 change knowledge-base behaviour), and the owner decided the upgrade goes through laptop-bootstrap.

## Authorizations
Default (docs/agent-workflow.md): repository on this worktree/branch + smoke VM (no smoke-down).
Extra: commit on `feat/open-webui-0-13-5` (Conventional Commits). NOT granted: push, PR, merge, and any change to this laptop's running Open WebUI (backup, `make play-open-webui`, container stop/start): those are owner decisions after the Codex review.

## Scope
In: bump `open_webui_version` in `roles/open_webui/defaults/main.yml` from v0.13.0 to the target tag (v0.13.5 if it is still the latest stable release; if a newer stable exists, stop and report, the pilot asks the owner); README/docs mentioning v0.13.0; release-note analysis v0.13.0 → target (database migrations, breaking changes, RAG/knowledge/embedding/tool-calling changes, env var renames that the role sets); smoke VM replay twice; the exact owner runbook for this laptop (backup → apply → checks → rollback).
Out: Ollama, LiteLLM, any Open WebUI admin setting or knowledge base, any data in the laptop's `open-webui` volume, the vault.

## Acceptance criteria
| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Target tag chosen from the official releases page, with date | URL + tag + date in report | VERIFIED |
| AC2 | Release notes v0.13.0 → target analysed: DB migrations, breaking changes, settings/env vars used by the role, changes to knowledge bases, embeddings, hybrid search, native tool calling | report section with links | VERIFIED |
| AC3 | `open_webui_version` bumped in the role default only; docs updated; no other behaviour change | diff | VERIFIED |
| AC4 | Checks of docs/agent-workflow.md §4.2 for role changes pass (ansible-lint, yamllint, syntax-check) | command outputs | VERIFIED |
| AC5 | Smoke VM: `TAGS=open-webui` replay from v0.13.0 to target, then a second run `changed=0`; image tag and `/api/config` version checked on the VM | excerpts | VERIFIED |
| AC6 | Owner runbook for this laptop: volume backup (README « Backup and restore »), `make play-open-webui`, `docker inspect` image, `/api/config` version, second run `changed=0`, sign-in check, Ollama models visible, rollback steps; states what needs sudo or the vault (`pass`) | report section | VERIFIED (written, VM-rehearsed; laptop run pending owner) |
| AC-SAFE | Owner's local work preserved; no secret read or written (dummy vault, §4.1); hooks not bypassed; this laptop's Open WebUI untouched | §6 + `docker inspect open-webui` image unchanged (v0.13.0) at the end | VERIFIED |

## Plan
1. Inspect the role, its README, defaults; current laptop state read-only (`docker inspect open-webui --format '{{.Config.Image}}'`, `curl -fsS http://127.0.0.1:3030/api/config | jq -r .version`).
2. Release notes and target tag (official GitHub releases; context7 first for docs).
3. Implement the bump + docs; checks §4.2.
4. Smoke VM replay twice.
5. report.md (docs/agent-workflow.md §7) with the owner runbook; commit on the branch. Reviews are routed by the pilot (Codex), not started by the executor.

## State
- Phase: report after fix-1 (awaiting review 2, routed by the pilot)
- Branch / worktree: feat/open-webui-0-13-5 / /home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/open-webui-0-13-5
- Base commit: f8299e9 (origin/main)
- Evidence dir: ~/.local/share/laptop-bootstrap-agent/2026-11-28-open-webui-0-13-5/
- Reviewer: routed by the pilot (Codex)
- Review cycle: 1 of 3 (review 1 CHANGES_REQUESTED, fixed)
- Next step: Codex review 2 (pilot); if no blocker/major: push, PR, merge (CI green), then owner runbook in report.md
- Main-tree snapshot baseline: E/main-tree-snap-baseline.txt (6c87c520…d056a8, unchanged at report)
- Smoke VM: smoke_default (Vagrant state in the portainer worktree), started with virsh, left running on v0.13.5

## Notes for the executor
- Model economy: mechanical work (release-note scraping, lint/smoke runs, log parsing) may go to cheaper subagents (Sonnet/Haiku); list delegations in report.md.
- Never run `make play*` against this laptop, never stop or recreate the `open-webui` container, never touch the `open-webui` volume.
- End your turn with the line: `report ready, Version = <commit sha>`.

## Log
- 2026-11-28 pilot: mission framed on owner request; worktree from origin/main f8299e9.
- 2026-11-28 owner « tu es autorisé à faire : il te restera à pousser, ouvrir la PR, fusionner, et appliquer la mise à jour sur ton portable »: authorizes, for this mission only and AFTER a Codex review with no blocker/major finding: push of feat/open-webui-0-13-5, PR to main, merge (keep commits) once CI is green, then the laptop apply per the report's owner runbook (volume backup first, make play-open-webui, checks, second run changed=0). Steps needing the real vault (`pass`) or an interactive sudo password stay with the owner. Pilot routes these after the review; the executor does not start them on its own.
- 2026-11-28 inspect: laptop open-webui 96ee79d9 v0.13.0 healthy on 192.168.10.217:3030 (repo says 0.0.0.0; pre-existing drift). /api/config on 127.0.0.1 unreachable (not on loopback).
- 2026-11-28 releases: v0.13.5 latest stable (2026-11-25); notes v0.13.1-v0.13.5 saved in E, analysis delegated (Sonnet) and spot-checked.
- 2026-11-28 implement: defaults v0.13.5, role README, README, BACKLOG. Worktree venv built with --python 3.12 (rpds-py). Lint/yamllint/syntax exit 0.
- 2026-11-28 verify: VM baseline v0.13.0 changed=2 (filter sources) → seed user+chat → backup → update changed=1 (alembic e42c8f710a36 → 5e7a2c9d4b13, chat migrated) → changed=0 → rollback rehearsal OK → update again changed=1 → changed=0.
- 2026-11-28 report: report.md written; laptop open-webui unchanged (same id, v0.13.0, restarts 0); main snapshot unchanged.
- 2026-11-28 fix-1: review 1 CHANGES_REQUESTED (F1.1, F1.2 major; F1.3 minor). F1.1/F1.2 → bin/open-webui-volume.sh (backup: space check, stop, .partial, archive check gzip+integrity+key, rename, restart on any exit; restore: placeholder/missing refused, archive check, staging volume + check, stop, prerestore copy, swap + check, put-back on failure, container left stopped); runbook as one set -euo pipefail block; role README Backup/Restore/Rollback aligned. F1.3 → report "Authorizations and decisions" quotes the owner's conditional grant (not yet met). VM: apt-get clean (disk), backup failures a-c, restore failures a-c, gate closed, restore→rollback v0.13.0, gated update changed=1, idempotence changed=0. Laptop untouched. BACKLOG: portainer README restore follow-up.
