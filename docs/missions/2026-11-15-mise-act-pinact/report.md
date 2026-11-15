# Report — mission 2026-11-15-mise-act-pinact

Verdict: PASS
Version: dbe84d35435d3ab5948c90cbeaa062d085b3e3bb

The verdict covers the executor's verification only. The independent review has not run yet; the pilot routes it.

## Executive summary

- Objective: seed `act` (nektos/act) and `pinact` (decision D1) in the mise reference config `roles/cli_tools/files/config.toml`.
- Done: `act = "0.2.97"` and `pinact = "5.0.2"` are added as exact pins, using the aqua backend. BACKLOG has a follow-up entry for pinning this repo's CI actions with pinact (decision D3).
- Verified: AC1 to AC6 and AC-SAFE, on lint and the smoke VM. Nothing was run on the real laptop; the owner command is below.
- act 0.2.97 is an exception to the AC2 age rule (owner decision D4, 2026-11-15, verbatim « D4 B »).

## Initial state

- Main checkout `/home/xgueret/Workspace/02-infrastructure/local/laptop-bootstrap` was on branch `feat/mise-act-pinact` (created by the pilot) at `019c7fa` (= `origin/main`), with no upstream set.
- The only untracked path was the mission directory written by the pilot. No other changes, so there was no owner work to protect in the tree. The existing stash list had 2 entries before and after; it was not touched.
- `origin` = `git@github-xgueret:TiPunchLabs/laptop-bootstrap.git`. `ssh -T git@github-xgueret` returned `Hi xgueret!`.

## Files

- Modified: `roles/cli_tools/files/config.toml` — adds 2 pins and a 2-line comment noting that act needs Docker (role `docker`).
- Modified: `BACKLOG.md` — new Deferred entry "CI — pin workflow actions to commit SHAs with pinact"; the Watch entry for the seed pins mentions act/pinact; `Last review: 2026-11-15`.
- Created: `docs/missions/2026-11-15-mise-act-pinact/mission.md` (pilot-written, then updated by the executor) and `report.md`.
- Not modified: README.md and `docs/guide-daily-usage.md`, because neither lists individual mise tools (checked with grep). The README's description of exact pins still holds.

## AC2 version selection and decision D4

- The cutoff for the 14-day rule was a publish date on or before 2026-11-01.
- pinact 5.0.2: stable, published 2026-10-25T14:07Z, has the asset `pinact_linux_amd64.tar.gz`. It meets the rule.
- act: 0.2.95 (2026-11-03), 0.2.96 (2026-11-03) and 0.2.97 (2026-11-04T16:35Z) are too recent, so the rule would pick 0.2.94. But 0.2.94 is affected by:
  - GHSA-9j7q-g3ch-2283 (high): a path traversal in `uses:` / `runs.main` that leads to remote code execution on the host. Fixed in 0.2.96.
  - GHSA-jpm2-x6wf-fxjc (high): a bypass of the allowlist for project `.actrc` files. Fixed in 0.2.95.
  - GHSA-5xfg-9629-mqgg (medium): secret masking can leave part of a secret in the log. Fixed in 0.2.97.
- The release notes for 0.2.95, 0.2.96 and 0.2.97 list only those security fixes.
- Owner decision D4, 2026-11-15, verbatim « D4 B »: pin act 0.2.97 and record an AC2 exception (a security fix overrides the 14-day age rule). This is recorded in the AC2 row, the D4 section and the Log of `mission.md`.
- Sources: `gh api repos/{nektos/act,suzuki-shunsuke/pinact}/releases` and `gh api repos/nektos/act/security-advisories`.
  - `ac2-releases.txt` holds the release list: tags, prerelease and draft flags, publish dates.
  - `ac2-advisories.txt` was added after review 1 (F1), captured at 2026-11-15T21:06Z. It holds the full act advisory list (ID, severity, affected and fixed ranges, summary), the release notes and linux-x64 assets of act 0.2.94 to 0.2.97, and the pinact 5.0.2 linux-amd64 assets.

## Verification

