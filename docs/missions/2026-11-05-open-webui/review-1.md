# Review 1 — 2026-11-05-open-webui

VERDICT: PASS_WITH_RESERVATIONS

## Findings

- F1.1 [minor] roles/open_webui/README.md:126 — The restore example ends with
  `docker start open-webui`, whereas rollback at lines 135–136 requires restoring
  the old data before selecting the old image. Following that restore example
  during rollback starts the newer image against the restored database and can
  immediately migrate it forward again. Explicitly instruct rollback users to
  omit this start, keep the container stopped, select the previous version, and
  let the role recreate it. The warning that downgrading does not reverse
  migrations is otherwise correct.

## AC check

Evidence names below refer to
`/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`.
VM results are inspected implementer evidence, not deployments rerun by this
reviewer.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Bootstrap include has both task and applied tags; meta dependency is Docker. `vm-run-1b.log` executes only bootstrap facts, Docker/keyring tasks and Open WebUI. Makefile target is present in `make help`. |
| AC2 | VERIFIED | Official image name and explicit `v0.13.0` default; release-shaped version assertion. `vm-run-assert-main.log` records that assertion rejecting the supplied value; HTTP evidence reports 0.13.0. No independent online release/security assessment. |
| AC3 | VERIFIED | Named volume mounted at `/app/backend/data`. Persistence logs show different container IDs, the same key fingerprint and user row, and HTTP 200 with the old session. Upgrade logs independently show preservation across v0.12.5 → v0.13.0, including a changed Alembic revision. |
| AC4 | VERIFIED | Container inspection records `unless-stopped`, `healthy`, and the configured health check. Reboot log records container start after VM boot and successful `/health`. Installed module documentation supports `state: healthy` and its timeout. |
| AC5 | VERIFIED | Defaults are wired directly into container parameters. Checks show loopback binding and refused LAN access; upgrade instance shows alternate bind, port, version, name and volume. `/ollama/config` confirms the default endpoint. Changing an existing installation to a different Ollama endpoint was not demonstrated. |
| AC6 | VERIFIED | Role leaves authentication settings untouched and supplies only the secret-file path. Functional logs show first user admin, subsequent signup 403 and unauthenticated models 401. Persistence scripts print fingerprints, not keys/tokens; supplied pre-commit log reports secret detection passed. This does not certify all historical session activity. |
| AC7 | VERIFIED | Meta dependency explicitly installs/checks Docker. Initial failure identifies missing `python3-debian`; subsequent fresh Docker installation succeeds with that prerequisite added. The added package is directly required by the existing `deb822_repository` task and is idempotent. |
| AC8 | VERIFIED | Only the data volume is declared; inspection confirms no socket and no privilege flag. `pull: missing` is supported by the installed collection. No updater is introduced. |
| AC9 | VERIFIED | Current-code empty-volume run reports changed=2, followed by changed=0; recreation reports changed=1; repeat, reboot, upgrade and combined-tag runs report changed=0 with failed=0. Tested role/bootstrap/Docker source matches this worktree byte for byte. |
| AC10 | VERIFIED | `vm-checks-1.log`: `/` returns HTTP 200 HTML with Open WebUI title; `/health` returns status true; API reports version 0.13.0. |
| AC11 | VERIFIED, limited scope | Stub integration demonstrates container-to-host routing and Open WebUI model/version API forwarding. Recorded laptop probe reaches real Ollama from a transient container. Real Ollama through Open WebUI and inference remain explicitly untested, as the mission states. |
| AC12 | VERIFIED from supplied evidence; partial reviewer rerun | Pre-commit and production ansible-lint logs report passes; syntax log identifies the playbook; brief records exit 0 for all checks. Reviewer yamllint and whitespace checks pass. Reviewer syntax and Makefile tool-check attempts encounter sandbox filesystem restrictions below. |
| AC13 | VERIFIED with reservation | Installation, prerequisites, variables, owner checks, updates, backup/restore, removal and future homelab work are documented; README, CLAUDE, spec and BACKLOG agree with the implementation. F1.1 concerns rollback instructions. |
| AC-SAFE | NOT_VERIFIED | Correctly left pending in the mission. Diff introduces no management of existing `brain-rag` data, homelab, Ollama configuration or mise. Final main-tree/stash preservation check remains for closeout; this review does not certify the implementer's entire action history. |

