#!/usr/bin/env python3
"""Shared configuration for macOS Optimizer."""

from __future__ import annotations

import os
from pathlib import Path

VERSION = "2.2.0"

BASE_DIR = Path(os.path.expanduser("~/.mac_optimizer"))
BACKUP_DIR = BASE_DIR / "backups"
LOG_DIR = BASE_DIR / "logs"
CONFIG_DIR = BASE_DIR / "config"
PROFILES_DIR = BASE_DIR / "profiles"

for directory in (BASE_DIR, BACKUP_DIR, LOG_DIR, CONFIG_DIR, PROFILES_DIR):
    directory.mkdir(parents=True, exist_ok=True)

ENABLE_ADVANCED_FEATURES = True
ENABLE_EXPERIMENTAL = False
ENABLE_LOGGING = True

MIN_MACOS_VERSION = "10.15"
MIN_MEMORY_GB = 4
MIN_DISK_SPACE_GB = 10

GUI_HOST = "127.0.0.1"
GUI_PORT = 8080
GUI_TITLE = "macOS Optimizer"
GUI_THEME = "dark"

OPTIMIZATION_CATEGORIES = {
    "performance": {
        "label": "System Performance",
        "description": "Kernel limits, responsiveness, and power performance mode",
        "icon": "bolt",
        "safety": "Moderate — may require sudo",
    },
    "graphics": {
        "label": "Graphics & UI",
        "description": "Reduce transparency, motion, and animation overhead",
        "icon": "palette",
        "safety": "Safe — preference-domain changes",
    },
    "display": {
        "label": "Display",
        "description": "Font smoothing and display-related preferences",
        "icon": "monitor",
        "safety": "Safe — reversible defaults",
    },
    "storage": {
        "label": "Storage Cleanup",
        "description": "Clear safe caches, old logs, and leftover clutter",
        "icon": "delete_sweep",
        "safety": "Safe — skips critical paths",
    },
    "network": {
        "label": "Network",
        "description": "TCP buffer and latency-oriented sysctl tuning",
        "icon": "wifi",
        "safety": "Moderate — may require sudo; often resets on reboot",
    },
}
