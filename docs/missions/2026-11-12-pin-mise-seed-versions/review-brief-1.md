# Review brief 1 — 2026-11-12-pin-mise-seed-versions

## Mission

- Id: `2026-11-12-pin-mise-seed-versions`
- Objective (verbatim, owner): "Make the bootstrap deterministic for the tools
  currently declared as "latest" in roles/cli_tools/files/config.toml. This file is
  copied only if the user's global Mise configuration is absent. Day-to-day
  maintenance belongs to Mise. Preserve the existing deliberate major tracks for
  Node.js and pnpm." Full objective, audit steps and acceptance criteria: `mission.md`.
- Branch: `feat/pin-mise-seed-versions` (no upstream), worktree
  `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/pin-mise-seed-versions`
- Base commit: `31e294c601f6214f071ef9d878a25df822bdec37` (`origin/main`)
- Changes are staged, not committed (`git diff --cached` / `git diff HEAD`).

```
 BACKLOG.md                                          | 26 ++++++-
 README.md                                           | 14 +++-
 docs/adr/0001-unified-cli-tool-management-with-mise.md | 12 +++
 docs/guide-daily-usage.md                           | 11 +--
 docs/missions/2026-11-12-pin-mise-seed-versions/    (mission.md, this brief: new)
 roles/cli_tools/files/config.toml                   | 26 +++---
```

Evidence directory (read-only for you):
`~/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/`.

## Version selection

Rule: prefer a version already validated in use. All 12 pins are the versions
active in the owner's laptop global config (`laptop-mise-ls-global.json`, read with
`mise ls --global --json`, read-only), installed 2026-10-23 (bat 2026-04-20)
(`laptop-install-dates.txt`). Each is listed by `mise ls-remote` on the effective
backend (`ls-remote-<tool>.txt`, `resolution.txt`) and is a non-prerelease,
non-draft GitHub release (`upstream-releases.txt`), except awscli: aws/aws-cli has
no GitHub releases, only the tag `refs/tags/2.38.5`; its aqua backend installed it.

| Tool | Old | New | Backend (`mise tool --backend`) | Newest at 2026-11-12 |
|---|---|---|---|---|
| uv | latest | 0.13.5 | aqua:astral-sh/uv | 0.13.7 |
| fzf | latest | 0.74.5 | aqua:junegunn/fzf | 0.75.0 |
| direnv | latest | 2.38.2 | aqua:direnv/direnv | 2.38.2 |
| zoxide | latest | 0.10.0 | aqua:ajeetdsouza/zoxide | 0.10.0 |
| eza | latest | 0.23.5 | aqua:eza-community/eza | 0.23.5 |
| bat | latest | 0.26.1 | aqua:sharkdp/bat | 0.26.1 |
| chezmoi | latest | 2.73.3 | aqua:twpayne/chezmoi | 2.74.1 |
| starship | latest | 1.27.0 | aqua:starship/starship | 1.27.0 |
| kubectl | latest | 1.37.1 | aqua:kubernetes/kubernetes/kubectl | 1.37.2 |
| terraform | latest | 1.17.0 | aqua:hashicorp/terraform | 1.17.2 |
| awscli | latest | 2.38.5 | aqua:aws/aws-cli | 2.40.0 |
| k9s | latest | 0.51.0 | aqua:derailed/k9s | 0.51.0 |
| node | 26 | 26 (unchanged) | core:node | — |
| pnpm | 12 | 12 (unchanged) | aqua:pnpm/pnpm | — |

Compatibility:
- fzf: role hook `eval "$(fzf --bash)"` needs >= 0.48; `fzf --bash` exit 0 with 0.74.5 (isolated and VM).
- terraform 1.17.0 satisfies every `required_version` found in `~/Workspace`
  (strictest: `>= 1.13.3`, `>= 1.6.0, < 2.0.0`; this repo `github-terraform/`: `>= 1.11.0`).
- kubectl: no live cluster (current context unreachable). Declared clusters:
  homelab `kubecluster` `k8s_release: "1.34"` (README: dormant, no VMs),
  `vagrant-k8s-cluster` README `k8s_version: "1.33.0"`. 1.37 is outside the ±1
  minor skew for both; kept the validated 1.37.1 (matches the laptop) and recorded
  a Watch entry in BACKLOG. Treat this choice as reviewable.
- Platforms: linux-x64 only verified (laptop and VM are x86_64). arm64 not tested.

## Acceptance criteria (Claude Code statuses)

