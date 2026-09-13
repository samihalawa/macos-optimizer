#!/usr/bin/env bash
# Shared shell defaults for macOS Optimizer CLI helpers.
# shellcheck disable=SC2034

OPTIMIZER_VERSION="2.2.0"
OPTIMIZER_BASE_DIR="${HOME}/.mac_optimizer"
OPTIMIZER_MIN_MACOS="10.15"
OPTIMIZER_AUTO_BACKUP_LIMIT=5

# Preference domains snapshotted before UI/graphics changes
OPTIMIZER_TRACKED_DOMAINS=(
  "com.apple.dock"
  "com.apple.finder"
  "com.apple.universalaccess"
  "com.apple.WindowManager"
  "com.apple.QuickLookUI"
  "NSGlobalDomain"
)
