# Contributing to laptop-bootstrap

Thank you for your interest in contributing!

## How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

## Code Style

- Run `pre-commit run --all-files` before committing
- Follow existing code patterns
- Use `ansible-lint` for Ansible roles
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

## Questions?

Open an issue for any questions or concerns.
