# Review 3 — 2026-11-12-pin-mise-seed-versions

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- F3.1 [minor] docs/missions/2026-11-12-pin-mise-seed-versions/mission.md:64 — AC-SAFE is marked VERIFIED for “nothing run on the real laptop besides read-only `mise ls/registry/ls-remote`”, but the mission log and `kubectl-1.34.13-vagrant.txt` record additional laptop commands, including client/server version and node queries. The earlier brief also lists additional read-only mise commands. Reconcile the criterion with the recorded read-only cluster checks and isolated tests, and qualify any historical safety assertions that lack a complete command audit. This is an inaccurate verification statement, not evidence that the live config was changed or secrets were exposed.

## AC check

Evidence filenames refer to `/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/`. Execution logs are supplied implementer evidence; reviewer reruns below were local reads only.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Independent TOML comparison against HEAD confirms the same 14 identifiers and order, exactly twelve numeric semver replacements, unchanged node `26` and pnpm `12`, and no additional top-level configuration. Every exact version appears in its saved backend listing. `toml-compare-2.txt` agrees. |
| AC2 | VERIFIED from supplied evidence, linux-x64 only | Earlier review evidence remains applicable to the eleven unchanged pins. `kubectl-1.34.13-vagrant.txt` records isolated installation exit 0 and the absolute-path binary reporting v1.34.13; the new VM state agrees. Brief 3 quotes release metadata for v1.34.13 (`prerelease=false`, `draft=false`, published 2026-10-28). The saved listing ends the 1.34 series at 1.34.13. The release metadata was not independently fetched; `upstream-releases.txt` still describes the previous kubectl pin. |
| AC3 | VERIFIED within stated coverage | Saved live test: client v1.34.13, server v1.34.3, version exit 0 without skew warning, three Ready nodes and nodes exit 0. The client matches the minor of the other declared, dormant 1.34 cluster; no live test of that cluster is claimed. Terraform 1.17.0 satisfies all seven constraint spellings in `terraform-constraints.txt`; search exit 2 and unreadable directories limit coverage. `smoke-fzf-bash.txt` records fzf 0.74.5, direct hook exit 0 and evaluation exit 0; run 4 repeats direct hook exit 0. |
| AC4 | VERIFIED from unchanged code and saved VM evidence | Task diff is empty; `force: false` and installation conditional on seed change remain. Run 4 seeds and installs, recap changed=2/failed=0. Independent seed SHA-256 `b482062fd07a5f727244b4387853ad1c92be20e0716eca4850565cd782248a3a` matches `smoke-4-vm-state.txt`, which lists kubectl 1.34.13 and the other requests. Run 5 has changed=0 and installation skipped. Run 6 preserves the edited 1.34.12 config hash `0549154b…` and mtime `1794519121`, reports changed=0 and skips installation. Replay exits 0 are quoted in brief 3; logs corroborate successful recaps. |
| AC5 | VERIFIED | Seed comment, README, ADR amendment and BACKLOG consistently explain the kubectl exception for 1.34 clusters. README retains exact-pin updates, major tracks, line-by-line promotion, preview and config-rewriting caveats. BACKLOG's server range 1.33–1.35 is correct for client 1.34 and distinguishes the unchanged laptop request. Daily guide is byte-identical to the reviewed version. Prior command demonstrations remain applicable. |
| AC6 | VERIFIED from supplied evidence | `iso3-kubectl-1.34.13-upgrade.txt` records plain upgrade exit 0, current request 1.34.13 before/after and newer 1.37.2 outside the configured range. The explicit-update half remains the previously reviewed `iso2-upgrade-demo.txt`; it demonstrates the mechanism using the previous pin. The bare client v1.34.3 is explicitly traced to `/usr/local/bin/kubectl`; the mise-executed client reports v1.34.13. |
| AC7 | VERIFIED from supplied evidence | `precommit-5.log` ends exit=0, including passing secret detection and ansible-lint. Brief 3 records syntax-check and yamllint exit 0; saved syntax output names the playbook and yamllint log is empty. Reviewer whitespace check passes. No hook rerun. |
| AC-SAFE | NOT_VERIFIED as written; partial evidence available | F3.1 contradicts the literal command restriction. The mission now records owner approval for VM destruction and a completed main-tree comparison; `main-tree-snap-final.txt` says `unchanged` against the recorded baseline `14021b4b…`. These address the previous pending-comparison reservation at the supplied-evidence level. No full historical command audit or fresh main-tree comparison was performed by this reviewer. The reviewed code preserves seed ownership and does not change cleanup or hooks. |

