# Mission 2026-11-12-pin-mise-seed-versions — Pin the first-install mise tool versions

## Objective

Verbatim objective (owner prompt, 2026-11-12):

> Make the bootstrap deterministic for the tools currently declared as "latest" in
> roles/cli_tools/files/config.toml. This file is copied only if the user's global
> Mise configuration is absent. Day-to-day maintenance belongs to Mise. Preserve the
> existing deliberate major tracks for Node.js and pnpm.

Audit and implementation steps 1-4 and the acceptance criteria of the prompt apply
in full; they are restated as AC1-AC7 below.

## Authorizations

Default: repository on a mission branch/worktree + smoke VM (no smoke-down).
Extra, granted in the objective: none. Commit, push, PR, merge and laptop
application are left to the owner.

## Scope

In: `roles/cli_tools/files/config.toml` (12 `latest` entries → exact versions),
README "Managing CLI tools with mise", `docs/guide-daily-usage.md` promotion
example, ADR-0001 amendment, `BACKLOG.md`, this mission directory.

Out: retry behaviour of the first `mise install` (reported only), the mise binary
and its installer (`cli_tools_mise_install_url`), Node.js / pnpm tracks, the live
laptop config, any Ansible task change.

## Initial state

- Main checkout: `main` at `fbaa44e`, clean, behind `origin/main` by 10; untouched.
  Snapshot: `~/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/main-tree-snap-baseline.txt`
  = `14021b4b6df2704d9016ae0325e5d05c583e506c3fcc0c8ab889573b463f3f90`.
- Base: `origin/main` = `31e294c601f6214f071ef9d878a25df822bdec37`.
- Stashes `stash@{0}`, `stash@{1}` (older branches) exist; not touched.

## Audit findings

- Seed: `roles/cli_tools/tasks/main.yml` — `copy` with `force: false` to
  `~/.config/mise/config.toml` (register `cli_tools_mise_config`); `mise install --yes`
  runs only `when: cli_tools_mise_config.changed`.
- First-install failure after the copy: the config stays in place, the play fails;
  the next run sees the file, `copy` reports `ok`, install is skipped, so tools stay
  missing. Recovery (owner, on the affected machine): `~/.local/bin/mise install`
  (or move the config aside and `make play TAGS=mise`). Retry behaviour unchanged
  (out of scope); now documented in README.
- fzf: the role's shell hook uses `eval "$(fzf --bash)"`, needs fzf >= 0.48.
- Inventory at base: 12 `latest` (uv fzf direnv zoxide eza bat chezmoi starship
  kubectl terraform awscli k9s), `node = "26"`, `pnpm = "12"`. Matches the prompt.

## Acceptance criteria

| ID | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | Same 14 tools, same identifiers (no backend/option added or dropped); 12 `latest` → exact stable versions; node `26`, pnpm `12` unchanged | `tomllib` comparison old vs new + `ls-remote` membership | VERIFIED |
| AC2 | Every pin is resolvable on the effective backend for linux-x64 and is a stable upstream release | isolated `mise install` + binary `--version`; GitHub release flags | VERIFIED |
| AC3 | Compatibility checked: kubectl vs known cluster minors, terraform vs constraints, fzf vs shell hook | `terraform-constraints.txt`, skew policy, `smoke-fzf-bash.txt` | VERIFIED (kubectl 1.34.13 after owner decision D3: vagrant cluster v1.34.3 tested) |
| AC4 | Seed-only behaviour kept: first install seeds and installs exact versions; second run `changed=0`; a locally modified global config is preserved and install task skipped | smoke VM `TAGS=mise` x3 | VERIFIED |
| AC5 | README distinguishes range upgrades from exact-pin updates; preview, `mise use -g TOOL@VERSION`, promotion, `--bump` caveats; examples verified with the mise used for tests | isolated demo with mise 2026.10.18 | VERIFIED |
| AC6 | Plain upgrade vs explicit update demonstrated in isolation for one pin (kubectl) | `iso2-upgrade-demo.txt` | VERIFIED |
| AC7 | Repository checks for the diff pass | `pre-commit run --files …`, ansible-lint, yamllint, syntax-check | VERIFIED |
| AC-SAFE | Main tree unchanged; vault/`pass` never opened, no secret printed or written; hooks not bypassed; nothing mutating on the real laptop. Laptop commands were read-only: `mise ls/registry/ls-remote/latest/tool`, `kubectl version`, `kubectl config get-contexts`, and (after D3) `kubectl --context vagrant version` / `get nodes` with a kubectl installed in the isolated scratchpad env (kubeconfig used by kubectl, credentials not printed). Isolated mise installs wrote only under the scratchpad. | snapshot compare (`main-tree-snap-final-2.txt`), mission log | VERIFIED (main tree, mutation scope); command list from this log, not an independent audit |

