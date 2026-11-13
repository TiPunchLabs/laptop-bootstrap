# Report — 2026-11-12-pin-mise-seed-versions

## Executive summary

Objective: make the first-install mise seed deterministic by replacing the twelve
`latest` entries in `roles/cli_tools/files/config.toml` with exact stable versions,
keeping the Node.js (`26`) and pnpm (`12`) major tracks and the seed-only Ansible
behaviour.

Verdict: PASS. All acceptance criteria are VERIFIED with the limits listed below;
the last review (3 of 3) is PASS_WITH_RESERVATIONS, its one minor finding fixed.

- 11 entries pinned to the versions validated in daily use on the owner's laptop;
  kubectl pinned to 1.34.13 (owner decision D3) to match the 1.34 clusters, tested
  live on the `vagrant` cluster (server v1.34.3, three nodes Ready, no skew warning);
  node/pnpm tracks unchanged; no Ansible task changed.
- Smoke VM (`TAGS=mise`): first install gives exactly the pinned versions; second
  run `changed=0`; a mise-modified global config is preserved and the install task skipped.
- README, daily-usage guide and ADR-0001 now distinguish range upgrades from
  exact-pin updates; BACKLOG gets four follow-ups.
- Nothing was committed, pushed or applied to the laptop.

## Initial state and scope

- Main checkout `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap`:
  `main` at `fbaa44e`, clean, behind `origin/main` by 10. Not modified.
- Mission branch `feat/pin-mise-seed-versions` (upstream unset), worktree
  `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/pin-mise-seed-versions`,
  base `origin/main` = `31e294c601f6214f071ef9d878a25df822bdec37`.
- Out of scope: retry of a failed first install (reported, backlog), the mise binary
  and installer, node/pnpm tracks, the laptop's live config.

## Audit results

- `roles/cli_tools/tasks/main.yml`: seed is `copy` with `force: false`, registered as
  `cli_tools_mise_config`; `mise install --yes` runs only `when: cli_tools_mise_config.changed`.
- Failed first install after the copy: the config stays, the play fails; every later
  run reports the copy `ok` and skips install, so tools stay missing. Recovery on that
  machine: `~/.local/bin/mise install` (or move `~/.config/mise/config.toml` aside and
  `make play TAGS=mise`). Now documented in README; retry change left to BACKLOG.
- Inventory at base matches the prompt: 12 `latest` + `node = "26"`, `pnpm = "12"`.
  Entries are bare names (no backend or options), so the effective backend comes
  from the mise registry; all 12 resolve to aqua.

## Files changed (staged, not committed)

- Modified: `roles/cli_tools/files/config.toml`, `README.md` (Managing CLI tools with
  mise), `docs/guide-daily-usage.md` (`jq` example, promotion wording),
  `docs/adr/0001-unified-cli-tool-management-with-mise.md` (amendment 2026-11-12),
  `BACKLOG.md`.
- Created: `docs/missions/2026-11-12-pin-mise-seed-versions/{mission.md,review-brief-1.md,review-1.md,review-brief-2.md,review-2.md,review-brief-3.md,review-3.md,report.md}`.
- Deleted: none.

## Versions by tool

