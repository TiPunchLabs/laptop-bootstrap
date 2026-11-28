# Review 2 — 2026-11-28-open-webui-0-13-5

VERDICT: CHANGES_REQUESTED

Version: c364acb97fcc6aad6ebfb4609445ff974d2fc069

## Findings

- F2.1 [major] roles/open_webui/README.md:145 — The update example still permits migration after a failed backup. Only the first apply (line 142) is guarded by `&&`; the second `make play-open-webui` runs unconditionally after the inspect/curl commands. This block has no failure-exiting shell wrapper. Pasting it into an ordinary shell after a backup failure therefore reaches the supposedly idempotent second apply, which becomes the first upgrade without a validated backup. Expected fix: guard the entire deploy/check/second-apply sequence with successful backup and apply, for example in an explicitly invoked Bash block with `set -euo pipefail`, as in the report. Verify the complete documented sequence with a failing backup and confirm neither apply is reached. F1.1 is fixed in the mission report, but remains open in the reusable README procedure.
- F2.2 [minor] bin/open-webui-volume.sh:69 — A failed restart after a successful backup is logged but does not change the successful exit status: `docker start ... || log ...` ends successfully because `log` succeeds. The archive path has already been printed. Thus callers see success despite the promised restoration of the previous running state failing. Expected fix: preserve an existing failure status, but return nonzero when restart fails after an otherwise successful backup; document that the valid archive can remain in this case. This does not invalidate the archive, so it is not itself a data-loss blocker.

## AC check

| ID | Reviewer status | Basis |
|---|---|---|
| AC1 | VERIFIED from previously reviewed supplied evidence | Review 1 checked saved official release metadata for v0.13.5, dated 2026-11-25. No new upstream verification in this cycle. |
| AC2 | VERIFIED as previously reviewed release-note analysis | The release analysis and role settings are unchanged since review 1. Its limits concerning undocumented upstream behavior remain. |
| AC3 | VERIFIED for role configuration scope | Full diff changes only the version default in role configuration; tasks, templates and shared firewall are unchanged. Fix 1 additionally introduces the explicitly reviewed operational backup/restore script. |
| AC4 | VERIFIED from supplied evidence and independent static checks | Existing lint/syntax/hook evidence remains applicable to the unchanged role. Reviewer ShellCheck, shfmt, Bash syntax, yamllint and whitespace checks pass. The saved `pre-commit.log` predates the script (shell hooks skipped); this cycle independently checks the script directly. |
| AC5 | VERIFIED from supplied VM evidence | Fix-1 gated upgrade reports exit 0, `changed=1 failed=0`; second run reports `changed=0 failed=0`. Final probe shows healthy v0.13.5, API 0.13.5, expected migration, retained user and key hash. |
| AC6 | NOT_VERIFIED for all published procedures being safe | Report's single Bash block gates apply correctly; restore block gates old-version apply and leaves the newer container stopped. VM failure and rollback evidence supports these paths. README update procedure still bypasses the gate via its second apply (F2.1); restart error reporting also needs correction (F2.2). No laptop execution assessed. |
| AC-SAFE | VERIFIED to the extent of supplied evidence | `laptop-final-fix1.log` retains original container ID, v0.13.0, original start time and zero restarts; main-tree preservation remains a reported assertion with baseline artifact, as qualified in review 1. No evidence of secret contents, hook bypass or role behavior expansion. Reviewer performed no network, Docker/VM/laptop operations, vault access or git writes, and wrote only this review. |

## Commands run

`E` denotes `/home/xgueret/.local/share/laptop-bootstrap-agent/2026-11-28-open-webui-0-13-5`. Inspection commands below did not execute the owner runbook.

