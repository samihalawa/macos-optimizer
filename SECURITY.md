# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 2.2.x | ✅ |
| 2.1.x | ⚠️ best-effort |
| < 2.1 | ❌ |

## What this project does

macOS Optimizer runs **locally** and may:

- Read system information (`sw_vers`, `vm_stat`, `sysctl`, disk usage)
- Modify user preference domains via `defaults`
- Optionally elevate with `sudo` for kernel/network parameters and cleanup tasks
- Write backups and logs under `~/.mac_optimizer/`

It does **not** phone home, collect analytics, or require cloud accounts.

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

1. Use GitHub **Private vulnerability reporting** on this repository if enabled, or
2. Contact the repository owner (@samihalawa) with a clear description, impact, and reproduction steps.

We aim to acknowledge reports within **7 days** and to share a remediation plan when confirmed.

## Safe usage recommendations

- Review each optimization description before applying bulk changes
- Keep Time Machine (or another full backup) current
- Prefer the built-in backup before first-time runs
- Avoid running untrusted forks with elevated privileges
- Inspect `~/.mac_optimizer/logs` after changes

## Supply chain

- Prefer cloning from `https://github.com/samihalawa/macos-optimizer`
- Install GUI dependencies only from the pinned `gui/requirements.txt` inside a virtualenv
- Do not paste unknown shell one-liners that download and pipe into `bash`
