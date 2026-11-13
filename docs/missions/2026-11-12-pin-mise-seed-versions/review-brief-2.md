# Review brief 2 — 2026-11-12-pin-mise-seed-versions

Same mission, branch, base commit (`31e294c`) and objective as
`review-brief-1.md`. Review 1: `PASS_WITH_RESERVATIONS`, three minor findings.
This cycle is narrow: check that each resolution below is correct and complete,
and that nothing else changed since review 1 except these files and `mission.md`.

## Resolutions

- F1.1 (README `--bump` wording) — fixed, `README.md:135`: now says `--bump` moves
  each selected tool to its newest release, crossing a major track *when a newer
  major exists*, and rewrites the selected requests; preview and explicit-tool
  advice kept. Consistent with `iso2-upgrade-demo.txt` (same-major bumps for
  uv/fzf/chezmoi/terraform/awscli; node/pnpm absent, no newer major).
- F1.2 (BACKLOG kubectl ranges) — fixed, `BACKLOG.md` Watch entry "Seed pins age…":
  1.33-1.35 for the 1.34 cluster, 1.32-1.34 for the 1.33 cluster, 1.33-1.34 for both.
- F1.3 (AC3 evidence) — evidence added in
  `~/.local/share/laptop-bootstrap-agent/2026-11-12-pin-mise-seed-versions/`:
  - `terraform-constraints.txt`: every `required_version` in `~/Workspace/**/*.tf`
    (strictest `>= 1.13.3` and `>= 1.6.0, < 2.0.0`; 1.17.0 satisfies all). grep exit
    2 only because some `docker.local/portainer/data/*` directories are unreadable
    (permission denied, listed in the file); those are runtime data, not Terraform.
  - `smoke-fzf-bash.txt` (in the smoke VM, fzf 0.74.5 via mise): `fzf --bash exit=0`,
    29042 bytes emitted, `eval "$(fzf --bash)"` in bash → `eval-exit=0`.
  AC3 is now claimed VERIFIED for terraform and fzf; for kubectl it is
  "checked, incompatible with dormant clusters, disclosed" (not a compatibility claim).
- Reservations: mission state reconciled in `mission.md`; AC-SAFE final main-tree
  comparison and the owner's approval of `make smoke-down` (owner answer to an
  explicit question: "Destroy VM, recreate (Recommended)") are recorded in
  `mission.md` Log and will be in `report.md`.

## Checks after the fixes

`pre-commit run --files <staged>` with the dummy vault file → see `precommit-3.log`
in the evidence directory (exit status in the file's last line).

Write your review to
`docs/missions/2026-11-12-pin-mise-seed-versions/review-2.md` in the §5.5 format.
That is the only file you may create or edit.
