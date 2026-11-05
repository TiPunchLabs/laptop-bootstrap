# Review 1 — 2026-11-05-pnpm-branch-and-ansible-cfg

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- None requiring changes to this diff.

## AC check

`E` below denotes the evidence directory named in the brief. Historical runs
are distinguished from checks independently rerun during this review.

| ID | Reviewer status | Basis |
|---|---|---|
| WS1-AC1 | VERIFIED | Independently confirmed identical trees for `674c2bf` and `5a7fcfd`, identical stable patch IDs (`66edef6c995b60363050d9dc3ec3b6686ed53eff`), negative cherry marker, and squash commit ancestry in `main`. The replacement task remains in the current role with the same regexp and replacement. |
| WS1-AC2 | VERIFIED | Integration proof establishes no unique branch content; recorded pre-deletion open-PR query returned `[]`. Recorded worktree/reflog inspection and the current worktree list support safe deletion. No worktree currently uses that branch. Session preservation beyond these resource checks was not independently observed. |
| WS1-AC3 | VERIFIED | `E/ws1-deletion.log` records rechecking both refs at the proven SHA, local `-d` exit 0, remote deletion exit 0, and empty local/remote refs afterwards. Local branch absence independently confirmed. The warning from `-d` alone would not prove integration; the separate tree/patch proof does. Cleanup BACKLOG removal is appropriate. |
| WS2-AC1 | VERIFIED | `E/ws2-repro-hook-3.14.log` shows the old isolated hook failing to resolve `community.general.xml`, with the obsolete Python 3.12 collection path. The hook's inner exit code is 2; this is consistent with the brief reporting a failing outer pre-commit invocation. The loader/source inspection and recorded config variants support the root-cause explanation. |
| WS2-AC2 | VERIFIED | Active configuration has no Python-version path. Independent probe confirms `resolve_path('')` and empty pathspec resolve to the repository directory; the finder drops that directory because it contains no `ansible_collections`. Its filtered configured paths contain only this venv's site-packages, and `community.general.xml` resolves there. See the environment qualification under Reservations. |
| WS2-AC3 | VERIFIED | Recorded matrix explicitly reports sync, syntax, lint, yamllint and hook exits 0 on Python 3.12, 3.14 and 3.11; corresponding logs show lint/hook success and expected vault-decryption warnings. Resolved collection paths match each interpreter's venv. Independently reran discovery and both playbook syntax checks on current Python 3.12. |
| WS2-AC4 | VERIFIED | Diff inspection and independent scoped diff confirm no changes to `uv.lock`, `pyproject.toml` or `.github`; no `.python-version` added. Supported Python range remains `>=3.10`. The lint-version/environment change is explicitly authorized in the mission. |
| WS2-AC5 | VERIFIED | Setup, workflow and troubleshooting references are consistent with the new local hook. Active-reference search found only the intended collection-path settings/comments; historical mission/spec files are untouched. Both completed BACKLOG entries are removed, and the review date is current. |
| AC-HOOKS | NOT_VERIFIED | Recorded matrix hooks and `E/precommit-1.log` support successful pre-commit checks at this stage. Final commit/push hooks and checks including later mission/review/report files remain pending; no pre-commit rerun was permitted during review. |
| AC-CI | NOT_VERIFIED | Final pushed SHA and CI run do not yet exist in the supplied evidence; network access is prohibited. |
| AC-SAFE | NOT_VERIFIED | Review changed only this review file in the repository, used the dummy vault for Ansible checks, and performed no laptop execution, network or Git mutation. Current worktree/stash listings agree with the described resources. Final main-tree checksum/resource comparison remains pending, as correctly recorded in the mission. |

The local hook preserves upstream `-v --force-color`, `pass_filenames: false`
and `always_run: true`. The cached upstream manifest was inspected, and the
read-only pre-commit database identifies that cache as v24.12.2 with the old
additional dependencies. Default pre-commit stages remain unchanged. No skip,
file filter or rule exclusion was introduced. Running the project's approved
lint version through uv is documented and supported by the matrix evidence.

Consumers were inspected: Makefile play/lint targets rely on the documented
activated environment; CI uses uv; `uninstall-opera.yml` uses built-in modules
and passes syntax checking. `make clean` removes local caches, not `.venv`.
Smoke explicitly selects `test/smoke/ansible.cfg`, so a smoke run would not test
this configuration change.

## Commands run

