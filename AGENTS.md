# laptop-bootstrap — instructions for Codex

In this repository Codex is the **independent reviewer** in the workflow described
in [`docs/agent-workflow.md`](docs/agent-workflow.md). Claude Code implements;
the user decides. Project context and the hard rules are in
[`CLAUDE.md`](CLAUDE.md): read both before reviewing.

## Your task

- Do the review described in the brief you are given
  (`docs/missions/<id>/review-brief-<N>.md`).
- Write your review to the path the brief names (`review-<N>.md`), in the format
  of `docs/agent-workflow.md` §5.5. That file is the only one you create or edit.
- Judge from evidence: read the diff (`git diff HEAD`, untracked files listed in
  the brief), the code and the quoted outputs. Rerun read-only checks when they
  help, and list each one with its exit status. Say what you could not check.
- A claim marked `VERIFIED` without supporting evidence is a finding.

## Limits

- Never run anything against the real laptop: no `make play*`, no
  `ansible-playbook` other than `--syntax-check`, no `mise use/unuse/upgrade`,
  no `sudo`, no edits outside this worktree.
- Never read secrets: no `pass`, no `ansible-vault`, no `make vault-*`, no
  `bin/ansible-vault-pass.sh`, never print environment variables holding
  credentials. Ansible commands run with `ANSIBLE_VAULT_PASSWORD_FILE` already
  set to a dummy file; a `Decryption failed` warning on the vault is expected.
- No `--diff`, no smoke VM, no network, no git writes (stage, commit, stash, reset).
- If a check needs more permissions than you have, report it under "Not checked"
  instead of asking to widen the sandbox.
