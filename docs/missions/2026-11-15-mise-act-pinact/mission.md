# Mission 2026-11-15-mise-act-pinact — Seed act and pinact in the mise reference config

## Objective

Owner request (2026-11-15, verbatim, to the pilot):

> projet laptop: prendre en charge l'installation de act (https://nektosact.com/installation/index.html) et pin-github-actions

Pilot framing, approved by the owner on 2026-11-15 (« D1 et D2 je suis tes recommandations », « et D3 aussi », « et go pour le reste »):

- `act` (nektos/act) and `pinact` (suzuki-shunsuke/pinact, the chosen "pin GitHub
  Actions" tool, decision D1) are added to the mise reference config
  `roles/cli_tools/files/config.toml` as exact pins, through mise's default aqua backend
  (`aqua:nektos/act`, `aqua:suzuki-shunsuke/pinact`).
- A fresh laptop gets both tools on first seed. The owner's live laptop gets them with
  the command written in `report.md` (AC6), run by the owner after merge.

## Authorizations

Default: repository on a mission branch/worktree + smoke VM (no smoke-down).
Extra, granted by the owner on 2026-11-15 (decision D2): commit on
`feat/mise-act-pinact`, push of that branch to `origin`
(`git@github-xgueret:TiPunchLabs/laptop-bootstrap.git`, check the alias first), open a
pull request to `main` (draft).
Not authorized: merge, branch deletion, anything on the real laptop (`make play*`,
`mise use/install` against the live config, apt, `~/.config/*`).

Review: routed by the pilot (agent-workflow `pilotage`), **not** started by the executor.
Reviewer for this mission: a fresh Claude Code session (`review-claude`), per the
owner's 2026-11-15 override replacing Codex. Skip workflow-doc §5 (Codex via Herdr):
deliver `report.md` and stop; the pilot briefs the reviewer and relays findings.

## Scope

In: `roles/cli_tools/files/config.toml` (+2 lines, with a comment if useful),
README (tool list / "Managing CLI tools with mise" if it lists tools),
`docs/guide-daily-usage.md` only if it lists the tools, `BACKLOG.md`, this mission directory.

Out (decision D3, owner 2026-11-15 « et D3 aussi »): pinning this repository's own
workflow actions to SHAs with pinact — separate mission; add a `BACKLOG.md` entry for it.
Also out: any Ansible task change, the live laptop config, `~/.config/act/actrc` (act
asks its image size interactively on first run), Docker setup (role `docker`).

## Pilot pre-checks (2026-11-15, read-only)

- `mise registry`: `act → aqua:nektos/act asdf:gr1m0h/asdf-act`, `pinact → aqua:suzuki-shunsuke/pinact`.
- `mise ls-remote`: act newest 0.2.97, pinact newest 5.0.2 (candidates; AC2 decides).
- Neither tool on the owner's PATH nor in the live mise installs.
- `.github/workflows/ci.yml` uses tag refs (`actions/checkout@v7`, …): input for the D3 follow-up only.
- Branch `feat/mise-act-pinact` created by the pilot from `origin/main` = `019c7fa`
  in the main checkout (clean before), upstream unset. This mission directory is the
  only untracked path (pilot-written); commit it with the change.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Exactly two tools added (`act`, `pinact`), exact version strings; the 14 existing entries unchanged (node `26`, pnpm `12` tracks kept) | `tomllib` comparison base vs branch | VERIFIED — tomllib: base 14, branch 16, added act 0.2.97 + pinact 5.0.2, removed/changed none (evidence `ac1.txt`) |
| AC2 | Each pin is a stable (non-prerelease) upstream release, published ≥ 14 days before 2026-11-15, resolvable on linux-x64 via the aqua backend; if the newest is younger, take the newest that qualifies. Exception (owner decision D4, 2026-11-15, verbatim « D4 B »): a security fix overrides the 14-day age rule, so act = 0.2.97 (0.2.94 carries high advisories GHSA-9j7q-g3ch-2283 and GHSA-jpm2-x6wf-fxjc; 0.2.95-0.2.97 are security-fix-only releases) | `mise ls-remote`, GitHub release metadata, isolated `mise install` (never into the live config) | VERIFIED (with D4 exception) — pinact 5.0.2 meets the rule; act 0.2.97 by D4; isolated `mise install` exit 0, backends `aqua:nektos/act` / `aqua:suzuki-shunsuke/pinact`, live config sha256 unchanged (`ac2-*.txt`) |
| AC3 | Fresh seed installs both and they work | smoke VM: move the VM's `~/.config/mise/config.toml` aside, `make smoke-replay TAGS=mise`; in the VM `act --version`, `pinact --version`, `act -l -W .github/workflows/ci.yml` on the rsynced repo | VERIFIED — fresh VM, first provision `TAGS=mise`: failed=0; `act version 0.2.97`, `pinact version 5.0.2`, `act -l -W .github/workflows/ci.yml` exit 0 (jobs lint, terraform) (`smoke-1-*.log`) |
| AC4 | Seed-only behaviour kept: second replay `changed=0`; an existing config is not rewritten | second `smoke-replay TAGS=mise`; config sha256 before/after | VERIFIED — replays 2 and 3 `changed=0`; config sha256 unchanged by replay 2, and an owner-edit marker survives replay 3 (`ac4.txt`) |
| AC5 | Lint and syntax pass | `make lint`, `.venv/bin/ansible-lint`, `.venv/bin/yamllint .`, `ansible-playbook playbook.yml --syntax-check` with the dummy vault password file (§4.1) | VERIFIED — make lint, ansible-lint, yamllint, --syntax-check all exit 0 with the dummy vault file (`ac5-*.log`) |
| AC6 | `report.md` gives the exact owner command for the live laptop (e.g. `mise use -g act@<v> pinact@<v>`), not executed | inspection of `report.md` | VERIFIED — `report.md` → Owner command: `mise use -g act@0.2.97 pinact@5.0.2`, not executed |
| AC-SAFE | Owner's local work preserved; no secret read or written; hooks not bypassed; nothing run on the real laptop | workflow doc §6 | VERIFIED — no secret read, hooks ran on commit, live mise config sha256 unchanged, act/pinact absent from host PATH, stash list untouched |

## Plan

1. Inspect (workflow doc §3.1), evidence dir `~/.local/share/laptop-bootstrap-agent/2026-11-15-mise-act-pinact/`.
2. Work on `feat/mise-act-pinact` (already created).
3. AC2 version selection, then edit config.toml + docs + BACKLOG (incl. the D3 follow-up entry).
4. Verify AC1, AC3, AC4, AC5 (smoke tag `mise`, never `cli-tools`).
5. Commit (Conventional Commits, hooks on), push the branch, open the PR to `main` as draft.
6. Write `report.md` (`Verdict:` and `Version:` = the pushed implementation commit SHA), commit + push it, stop.
   The pilot routes the review; correction cycles come back to this same session.

## State

- Phase: done (awaiting pilot-routed review)
- Branch / worktree: feat/mise-act-pinact / main checkout
- Base commit: 019c7fa
- Evidence dir: ~/.local/share/laptop-bootstrap-agent/2026-11-15-mise-act-pinact/ (`ac2-releases.txt`)
- Reviewer: routed by pilot (review-claude)
- Review cycle: 0 of 3
- Smoke VM: created for this mission (`make smoke-up`, first provision `TAGS=mise`), left running; `smoke-down` needs approval.
- Next step: pilot routes the review of the draft PR; correction cycles return to this session.

### AC2 findings (2026-11-15, `gh api repos/<repo>/releases`, `.../security-advisories`)

- Cutoff: published on or before 2026-11-01 (14 days before 2026-11-15).
- pinact: 5.0.2, stable, published 2026-10-25, has `pinact_linux_amd64.tar.gz`. Meets AC2. No conflict.
- act: 0.2.95 (2026-11-03), 0.2.96 (2026-11-03), 0.2.97 (2026-11-04) are too recent. The newest
  version that meets the rule is 0.2.94 (2026-10-31T19:36Z, stable, has `act_Linux_x86_64.tar.gz`).
- 0.2.94 has three published GitHub advisories, fixed in the versions that are too recent:
  - GHSA-9j7q-g3ch-2283, high: path traversal in `uses:` / `runs.main` leading to host RCE. Affects < 0.2.96, fixed in 0.2.96.
  - GHSA-jpm2-x6wf-fxjc, high: project `.actrc` allowlist bypass (argument smuggling). Affects < 0.2.95, fixed in 0.2.95.
  - GHSA-5xfg-9629-mqgg, medium: secret masking leaves part of a secret in the log. Affects 0.2.26 to < 0.2.97, fixed in 0.2.97.
- 0.2.95, 0.2.96 and 0.2.97 contain only those security fixes (release notes), with no other change.

### D4 — act pin: the 14-day rule conflicts with known high-severity advisories

- Option A: apply AC2 as written, `act = "0.2.94"`. A fresh laptop gets a version with a published host-RCE advisory.
  Not recommended.
- Option B (recommended): `act = "0.2.97"`, published 2026-11-04, 11 days old, stable. It is the
  security-fix release, and its changelog is one masking fix. AC2 gets a recorded exception:
  "security fix overrides the age rule". Verification is unchanged (isolated install, smoke).
- Option C: leave act out of this mission, ship pinact only, and add act after 2026-11-18 (when 0.2.97 is 14 days old).
- The work was blocked until the owner or pilot chose.
- Resolution: owner decision D4, 2026-11-15, verbatim « D4 B ». Option B was applied: `act = "0.2.97"`, `pinact = "5.0.2"`.

## Log

- 2026-11-15 framing: mission written by pilot; D1 pinact, D2 commit/push/PR, D3 out of scope — all approved by owner.
- 2026-11-15 inspect: main checkout clean except this untracked mission dir; on feat/mise-act-pinact at 019c7fa, upstream unset; origin uses github-xgueret alias.
- 2026-11-15 AC2: pinact 5.0.2 qualifies; act newest qualifying 0.2.94 carries 2 high advisories fixed in 0.2.95/0.2.96 → decision D4 raised, executor stopped.
- 2026-11-15 decision: owner D4, verbatim « D4 B » (2026-11-15): pin act 0.2.97 with a recorded AC2 exception (a security fix overrides the 14-day age rule); pinact 5.0.2 unchanged. Executor resumed at plan step 3.
- 2026-11-15 verify: AC1, AC2, AC3, AC4, AC5 VERIFIED (evidence dir). README and guide do not list tools: unchanged.
- 2026-11-15 ship: implementation commit dbe84d3 pushed; draft PR #68 to main opened; report.md (Verdict: PASS, Version: dbe84d3…) committed and pushed. Executor stopped.
