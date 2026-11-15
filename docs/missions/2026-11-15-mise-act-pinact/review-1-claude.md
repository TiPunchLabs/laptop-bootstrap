# Review 1 (Claude Code) — 2026-11-15-mise-act-pinact
VERDICT: PASS_WITH_RESERVATIONS
Version: dbe84d35435d3ab5948c90cbeaa062d085b3e3bb
Reviewer: claude:ba98aa81-caa5-4238-bab0-4b08ffcc7c24 (fallback)
Reason: owner-command

Evidence dir is abbreviated `$E` = `~/.local/share/laptop-bootstrap-agent/2026-11-15-mise-act-pinact/`.
No blocker or major finding. The change itself is correct; the four minor findings are
about evidence and wording, and none requires a new implementation commit.

## Findings

F1 [minor] docs/missions/2026-11-15-mise-act-pinact/report.md:38 — the report says the output of `gh api .../releases` and `gh api repos/nektos/act/security-advisories` is "saved in the evidence dir as `ac2-releases.txt`". That file holds only tag / prerelease / draft / published lines for the two repos. No advisory output, release notes or asset list is saved anywhere in `$E`. The whole basis of the D4 exception (GHSA-9j7q-g3ch-2283, GHSA-jpm2-x6wf-fxjc, GHSA-5xfg-9629-mqgg, their severities and fixed versions, "0.2.95-0.2.97 are security-fix-only") and the Known-risk entry GHSA-jm9r-836x-3vhh therefore rest on the executor's statement alone — expected fix: save the advisory and release-note output in `$E` (e.g. `ac2-advisories.txt`) and cite it, or reword line 38 to say only the release list was saved.

F2 [minor] docs/missions/2026-11-15-mise-act-pinact/report.md:50 — "The live `~/.config/mise/config.toml` has the same sha256 before and after" cites `ac2-isolated-install.txt`, which ends with `live config unchanged: yes` and no hash values. The claim is corroborated independently (see AC-SAFE), but the cited evidence does not show it — expected fix: record both sha256 values in the evidence, or word the claim as "compared, equal (values not recorded)".

F3 [minor] docs/missions/2026-11-15-mise-act-pinact/report.md:66 — AC5 says the four commands "all exited 0", but `ac5-make-lint.log`, `ac5-ansible-lint.log`, `ac5-syntax.log` and `ac5-yamllint.log` (0 bytes) record no exit status; `docs/agent-workflow.md` §4.3 asks for "the command, exit status and the relevant lines". The log contents are consistent with success (all hooks `Passed`, `0 failure(s), 0 warning(s)`, `playbook: playbook.yml`) — expected fix: append `exit=$?` to these logs in future missions, as `ac4.txt` and `ac2-isolated-install.txt` already do; no rerun needed for this one.

F4 [minor] roles/cli_tools/files/config.toml:7 — the header comment says "Exact pins: a fresh laptop gets the versions validated on the owner's laptop". `act` and `pinact` (lines 24-25) were validated on the smoke VM only and are not installed on the laptop (`README.md:133` makes the same statement). It becomes true once the owner runs the AC6 command — expected fix: none required if the owner runs the command right after merge; otherwise add "(smoke VM only until promoted)" to the comment on lines 22-23.

## AC check