## Plan

1. Audit (done). 2. Resolve versions (done). 3. Edit seed + docs (done).
4. Isolated mise tests (done). 5. Smoke VM `TAGS=mise` x2 + modified-config run.
6. Repo checks. 7. Codex review via Herdr. 8. report.md, BACKLOG.md.

## State

- Phase: done
- Branch / worktree: `feat/pin-mise-seed-versions` (upstream unset) /
  `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/pin-mise-seed-versions`
- Base commit: `31e294c601f6214f071ef9d878a25df822bdec37`
- Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/`
- Reviewer: herdr agent `lb-review` (codex), pane `w1Y:p5` (closed)
- Review cycle: 3 of 3
- Next step: owner — review and merge the PR; smoke VM (D2)

## Log

- 2026-11-12 inspect: worktree created from origin/main 31e294c; `uv sync --frozen --python 3.12`.
- 2026-11-12 inspect: laptop versions read with `mise ls --global --json` (read-only).
- 2026-11-12 verify: first isolated run under `~/.local/share/...` invalid — mise
  picked `/home/xgueret/.config/mise/config.toml` as an ancestor project config;
  rerun under the scratchpad with `MISE_CEILING_PATHS` (valid run: `iso2-*`).
- 2026-11-12 verify: smoke VM `smoke_default` reused from the merged
  open-webui-homelab-proxy worktree (domain name collision otherwise); `make smoke-up`
  ran the full provisioner because the copied machine state had no provision sentinel.
- 2026-11-12 blocked: host `/` reached 100% (466G, 0 avail) during that provision
  (`Errno::ENOSPC` in vagrant, `os error 28`); qemu paused `smoke_default`.
  Moved this mission's own isolated mise dirs (`iso-install`, `iso-resolve`, 1.4G)
  to the tmpfs scratchpad → 1.4G free. Repo checks (pre-commit, ansible-lint,
  yamllint, syntax-check) had already passed. Waiting for the owner's decision on
  disk space and the paused VM.
- 2026-11-12 decision: owner chose "Destroy VM, recreate (Recommended)"; `make smoke-down`
  exit 0 (domain removed, 14G free); owner freed more space (37G free after run 1).
- 2026-11-12 verify: run 1 `LAPTOP_BOOTSTRAP_TAGS=mise make smoke-up` exit 0 changed=6;
  run 2 `make smoke-replay TAGS=mise` exit 0 changed=0; run 3 after `mise use -g
  kubectl@1.37.2` in the VM: exit 0 changed=0, config sha256/mtime unchanged.
- 2026-11-12 review-1: Codex PASS_WITH_RESERVATIONS, F1.1-F1.3 minor; all fixed.
- 2026-11-12 review-2: brief sent (narrow re-check of the fixes).
- 2026-11-12 review-2: Codex PASS_WITH_RESERVATIONS, no findings.
- 2026-11-12 report: main tree unchanged (`14021b4b…`); pane w1Y:p4 closed; report.md written. Verdict PASS.
- 2026-11-12 decision: owner D3 — pin kubectl 1.34.13 (owner tested the vagrant
  context: kubectl 1.34.13, server 1.34.3, three nodes Ready, no skew warning).
- 2026-11-12 verify: same test reproduced read-only (`kubectl-1.34.13-vagrant.txt`);
  TOML compare PASS (`toml-compare-2.txt`); isolated plain upgrade keeps 1.34.13.
  Observation: stray `/usr/local/bin/kubectl` v1.34.3 on the laptop (not dpkg-owned).
- 2026-11-12 verify: smoke run 4 (config moved aside, re-seed) changed=2, VM config
  = repo `b482062f…`, kubectl 1.34.13; run 5 changed=0; run 6 after `mise use -g
  kubectl@1.34.12` changed=0, config sha256/mtime unchanged. pre-commit exit 0.
- 2026-11-12 review-3: brief sent.
- 2026-11-12 review-3: Codex PASS_WITH_RESERVATIONS, F3.1 minor (AC-SAFE wording
  omitted the read-only cluster queries) → fixed. Task diff empty; main tree
  unchanged (`14021b4b…`); pane w1Y:p5 closed; report.md updated. Verdict PASS.
- 2026-11-12 verify: owner ran `mise use -g kubectl@1.34.13` on the laptop; direct
  `kubectl --context vagrant version` → client v1.34.13, server v1.34.3, no warning.
  Reproduced read-only in a fresh shell (`laptop-kubectl-final.txt`); a stale
  pre-change PATH still resolves 1.37.1 (recorded in report).
- 2026-11-12 decision: owner authorized commit, push and PR (D1); merge and VM left to owner.
