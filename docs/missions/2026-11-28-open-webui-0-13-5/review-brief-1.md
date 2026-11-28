# Review brief 1 — 2026-11-28-open-webui-0-13-5

- Mission: `docs/missions/2026-11-28-open-webui-0-13-5/mission.md` (objective, authorizations, AC table). Read it first, then `report.md` in the same folder (executor's AC statuses, evidence, owner runbook).
- Branch `feat/open-webui-0-13-5`, base `f8299e9` (origin/main), version under review: `c318c0bdd5e27a9ab1013ffe241157b5519db48b`. Diff: `git diff f8299e9 c318c0b` (6 files: role default, role README, README, BACKLOG, mission, report).
- Evidence directory (read-only for you): `~/.local/share/laptop-bootstrap-agent/2026-11-28-open-webui-0-13-5/`.

## What to review

1. AC1–AC6 and AC-SAFE against the code and the evidence; every VERIFIED must be backed by evidence.
2. The release-note analysis v0.13.0 → v0.13.5 (database migrations, breaking changes, settings/env vars the role sets, knowledge base / embeddings / hybrid search / native tool calling): is anything the role sets or the owner runbook relies on affected and missed? You have no network: judge from the report's quotes and the role's templates/tasks; list what you could not check.
3. The owner runbook for this laptop (report): backup before apply, order of steps, health-wait (300 s) vs a long migration on real data, rollback, what needs `pass` (vault) or sudo. It will be executed after this review: any step that could lose data or leave Open WebUI down is at least major.
4. The binding change the report flags: the live container is published on 192.168.10.217:3030 while the repo sets 0.0.0.0:3030; the apply will move it. Assess exposure given the role's firewall tasks (`roles/open_webui/tasks/firewall.yml`, templates) and say whether it is acceptable as is.
5. Idempotence, consistency with README/guides, proportionality, CLAUDE.md hard rules.

## Rules

- Read AGENTS.md of this repository. No network; never read or decrypt the vault (a dummy password file is set in `ANSIBLE_VAULT_PASSWORD_FILE`); never touch this laptop's `open-webui` container or volume, the smoke VM, or anything outside this worktree except reading the evidence directory.
- Severity: blocker/major only for data loss risk, a broken apply or rollback, a security exposure, or an AC claimed VERIFIED without evidence; everything else minor.
- Write ONLY `docs/missions/2026-11-28-open-webui-0-13-5/review-1.md`, format `docs/agent-workflow.md` §5.5, header line `VERDICT: …` and `Version: c318c0bdd5e27a9ab1013ffe241157b5519db48b`.
