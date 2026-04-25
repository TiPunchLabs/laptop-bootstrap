# 🛠️ Daily Usage of laptop-bootstrap

> **Objective**: Use this project day-to-day — add a CLI tool, swap a package, change a config, validate the change, and roll it onto your laptop without breaking anything.
> **Prerequisites**: A working clone (see [README](../README.md) → Installation), `make`, `direnv` activated, smoke VM optional but recommended.
> **Estimated duration**: 5–10 min per change once the loop becomes muscle memory.

## Table of Contents

1. [📖 Introduction](#-introduction)
2. [🏗️ Mental Model](#️-mental-model)
3. [🎯 Editing your configuration](#-editing-your-configuration)
4. [🛠️ Verifying changes](#️-verifying-changes)
5. [🚀 Applying to your laptop](#-applying-to-your-laptop)
6. [🔄 Git workflow](#-git-workflow)
7. [🔐 Secrets & vault](#-secrets--vault)
8. [🔧 Troubleshooting](#-troubleshooting)
9. [✅ Best practices](#-best-practices)
10. [🎓 Conclusion](#-conclusion)
11. [📚 Resources](#-resources)

------

## 📖 Introduction

`laptop-bootstrap` is the source of truth for your developer laptop. Every package, every CLI tool, every shell hook lives in version control. The "daily usage" question is: how do you keep that source of truth honest while still being able to ship a change in a few minutes?

The answer is a small loop: **edit a vars file → smoke-test → ship → apply locally**. The Makefile collapses the verbs of that loop down to single targets so the friction stays low.

> **Analogy**: It's like running a tiny supply chain. You don't ship to production from your kitchen counter — you stage it on a clean workbench (the smoke VM), then deploy. The Makefile is the conveyor belt.

------

## 🏗️ Mental Model

```
 ┌────────────────── EDIT ──────────────────┐    ┌──────── VERIFY ────────┐    ┌────── APPLY ──────┐
 │                                          │    │                        │    │                   │
 │ roles/cli_tools/vars/main.yml            │    │  make lint-ansible     │    │  make play         │
 │ roles/bootstrap/vars/main/software.yml   │ ─► │  make smoke-up         │ ─► │  make play-<role>  │
 │ roles/{docker,vagrant,git}/vars/main.yml │    │  make smoke-replay     │    │                   │
 │ group_vars/all/vault/main.yml (vault)    │    │  → expect changed=0    │    │  on the laptop     │
 │                                          │    │      on 2nd replay     │    │                   │
 └──────────────────────────────────────────┘    └────────────────────────┘    └───────────────────┘
                  │                                          │                           │
                  └────────────────── git switch -c → commit → push → PR ────────────────┘
```

Three principles that fall out of this model:

1. **One config, two execution targets.** The same playbook runs against (a) a throwaway Ubuntu VM and (b) your laptop. If it can't survive the VM, it shouldn't touch the laptop.
2. **Idempotence is the contract.** A second replay should report `changed=0`. Anything else is a bug.
3. **Roles are tag-aligned.** Every role has a tag of the same name; you almost never run the full playbook in a tight feedback loop.

------

## 🎯 Editing your configuration

The "what do I edit?" table — keep it open in a tab during the first month:

| Intent                               | File                                          | Mechanism                              |
| ------------------------------------ | --------------------------------------------- | -------------------------------------- |
| Add / remove a CLI tool              | `roles/cli_tools/vars/main.yml`               | `cli_tools_mise_tools` dict            |
| Change CLI tool version              | same file                                     | `tool: <semver>` instead of `latest`   |
| Add an apt repo + package            | `roles/bootstrap/vars/main/software.yml`      | append entry to `bootstrap_software_list` |
| Change docker repo / arch            | `roles/docker/vars/main.yml`                  | `docker_deb822` / `docker_gpg`         |
| Change HashiCorp/vagrant repo        | `roles/vagrant/vars/main.yml`                 | `vagrant_hashicorp_deb822`             |
| Tweak git identity / aliases         | `roles/git/vars/main.yml`                     | role vars                              |
| Add devtools (Postman & co.)         | `roles/devtools/`                             | edit tasks + vars in the role          |
| Hostname, locale, base apt packages  | `roles/bootstrap/vars/main/*.yml`             | `bootstrap_*` vars                     |
| Manage a secret                      | `group_vars/all/vault/main.yml`               | `make vault-edit`                      |

> 💡 **Note**: 90% of daily changes touch only `cli_tools/vars/main.yml` or `bootstrap/vars/main/software.yml`. Stay there until you need more.

### Example — adding `jq`

```yaml
# roles/cli_tools/vars/main.yml
cli_tools_mise_tools:
  uv: latest
  fzf: latest
  # ... existing entries ...
  jq: latest        # ◄ new line
```

That's it. The role takes care of the rest:
- Re-renders `~/.config/mise/config.toml` (template).
- Detects `jq` in `declared - installed` → triggers `mise install --yes`.
- If you ever delete the line, the symmetric `installed - declared` set-diff will trigger `mise uninstall --all jq` on the next run. No dead weight on disk.

### Example — adding a deb822 apt source

```yaml
# roles/bootstrap/vars/main/software.yml
bootstrap_software_list:
  # ... existing entries ...
  - name: "discord"
    package: "discord"
    key_url: "https://packages.discord.com/keys/discord.asc"
    key_format: "ascii"
    deb822:
      uris: "https://packages.discord.com/apt"
      suites: "stable"
      components: ["main"]
```

The role downloads the key, dearmors it atomically, writes `/etc/apt/sources.list.d/discord.sources` via `deb822_repository`, and installs the package. One entry, full lifecycle.

------

## 🛠️ Verifying changes

The fast-to-slow ladder of feedback:

```bash
make lint-ansible        # 5–10 s — catches structural / lint issues
make lint                # 30–60 s — full pre-commit (yamllint, shellcheck, vault check, etc.)
make smoke-replay TAGS=cli-tools   # 1–3 min — replay the touched role on the smoke VM
make smoke-replay        # 3–5 min — full playbook replay (excluding `vagrant` tag by default)
```

The single rule: **after a change, replay twice**. The first replay applies the change; the second replay must show `changed=0`. If it doesn't, you have a non-idempotent task — fix it before shipping.

If the smoke VM isn't booted yet:

```bash
make smoke-up            # one-time create; ~10 min for the first box download
```

To inspect state on the VM:

```bash
make smoke-ssh
# inside the VM:
mise ls
ls /etc/apt/sources.list.d/
```

When in doubt, throw the VM away and start over:

```bash
make smoke-down && make smoke-up
```

> ⚠️ **Warning**: The default `LAPTOP_BOOTSTRAP_SKIP_TAGS=vagrant` means the `vagrant` role is **not** exercised on the smoke VM (nested virtualization is fragile). HashiCorp source / vagrant install changes are only structurally validated by lint until you replay on your laptop.

------

## 🚀 Applying to your laptop

Once the smoke VM is green, point the same playbook at `localhost`:

| Goal                                  | Command                                  |
| ------------------------------------- | ---------------------------------------- |
| Run the whole bootstrap               | `make play`                              |
| Apply only the cli_tools change       | `make play-cli-tools`                    |
| Apply docker + git in one go          | `make play TAGS=docker,git`              |
| Apply only the cleanup_legacy role    | `make play-cleanup-legacy`               |

After a `cli-tools` run that added a new shell hook, reload your shell:

```bash
exec bash    # or open a fresh terminal — the managed block is read at shell startup
```

------

## 🔄 Git workflow

The project follows GitHub Flow: every change rides on a feature branch, merges via PR.

```bash
git switch -c feat/add-jq                    # always a feature branch
# ... edit roles/cli_tools/vars/main.yml ...
make lint-ansible
make smoke-replay TAGS=cli-tools             # 1st: changed≥1
make smoke-replay TAGS=cli-tools             # 2nd: changed=0 (idempotence proof)
git add -p
git commit -m "feat(cli_tools): add jq"      # Conventional Commits — pre-commit runs
git push -u origin HEAD
gh pr create
```

After merge:

```bash
git switch main
git pull --ff-only
git branch -d feat/add-jq
make play-cli-tools                          # roll the change onto your laptop
```

> 💡 **Note**: Use `git switch -c` to create a branch and `git switch <name>` to navigate; `git checkout` is multi-purpose and can silently restore files when a path collides with a branch name.

------

## 🔐 Secrets & vault

Secrets live in `group_vars/all/vault/main.yml`, encrypted with `ansible-vault`. The vault password is read from `pass` via `bin/ansible-vault-pass.sh` (entry: `ansible/vault`).

| Action                | Command            |
| --------------------- | ------------------ |
| Edit secrets          | `make vault-edit`  |
| Read without editing  | `make vault-view`  |

The pre-commit hook `Check Ansible Vault Encryption` blocks any commit that contains plaintext where vault was expected. Never bypass it.

> ⚠️ **Warning**: Never commit `.env` files, plaintext secrets, or unencrypted variants of vault files. The `detect-private-key` and vault-encryption hooks should catch most cases — but the contract is yours to uphold.

------

## 🔧 Troubleshooting

### `Cannot allocate memory` during pre-commit (gpg-agent OOM)

Symptom: `ansible-lint` hook fails with `gpg: public key decryption failed: Cannot allocate memory`. Cause: the gpg-agent that pre-commit's vault decrypt invokes runs out of memory.

```bash
gpgconf --kill all
bash bin/ansible-vault-pass.sh >/dev/null     # primes a fresh agent
# retry the commit
```

### Smoke VM reports `changed≠0` on second replay

This is a non-idempotent task — the role does work it shouldn't repeat. Find which task changed:

```bash
grep -B 1 "^changed: \[local\]" <provision-log>
```

Common causes:
- A `command:` task without `changed_when:` → use a register-and-conditional pattern, or set `changed_when: false` if the command is a probe.
- A file resource where the source content actually drifts each run (templates pulling `now()`, hostnames, etc.).
- A `notify:`-fed handler that was meant to fire only once but fires every replay because the trigger task is itself changed every run.

### Mise tool I installed manually disappears

By design — the `cli_tools` role prunes anything in `mise ls --installed` that isn't in `cli_tools_mise_tools`. Add the tool to the declared list, or expect it to vanish on the next `--tags cli-tools` run.

### Standalone shell hooks in `~/.bashrc` after migration

Pre-`blockinfile` versions of the role appended `eval` lines directly. After upgrading, those orphan lines persist. Delete them by hand once, then run `make play-cli-tools` to regenerate the managed block. See [README → Manual `.bashrc` cleanup](../README.md#manual-bashrc-cleanup-one-time).

### "Tag not found" when running `make play TAGS=foo`

You misspelled a tag, or you're trying to run a role that the playbook doesn't include yet. Check `make help` for the registered shortcuts and the [README → Available Tags](../README.md#available-tags) for the canonical list.

------

## ✅ Best practices

- **Stay on the role tag.** `make play-cli-tools` is faster than `make play`, exposes only the failures relevant to your change, and avoids re-applying things that don't need it.
- **Two replays, every time.** First run = the change applies; second run = the proof of idempotence. Skipping the second is how non-idempotent tasks slip in.
- **One concern per PR.** A `cli_tools` change and a `docker` repo bump don't belong in the same diff — the smoke replay can't tell you which one regressed `changed=0`.
- **Conventional Commits, narrow scope.** `feat(cli_tools): add jq`, not `feat: stuff`. The scope makes future bisects two minutes instead of twenty.
- **Trust pre-commit.** If a hook fails, fix the underlying issue. Bypassing with `--no-verify` is an instant tech-debt loan.
- **Smoke VM is disposable.** If you suspect contamination from a previous run, `make smoke-down && make smoke-up` is cheap insurance.

------

## 🎓 Conclusion

The whole point of this project is that you can update your laptop the way you update a server: edit, lint, test, ship. The Makefile is just convenience — every `make` target is a 1-liner you could type from memory. But typing them from memory once a week, you'll forget the flags. Use the targets.

The shortest viable loop is:

```bash
git switch -c feat/X
# edit
make smoke-replay TAGS=X      # twice
git commit && git push && gh pr create
# merge, then on your laptop:
make play-X
```

Anything more complicated than this is either (a) the smoke VM caught something or (b) a real architectural decision that deserves an ADR in `docs/adr/`.

------

## 📚 Resources

- [README](../README.md) — install, tags, security
- [Smoke-test guide](guide-smoke-test-vagrant.md) — the full Vagrant + libvirt walkthrough
- [ADR-0001 — Unified CLI tool management with mise](adr/0001-unified-cli-tool-management-with-mise.md) — the *why* behind `cli_tools`
- [`mise` docs](https://mise.jdx.dev/) — version manager reference
- [`deb822_repository` module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/deb822_repository_module.html) — apt source format used across roles
- [Conventional Commits](https://www.conventionalcommits.org/) — commit message style

> **Document created on**: 2026-04-24
> **Author**: Xavier Gueret
> **Version**: 1.0
