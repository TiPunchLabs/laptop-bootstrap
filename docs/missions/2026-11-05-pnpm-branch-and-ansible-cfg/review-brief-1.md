# Review brief 1 — 2026-11-05-pnpm-branch-and-ansible-cfg

## Mission

- Id `2026-11-05-pnpm-branch-and-ansible-cfg`; objective, authorizations and the
  user's design decision are in `mission.md`. Two distinct workstreams:
  - WS1: delete the obsolete branch `fix/pnpm-home-after-mise` after proving its
    content is in `main`. Already executed (deletion is not in this diff); review
    the proof and the procedure.
  - WS2: remove the Python 3.12-specific `collections_path` from `ansible.cfg`,
    keeping collection discovery working. This is the diff.
- Worktree: this directory, branch `fix/ansible-cfg-python-path` (no upstream), base
  `5ccad81` (= `origin/main`). `.venv` currently on Python 3.12.

## Diff under review

`git diff --cached` (all staged, nothing committed yet):

- `ansible.cfg` — `collections_path =` (empty) + comment.
- `.pre-commit-config.yaml` — remote `ansible/ansible-lint` v24.12.2 hook
  (`additional_dependencies: jmespath, ansible-core<2.19`) replaced by a `repo: local`
  hook `entry: uv run --no-sync ansible-lint -v --force-color`, `language: system`,
  `pass_filenames: false`, `always_run: true`. Approved by the user (see mission.md).
- `docs/agent-workflow.md` §3, `README.md`, `CONTRIBUTING.md`,
  `docs/guide-daily-usage.md` (troubleshooting), `BACKLOG.md` (two entries removed).
- `docs/missions/2026-11-05-pnpm-branch-and-ansible-cfg/mission.md` (new).

## Evidence

`E=~/.local/share/laptop-bootstrap-agent/2026-11-05-pnpm-branch-and-ansible-cfg/`:

- WS1: `ws1-integration-proof.txt`, `ws1-content-evolution.txt`, `ws1-deletion.log`.
  Local git data also lets you check: `git cat-file -t 674c2bf`, `git diff 5a7fcfd 674c2bf`,
  `git show 674c2bf | git patch-id --stable` vs `5a7fcfd`, `git cherry -v main 674c2bf`
  (the branch ref is gone; use the SHA).
- WS2 root cause: `ws2-repro-hook-3.14.log` (original config, 3.14 venv, hook exit 1,
  `syntax-check[unknown-module]` on `community.general.xml`),
  `ws2-repro-3.14-current-cfg.txt`, `ws2-cfg-variants-3.14.txt` (line removed →
  `~/.ansible` 11.4.7 wins; empty → venv only), `ansible.cfg.orig`.
  ansible-core source for ordering: `.venv/lib/python3.12/site-packages/ansible/utils/collection_loader/_collection_finder.py:185-213`
  and pathspec parsing `ansible/config/manager.py:187-192`.
- WS2 verification: `matrix.sh` (script), `ws2-matrix-summary.txt` and per-check logs
  `ws2-py<ver>-<check>.log` for 3.12, 3.14, 3.11; `ws2-hook-binary.txt` (hook resolves
  `.venv/bin/ansible-lint` 26.1.1); `ws2-scope.txt`; `precommit-1.log`.

## Checks run by Claude Code

All with the dummy vault, `env_dirty=0`, `VIRTUAL_ENV` unset, other `.venv/bin` off PATH:

- Matrix (each Python): `uv sync --frozen --python X` → 0; `ansible-playbook playbook.yml --syntax-check` → 0;
  `ansible-lint` → 0; `yamllint .` → 0; `pre-commit run ansible-lint --all-files` → 0;
  community.general resolved from the venv of that Python.
- `pre-commit run --files <8 staged files>` → exit 0, all applicable hooks Passed.

Not run: smoke VM (NOT_APPLICABLE: VM loads `test/smoke/ansible.cfg` per
`test/smoke/Vagrantfile:52`); laptop (owner only); CI (after push).

## What to review

- WS1: is the integration proof sufficient (squash merge), was deletion safe, is
  BACKLOG updated correctly?
- WS2: is the root cause right? Does `collections_path =` reliably mean "venv only"
  (check `resolve_path('')` behaviour and the finder's filtering yourself)? Any
  consumer of `ansible.cfg` that still needs a collections path (Makefile targets,
  `uninstall-opera.yml`, CI, `make clean`, smoke)? Is the local hook equivalent to
  the upstream one (args, `pass_filenames`, `always_run`), and is depending on `uv`
  + `.venv` at commit time acceptable and documented? Hard rules: hooks not weakened.
- Docs: every active reference updated, history untouched, wording accurate.
- Every `VERIFIED` backed; no secret exposure; no Python pin or dependency change.

You may rerun read-only checks (e.g. `.venv/bin/ansible-config dump`, the plugin
loader probe, `.venv/bin/ansible-playbook playbook.yml --syntax-check`). Do not
run `uv sync` (it rewrites `.venv`) or `pre-commit` (caches outside the worktree).

## Output

Write `docs/missions/2026-11-05-pnpm-branch-and-ansible-cfg/review-1.md` (§5.5 format), nothing else.