Evidence dir: `~/.local/share/laptop-bootstrap-agent/2026-11-15-mise-act-pinact/`.

- AC1 — VERIFIED.
  - Method: a `tomllib` comparison of `git show 019c7fa:roles/cli_tools/files/config.toml` against the branch file.
  - Result: base 14, branch 16; added `{'act': '0.2.97', 'pinact': '5.0.2'}`; removed `[]`; changed `[]`; node `26`, pnpm `12`. Evidence: `ac1.txt`.
- AC2 — VERIFIED, with the D4 exception.
  - Method: `mise install act@0.2.97 pinact@5.0.2` with `MISE_DATA_DIR`, `MISE_CACHE_DIR`, `MISE_STATE_DIR`, `MISE_CONFIG_DIR` and `MISE_GLOBAL_CONFIG_FILE` pointed at a scratch directory.
  - Result: exit 0. `mise tool` reports the backends `aqua:nektos/act` and `aqua:suzuki-shunsuke/pinact`. The tools report `act version 0.2.97` and `pinact version 5.0.2`.
  - The live `~/.config/mise/config.toml` was hashed before and after the install and the two values were equal. The evidence records only the result (`live config unchanged: yes`), not the hash values.
  - After review 1 (F2), the current value was recorded in `live-config-sha256.txt`: `bbff8c10…b28f`, 365 bytes, mtime 2026-11-12 18:47 (before the mission).
  - Evidence: `ac2-isolated-install.txt`, `live-config-sha256.txt`.
- AC3 — VERIFIED.
  - Method: the smoke VM did not exist, so `LAPTOP_BOOTSTRAP_TAGS=mise make smoke-up` created it. Its first provision was limited to the `mise` tag, so the seed ran with no config present: exit 0, recap `ok=10 changed=6 failed=0`.
  - Inside the VM (user `vagrant`):
    - `mise ls` shows act 0.2.97 and pinact 5.0.2, and `mise ls --missing` is empty.
    - The seeded config's sha256 equals the reference's (`4dc7aef6…d1ee`).
    - `act --version` printed 0.2.97 and `pinact --version` printed 5.0.2.
    - `act -l -W .github/workflows/ci.yml` exited 0 and listed the jobs `lint` and `terraform`. It also warned "Couldn't get a valid docker connection", which is expected because the `mise` tag does not install Docker.
    - In an interactive shell, both binaries resolve under `~/.local/share/mise/installs/`.
  - Evidence: `smoke-1-up-mise.log`, `smoke-1-vm-checks.log`.
- AC4 — VERIFIED.
  - Replay 2 (`make smoke-replay TAGS=mise`): exit 0, `ok=9 changed=0 failed=0 skipped=1`. The config's sha256 is unchanged (`4dc7aef6…`).
  - A marker line was then appended to the VM config by hand (sha256 `5c82c3df…028c`). Replay 3: exit 0, `changed=0`. The sha256 is unchanged and the marker is still present.
  - Evidence: `ac4.txt`, `smoke-2.log`, `smoke-3.log`.
- AC5 — VERIFIED.
  - Method: `make lint`, `.venv/bin/ansible-lint`, `.venv/bin/yamllint .` and `.venv/bin/ansible-playbook playbook.yml --syntax-check`, all with the dummy vault password file and direnv credentials unset.
  - Result: the logs are consistent with success: every pre-commit hook `Passed`, ansible-lint `0 failure(s), 0 warning(s)` at profile `production`, syntax check `playbook: playbook.yml`, and an empty yamllint log. The exit statuses were printed in the session but not written to the logs (F3), and the checks were not rerun.
  - ansible-lint logged the expected "Decryption failed" warning on the vault file.
  - The pre-commit hooks also passed during `git commit`.
  - Evidence: `ac5-*.log`.
- AC6 — VERIFIED: the owner command is in the "Owner command" section below. It was not executed.
- AC-SAFE — VERIFIED.
  - No secrets were read: no `pass` or `ansible-vault`, and the vault was never decrypted.
  - Hooks ran on the commit, with no `--no-verify` and no `SKIP`.
  - Nothing ran on the real laptop. The live mise config is unchanged, and act and pinact are not on the host's PATH.
  - The stash list was not touched. No `--diff` was used.