- `cat AGENTS.md CLAUDE.md docs/agent-workflow.md docs/missions/2026-11-28-open-webui-0-13-5/review-brief-2.md` → exit 0; read rules and brief. `cat` of mission, review 1, brief 1 and report → exit 0; read acceptance criteria, findings, resolutions and runbook; targeted report reads completed truncated batch output.
- `git status --short`, `git diff HEAD`, `git rev-parse HEAD` → exit 0 each; reviewed HEAD matches the requested version, tracked working tree unchanged, only brief 2 initially untracked.
- `git diff c318c0b c364acb --stat`, targeted correction diff of role README, full-change diff of defaults/README, `git diff f8299e9 c364acb --name-only`, and diff of role tasks/templates/shared firewall → exit 0 each; inspected changed scope and confirmed deployment logic unchanged.
- `nl -ba bin/open-webui-volume.sh`, numbered README inspection, `cat .pre-commit-config.yaml`, `git ls-tree HEAD bin/open-webui-volume.sh` → exit 0 each; reviewed all script paths, documentation and executable mode.
- `rg --files E`, `cat E/vm-fix1-{backup-failures,backup-ok,gate-closed,restore-failures,restore-ok}.log E/script-sha256.txt E/laptop-final-fix1.log`, `tail -n 16 E/vm-fix1-{rb-v0130,rb-probe,rb-data,gated-upgrade,upgrade,idempotence,final}.log`, targeted `rg -n` over rollback/idempotence/lint/hook logs, and `cat E/pre-commit.log` → exit 0 each; inspected failure cases, successful restore, retained data, final state and static-check evidence.
- `sha256sum bin/open-webui-volume.sh` → exit 0; full hash `a4b8fb5fa41eef5c3b5262dc05c2535bcf6d3ae38e26e03d71e73a352faf38bc` matches the supplied rehearsal artifact.
- `command -v shellcheck shfmt` → exit 0; both installed. `shellcheck bin/open-webui-volume.sh`, `shfmt -d bin/open-webui-volume.sh`, `bash -n bin/open-webui-volume.sh`, `.venv/bin/yamllint .`, `git diff --check f8299e9 c364acb` → exit 0 each, no diagnostics.
- `bash -c 'backup() { return 1; }; apply() { echo APPLY_REACHED; }; archive=$(backup) && apply; :; :; apply'` → exit 0, printed `APPLY_REACHED`; side-effect-free reproduction of the README's failed-backup control flow, substituting shell functions and no-op probes for operational commands.
- Bash simulation of the EXIT trap using `false || printf "FAILED: restart\n" >&2` after printing an archive path → exit 0 despite the failure diagnostic; confirms F2.2 without Docker operations.
- Read the using-superpowers skill instructions → exit 0; applied workflow guidance within the review restrictions.

## Not checked

- No network or Context7: explicitly prohibited. No current upstream release lookup or image/source fetch.
- No Docker, VM, laptop apply, restore, sudo, real vault, `pass` or smoke commands. VM observations above are supplied logs, not reviewer reruns.
- Put-back after a mid-swap failure remains NOT_VERIFIED dynamically, as the report correctly states. No fault injection performed.
- Hooks were not rerun because they can edit files; Ansible-lint and syntax-check were assessed from existing evidence. No independent main-checkout snapshot, for the same scope reason recorded in review 1.

## Reservations

- F1.2 is resolved in the reviewed report/script: placeholder/missing/truncated archives fail before live-data replacement; archive checks cover gzip integrity, SQLite integrity and a nonempty secret key. Full extraction and another check precede the stop. The current data is copied to a retained prerestore volume before deletion, and successful restore leaves the container stopped. VM logs demonstrate unchanged running state and database hash for the tested early failures, and successful rollback to v0.13.0 with sign-in/chat preservation. Archives are created with umask 077, with observed root-owned 0600 permissions; content is not printed by the script.
- By inspection, either swap-helper failure or post-swap check failure enters put-back; failed put-back exits nonzero with manual recovery instructions, retains the prerestore source and never starts the container. Leaving this branch unrehearsed is acceptable as an explicit reservation, rather than a VERIFIED claim, given the preserved recovery copy and readable control flow. It does not establish automatic recovery under persistent disk/I/O failure. Failures after stopping but before swapping can also leave the original container stopped; the report's statement that every pre-swap failure leaves it running is too broad.
- F1.3 is resolved in the report's authorization section: the owner's conditional grant and review/CI conditions are stated. This review still has a major finding, so its review condition remains unmet.
- The script is proportionate to the backup/rollback safety requirements. Deployment idempotence and the prior firewall assessment are unaffected. Backup restart failure and the full README failure sequence were not covered by the supplied VM gate test, which tests only the first `backup && apply` chain.
