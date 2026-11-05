# Report — 2026-11-05-pnpm-branch-and-ansible-cfg

## Verdict

PASS. WS1: `fix/pnpm-home-after-mise` proven integrated and deleted locally and
remotely. WS2: Python-specific `collections_path` removed; collection discovery
proven on Python 3.12, 3.14 and 3.11; PR #60 open, CI green. Codex review 1:
PASS_WITH_RESERVATIONS, no findings. Merge and laptop application are the owner's.

Evidence dir `E` = `~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-branch-and-ansible-cfg/`.

## Workstream 1 — obsolete pnpm branch

- Proof (`ws1-integration-proof.txt`): branch `674c2bf` (local = remote) vs PR #50
  squash `5a7fcfd` — same parent `2a7e1c2`, identical tree `54f43640…`, empty diff,
  identical patch-id `66edef6c…`, `git cherry` marks `-`. The task it added is still
  on `main` (`roles/cli_tools/tasks/main.yml:69-75`, same regexp/replace; comment
  extended by #59). No worktree, no open PR, reflog = creation + one commit.
- Deletion (`ws1-deletion.log`): refs re-checked, `git branch -d` exit 0 (merged into
  its upstream, so no forced deletion), `git push origin --delete` exit 0 with the
  pre-push hook; refs gone, commit object kept.
- `BACKLOG.md`: Cleanup entry removed.

## Workstream 2 — Python-independent `ansible.cfg`

Root cause: `ansible.cfg` (since the initial commit) set
`collections_path = ./.venv/lib/python3.12/site-packages/ansible_collections`. Only
the pre-commit ansible-lint hook needed it: it ran in a pre-commit venv without
collections. Venv runs find collections through `sys.path` (ansible-core
`_collection_finder.py:185-213`: configured paths first, then `sys.path`). Reproduced
on a 3.14 venv: hook `syntax-check[unknown-module]` on `community.general.xml`
(`ws2-repro-hook-3.14.log`). Removing the line alone would let `~/.ansible/collections`
(community.general 11.4.7) shadow the venv's 12.2.0 (`ws2-cfg-variants-3.14.txt`).

Solution (owner-approved option "Local hook, locked lint"):

- `ansible.cfg`: `collections_path =` (empty, commented): only the interpreter's
  `sys.path`, i.e. the uv venv.
- `.pre-commit-config.yaml`: local hook `uv run --no-sync ansible-lint -v --force-color`,
  `pass_filenames: false`, `always_run: true` (upstream flags), locked ansible-lint
  26.1.1 = CI's. Replaces remote v24.12.2 + `ansible-core<2.19`.
- Docs: `docs/agent-workflow.md` §3, `README.md`, `CONTRIBUTING.md`,
  `docs/guide-daily-usage.md` (troubleshooting), `BACKLOG.md` (Watch entry removed).
  Historical specs, plans and mission reports untouched.
- Unchanged: `uv.lock`, `pyproject.toml`, `.github/`, Python range `>=3.10`, no
  `.python-version` (`ws2-scope.txt`).

## Verifications executed

| Check | Result | Evidence |
|---|---|---|
| Reproduction, original config, 3.14 venv | hook exit 1, unknown-module | `ws2-repro-hook-3.14.log` |
| Matrix 3.12.12 / 3.14.7 / 3.11.17: `uv sync --frozen`, resolution, `--syntax-check`, `ansible-lint`, `yamllint .`, hook `--all-files` | all exit 0; community.general from each venv (12.2.0, 12.2.0, 11.4.2), never `~/.ansible` | `ws2-matrix-summary.txt`, `ws2-py*-*.log` |
| Hook binary | worktree `.venv/bin/ansible-lint` 26.1.1, ansible-core 2.20.1 | `ws2-hook-binary.txt` |
| pre-commit on all changed files; commit and pre-push hooks (dummy vault, `env_dirty=0`) | pass | `precommit-1.log`, `precommit-2.log`, `commit-1.log`, `push-1.log`, `commit-1.env` |
| CI on `2645ae2` (run 42111186887) | lint, terraform success; ansible-lint "Passed: 0 failure(s)… 'production'" | `ci-run-42111186887.log` |
| AC-SAFE | main tree snapshot `ac6d357d…c19362e` unchanged; both stashes unchanged; `agent-workflow-closeout` clean; unrelated branches present | this session |

The commit adding this report is pushed afterwards; its CI is checked in the session reply.

## Not executed / limits

- Smoke VM: NOT_APPLICABLE — it loads `test/smoke/ansible.cfg` (`Vagrantfile:52`).
- Laptop: not run (owner). `make play` from the laptop's `.venv` resolves the same way
  as the matrix, but this was not executed there.
- Python 3.10 (ansible-core 2.17) not in the matrix.
- Codex reservations: an empty `collections_path` is not an enforced venv boundary
  (repo-local `ansible_collections`, extra `sys.path` entries or env overrides still
  count); `uv run --no-sync` trusts the existing `.venv` (run `uv sync` after
  `uv.lock` changes; documented); the 3.14 reproduction inherited a foreign
  `VIRTUAL_ENV`, which uv ignored.
- Running Ansible outside the uv venv (system `ansible-playbook`) is unsupported and
  would no longer see `~/.ansible/collections` either.

## Reviews

- Review 1: PASS_WITH_RESERVATIONS, no findings (independently rechecked WS1 proof,
  empty-path resolution, hook equivalence, syntax checks). Codex pane `w1Q:pD` closed.

## State

- PR #60 https://github.com/TiPunchLabs/laptop-bootstrap/pull/60, branch
  `fix/ansible-cfg-python-path`; not merged.
- Worktree `../laptop-bootstrap-worktrees/ansible-cfg-python-path` kept until merge.
- Main tree `main` at `5ccad81`, clean, unchanged.

## Next step (owner)

Merge PR #60. Then, in the main checkout, keep `.venv` synced (`uv sync`) so the
local ansible-lint hook runs; remove the worktree and branch after merge.