| AC | Status (VERIFIED / NOT_VERIFIED / FAILED) | Evidence (command + result on the SHA) |
|---|---|---|
| AC1 | VERIFIED (re-run) | `python3` + `tomllib` on `git show 019c7fa:roles/cli_tools/files/config.toml` vs `git show dbe84d3...:<same>`: top-level keys `['tools']` both; base 14, head 16; added `{'act': '0.2.97', 'pinact': '5.0.2'}` (both `str`); removed `[]`; changed `[]`; node `26`, pnpm `12`. Matches `$E/ac1.txt`. |
| AC2 | VERIFIED on saved evidence, not re-run; D4 basis not independently verified (F1) | `$E/ac2-releases.txt`: pinact v5.0.2 `prerelease=false`, published 2026-10-25T14:07:24Z (≤ cutoff 2026-11-01), newest listed. act v0.2.97 `prerelease=false`, published 2026-11-04T16:35:28Z (11 days, fails the age rule); newest qualifying is v0.2.94 (2026-10-31T19:36:11Z), as the report says. act = 0.2.97 is covered by the D4 exception written into the AC2 row of `mission.md`. `$E/ac2-isolated-install.txt`: `exit=0`, assets `act_Linux_x86_64.tar.gz` / `pinact_linux_amd64.tar.gz`, `Backend: aqua:nektos/act` / `aqua:suzuki-shunsuke/pinact`, install paths under the executor's scratchpad `mise-iso/`. |
| AC3 | VERIFIED on saved evidence, not re-run | `$E/smoke-1-up-mise.log` lines 615-648: only the `bootstrap` facts and `cli_tools` tasks ran (no `cleanup_legacy`), `Seed mise global config` and `Install tools from the freshly seeded config` both `changed`, recap `ok=10 changed=6 failed=0`. `$E/smoke-1-vm-checks.log`: `mise ls` act 0.2.97 / pinact 5.0.2, `mise ls --missing` empty, `act version 0.2.97`, `pinact version 5.0.2`, `act -l -W .github/workflows/ci.yml` lists `lint` and `terraform`, `act-l exit=0`. Seeded config sha256 `4dc7aef6...d1ee` equals the sha256 I computed from `git show dbe84d3...:roles/cli_tools/files/config.toml`, so the VM ran the file under review. Method differs from the AC text (fresh VM instead of moving the config aside); equivalent, and declared in the report. |
| AC4 | VERIFIED on saved evidence, not re-run | `$E/ac4.txt` + `smoke-2.log` + `smoke-3.log`: replays 2 and 3 `exit=0`, recap `ok=9 changed=0 failed=0 skipped=1`, the seed task `ok`, the install task `skipping`; sha256 `4dc7aef6...` before and after replay 2; marker config `5c82c3df...028c` before and after replay 3, marker line still present. |
| AC5 | VERIFIED on saved evidence, not re-run; exit codes not recorded (F3) | `$E/ac5-make-lint.log`: 15 hooks `Passed`, flake8 `Skipped` (no files). `$E/ac5-ansible-lint.log`: `Passed: 0 failure(s), 0 warning(s) in 87 files`, profile `production`, vault "Decryption failed" warning (dummy password, expected). `$E/ac5-syntax.log`: `playbook: playbook.yml`. `$E/ac5-yamllint.log`: empty. Logs dated 14:49, commit dbe84d3 at 14:57: run on the pre-commit tree; the only non-doc file is byte-identical to the SHA (sha256 above). |
| AC6 | VERIFIED | `git show 7eeacd8:.../report.md` line 99: `mise use -g act@0.2.97 pinact@5.0.2`, under the heading "Owner command (live laptop, after merge, not executed)". Versions match the pins. Line 104 correctly says `make play TAGS=mise` would not add the tools (seed-only). |
| AC-SAFE | VERIFIED for the observable parts; the rest is under "Not checked" | `git diff --stat 019c7fa 7eeacd8 -- roles playbook.yml Makefile .github README.md docs/guide-daily-usage.md docs/adr`: only `roles/cli_tools/files/config.toml` (+4). `git stash list`: 2 entries, as reported. `ls ~/.local/share/mise/installs`: no `act`, no `pinact`. `ls -la ~/.config/mise/config.toml`: 365 bytes, mtime 2026-11-12 18:47 (before the mission). `git status --short`: only this mission's untracked brief. |

Scope (brief item 2):

- `git diff --name-status 019c7fa dbe84d3...`: `M BACKLOG.md`, `A docs/missions/2026-11-15-mise-act-pinact/mission.md`, `M roles/cli_tools/files/config.toml`. Commit 7eeacd8 adds `report.md` and updates `mission.md` only. No Ansible task, playbook, Makefile or workflow change.
- D3 follow-up is recorded: `BACKLOG.md` lines 54-59 at the SHA, "CI — pin workflow actions to commit SHAs with pinact", citing this mission. `.github/workflows/ci.yml` still uses tag refs (lines 14, 17, 22, 47, 50), so nothing from D3 leaked into this change.
- README and guide left unchanged is justified: `git grep` at the SHA finds no list of the mise-managed tools in `README.md` or `docs/guide-daily-usage.md` (README:153 lists what `cleanup_legacy` purges, a different list). The only tool list is `docs/adr/0001-unified-cli-tool-management-with-mise.md:37`, which the report itself flags as left unchanged.

Report accuracy (brief item 3):

- Owner command present and marked not executed (line 99).
- D4 exception stated in the executive summary, the AC2 section, the Known risks and the commit message of dbe84d3.
- GHSA-jm9r-836x-3vhh stated as unpatched and affecting 0.2.97 (line 85).
- No claim that anything was applied to the laptop; "Verification covers lint and the smoke VM only, not the laptop" is explicit.
- `Verdict:` / `Version:` lines match §7 and the SHA under review.

## Commands run

All read-only, from the repository root.

