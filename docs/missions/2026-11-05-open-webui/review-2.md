# Review 2 — 2026-11-05-open-webui

VERDICT: PASS

## Findings

None open. F1.1 is resolved: `roles/open_webui/README.md:134` labels the final
start as plain-restore-only; lines 145–151 explicitly keep the restored database
stopped until the previous image is selected and recreated by the role.

The new round-trip evidence supports that ordering. `vm-rb-steps-1.log` and
`vm-rb-steps-2.log` record a mode-0600 archive, update from v0.12.5 to v0.13.0,
restore with container state `exited`, then recreation on v0.12.5. The Alembic
revision returns from `e42c8f710a36` to the backed-up `0bd252b206fb`; the test user
remains, sign-in returns HTTP 200, and the container is healthy. This demonstrates
restoring the earlier database, not reversing migrations by changing an image tag.

Ollama documentation matches the new test: the container environment changes to
port 11999, while `/ollama/config` still returns port 11434. The README, defaults
comment and spec now identify the variable as an installation seed and direct
later changes to Admin Settings → Connections. This is sufficient for the
objective's configurable endpoint with documented defaults; it does not promise
Ansible reconciliation of saved application settings. The other exposed role
variables control Docker resources or the Ansible health wait, rather than
Open WebUI database settings; no analogous undocumented first-start restriction
was identified. `WEBUI_SECRET_KEY_FILE` is a fixed path, not an exposed variable.

## AC check

Evidence paths below are relative to
`/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-05-open-webui/`.
Unchanged results retain the evidence assessment from review 1. VM tests were
inspected, not executed by this reviewer.

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED | Unchanged bootstrap/tag/Makefile wiring and Docker dependency; review 1's scoped task evidence remains applicable. |
| AC2 | VERIFIED | Unchanged pinned official image and release assertion; prior rejection test and version response remain applicable. |
| AC3 | VERIFIED | Prior recreation/upgrade evidence plus new backup/update/restore round trip retains the test user and permits sign-in. |
| AC4 | VERIFIED | Restart policy and health configuration are unchanged; prior reboot evidence and new healthy rollback probe support the criterion. |
| AC5 | VERIFIED, install-time Ollama setting | Bind/port/version overrides remain supported. `vm-ollama-url.log` and its probe distinguish changed environment from unchanged saved endpoint. Documentation explicitly states the limitation and the supported application settings workflow. The URL-change test is on v0.12.5, as the README states. |
| AC6 | VERIFIED within inspected evidence | Auth configuration and secret-file approach are unchanged. New probes do not print passwords or tokens; `pre-commit-2.log` reports secret detection passed. Backup output shows owner root and mode 0600. |
| AC7 | VERIFIED | Unchanged Docker prerequisite and `python3-debian` fix; prior fresh-install evidence remains applicable. |
| AC8 | VERIFIED | Mounts and `pull: missing` are unchanged; no socket or updater introduced. |
| AC9 | VERIFIED | `vm-run-10-final-tree.log`: ok=23, changed=0, failed=0. Rollback sequence reports changes 2/1/1/0 with failed=0 throughout. Five role/wiring files match the tested tree byte for byte. |
| AC10 | VERIFIED | Prior HTTP UI evidence remains applicable; application implementation is unchanged. |
| AC11 | VERIFIED, limited scope | Prior stub integration and recorded real-Ollama network probe remain applicable. No inference or real-Ollama-through-Open-WebUI claim has been added. |
| AC12 | VERIFIED from supplied evidence; partial reviewer rerun | `pre-commit-2.log` reports passes; `lint-ansible-3.log` reports production-profile success with expected dummy-vault warnings. Brief records exit 0 for renewed lint/syntax checks. Reviewer yamllint and whitespace checks pass. |
| AC13 | VERIFIED | F1.1 fixed; backup/rollback round trip corroborates the revised instructions. Persistent Ollama configuration is now documented consistently in README, defaults and spec. |
| AC-SAFE | NOT_VERIFIED | Mission correctly leaves final preservation snapshot pending. No additional evidence in this brief closes that criterion; review approval does not replace closeout checks. |

The updated AC5 and AC13 qualifications are supported. AC9's existing table
evidence remains valid, and the additional final-tree run strengthens it. No
review-1 reservation needs promotion to a finding.

## Commands run

- `git status --short`, `git diff HEAD --stat`, `git diff`, and scoped
  `git diff --cached -- <reviewed paths>` → each exit 0; staged implementation,
  documentation and mission changes inspected; no unstaged edits before output.
- `git diff --check HEAD` → exit 0; no whitespace errors.
- `.venv/bin/yamllint .` → exit 0; no findings.
- `cat` of brief 2, review 1, current role README/defaults/tasks, mission, spec,
  `vm-rb-steps-{1,2}.log`, `vm-rb-probe.sh`, `vm-ollama-url{,-1}.log`,
  `vm-ollama-url-probe.sh`, `pre-commit-2.log`, and `lint-ansible-3.log`
  → each inspection batch exit 0; evidence and documentation assessed above.
- `sed -n '98,133p' docs/missions/2026-11-05-open-webui/mission.md` and
  `nl -ba roles/open_webui/README.md` → each exit 0; AC statuses and correction
  locations confirmed.
- Read-only Python extraction of recaps from `vm-rb-[1-4]-*.log` and
  `vm-run-10-final-tree.log`, with byte comparisons for Open WebUI tasks/defaults/
  meta, bootstrap tasks and Docker installation tasks against the evidence tree
  → exit 0; successful recaps and all five source matches confirmed.

## Not checked

- No VM, container, laptop deployment, network access, secrets or git writes
  performed by this reviewer. Runtime conclusions rely on supplied evidence.
- Full pre-commit, ansible-lint, syntax and Makefile tool checks were not rerun
  in this cycle. Review 1 documented sandbox cache/temp restrictions; fresh
  implementer logs were inspected without requesting broader permissions.
- No browser verification of the Admin Settings workflow or independent URL
  change test on v0.13.0. The supplied URL persistence test is explicitly scoped
  to v0.12.5; the v0.13.0 default endpoint integration was assessed in review 1.
- No online upstream release/security assessment or Context7 lookup, because
  the repository review rules prohibit network access.
- Final main-tree/stash preservation comparison and mission-resource cleanup
  remain closeout work, not established by this review.

## Reservations

- Laptop application and real Ollama inference remain owner validation. A
  healthy application endpoint does not establish backend availability.
- Docker's duplicate execution for combined tags and validation after its meta
  dependency remain disclosed, idempotent limitations; no additional mechanism
  is warranted by the evidence.
