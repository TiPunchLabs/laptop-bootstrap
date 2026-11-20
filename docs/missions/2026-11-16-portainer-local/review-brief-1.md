# Review brief 1 — 2026-11-16-portainer-local (step S2)

You are the independent reviewer (Codex). Rules: `AGENTS.md` and `docs/agent-workflow.md` §5 of this repository, plus the pilot's `AGENTS.md` (/home/xgueret/Workspace/01-projets/tipunchlabs/agent-workflow/AGENTS.md). Be adversarial; do not trust `report.md`.

## Mission

- `docs/missions/2026-11-16-portainer-local/mission.md` (objective verbatim, requirements 1–6 for laptop-bootstrap, AC1–AC8, AC-SAFE, Log with owner decision D1 « Hash dans Vault »). Steps S3/S4 (homelab, AC6/AC7) are out of this review.
- Worktree `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap-worktrees/portainer`, branch `feat/portainer-local`, not pushed. Main checkout (`laptop-bootstrap`, branch `feat/mise-act-pinact`) is not part of the review and must not be touched.
- Version under review: **`29624435c902870829ef068ebe71efce02cb6820`**. Base `origin/main` `0b892c6`. Diff: `git diff 0b892c6 2962443`. Later commit `a678a0e`: docs only (report, `owner-commands-d1.md`).
- Executor report: `report.md` (S1 + "Update for D1"), evidence in the paths it names (`E/…`), owner commands `owner-commands-d1.md`.

## What the executor did (claims to verify)

- New role `portainer` (Portainer CE 2.45.3 LTS, `--http-disabled`, named volume, health check, dedicated tag, socket mount, loopback default; LAN exposure only after an admin exists (`/api/users/admin/check` 204) and only for 192.168.10.70).
- Open WebUI's filter moved into a shared internal role `docker_port_filter` (`present`/`absent`), claimed byte-identical rendering for Open WebUI's values and `changed=0` on the VM against a main-built baseline.
- D1: admin created at first start from `portainer_admin_password_hash` (vault alias), `--admin-password-file`, `no_log`, guards.
- Tested on the smoke VM (exposure, Docker restart, reboot ordering, disable, Open WebUI sentinel); laptop apply at a61f35f loopback-only; Open WebUI untouched.

## Requested checks

1. Security: socket exposure and its documentation; no setup page ever reachable from the LAN without an admin (ordering of tasks and guards, first install and reinstall, `--check` behaviour after 2962443); hash handling (`no_log`, file mode, lifetime of any password file in the container/host, nothing in logs/diffs/evidence); `--http-disabled` and only 9443 published; IPv4 only.
2. Refactor safety: `docker_port_filter` really keeps Open WebUI's behaviour (tasks, templates, handler/unit names, ordering vs docker.service, disable path); no second competing firewall mechanism; scoped rules, no flush.
3. Idempotence and lifecycle claims supported by the VM evidence; pinned tag is a current LTS (state your source or mark NOT_VERIFIED offline).
4. `owner-commands-d1.md`: correct, safe (password never echoed or on a command line, hash not printed), complete checks, working rollback.
5. `report.md` honest; ansible-lint/yamllint/syntax-check claims; repo conventions (`CLAUDE.md`, `AGENTS.md`).

No network, no apply on the laptop, no vault access. You may run `ansible-lint`, `yamllint`, `--syntax-check` with a dummy vault password file as the report does.

## Output

Only `docs/missions/2026-11-16-portainer-local/review-1.md`, format of `docs/agent-workflow.md` §5.5:

```
VERDICT: PASS | PASS_WITH_RESERVATIONS | CHANGES_REQUESTED | BLOCKED
Version: 29624435c902870829ef068ebe71efce02cb6820
```

Findings `F1.<k> [blocker|major|minor] file:line — problem — expected fix`, AC check table, Commands run, Not checked, Reservations.
