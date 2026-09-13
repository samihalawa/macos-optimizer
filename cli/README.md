# macOS Optimizer CLI

Interactive terminal toolkit for performance, graphics, display, storage, and network tweaks on macOS.

## Install / run

```bash
cd cli
chmod +x src/macos-optimizer.sh
./src/macos-optimizer.sh
```

From the repository root:

```bash
make cli
```

## Flags

| Flag | Description |
|---|---|
| `-h`, `--help` | Show usage |
| `-v`, `--version` | Print version |
| `-i`, `--info` | System information (macOS only) |
| `--check` | Requirement checks (macOS only) |

`src/script.sh` remains as a thin compatibility wrapper.

## Features

- Full-screen interactive menu with live status
- Category optimizations with progress feedback
- Preference backups under `~/.mac_optimizer/backups`
- Apple Silicon / Intel detection

## Configuration

Shared defaults live in [`../config/settings.sh`](../config/settings.sh).

## Safety

- Prefer single categories before **Run All**
- Keep Time Machine current
- Some `sysctl` settings reset after reboot

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).
