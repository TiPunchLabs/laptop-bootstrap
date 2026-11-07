# Review 1 — 2026-11-07-remove-portainer

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- None requiring changes before the planned cleanup.

The diff contains only the BACKLOG date and the two mission documents. Independent
searches confirm AC1. The indirect matches are historical Open WebUI socket-safety
evidence, a workflow timeout, and dependency metadata; none installs or configures
Portainer. Inspection of the Docker installation, bootstrap includes, hosts task
and Open WebUI role found no indirect Portainer dependency.

Against the quoted laptop inventory, the selected container, image and standalone
directory are dedicated Portainer resources. The plan backs up the bind data
before removal, rechecks the container identity and image consumers, uses trash
for the directory, and contains no prune. In particular, the agent's bind mount
of `/var/lib/docker/volumes` is not a dedicated Portainer volume and must remain
untouched, as the plan implies.

The backup design is reasonable: a local image, no network or pull, read-only
source, destination outside the repository, owner-readable archive and restrictive
permissions. Archiving necessarily reads bytes; “File contents are not read” is
understood here as no disclosure or manual inspection of their contents. Archive
creation and complete listing must succeed before any removal; preserve failure
statuses and verify the stated ownership and modes in the execution evidence.

Keeping `local_network` is required by its quoted unrelated members. Keeping the
separate `ansible-docker-apps` repository untouched preserves owner work and is
appropriate to the stated scope. The inactive Caddy block is a residual reference,
not evidence of a startup mechanism. The findings identify restart policy,
standalone Compose and the separate Ansible role; no additional recreation
mechanism is apparent from the supplied evidence.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Tracked-tree search returns no matches outside this mission; supplemental working-tree search also returns no matches. No unsupported VERIFIED claim found. |
| AC2 | NOT_VERIFIED | Container removal has not happened; quoted evidence identifies the intended agent. |
| AC3 | NOT_VERIFIED | Image removal and resource preservation require post-inventory; shared network is correctly excluded from removal. |
| AC4 | NOT_VERIFIED | Backup is planned, not created or validated. |
| AC5 | NOT_VERIFIED | Active agent and Compose path remain pending cleanup; separate repository recreation path remains documented. |
| AC6 | NOT_VERIFIED | Requires post-cleanup health and resource comparisons. |
| AC7 | VERIFIED | This review assesses the repository diff and cleanup plan at the pre-removal stage described in the brief. |
| AC8 | NOT_VERIFIED | Commit, push, PR and CI are future work. |
| AC-SAFE | NOT_VERIFIED | Final comparisons of the two baseline snapshots are outstanding. This review made no laptop calls, secret reads, git writes or changes outside this review file. |

## Commands run

- `cat AGENTS.md CLAUDE.md docs/agent-workflow.md docs/missions/2026-11-07-remove-portainer/review-brief-1.md` → exit 0; read rules, format and scope.
- `git status --short && git diff HEAD && git ls-files --others --exclude-standard` → exit 0; three staged files, no unstaged or untracked files at review start.
- `cat docs/missions/2026-11-07-remove-portainer/mission.md` → exit 0; inspected plan and quoted evidence.
- `rg --files -g AGENTS.md -g '*portainer*' -g '*Portainer*' -g '.pre-commit-config.yaml' -g 'Makefile' -g 'ansible.cfg'` → exit 0; located repository instructions and configuration files.
- `git grep -niI portainer -- . ':!docs/missions/2026-11-07-remove-portainer'` → exit 1; no matches (expected).
- `git grep -nIE '9000|9001|9443|docker\.sock|/var/lib/docker/volumes|local_network|portainer\.local' -- . ':!docs/missions/2026-11-07-remove-portainer'` → exit 0; only unrelated matches described above.
- Read batch using `cat` on `.pre-commit-config.yaml`, Docker tasks/defaults, Open WebUI tasks/defaults and bootstrap tasks → exit 1; all existing files printed, but `roles/docker/defaults/main.yml` does not exist. The subsequent chained branch checks did not run in this batch; rerun below.
- `nl -ba docs/missions/2026-11-07-remove-portainer/mission.md` → exit 0; checked plan and criterion locations.
- `git diff HEAD --check && git branch --show-current && git rev-parse HEAD origin/main && git ls-files --others --exclude-standard` → exit 0; clean patch formatting, branch `chore/remove-portainer`, HEAD and origin/main both `fbaa44efd37cde479c6117bae62a3fe33c6774d4`, no untracked files before writing this review.
- `cat roles/docker/tasks/install_docker_docker_compose_plugin.yml roles/bootstrap/tasks/update_hosts.yml` → exit 0; Docker engine installation and hosts templating inspected.
- `rg -n -i --hidden --glob '!.git' --glob '!.venv/**' --glob '!docs/missions/2026-11-07-remove-portainer/**' --glob '!group_vars/all/vault/**' portainer .` → exit 1; no matches, including non-ignored untracked files and hidden files within these exclusions.
- `.venv/bin/yamllint .` → exit 0; no diagnostics.

## Not checked

- Laptop state, Docker commands, backup, trash operation, service/cron inventories and external repositories: prohibited for this reviewer; assessed only from quoted evidence.
- Main-tree and separate-repository baseline comparisons: deferred until execution/report; not independently reproduced.
- Pre-commit, ansible-lint and syntax-check: supplied exit statuses reviewed, not independently rerun. Pre-commit can modify files and caches; this review permits only its output file to change. The quoted pre-commit file list does not include the later brief or this review; include all final mission files in the implementer's required checks before committing.
- Smoke replay: NOT_APPLICABLE to this documentation-only repository diff; no VM was used.
- Historical commits, other worktrees and stashes: not independently searched; current-tree AC1 does not require rewriting them.
- Network documentation and CI: no network used, as required.

## Reservations

- This verdict covers the repository change and the proposed cleanup, not successful removal or a laptop health result. Keep AC2–AC6 and AC-SAFE unverified until their checks supply evidence.
- The committed `deploy_portainer: true` in the separate repository can recreate Portainer if that version is run later. The current uncommitted `false` is not a durable repository change. Preserve the owner's work and explicitly carry this residual path and the retained Caddy reference into the final report; do not describe their preservation as eliminating every future recreation path.
- The plan states backup permissions and completeness requirements but supplies no executed command or output yet. The execution evidence must establish those properties before trashing the original, without exposing database or key contents.
