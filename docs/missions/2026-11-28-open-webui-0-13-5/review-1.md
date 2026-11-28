# Review 1 — 2026-11-28-open-webui-0-13-5

VERDICT: CHANGES_REQUESTED

Version: c318c0bdd5e27a9ab1013ffe241157b5519db48b

## Findings

- F1.1 [major] docs/missions/2026-11-28-open-webui-0-13-5/report.md:258 — The backup does not gate the irreversible upgrade. These are independent shell commands: if stopping the container fails, tar can copy a live SQLite database; if tar fails (for example, disk full), `docker start`, `ls`, and `make play-open-webui` still execute. Listing the directory can show an older archive or a partial new archive and does not establish a usable backup. The only rollback source can therefore be missing or inconsistent when migration starts. Expected fix: make successful stop, backup creation, and validation of the exact new archive explicit prerequisites to apply; abort the upgrade on any failure. Capture an unambiguous archive filename, check its readability/integrity and expected data/key entries without printing their contents, and ensure backup failure restores service on the old image while still reporting failure. Pre-pull the backup helper before stopping to avoid an unnecessary outage if that pull fails.
- F1.2 [major] docs/missions/2026-11-28-open-webui-0-13-5/report.md:295 — Restore deletes every file in the live volume before opening or validating the selected archive. A mistyped archive name, the unchanged `<archive>` placeholder, or a truncated archive destroys the current data before tar fails; the following old-version apply remains independently executable and can start on an empty or partially restored volume. Expected fix: require an explicit archive selection and validate it before any deletion, preferably extract successfully into a separate staging volume first. Stop on restore failure and prevent any subsequent start/apply against incomplete data. Preserve the existing volume until a usable replacement is established. Keep the correct existing instruction never to start v0.13.5 on restored v0.13.0 data. The successful VM rehearsal demonstrates the happy path, not these failure paths.
- F1.3 [minor] docs/missions/2026-11-28-open-webui-0-13-5/report.md:356 — The report says push/PR are not authorized, while the mission log records the owner's later conditional authorization for push, PR, merge and laptop apply after a review without blocker/major findings. Expected fix: reconcile the report's decisions and mission authorization summary with that grant, retaining the review/CI conditions and owner-only vault/interactive-sudo steps. The condition is not satisfied by this review.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED from supplied evidence | `releases-list.log` marks v0.13.5 Latest; saved release JSON gives 2026-11-25T09:37:55Z, `isPrerelease=false`, and the official tag URL. No live latest-release check performed. |
| AC2 | VERIFIED as release-note analysis | Compared the saved v0.13.1–v0.13.5 notes with the report and actual role settings. Migration warnings, preload/native calling, retrieval defaults, full-text threshold rename, embeddings diagnostics, removed direct connections, and relevant v0.13.4/v0.13.5 changes are covered. No missed change to a role-set variable is evident from these notes. Absence from notes is not a source-code compatibility proof. |
| AC3 | VERIFIED | Base-to-version diff changes only `open_webui_version` in executable configuration, from v0.13.0 to v0.13.5; remaining changes are documentation/tracking. Tasks, templates and other defaults are unchanged; working-tree `git diff HEAD` is empty. |
| AC4 | VERIFIED from supplied evidence, yamllint independently rerun | Saved ansible-lint output reports zero failures/warnings; syntax log identifies the playbook; report records exit 0 for each required check. Saved pre-commit output shows applicable hooks passed, including gitleaks. Reviewer yamllint and diff whitespace checks exit 0. |
| AC5 | VERIFIED from supplied VM evidence | `vm-01-upgrade.log`: `ok=31 changed=1 failed=0`; `vm-02-idempotence.log`: `changed=0 failed=0`. Probes confirm v0.13.0 → v0.13.5, healthy, API version 0.13.5, unchanged key hash, retained user/chat and seven migrations. Rollback probes confirm restored v0.13.0 data; reupgrade and final idempotence also succeed. |
| AC6 | NOT_VERIFIED for safe execution | Required apply, image/API checks, second run, sign-in, Ollama and privileges are documented; healthy-timeout guidance and rollback image ordering are appropriate. F1.1/F1.2 must be resolved before the runbook can be accepted for the laptop. No laptop apply performed. |
| AC-SAFE | VERIFIED to the extent of the supplied record | Baseline/final laptop logs show the same container ID, v0.13.0 and binding; final log records original start time and zero restarts. Dummy-vault warnings, VM wrapper and hook output support the recorded safety claims. Main-tree preservation is reported with the baseline hash; an independent final snapshot is unavailable in the supplied artifacts. Reviewer performed no network, secret access, Docker/VM operations or git writes and wrote only this review. |