No unsupported `VERIFIED` claim warrants a separate finding: evidence supports
the stated VM outcomes, with the qualifications above. The implementation is
proportionate: one role using existing Docker management and native collection
health waiting, without a second service manager or update mechanism.

## Commands run

- `git status --short`, `git rev-parse --short HEAD`,
  `git branch --show-current` → each exit 0; 13 staged paths, base `2284c88`,
  branch `feat/open-webui`.
- `git diff HEAD --stat`, scoped `git diff HEAD`, scoped `git diff --cached`,
  `git diff --cached --name-only`, `git diff` → each exit 0; reviewed staged
  implementation and mission documents; no unstaged changes before review output.
- `git diff --check HEAD` → exit 0, no whitespace errors.
- `make help` → exit 0, lists `play-open-webui` and its Docker dependency.
- `.venv/bin/yamllint .` → exit 0, no findings.
- `bash bin/check_make_venv_tools.sh` → exit 2; static recipe inspection reached
  runtime lint, where uv could not create its cache lock on the read-only home
  filesystem. No permission expansion requested.
- `test -s "$ANSIBLE_VAULT_PASSWORD_FILE" && .venv/bin/ansible-playbook -i inventory.yml playbook.yml --syntax-check`
  → exit 5; dummy-file presence check succeeded, but Ansible could not create
  its local temporary directory under `/home/xgueret/.ansible/tmp`.
- Read-only Python inspection of `vm-*.log` recaps and byte comparison of
  `roles/open_webui/{tasks,defaults,meta}/main.yml`, bootstrap tasks and Docker
  install tasks against the evidence tree → exit 0; recaps match the AC claims
  and all five source files are identical.
- `cat`, `rg`, `sed` and `nl` inspections of repository rules, changed files,
  installed module documentation/manifest, evidence scripts and cited logs
  → exit 0 for the inspection batches. One exploratory `cat` operand,
  `roles/docker/tasks/setup_docker_user.yml`, did not exist; the actual Docker
  task entry point and imported install file were read successfully.
  Installed collection manifest confirms community.docker 5.0.4; documentation
  supports `pull: missing`, `no_defaults`, `host-gateway`, mounts and health options.

## Not checked

- No VM, container, laptop playbook, network access, secret access or git writes
  performed by this reviewer. Existing VM evidence was read only.
- No Context7 or online upstream lookup: repository review rules prohibit
  network access. Used installed collection documentation instead; latest-release
  and security-fix assertions were not independently verified online.
- Syntax-check and Makefile tool-check reruns could not complete within the
  sandbox. Full pre-commit/ansible-lint were not independently rerun; supplied
  logs were inspected. No hooks or configuration were weakened.
- Backup/restore and rollback examples were inspected, not executed. No
  backup round-trip evidence is supplied; the mission does not claim one.
- No real-Ollama-through-Open-WebUI inference, browser interaction, or alternate
  Ollama endpoint change on an already configured volume was independently tested.
- Final main-tree/stash snapshot and test-resource cleanup remain closeout work.

## Reservations

- Resolve F1.1 before using the documented rollback procedure.
- Docker runs twice when both Docker and Open WebUI are selected, and version
  validation happens after its dependency. Both limitations are disclosed; the
  combined-tag log demonstrates idempotence. Neither requires extra abstraction.
- Health proves the application endpoint answers, not that Ollama is available
  or inference works. Owner validation remains necessary on the laptop.