## Commands run

- `cat` on the using-superpowers skill, `AGENTS.md`, `CLAUDE.md`, `docs/agent-workflow.md` and review brief 3 → exit 0 for each invocation; read applicable instructions, scope and output format.
- `git status --short` and `git diff HEAD -- . ':!docs/missions/2026-11-12-pin-mise-seed-versions/report.md'` → exit 0; inspected staged scope and diff, excluding the report as instructed. The large combined output was truncated; relevant files were read again in subsequent commands.
- `cat` on briefs 1–2, reviews 1–2 and `mission.md` → exit 0 for each invocation; established prior findings, acceptance criteria and recorded decisions.
- `ls -1` on the evidence directory and `cat roles/cli_tools/tasks/main.yml roles/cli_tools/files/config.toml` → exit 0; inventoried artifacts and inspected task guards and current seed.
- `cat` on `toml-compare-2.txt`, `kubectl-1.34.13-vagrant.txt`, `iso3-kubectl-1.34.13-upgrade.txt`, `smoke-4-pre.txt`, `smoke-4-vm-state.txt`, `smoke-6-pre.txt`, `smoke-6-post.txt`, `precommit-5.log`, `main-tree-snap-baseline.txt` and `main-tree-snap-final.txt` → exit 0; inspected new pin, behavior, checks and preservation evidence.
- `cat` on `smoke-4-reseed.log`, `smoke-5-replay.log`, `smoke-6-replay.log`, `upstream-releases.txt`, `terraform-constraints.txt`, `syntax.log`, `yamllint.log` and `smoke-fzf-bash.txt` → exit 0; inspected replay recaps and retained compatibility/check evidence.
- `git diff HEAD -- roles/cli_tools/files/config.toml`, `git diff HEAD --check` and `git diff --name-only` → exit 0 each; reviewed seed change, no whitespace errors, no unstaged changes before review creation.
- `python3 -` using `tomllib`, `git show HEAD`, saved version listings, SHA-256 and a task-diff assertion → exit 0; inventory, exact requests, listing membership, unchanged tasks and VM seed hash assertions pass. Same script compared prior blobs `65f6e30` (seed), `e3e701a` (guide), `7cbc624` (ADR): only the expected kubectl/comment and ADR exception changes; guide identical. It also checked the saved final-comparison result and the last three listed 1.34 patches.
- `nl -ba docs/missions/2026-11-12-pin-mise-seed-versions/mission.md | sed -n '54,72p'` → exit 0; located F3.1 and AC statuses.

## Not checked

- No network, Context7, remote release refresh, laptop commands, smoke VM operations, Git writes or hook reruns, per review limits. CLI behavior was assessed from saved evidence rather than current documentation fetches.
- No Debian, arm64 or live dormant-cluster test. Terraform search coverage excludes the disclosed unreadable directories.
- No independent historical authorization/secret-access audit, fresh main-checkout snapshot, or complete byte-for-byte cycle-2 baseline for all mission artifacts. Seed/ADR/guide comparisons use the implementation blobs retained in the earlier reviews; README/BACKLOG and mission updates were assessed against the prior reviews and current diff.
- `report.md` was excluded as requested.

## Reservations

- Correct the narrow AC-SAFE statement before repeating an unqualified VERIFIED claim in the final report. Available evidence supports the kubectl implementation and documented read-only cluster test; it does not certify every historical action.
- The existing laptop config remains independently owned by mise; changing the reference does not replace its recorded 1.37.1 request. This limitation is disclosed consistently.
- Exact requests do not freeze the installer, backend registry, remote artifacts or retained node/pnpm tracks. The change meets the stated scope of replacing the twelve `latest` requests.
