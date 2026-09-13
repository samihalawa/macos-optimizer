# Contributing to macOS Optimizer

Thanks for helping improve macOS Optimizer. This guide covers both the CLI and GUI.

## Project layout

```text
macos-optimizer/
├── cli/src/macos-optimizer.sh   # Terminal UI + optimizations
├── gui/src/app.py               # NiceGUI application
├── config/                      # Shared defaults (Python + shell)
├── docs/                        # EN / ES / ZH documentation
└── tests/cli/                   # bats smoke tests
```

## Development setup

```bash
git clone https://github.com/samihalawa/macos-optimizer.git
cd macos-optimizer

# CLI
chmod +x cli/src/macos-optimizer.sh
./cli/src/macos-optimizer.sh --help

# GUI
make install-gui
make gui
```

## Guidelines

### All contributions
- Prefer small, focused pull requests
- Update docs when behavior changes
- Never commit machine state from `~/.mac_optimizer/`, logs, or secrets
- Keep safety messaging honest (impact, sudo needs, reversibility)

### CLI (`cli/`)
- Target bash suitable for macOS `/bin/bash` and newer bash when available
- Run `shellcheck -x cli/src/macos-optimizer.sh` when possible
- Preserve `--help` / `--version` without requiring macOS APIs beyond detection
- Avoid destructive cleanup outside well-documented paths

### GUI (`gui/`)
- Python 3.9+
- Keep runtime dependencies minimal (`gui/requirements.txt`)
- Prefer `asyncio.to_thread` for blocking work
- Do not bind the UI beyond localhost by default

## Testing

```bash
make test
# or
python3 gui/src/test_app_helpers.py
# bats (optional)
bats tests/cli/test_script.sh
```

On Linux CI hosts, CLI tests should only assert `--help` / `--version` behavior. Full optimization paths require macOS.

## Documentation

- Update `README.md` for user-facing changes
- Keep `docs/en`, `docs/es`, and `docs/zh` roughly in sync for major features
- Add a `CHANGELOG.md` entry under **Unreleased** or the next version

## Pull requests

1. Branch from the default branch
2. Make the change + tests/docs
3. Run `make test` (and `make lint` if tools are available)
4. Open a PR with a clear summary and test notes
5. Link related issues

## Code of Conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Questions

Open a GitHub issue with the `question` label.