- `cat` of the brief, `mission.md`, `report.md`; `ls -la` of the mission dir and `$E`.
- `git status --short`, `git log --oneline -5`, `git diff --stat` / `git diff` / `git diff --name-status 019c7fa dbe84d35435d3ab5948c90cbeaa062d085b3e3bb`, `git diff --name-status dbe84d3 7eeacd8`, `git diff dbe84d3 7eeacd8 -- .../mission.md`, `git show --stat 7eeacd8`, `git show -s` on both commits, `git rev-parse HEAD origin/feat/mise-act-pinact origin/main`, `git merge-base 019c7fa dbe84d3`, `git stash list`.
- `python3` with `tomllib` on `git show <rev>:roles/cli_tools/files/config.toml` for `019c7fa` and the SHA (AC1).
- `python3` with `hashlib.sha256` on `git show dbe84d3:roles/cli_tools/files/config.toml` → `4dc7aef6c5f3a0fcd065be23d238ad5601a389302f9c91f40c053ceff165d1ee`.
- `git show dbe84d3:<file>` for `config.toml`, `BACKLOG.md`, `docs/agent-workflow.md` (§4.2, §4.3, §6, §7); `git grep` at the SHA for tool names and `mise` in `README.md`, `docs/guide-daily-usage.md`, `docs/adr`, and for `uses:` in `.github/workflows`.
- `git diff --stat 019c7fa 7eeacd8 -- roles playbook.yml Makefile .github README.md docs/guide-daily-usage.md docs/adr`.
- `cat` of `$E/ac1.txt`, `ac2-releases.txt`, `ac2-isolated-install.txt`, `ac4.txt`, `ac5-*.log`, `smoke-1-vm-checks.log`, `smoke-2.log`, `smoke-3.log`; `python3` line filter over `$E/smoke-1-up-mise.log` (649 lines; task names, `changed:` lines, recap).
- `ls ~/.local/share/mise/installs`, `ls -la ~/.config/mise/config.toml`, `ls -lad ~/.config/act ~/.config/mise ~/.config/pinact ~/.cache/act ~/.cache/actcache`, `ls ~/.actrc` (names and timestamps only; no file content read).

## Not checked

- Upstream facts, not re-fetched (no `gh`, `mise` or network): release dates and prerelease flags, asset names, the four advisories (IDs, severity, affected and fixed ranges), the "security-fix-only" release notes of act 0.2.95-0.2.97, and that 5.0.2 / 0.2.97 are still the newest releases.
- The owner decisions D1-D4 themselves (« D4 B » etc.): taken as quoted in `mission.md`; I have no access to the owner-pilot exchange.
- Nothing was re-executed: `mise install`, `make smoke-*`, `make lint`, `ansible-lint`, `yamllint`, `ansible-playbook --syntax-check`. AC2-AC5 rest on the saved logs.
- Smoke VM current state (running or not) and its contents.
- Remote state: no `git fetch`; `origin/feat/mise-act-pinact` = 7eeacd8 is the local remote-tracking ref only. Draft PR #68 (existence, draft state, head, CI result) not checked.
- AC-SAFE claims that leave no trace I can read: no secret was read or printed, hooks ran without `--no-verify` / `SKIP`, no `--diff` was used, the SSH alias check, and the live config sha256 equality (only its mtime and the absence of act/pinact installs were observed).
- That `mise use -g act@0.2.97 pinact@5.0.2` writes exact pins (not `latest`) on the laptop's mise version: not run; consistent with `README.md:123`.
- Links and anchors inside `report.md` and `BACKLOG.md`.

## Reservations

- The D4 exception is an owner decision, and the pin follows it. Its factual basis is not in the evidence dir (F1); if the pilot wants it on record, saving the advisory output closes that gap without touching the implementation commit.
- AC2-AC5 are confirmed by reading the executor's logs, not by re-running them. The logs are coherent with each other and with the SHA (config sha256 match), and I found nothing contradicting them.
- Smoke VM proof only: act was shown to install and parse `ci.yml`, not to run a job (no Docker under the `mise` tag). Laptop behaviour is unproven until the owner runs the AC6 command.
- `~/.config/act/` (empty, 2026-11-10), `~/.cache/act` (2026-11-12) and `~/.cache/actcache` (2026-11-11) exist on the laptop and predate this mission. They are not the executor's doing, but they show act has been used here before; the first-run image prompt described in the report may behave differently on this laptop.
- `docs/adr/0001-unified-cli-tool-management-with-mise.md:37` still lists 14 mise-managed tools without act and pinact. Out of scope and disclosed in the report; a one-line amendment is the pilot's call.
- F1-F3 would be fixed in `report.md` / the evidence dir, and F4 at most by a comment edit; none of them changes the two pins.