- `cat AGENTS.md docs/missions/2026-11-05-pnpm-branch-and-ansible-cfg/review-brief-1.md CLAUDE.md docs/agent-workflow.md` → exit 0; read review scope, hard rules and required format.
- `git status --short`, `git status --porcelain=v1 --untracked-files=all`, `git diff HEAD --stat`, `git diff HEAD` → each exit 0; inspected all nine staged files, including the brief; no initial unstaged or untracked files.
- `cat`/`sed` reads of the mission, named WS1/WS2 evidence, matrix script, hook logs, Makefile, project/lint/hook configuration, CI, smoke configuration, uninstall playbook and installed Ansible loader/config source → exit 0; evidence and consumer inspection described above. No secret store or vault contents read.
- `git diff --exit-code 5a7fcfd 674c2bf` → exit 0; no tree difference.
- `git cherry -v main 674c2bf` → exit 0; branch commit marked `-`.
- `git show 674c2bf --format= -- roles/cli_tools/tasks/main.yml` → exit 0; inspected original task.
- `git rev-parse '674c2bf^{tree}' '5a7fcfd^{tree}'` → exit 0; both `54f436402f178aa828c051f42c8ff339a3517c2a`.
- `git merge-base --is-ancestor 5a7fcfd main` → exit 0; squash commit integrated.
- `git show 674c2bf --format= | git patch-id --stable` and the same pipeline for `5a7fcfd` → each exit 0; identical patch IDs.
- `git branch --list fix/pnpm-home-after-mise`, `git worktree list`, `git branch -vv`, `git stash list` → each exit 0; branch absent, expected worktrees/branches/stashes listed, current branch has no upstream.
- `git diff HEAD --exit-code -- uv.lock pyproject.toml .github` → exit 0; unchanged.
- `git diff HEAD --check` → exit 0 on both invocations; no whitespace errors.
- `rg -n 'python3\.12|--python 3\.12|collections_path|v24\.12\.2|ansible-core<2.19'` excluding lock and historical missions/specs → exit 0; only intended collection-path configuration/comments matched.
- `rg --files --hidden /home/xgueret/.cache/pre-commit -g .pre-commit-hooks.yaml` → exit 0; located cached manifests.
- Source-definition search under `ansible/config` → exit 1; no match there. Broader source inspection located and read `resolve_path` in `config/manager.py`. Log-result search → exit 0; matrix logs corroborate results.
- Initial `.venv/bin/python` loader probe → exit 1; Ansible attempted to create its default temporary directory under read-only `~/.ansible/tmp`. No permission expansion requested.
- Repeated Python loader/config probe with `ANSIBLE_LOCAL_TEMP=/tmp/laptop-bootstrap-review-ansible`, bytecode disabled and dummy vault configured → exit 0; empty-path resolution, filtering and venv module-path assertions passed.
- `.venv/bin/ansible-playbook playbook.yml --syntax-check` and `.venv/bin/ansible-playbook uninstall-opera.yml --syntax-check`, each with dummy vault, credential variables unset, bytecode disabled and temporary directory under `/tmp` → each exit 0; both playbooks parse.
- `cat /home/xgueret/.cache/pre-commit/repok29dhhsq/.pre-commit-hooks.yaml` → exit 0; upstream arguments and execution flags match.
- Cached-repository `git describe --tags --exact-match` → exit 128; cache has no tag names. `git log -1 --format='%H %s'` → exit 0; cache HEAD recorded. `rg` for version in its `CHANGELOG.md` → exit 2; file absent.
- Read-only SQLite query of pre-commit `db.db` → exit 0; cached path maps to ansible-lint v24.12.2 with `jmespath,ansible-core<2.19`.

## Not checked

- No network, Context7/current online documentation, live remote-ref/PR recheck or CI query, per review restrictions. Installed source, cached upstream manifest and supplied logs were used instead.
- No `uv sync`, pre-commit invocation or lint rerun that could update external caches; reviewed the supplied matrix and hook logs instead.
- No independent matrix rebuild on Python 3.11/3.14. Python 3.10 was not covered by the supplied matrix; the acceptance criterion requires 3.12 plus another supported version.
- No smoke VM execution: separate configuration, so NOT_APPLICABLE to these changed runtime files.
- No laptop provisioning or runtime module execution; syntax/lint results do not establish laptop behavior.
- No final main-tree snapshot comparison, commit/push hook run or final-file pre-commit run; these are delivery-stage checks still required by the mission.

## Reservations

- Empty `collections_path` suppresses Ansible's default user/system collection directories; it is not an enforced venv boundary. A repository-local `ansible_collections` directory, extra Python search paths, playbook-adjacent collections or environment overrides can affect discovery. For this repository and its documented uv environment, the source inspection, independent probe and matrix support the intended behavior.
- `uv run --no-sync` uses the prepared environment without validating/resynchronizing it against the lock. The documented `uv sync` prerequisite must be maintained; the hook's version follows that environment. This is the approved tradeoff, not an observed hook bypass.
- The initial reproduction inherited a mismatched `VIRTUAL_ENV` and also warns about old ansible-core on Python 3.14. The log explicitly says that environment was ignored, shows the obsolete collection path and unresolved module, and the subsequent matrix removes the inherited environment. These qualifications do not invalidate the diagnosis.
- PASS_WITH_RESERVATIONS applies to the reviewed change and supplied evidence, not to completion of the pending delivery, CI or laptop checks.
