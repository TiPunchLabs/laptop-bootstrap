# Report — 2026-11-06-open-webui-closeout

## Verdict

PASS. All acceptance criteria are VERIFIED, with the qualifications below. Codex
review 1 returned CHANGES_REQUESTED with 2 major findings, both fixed; review 2
returned PASS_WITH_RESERVATIONS with no open findings. The laptop was not changed.
The role code needed no correction; the only fix is documentation.

## 1. Validation record and cleanup

- PR #62: state `MERGED`, merged by the owner at 2026-11-06T01:25:15Z, merge
  commit `67db4bcf4fab47e9a0dd9044e8e0c1a0807b0746` (= `origin/main`).
  `git merge-base --is-ancestor 2356c04 origin/main` → exit 0.
- Validation record: `docs/missions/2026-11-05-open-webui/report.md` → "Post-merge
  record (2026-11-06)".
  - Owner-confirmed: "Open WebUI is operational on the laptop", quoted as given.
    The statement does not itemise the UI, the admin account, Ollama or inference,
    so those items stay not individually confirmed.
  - Agent-executed, read-only (`laptop-readonly-probe.log`): the container is
    `ghcr.io/open-webui/open-webui:v0.13.0` and `Up (healthy)`; the port is
    published on `127.0.0.1:3030` only; restart policy is `unless-stopped`; volume
    `open-webui` is mounted on `/app/backend/data`; `/health` returns
    `{"status":true}` and `/api/config` reports version `0.13.0`.
- Cleaned up, after checking that the worktree status was empty, that
  `git log origin/main..feat/open-webui` was empty, and that the ignored
  `.ansible` and `test/smoke/.vagrant` directories held no file:
  - The worktree `../laptop-bootstrap-worktrees/open-webui`, with its own `.venv`,
    removed with `git worktree remove`.
  - The local branch `feat/open-webui`, removed with `git branch -d`
    (`was 2356c04`).
  - The remote branch was already deleted by GitHub at merge (`fetch --prune` →
    `[deleted] origin/feat/open-webui`, `ls-remote` empty), so there was nothing
    for the agent to delete.
  - The mission Herdr pane `w1Q:pG` is closed.
- Preserved (`safety-check-1.log`):
  - The main checkout is on `main` at `67db4bc`, with a clean status.
  - The 2 stashes are identical to the baseline.
  - The shared hooks still use the main checkout venv.
  - The `agent-workflow-closeout` worktree is untouched.
  - No main-tree `snap` baseline was taken, so this is a current observation
    (clean at the start and clean at the end), not a checksum before/after proof.

## 2. Version management

- How the version reaches the image:
  - `roles/open_webui/defaults/main.yml` sets `open_webui_version: "v0.13.0"`.
  - In `tasks/main.yml`, an assert requires `^v\d+\.\d+\.\d+$`.
  - The same file passes `image: "{{ open_webui_image }}:{{ open_webui_version }}"`
    to `community.docker.docker_container`, with `pull: missing`.
  - Role defaults are the lowest Ansible variable precedence, so
    `group_vars/all/vars.yml` and `-e` both override it.
- Upgrade evidence, reused from the VM tests of mission `2026-11-05-open-webui`.
  The tested role code is byte-identical to the current code (Codex `cmp`).
  - Run 1 used `-e open_webui_version=v0.12.5`. Run 2 used the same arguments
    without that option, so the role's default v0.13.0 applied.
  - Run 2 reported `changed=1`, all from the container task. Afterwards the image
    and version were v0.13.0 and the alembic revision moved from `0bd252b206fb` to
    `e42c8f710a36`. The user was the same, the secret key fingerprint was identical
    (`3217401197e04f68…`), and an old session token still returned HTTP 200.
  - Run 3, with the same version, reported `changed=0`. The rollback rerun also
    reported `changed=0` (`vm-rb-4-idem.log`).
  - Backup → update → restore → previous tag worked on the VM: back on v0.12.5
    with the old schema, the user kept and sign-in returning 200.
- Fix (`roles/open_webui/README.md`): the Updating section used to say "or override
  it" without saying how, and the variables note suggested `-e` for one-off
  overrides.
  - For `open_webui_version`, a one-off `-e` is a trap. `make` targets pass no
    extra variables, so the next `make play-open-webui` or `make play` goes back to
    the default tag. That downgrades an already migrated database with no
    backup-based restore.
  - The README now says where to set the version so it persists: the role default
    through a PR, or `group_vars/all/vars.yml` for this laptop only.
  - It gives the deploy and check commands: `make play-open-webui`,
    `docker inspect … {{.Config.Image}}`, `curl …/api/config | jq -r .version`, and
    a second run expecting `changed=0`.
  - It makes the backup mandatory before every update, warns against `-e`, and
    points the rollback's step 3 at the same location.

## Checks

- pre-commit on the changed files (dummy vault, env cleaned) → exit 0. Rerun
  before the commit.
- The role and variables are unchanged, so there was no lint or VM rerun beyond
  the hooks.
- Not executed:
  - an override through `group_vars` (it relies on documented Ansible precedence);
  - any upgrade, downgrade or second run on the laptop (forbidden by the
    objective);
  - Ollama reachability from the container on the laptop;
  - inference.

## Reviews

- Review 1: CHANGES_REQUESTED.
  - F1.1: the report widened the owner's statement. Fixed: quoted verbatim, scope
    stated.
  - F1.2: AC-SAFE, AC7 and the phase claimed completion early. Fixed: safety
    checks run and recorded, statuses corrected.
- Review 2: PASS_WITH_RESERVATIONS, no open findings. Reservations, carried over
  here:
  - the safety evidence is a current observation, not a checksum proof;
  - the VM evidence covers v0.12.5 → v0.13.0, not every future migration, and not
    idempotence on the laptop.

## Remaining limitations

- Upstream image tags are mutable; images are pinned by tag, not digest (unchanged
  from the first mission).
- Each future version bump still needs the release notes read and a backup taken;
  the role cannot detect a downgrade.

## Git state

- Branch `docs/open-webui-closeout`, worktree
  `../laptop-bootstrap-worktrees/open-webui-closeout`, base `67db4bc`.
- Commit, push and PR are authorized by the objective; their result is given in the
  closing message, since this file is part of that commit.
- Not merged.

## Next action (owner)

- Review and merge the PR.
- No laptop action is needed: the running installation is unchanged.
- For the next Open WebUI update, follow `roles/open_webui/README.md` → Updating.
