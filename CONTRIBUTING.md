# Contributing to laptop-bootstrap

Thank you for your interest in contributing!

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git switch -c feat/amazing-feature`)
3. Validate your change locally (see [Code Style](#code-style) and [Smoke test](#smoke-test) below)
4. Commit your changes (`git commit -m 'feat: add amazing feature'`)
5. Push to the branch (`git push -u origin HEAD`)
6. Open a Pull Request

For the day-to-day workflow (which file to edit, how to verify, how to ship), see [`docs/guide-daily-usage.md`](docs/guide-daily-usage.md).

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

## Code Style

- Run `make lint` (or `pre-commit run --all-files`) before committing
- Use `make lint-ansible` for fast feedback while editing a role
- Follow existing code patterns
- Use `terraform fmt` for Terraform files

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/laptop-bootstrap.git
cd laptop-bootstrap

# Install dependencies
direnv allow
# or
uv sync && source .venv/bin/activate

# Install pre-commit hooks
pre-commit install
```

## Smoke test

Validate your change on a clean Ubuntu VM before sending a PR:

```bash
make smoke-up                       # one-time, ~10 min
make smoke-replay TAGS=<your-tag>   # replay your scope
make smoke-replay TAGS=<your-tag>   # second replay must show changed=0
```

See [`docs/guide-smoke-test-vagrant.md`](docs/guide-smoke-test-vagrant.md) for the full walkthrough.

## Questions?

Open an issue for any questions or concerns.