| ID | Status | Evidence |
|---|---|---|
| AC1 inventory | VERIFIED | `toml-compare.txt`: same 14 keys in same order, no other top-level keys; 12 exact semver present in ls-remote; node/pnpm `track_preserved=True`; `RESULT PASS` |
| AC2 resolvable + stable | VERIFIED | isolated `mise install --yes` exit 0, 14/14 (`iso2-install.log`, `iso2-ls.txt`), binaries report pinned versions (`iso2-binaries.txt`); smoke VM same (`smoke-1-vm-state.txt`); `upstream-releases.txt` |
| AC3 compatibility | VERIFIED with limits | see above |
| AC4 seed-only behaviour (VM) | VERIFIED | run 1 `LAPTOP_BOOTSTRAP_TAGS=mise make smoke-up` exit 0: Seed `changed`, Install tools `changed`, recap `changed=6 failed=0` (`smoke-1-up-mise.log`); VM config sha256 `6600d2a6…` = repo file; `mise ls --global` = pins (mise 2026.11.6, Ubuntu 24.04.2). Run 2 `make smoke-replay TAGS=mise` exit 0, recap `ok=9 changed=0 skipped=1`, Install tools `skipping` (`smoke-2-replay.log`). Run 3: in VM `mise use -g kubectl@1.37.2` → sha256 `5c1b664e…`, mtime `1794507515`; replay exit 0, Seed `ok`, Install tools `skipping`, `changed=0`; after: same sha256, same mtime, `mise current kubectl` 1.37.2 (`smoke-3-*.txt`, `smoke-3-replay.log`) |
| AC5 docs | VERIFIED | README "Managing CLI tools with mise", guide `jq` example, ADR amendment; commands checked with mise 2026.10.18 (isolated) — `iso2-upgrade-demo.txt`, `iso2-use-pin.txt` (`use -g jq@latest` writes `"latest"`, `--pin` writes `"1.8.2"`) |
| AC6 upgrade demo | VERIFIED | `iso2-upgrade-demo.txt` (kubectl): `mise outdated` → "All tools are up to date" + note about newer versions outside range; `upgrade --dry-run` and plain `upgrade` exit 0, kubectl stays 1.37.1, config line unchanged; `use -g kubectl@1.37.2` exit 0 → config `kubectl = "1.37.2"`, `mise current` 1.37.2, binary v1.37.2; `upgrade --bump --dry-run` would bump uv/fzf/chezmoi/terraform/awscli and schedule old versions for pruning |
| AC7 repo checks | VERIFIED | `pre-commit run --files <staged>` exit 0 (gitleaks, ansible-lint passed; `precommit-1.log`), `ansible-lint` exit 0 production profile, `yamllint .` exit 0, `ansible-playbook playbook.yml --syntax-check` exit 0 — all with the dummy vault file. Rerun after BACKLOG/brief edits: see report |
| AC-SAFE | VERIFIED (final compare pending in report) | main-tree baseline `14021b4b…`; no `pass`/vault commands; no `--diff`; no hook skipped; real laptop: only read-only `mise ls/registry/ls-remote/latest/tool`, `kubectl version`/`config get-contexts` (no creds printed) |

Isolation method (AC2/5/6): `MISE_CONFIG_DIR/DATA/CACHE/STATE`, `MISE_GLOBAL_CONFIG_FILE`,
`HOME`, `XDG_*` under a scratchpad dir in `/tmp`, `MISE_CEILING_PATHS` set, PATH reset
(`iso-env.sh`). A first attempt under `~/.local/share/...` was invalid: mise walked
up to `/home/xgueret/.config/mise/config.toml` as a project config (logged in mission.md).

## Incidents

- The smoke VM name `smoke_default` collided with a VM owned by another (merged)
  worktree; its `.vagrant/` was copied here, `make smoke-up` ran the full provisioner,
  and the host disk filled (ENOSPC, VM paused). Owner approved `make smoke-down`;
  the VM was recreated with `TAGS=mise` only. Run 1 above is on that fresh VM.

## Checks not run

- Real laptop: nothing applied (owner only).
- arm64, Debian: not tested.
- CI: not run (no push).

## What to review

Per `docs/agent-workflow.md` §5.4: correctness vs AC1-AC7 and AC-SAFE, hard rules
in `CLAUDE.md` (mise owns its config — no new Ansible reconciliation; `mise` vs
`cli-tools`), seed-only behaviour unchanged (`roles/cli_tools/tasks/main.yml` is not
modified), README/guide/ADR accuracy and consistency, the kubectl choice,
proportionality, and whether each VERIFIED is backed by the cited evidence.

Write your review to
`docs/missions/2026-11-12-pin-mise-seed-versions/review-1.md` in the §5.5 format.
That is the only file you may create or edit.
