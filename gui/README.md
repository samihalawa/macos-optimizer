# macOS Optimizer GUI

Modern local web UI built with [NiceGUI](https://nicegui.io/), wrapping the same optimization ideas as the CLI.

## Requirements

- Python **3.9+**
- macOS for applying system tweaks (UI can start in preview mode elsewhere)

## Setup

```bash
cd gui
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/app.py
```

Open [http://127.0.0.1:8080](http://127.0.0.1:8080).

Or from the repo root: `make gui`.

## Features

- Dashboard with CPU / memory / disk snapshots (`psutil`)
- One-click optimizations with automatic preference backups
- Activity feed + persistent logs in `~/.mac_optimizer/logs/gui.log`
- Localhost-only bind by default

## Configuration

See [`../config/settings.py`](../config/settings.py) for port, paths, and category metadata.

## Development dependencies

```bash
pip install -r requirements-dev.txt
python src/test_app_helpers.py
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).
