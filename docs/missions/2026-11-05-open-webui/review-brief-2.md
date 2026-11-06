# Review brief 2 — 2026-11-05-open-webui

Same mission, branch, base and evidence directory as `review-brief-1.md`. Still
nothing committed: review with `git diff --cached` (everything is staged,
including `review-1.md`); `review-2.md` is the only file you create.

## Resolution of review 1

- F1.1 [minor] `roles/open_webui/README.md` rollback/restore ordering — **fixed**.
  Rollback is now four steps; step 2 restores *without* the final `docker start`,
  and the restore block's `docker start` is labelled "plain restore only". The
  documented procedure was executed on the VM (names `owui-rb`, port 3032), see below.

## Additional changes since review 1

- Backup command: `umask 077` inside the helper container (the archive holds the
  secret key; it was created 0644 before), helper image `alpine:3`, backup dir
  mounted `:ro` on restore.
- Codex "Not checked" items now executed:
  - Backup → update → rollback round trip: `vm-rb-steps-1.log`, `vm-rb-steps-2.log`,
    `vm-rb-{1,2,3,4}-*.log`, script `vm-rb-probe.sh`.
  - Ollama URL change on an initialized volume: `vm-ollama-url.log`,
    `vm-ollama-url-1.log`, script `vm-ollama-url-probe.sh`. Result: the env changed
    to `:11999` but Open WebUI kept using `:11434` (persistent config). This is
    upstream behaviour; it is now documented (role README → Variables and Ollama,
    `defaults/main.yml` comment, spec), with Admin Settings → Connections as the way
    to change it later. `ENABLE_PERSISTENT_CONFIG=False` deliberately not used.
- `vm-run-10-final-tree.log`: changed=0 with the current tree; the five role/wiring
  files are byte-identical to the tested copy.
- Checks rerun: `pre-commit run --files <staged files>` exit 0
  (`pre-commit-2.log`), ansible-lint exit 0 (`lint-ansible-3.log`), yamllint exit 0,
  `--syntax-check` exit 0.

## What to review

1. Whether F1.1 is resolved and the rollback/backup/restore text matches what
   `vm-rb-steps-*.log` show was executed.
2. Whether the Ollama-URL documentation is accurate and sufficient against
   `vm-ollama-url.log`, and whether any other role variable has the same
   first-start-only behaviour that the docs misstate.
3. Updated `mission.md` statuses (AC5, AC9, AC13) against the evidence.
4. Anything in review 1's reservations that should now be a finding.

## Output

Write `docs/missions/2026-11-05-open-webui/review-2.md` in the format of
`docs/agent-workflow.md` §5.5. That is the only file you create or edit.
