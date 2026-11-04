# Review brief 1 — 2026-11-04-agent-workflow

You are the independent reviewer (`AGENTS.md`). Review the change below and write
`docs/missions/2026-11-04-agent-workflow/review-1.md` in the format of
`docs/agent-workflow.md` §5.5. Do not edit any other file.

## Objective

Install the Herdr → Claude Code → Codex workflow in laptop-bootstrap so the user
can hand over `BACKLOG.md` objectives. Full objective, authorizations and
acceptance criteria: `docs/missions/2026-11-04-agent-workflow/mission.md`.
This review is also the live proof that the Herdr link works; no backlog task is
in scope.

## Change under review

- Branch `docs/agent-workflow` (no upstream), worktree = your working root, base
  `de0c4b6` (`origin/main`). All changes are staged, nothing is committed:
  `git diff --cached --stat` / `git diff --cached`.
- Created: `CLAUDE.md` (refresh of `6027b10:CLAUDE.md` from branch
  `docs/project-claude-md` + hard rules; compare with
  `git show 6027b10:CLAUDE.md`), `AGENTS.md`, `docs/agent-workflow.md`,
  `docs/missions/2026-11-04-agent-workflow/{mission.md,review-brief-1.md}`.
- Modified: `docs/guide-daily-usage.md` (only lines contradicting the
  `mise`/`cli-tools` rule), `README.md` (one link), `BACKLOG.md` (entry
  `Project-level CLAUDE.md` removed, cleanup entry for `docs/project-claude-md`
  added, Watch entry for the Python 3.12 path added).

## Context you cannot see

- The main tree (`../../laptop-bootstrap`, on `main`) holds the user's uncommitted
  pnpm fix (3 files). It must stay untouched; Claude Code checks its sha256.
- The Claude Code session inherits `ANSIBLE_VAULT_PASSWORD` and
  `TF_VAR_github_token` from direnv; your pane had them unset before launch and
  `ANSIBLE_VAULT_PASSWORD_FILE` points to a dummy file.
- herdr 0.9.1 and codex-cli 0.166.0 are installed; the commands in
  `docs/agent-workflow.md` §5 were checked against their `--help`. The launch
  you are running in used exactly §5.3.

## Checks already run by Claude Code (worktree, dummy vault)

| Command | Exit | Result |
|---|---|---|
| `.venv/bin/pre-commit run --files <7 staged files>` (first run, venv on Python 3.14) | 1 | ansible-lint hook: `couldn't resolve module community.general.xml` — caused by `ansible.cfg` `collections_path` pinned to python3.12 |
| same, after `uv sync --frozen --python 3.12` | 0 | all hooks Passed or Skipped, including `Detect hardcoded secrets` (gitleaks) and `detect private key` |
| `.venv/bin/ansible-lint` | 0 | Passed, 0 failures; `Decryption failed` warnings on the vault (expected, vault not opened) |
| `.venv/bin/yamllint .` | 0 | — |
| `.venv/bin/ansible-playbook playbook.yml --syntax-check` | 0 | — |

Not run: smoke VM (no Ansible code changed), any laptop run (forbidden).
`BACKLOG.md` and `docs/agent-workflow.md` were edited after these runs; Claude
Code reruns pre-commit before the report.

## What to check

1. Roles and permission limits are clear and consistent across `CLAUDE.md`,
   `AGENTS.md`, `docs/agent-workflow.md` (repo / smoke VM / laptop; commit, push,
   PR, merge, deletion).
2. The brief → review → fix → re-review loop and the resume procedure (§9) are
   usable by a fresh session without asking the user each step; the cycle limit
   and blocked report are unambiguous.
3. Local work and secrets are protected: worktree rule, snapshot (§5.2/§5.6),
   env sanitization before Codex starts, dummy vault, no `--diff`, no `pass`.
   Look for any command in the docs that would print a secret, decrypt the vault,
   touch the laptop or bypass a hook.
4. laptop-bootstrap specifics are right against the code: tags in
   `roles/bootstrap/tasks/main.yml`, `mise` vs `cli-tools`, mise seeding in
   `roles/cli_tools/tasks/main.yml`, untagged parts, smoke Vagrantfile behaviour,
   devtools/postman_cli paths.
5. The shell snippets in §4.1, §5.2, §5.3, §5.6 are correct (quoting, pathspecs,
   `jq` path, relative `$M`), and the guide edits are minimal and correct.
6. Proportionality: no duplicated rule sets that will drift, no superfluous file
   or script; anything that should be cut.
7. `BACKLOG.md` edits respect the file's convention.

Report each problem as a finding with severity. Do not rewrite the documents.
