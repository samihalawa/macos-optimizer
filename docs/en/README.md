# macOS Optimizer — English Guide

<img width="100%" alt="GUI screenshot" src="../images/gui-screenshot.png" />

## Overview

macOS Optimizer provides:

1. **CLI** — `cli/src/macos-optimizer.sh` interactive terminal menu  
2. **GUI** — `gui/src/app.py` NiceGUI dashboard on `http://127.0.0.1:8080`

Both share the philosophy of **backup-first**, **explainable** tweaks with no telemetry.

## Quick start

### CLI

```bash
chmod +x cli/src/macos-optimizer.sh
./cli/src/macos-optimizer.sh
```

### GUI

```bash
cd gui && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python src/app.py
```

## Optimization categories

| Category | Typical changes | Reversible |
|---|---|---|
| Performance | Animation / responsiveness prefs; optional high-perf power mode | Mostly yes |
| Graphics | Transparency, motion, Dock animation timing | Yes (`defaults`) |
| Display | Font smoothing related preferences | Yes |
| Storage | User caches (selected), old logs | Partial |
| Network | TCP-related `sysctl` values | Often resets on reboot |

## Data locations

| Path | Purpose |
|---|---|
| `~/.mac_optimizer/backups/` | Preference exports |
| `~/.mac_optimizer/logs/` | GUI / tooling logs |
| `~/.mac_optimizer/profiles/` | Optional profiles |

## Safety checklist

1. Time Machine (or clone) backup  
2. Built-in **Backup** action  
3. Apply one category and validate for a day  
4. Only then consider **Run All**

## Languages

- [English](README.md)
- [Español](../es/README.md)
- [中文](../zh/README.md)

## License

MIT — see the repository root `LICENSE`.
