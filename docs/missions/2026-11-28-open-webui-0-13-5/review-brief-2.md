# Review brief 2 — 2026-11-28-open-webui-0-13-5

- Version under review: `c364acb97fcc6aad6ebfb4609445ff974d2fc069` (branch `feat/open-webui-0-13-5`). Diff since review 1: `git diff c318c0b c364acb`. Full change: `git diff f8299e9 c364acb`.
- Read `mission.md`, your `review-1.md`, then `report.md` (section answering review 1) and the new backup/restore script and README sections.
- Evidence (read-only): `~/.local/share/laptop-bootstrap-agent/2026-11-28-open-webui-0-13-5/`.

## What to review

1. F1.1, F1.2, F1.3: is each resolved? Check the script and runbook code paths yourself (set -euo pipefail coverage, every failure exits before the irreversible step, archive validation, staging-volume restore, prerestore volume kept, container left stopped after restore, placeholder refused), and the VM failure-path evidence.
2. The NOT_VERIFIED branch (swap failure mid-restore → old data put back): is the code path correct by reading? Is leaving it unrehearsed acceptable?
3. Regressions: README backup/restore/rollback sections, proportionality of the script, shellcheck-level problems, secrets (archive permissions 0600, nothing printed), idempotence of the role unchanged.
4. AC6 and AC-SAFE again.

## Rules

Same as review-brief-1.md (no network, no vault, no Docker/VM/laptop operations, write only `docs/missions/2026-11-28-open-webui-0-13-5/review-2.md`, format §5.5, header `VERDICT:` and `Version: c364acb97fcc6aad6ebfb4609445ff974d2fc069`). Severity: blocker/major only for data loss risk, a broken apply or rollback, a security exposure, or an AC claimed VERIFIED without evidence.