## Commands run

All paths below are relative to this worktree unless stated otherwise. `E` denotes the brief's read-only evidence directory. These were inspection commands, not executions of the documented owner runbook.

- `cat AGENTS.md CLAUDE.md docs/agent-workflow.md docs/missions/2026-11-28-open-webui-0-13-5/review-brief-1.md` → exit 0; read rules, review format and scope.
- `cat` / `nl -ba ... | sed -n ...` of mission/report, role README/defaults/vars/tasks, shared firewall defaults/tasks/templates, Makefile and pre-commit configuration → exit 0; inspected implementation and runbook.
- `git status --short`, `git diff HEAD`, `git diff f8299e9 c318c0b --stat`, `git diff f8299e9 c318c0b`, `git diff --name-only f8299e9 c318c0b`, `git rev-parse HEAD` → exit 0; confirmed version and six-file committed scope, with only the review brief initially untracked.
- `rg --files` and targeted `rg -n` searches over role files, public vars and evidence filenames → exit 0; located artifacts and confirmed configured bind/source allowlist without reading the vault.
- `tail -n 38` over the named lint/hook, upgrade/idempotence, backup/rollback/data, laptop baseline/final logs and snapshot baseline → exit 0; inspected saved results. Python read-only parsing of the five release JSON files and VM probes/inventory → exit 0; checked release metadata/topics and VM state. `cat E/run-vm.sh E/releases-list.log` → exit 0; inspected wrapper and release selection.
- `.venv/bin/yamllint .` → exit 0, no diagnostics (also rerun separately with the same result).
- `git diff --check f8299e9 c318c0b` → exit 0, no whitespace errors.
- Two `rg` attempts under `.../module_utils/module_container[/module.py]` → exit 2 for a nonexistent path (the enclosing shell batches returned 0 after later successful commands). Corrected discovery with `rg --files --hidden --no-ignore .../module_utils`, followed by `rg -n` on `_module_container/module.py` and `modules/docker_container.py` → exit 0; inspected installed health-wait implementation and documentation.
- `cat` of using-superpowers, its Codex tools reference, and verification-before-completion skill instructions → exit 0; read applicable workflow guidance.

## Not checked

- No network or Context7 requests: explicitly prohibited by the review brief. Official upstream source, image contents and latest-release status were not independently fetched. Saved release notes cannot prove that every undocumented environment or storage behavior is unchanged.
- No laptop/VM/container/volume operations, real vault, `pass`, sudo, smoke replay or apply. Live firewall enforcement, IPv6 listeners, Caddy access, Ollama/model visibility, real-history migration duration and stored admin settings remain owner validation items.
- Ansible-lint, syntax-check and hooks were assessed from supplied evidence rather than rerun. Hooks can modify files; this review permits only the review file to be written.
- No independent main-checkout snapshot: reading other worktrees is outside this brief's permitted scope. Only the baseline hash artifact and report's unchanged assertion were supplied; this is weaker evidence than the laptop before/after logs.

## Reservations

- The bind move to `0.0.0.0:3030` is acceptable under the repository's stated IPv4/iptables design. The actual implementation is in `roles/open_webui/tasks/main.yml` and shared `docker_port_filter` files, rather than the brief's obsolete `tasks/firewall.yml` reference. The role asserts the iptables backend and installs/checks the filter before container recreation. The DOCKER-USER jump selects original-direction DNAT traffic; the DROP matches original host port 3030 and translated container port 8080 without restricting the destination host address, so widening the IPv4 bind does not bypass that rule. Only `192.168.10.70` is allowed externally; host-local traffic remains outside this filter as documented. Boot ordering requires the filter before Docker. This is a code assessment, not a live packet test.
- A 300-second health-wait failure does not undo migration or stop the container in the inspected installed module: it polls then fails. Watching migration progress and waiting for healthy before rerunning is appropriate; the tiny VM database does not establish a safe duration for the laptop's history. Preserve the pre-update backup throughout this period.
- The patch is proportionate: one default change with supporting documentation, no new abstraction. Saved VM evidence supports functional migration and rollback on the seeded dataset, without establishing laptop readiness. Resolve F1.1 and F1.2 before allowing the destructive owner runbook to proceed.