Selection rule: the version active in the owner's laptop global config (read-only
`mise ls --global --json`; installed 2026-10-23, bat 2026-04-20), confirmed present
in `mise ls-remote` on the effective backend and a non-prerelease upstream release.
Exception, kubectl: newest 1.34 patch, to stay within the ±1 minor skew of the
1.34 clusters (owner decision D3, replacing the laptop's 1.37.1).

| Tool | Old | New | Backend | Upstream evidence | Newest on 2026-11-12 |
|---|---|---|---|---|---|
| uv | latest | 0.13.5 | aqua:astral-sh/uv | release, 2026-10-22 | 0.13.7 |
| fzf | latest | 0.74.5 | aqua:junegunn/fzf | release v0.74.5, 2026-10-11 | 0.75.0 |
| direnv | latest | 2.38.2 | aqua:direnv/direnv | release, 2026-10-10 | 2.38.2 |
| zoxide | latest | 0.10.0 | aqua:ajeetdsouza/zoxide | release, 2026-07-04 | 0.10.0 |
| eza | latest | 0.23.5 | aqua:eza-community/eza | release, 2026-07-09 | 0.23.5 |
| bat | latest | 0.26.1 | aqua:sharkdp/bat | release, 2025-12-02 | 0.26.1 |
| chezmoi | latest | 2.73.3 | aqua:twpayne/chezmoi | release, 2026-10-20 | 2.74.1 |
| starship | latest | 1.27.0 | aqua:starship/starship | release, 2026-10-17 | 1.27.0 |
| kubectl | latest | 1.34.13 | aqua:kubernetes/kubernetes/kubectl | release v1.34.13, 2026-10-28 (newest 1.34 patch) | 1.37.2 |
| terraform | latest | 1.17.0 | aqua:hashicorp/terraform | release, 2026-10-21 | 1.17.2 |
| awscli | latest | 2.38.5 | aqua:aws/aws-cli | tag `2.38.5` (repo publishes no GitHub releases) | 2.40.0 |
| k9s | latest | 0.51.0 | aqua:derailed/k9s | release, 2026-06-06 | 0.51.0 |
| node | 26 | 26 | core:node | unchanged track (resolved 26.13.1 in tests) | — |
| pnpm | 12 | 12 | aqua:pnpm/pnpm | unchanged track (resolved 12.19.0 in tests) | — |

Compatibility:

- fzf: role hook `eval "$(fzf --bash)"` needs >= 0.48. In the VM with 0.74.5:
  `fzf --bash` exit 0 (29042 bytes), `eval` exit 0.
- terraform 1.17.0 satisfies every `required_version` found in `~/Workspace/**/*.tf`
  (strictest `>= 1.13.3`, `>= 1.6.0, < 2.0.0`; this repo `>= 1.11.0`). Search exit 2
  because some `docker.local/portainer/data/*` directories are unreadable.
- kubectl: first pinned to the laptop's 1.37.1, outside the ±1 minor skew of the
  declared clusters (homelab `kubecluster` 1.34, dormant; `vagrant-k8s-cluster`, README
  says 1.33). Owner decision D3: pin 1.34.13. Real test on the `vagrant` context, run
  by the owner and reproduced read-only by Claude Code with a kubectl 1.34.13 installed
  by mise in the isolated scratchpad env (`kubectl-1.34.13-vagrant.txt`): client
  v1.34.13, server v1.34.3 (the running cluster is 1.34, not the README's 1.33),
  `version` exit 0 with no skew warning, `get nodes` exit 0, three nodes Ready
  (k8s-controlplan, k8s-node1, k8s-node2, v1.34.3). The homelab 1.34 cluster was not
  tested live (dormant); same minor.
- Final laptop validation (owner, after `mise use -g kubectl@1.34.13` on the laptop):
  a direct `kubectl --context vagrant version` shows client v1.34.13, server v1.34.3,
  no skew warning; the three nodes had already been confirmed Ready. Reproduced
  read-only (`laptop-kubectl-final.txt`): live config `kubectl = "1.34.13"`,
  `mise current kubectl` 1.34.13; in a fresh interactive shell `kubectl` resolves to
  `~/.local/share/mise/installs/kubectl/1.34.13/kubectl`, client v1.34.13, server
  v1.34.3, no warning. Caveat: a shell whose PATH was set by mise before the change and
  not refreshed (here Claude Code's non-interactive shell) still lists
  `installs/kubectl/latest` (symlink to 1.37.1) first and prints v1.37.1 with the skew
  warning. Open a new shell (or let mise's prompt hook run); `mise prune` would remove
  the unused 1.37.1 install, owner's call.
- Platform: linux-x64 only (laptop and VM). arm64 and Debian not tested.

## Verification and evidence

Evidence directory: `~/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/`.
Ansible and pre-commit ran with the dummy vault file; credential variables unset.

| ID | Check | Result | Status |
|---|---|---|---|
| AC1 | `tomllib` old (`git show 31e294c:…`) vs new (`toml-compare.txt`; after D3 `toml-compare-2.txt`) | same 14 keys, same order, no other tables; 12 exact `X.Y.Z` present in ls-remote; node/pnpm preserved; RESULT PASS | VERIFIED |
| AC2 | isolated `mise install --yes` (mise 2026.10.18; `iso-env.sh`) | exit 0, 14/14; `mise ls` and each binary's `--version` report the pins (`iso2-*.txt`); GitHub release flags (`upstream-releases.txt`). kubectl 1.34.13: isolated install exit 0, binary v1.34.13 (`kubectl-1.34.13-vagrant.txt`); `gh api …/releases/tags/v1.34.13` prerelease=false draft=false | VERIFIED (linux-x64) |
| AC3 | compatibility | see above (`terraform-constraints.txt`, `smoke-fzf-bash.txt`, `kubectl-1.34.13-vagrant.txt`) | VERIFIED (kubectl live on the vagrant 1.34.3 cluster; homelab 1.34 by minor only) |
| AC4 | smoke VM, Ubuntu 24.04.2, mise 2026.11.6 (installed by the role from mise.run) | run 1 `LAPTOP_BOOTSTRAP_TAGS=mise make smoke-up` exit 0: Seed changed, Install tools changed, `changed=6 failed=0`; VM config sha256 `6600d2a6…` equals the repo file; `mise ls --global` = pins. Run 2 `make smoke-replay TAGS=mise` exit 0, `changed=0 skipped=1`. Run 3 after `mise use -g kubectl@1.37.2` in the VM (sha256 `5c1b664e…`, mtime 1794507515): exit 0, Seed ok, Install tools skipping, `changed=0`; afterwards same sha256 and mtime, `mise current kubectl` 1.37.2. After D3, same VM: run 4, config moved aside in the VM, `make smoke-replay TAGS=mise` exit 0, Seed changed, Install tools changed, `changed=2 failed=0`, VM config sha256 `b482062f…` = repo file, `mise ls --global` = pins incl. kubectl 1.34.13, `fzf --bash` exit 0 (`smoke-4-*`). Run 5 exit 0, `changed=0 skipped=1` (`smoke-5-replay.log`). Run 6 after `mise use -g kubectl@1.34.12` (sha256 `0549154b…`, mtime 1794519121): exit 0, Seed ok, Install skipping, `changed=0`, sha256/mtime unchanged, `mise current kubectl` 1.34.12 (`smoke-6-*`) | VERIFIED |
| AC5 | docs commands checked in isolation | `mise outdated`, `outdated --bump`, `upgrade`, `upgrade --dry-run`, `upgrade --bump --dry-run`, `use -g TOOL@VERSION`, `use -g --pin` behave as documented (`iso2-upgrade-demo.txt`, `iso2-use-pin.txt`) | VERIFIED |
| AC6 | kubectl demo (isolated) | plain `mise upgrade` exit 0: stays 1.37.1, config line unchanged, message "newer versions … do not match the configured version ranges"; `mise use -g kubectl@1.37.2` exit 0: config `kubectl = "1.37.2"`, active 1.37.2, binary v1.37.2 (demo on the earlier 1.37.1 pin; mechanism unchanged). Re-checked on 1.34.13: plain `mise upgrade` keeps 1.34.13 and lists 1.37.2 as outside the range (`iso3-kubectl-1.34.13-upgrade.txt`). `upgrade --bump --dry-run` would bump uv/fzf/chezmoi/terraform/awscli and schedule old installs for pruning after 24h | VERIFIED |
| AC7 | `pre-commit run --files <staged>` (5 runs, last `precommit-5.log` exit 0, gitleaks and ansible-lint passed); `ansible-lint` exit 0 (production profile); `yamllint .` exit 0; `ansible-playbook playbook.yml --syntax-check` exit 0 | pass | VERIFIED |
| AC-SAFE | main-tree snapshot before/after | `14021b4b6df2704d9016ae0325e5d05c583e506c3fcc0c8ab889573b463f3f90` at baseline, after review 2 and after review 3 (`main-tree-snap-final-2.txt`); no `pass`/vault command, no `--diff`, no hook skipped; laptop commands read-only: `mise ls/registry/ls-remote/latest/tool`, `kubectl version`, `kubectl config get-contexts`, and after D3 `kubectl --context vagrant version` / `get nodes` (kubeconfig used by kubectl, credentials not printed); isolated mise installs only under the scratchpad. Command list comes from the mission log, not an independent audit | VERIFIED |

Level reminder: lint and CI prove syntax; the VM proves a clean Ubuntu 24.04 install;
nothing has been run on the laptop.

## Reviews

- Review 1 (Codex via Herdr, agent `lb-review`): PASS_WITH_RESERVATIONS.
  F1.1 README `--bump` wording overstated crossing majors → fixed (conditional on a
  newer major existing). F1.2 BACKLOG kubectl range wrong for one cluster → fixed
  (separate ranges + intersection). F1.3 AC3 evidence not saved → evidence added.
- Review 2: PASS_WITH_RESERVATIONS, no findings; reservation was the pending final
  main-tree comparison, now done (unchanged). Snapshot of the worktree unchanged
  across both reviews. Pane `w1Y:p4` closed.
- Review 3 (after D3, last allowed cycle): PASS_WITH_RESERVATIONS. F3.1 minor:
  `mission.md` AC-SAFE listed only `mise` read commands while the log records
  read-only cluster queries → AC-SAFE reworded (mission.md and this report).
  Reservations accepted: the laptop's live config keeps its own kubectl request;
  exact pins do not freeze the installer, registry or node/pnpm tracks. Worktree
  snapshot unchanged across the review; task diff empty; pane `w1Y:p5` closed.

## Deviations, incidents and limits

- Invalid first isolated run: executed under `~/.local/share/...`, mise read
  `/home/xgueret/.config/mise/config.toml` as an ancestor project config and installed
  latest versions. Discarded; rerun under `/tmp` with `MISE_CEILING_PATHS`.
- Disk-full incident: libvirt domain `smoke_default` belonged to the merged
  open-webui-homelab-proxy worktree; its `.vagrant/` was copied here, and `make smoke-up`
  ran the full provisioner (no provision sentinel), filling `/` (ENOSPC, VM paused).
  This mission's 1.4G isolated dirs were moved to tmpfs; the owner chose "Destroy VM,
  recreate"; `make smoke-down` exit 0; VM recreated with `TAGS=mise`. Root now 51G free.
  The open-webui-homelab-proxy worktree's `test/smoke/.vagrant/` now points to a deleted domain.
- Upstream newer patches exist for 6 tools (table); the seed pins what was validated,
  not the newest.
- Not tested: arm64, Debian, a real laptop run, CI, a live homelab 1.34 cluster.
- `vagrant-k8s-cluster` README declares 1.33 but the running cluster is v1.34.3
  (observed). Not this repository's concern; noted for the owner.
- Observation, out of scope: a stray `/usr/local/bin/kubectl` v1.34.3 (not
  dpkg-owned, dated 2026-01-15) exists on the laptop. `cleanup_legacy` removes
  `kubectl-convert` there but not `kubectl`. With mise activated first in PATH it is
  shadowed; in a shell without mise it answers instead. Candidate cleanup for the owner.
- `mise upgrade --bump` (or `mise use -g kubectl@latest`) would move kubectl to 1.37.x,
  out of the cluster skew; README now says so.
- Exact pins do not freeze the mise binary, the registry or the node/pnpm tracks.

## Repository and infrastructure state

- Worktree changes staged (for gitleaks), not committed; no push, no PR.
- Smoke VM `smoke_default` (owned by this worktree now) is running; its mise config
  is the 1.34.12 test edit from run 6, and the run-3 config is kept at
  `~/mise-config-run3.toml` in the VM. `smoke-down` needs your approval.
- Laptop: no playbook run. The owner changed the live mise config (`kubectl = "1.34.13"`); Claude Code made no laptop change.

## Owner-side procedure for an already provisioned laptop

The seed only affects machines without `~/.config/mise/config.toml`; nothing changes
on this laptop when the branch merges, and no `make play` is needed. To align the
live config with the pins (optional; live versions already equal them except
kubectl, which this changes from 1.37.1 to 1.34.13):

```sh
diff -u roles/cli_tools/files/config.toml ~/.config/mise/config.toml   # shows "latest" vs exact
mise use -g uv@0.13.5 fzf@0.74.5 direnv@2.38.2 zoxide@0.10.0 eza@0.23.5 bat@0.26.1 \
  chezmoi@2.73.3 starship@1.27.0 kubectl@1.34.13 terraform@1.17.0 awscli@2.38.5 k9s@0.51.0
mise ls --global
```

Leaving the live entries on `latest` is also valid: mise owns the live config.

## Decisions required

- D1 Commit and PR: suggested commit `feat(cli-tools): pin first-install mise tool versions`
  on `feat/pin-mise-seed-versions`; set the upstream with the `github-xgueret` alias remote.
- D2 Smoke VM: keep or `make smoke-down` (from this worktree).
- D3 kubectl pin: decided by the owner — 1.34.13 (done, verified, reviewed).
- D4 (optional, out of scope) laptop leftovers: live kubectl aligned by the owner
  (`mise use -g kubectl@1.34.13`, done); remove or keep the stray
  `/usr/local/bin/kubectl` and the unused kubectl 1.37.1 install.

## Next action

D1 authorized by the owner: commit, push and PR (CI result in the PR). Merge stays
with the owner; the smoke VM is left as is.
