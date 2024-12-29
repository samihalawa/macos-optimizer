#!/usr/bin/env python3
# Shared configuration settings for macOS Optimizer

import os
from pathlib import Path

# Version
VERSION = "2.1"

# Paths
BASE_DIR = os.path.expanduser("~/.mac_optimizer")
BACKUP_DIR = os.path.join(BASE_DIR, "backups")
LOG_DIR = os.path.join(BASE_DIR, "logs")
CONFIG_DIR = os.path.join(BASE_DIR, "config")

# Create directories if they don't exist
for directory in [BASE_DIR, BACKUP_DIR, LOG_DIR, CONFIG_DIR]:
    Path(directory).mkdir(parents=True, exist_ok=True)

# Feature flags
ENABLE_ADVANCED_FEATURES = True
ENABLE_EXPERIMENTAL = False
ENABLE_LOGGING = True

# System requirements
MIN_MACOS_VERSION = "10.15"
MIN_MEMORY_GB = 4
MIN_DISK_SPACE_GB = 10

# GUI settings
GUI_PORT = 8080
GUI_TITLE = "macOS Optimizer"
GUI_THEME = "dark"

# Optimization categories
OPTIMIZATION_CATEGORIES = {
    "system": "System Tweaks",
    "power": "Power Management",
    "network": "Network Optimization",
    "performance": "Performance Enhancement"
} 