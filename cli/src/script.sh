#!/bin/bash
# Compatibility wrapper — prefer macos-optimizer.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/macos-optimizer.sh" "$@"
