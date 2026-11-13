# Review brief 3 — 2026-11-12-pin-mise-seed-versions

Same mission, branch, base commit (`31e294c`) and objective as
`review-brief-1.md`. Reviews 1 and 2: `PASS_WITH_RESERVATIONS` (review 2 had no
findings). This is the last allowed cycle (3 of 3).

## What changed since review 2 (owner decision D3)

The owner chose to pin kubectl to the cluster minor instead of the laptop's
1.37.1. Changed lines (all staged):

- `roles/cli_tools/files/config.toml`: `kubectl = "1.37.1"` → `kubectl = "1.34.13"`;
  pin comment adds "kubectl follows the clusters in use (1.34, within the ±1 minor
  skew policy)".
- `README.md:133`: exact-pin example is now `uv = "0.13.5"`, plus a note that kubectl
  is matched to the 1.34 clusters. `README.md:135`: `--bump` would also move kubectl
  past the clusters' minor.
- ADR-0001 amendment 2026-11-12: kubectl exception stated.
- `BACKLOG.md` Watch entry renamed "Seed pins age; kubectl follows the cluster minor"
  (vagrant context tested on server v1.34.3; laptop live config still 1.37.1).
- `mission.md` (state, log, AC3) and this brief. `report.md` is updated after
  this review; do not review it.

No Ansible task changed; `roles/cli_tools/tasks/main.yml` is untouched.

## Version choice

1.34.13 is the newest 1.34 patch: `ls-remote-kubectl.txt` lists 1.34.11-1.34.13
as the last 1.34 entries; `gh api repos/kubernetes/kubernetes/releases/tags/v1.34.13`
→ `prerelease=false draft=false published_at=2026-10-28`.

## Evidence (in `~/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/`)

- `toml-compare-2.txt`: new seed vs base, same 14 keys/order, 12 exact semver in
  `ls-remote`, node/pnpm tracks preserved → `RESULT PASS`.
- `kubectl-1.34.13-vagrant.txt` (laptop, read-only, kubectl installed by mise
  2026.10.18 into the isolated scratchpad env, binary called by absolute path,
  real kubeconfig): client v1.34.13, `--context vagrant version` → server v1.34.3,
  exit 0, no skew warning; `get nodes` → 3 nodes Ready, v1.34.3. The owner ran the
  same test independently with the same results.
- `iso3-kubectl-1.34.13-upgrade.txt`: new seed in the isolated env, `mise install`
  → all installed; plain `mise upgrade` keeps kubectl 1.34.13 (reports 1.37.2 as
  outside the range). Note: the bare `kubectl version --client` in that file prints
  v1.34.3 because PATH there has no mise shims and finds a stray
  `/usr/local/bin/kubectl` (not dpkg-owned) on the laptop; `mise exec -- kubectl`
  prints v1.34.13. Recorded as an observation, out of scope.
- Smoke VM (Ubuntu 24.04.2, mise 2026.11.6, same VM as before):
  - Run 4 (re-seed): `~/.config/mise/config.toml` moved aside in the VM
    (`smoke-4-pre.txt`), `make smoke-replay TAGS=mise` exit 0, Seed `changed`,
    Install tools `changed`, `changed=2 failed=0` (`smoke-4-reseed.log`). VM config
    sha256 `b482062f…` = repo file; `mise ls --global` = pins incl. kubectl 1.34.13;
    `fzf --bash` exit 0 (`smoke-4-vm-state.txt`).
  - Run 5: replay exit 0, Seed `ok`, Install tools `skipping`, `changed=0 skipped=1`
    (`smoke-5-replay.log`).
  - Run 6: in VM `mise use -g kubectl@1.34.12` → sha256 `0549154b…`, mtime
    1794519121 (`smoke-6-pre.txt`); replay exit 0, Seed `ok`, Install `skipping`,
    `changed=0`; after: same sha256 and mtime, `mise current kubectl` 1.34.12
    (`smoke-6-post.txt`, `smoke-6-replay.log`).

## Checks

- `pre-commit run --files <staged>` with the dummy vault file → `precommit-5.log`
  (exit 0; ansible-lint and gitleaks passed).
- `ansible-playbook playbook.yml --syntax-check` exit 0; `yamllint .` exit 0.

## Acceptance criteria deltas

- AC1, AC2, AC4: re-verified with the new pin (evidence above).
- AC3 kubectl: now VERIFIED (1.34.13 within ±1 minor of both declared clusters;
  live test on the vagrant 1.34.3 cluster).
- AC6: the plain-upgrade demo from review 1 (1.37.1) still describes the mechanism;
  plain upgrade re-checked on 1.34.13 in `iso3-…`.

## What to review

Correctness of the kubectl change and its documentation (seed comment, README,
ADR, BACKLOG) and consistency between them; whether each re-verified AC is
backed by the evidence above; anything else that changed since review 2.

Write your review to
`docs/missions/2026-11-12-pin-mise-seed-versions/review-3.md` in the §5.5 format.
That is the only file you may create or edit.
