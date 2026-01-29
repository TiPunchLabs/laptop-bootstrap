# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **Do not** open a public issue
2. Email the maintainers directly
3. Include details about the vulnerability
4. Allow time for a fix before public disclosure

We take security seriously and will respond promptly.

## Security Best Practices

This project uses several security measures:

- **Ansible Vault**: Sensitive variables are encrypted
- **Pre-commit hooks**: Detect private keys and secrets before commit
- **No hardcoded credentials**: All secrets are managed via environment variables or vault