## Deviations and limitations

- AC3 was planned as "move the VM's config aside, then replay". Because the VM did not exist, it was created fresh with a `mise`-only first provision instead. This gives the same proof: the seed runs on a VM with no config.
- The smoke VM ran only the `mise` tag, without Docker. That proves act installs and parses workflows, but not that it can run a job. Running a job needs Docker (role `docker`), which is out of scope.
- act asks for a default image size the first time it runs interactively, then writes `~/.config/act/actrc`. That file is out of scope and not managed. In the VM's non-interactive `act -l` run, act created an empty `~/.config/act/` directory and did not ask.
- `docs/adr/0001-unified-cli-tool-management-with-mise.md` lists the in-scope mise tools (line 37) and does not include act or pinact. The ADR was outside the mission's scope, so it was left unchanged. A one-line amendment is optional.
- The smoke VM was left running (`smoke-down` needs approval).
- Verification covers lint and the smoke VM only, not the laptop.

## Known risks

- GHSA-jm9r-836x-3vhh (medium, "CI/CD pipeline vulnerabilities in GitHub Actions workflows"): published 2026-03-26, affects all act versions (`> 0`), and has no patched version. 0.2.97 is affected too, and no pin can avoid it.
- act 0.2.97 was pinned 11 days after its release, before the usual 14-day period (D4). The trade-off was accepted to avoid two high-severity advisories.
- act runs the workflows of the repository it is pointed at, with access to the Docker daemon. Use it on trusted repositories.

## Review 1

- Reviewer: Claude Code, routed by the pilot. File: `review-1-claude.md`, brief: `review-brief-1-claude.md`.
- Verdict: PASS_WITH_RESERVATIONS on `dbe84d3`. Four minor findings, no blocker or major.
- F1, D4's factual basis was not in the evidence: fixed. The advisory list, release notes and assets were saved to `ac2-advisories.txt`, which is cited in the AC2 section. The data matches what this report already stated.
- F2, the live-config hash was claimed without recorded values: fixed by rewording. AC2 now says the hashes were compared and equal but not recorded, and the current value is recorded in `live-config-sha256.txt`.
- F3, the AC5 exit statuses were not recorded: fixed by rewording. AC5 now says the logs are consistent with success and the exit statuses were not recorded. Not rerun, as the pilot asked.
- F4, the config.toml header says the pins were validated on the owner's laptop, but act and pinact were validated on the smoke VM only: no change, on the pilot's instruction. The owner runs the AC6 command right after merge, which makes the comment true.
- The correction touched only docs and evidence. config.toml and the roles are unchanged, so `Version:` stays `dbe84d3`.

## Git state

- Branch `feat/mise-act-pinact`, tracking `origin/feat/mise-act-pinact`.
- Implementation commit `dbe84d35435d3ab5948c90cbeaa062d085b3e3bb` is pushed.
- Draft PR https://github.com/TiPunchLabs/laptop-bootstrap/pull/68 targets `main` and is open, with head `dbe84d3`.
- This report is in a following commit on the same branch (`7eeacd8`). The review 1 correction is in a further docs-only commit, and PR #68 was then marked ready for review.
- Nothing was merged, and no branch was deleted.

## Owner command (live laptop, after merge, not executed)

```bash
mise use -g act@0.2.97 pinact@5.0.2
act --version      # act version 0.2.97
pinact --version   # pinact version 5.0.2
```

- `mise use -g` installs both tools and writes the exact versions to `~/.config/mise/config.toml`. No Ansible run is needed: Ansible never reconciles an existing config, so `make play TAGS=mise` would not add the tools.
- Optional check after running it: `diff -u roles/cli_tools/files/config.toml ~/.config/mise/config.toml`.

## Decisions required

- None block this mission.
- Optional: approve `make smoke-down` to remove the smoke VM.

## Next action

- Review 1 has been addressed and PR #68 is ready for review.
- The owner merges, then runs the owner command above right after merging (see F4).
