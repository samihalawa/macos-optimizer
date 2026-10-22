# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-09-13

### Added
- Polished root README with badges, feature table, safety guidance, and quick start
- CLI flags: `--help`, `--version`, `--info`
- Clean NiceGUI application (`gui/src/app.py`) with dashboard, optimizations, logs, and settings
- Makefile for `cli`, `gui`, `test`, and `lint` workflows
- Community files: `CODE_OF_CONDUCT.md`, `SECURITY.md`, GitHub issue/PR templates
- Multi-language docs refresh (EN / ES / ZH)
- Proper MIT `LICENSE` matching project headers
- Structured `.gitignore` for Python, caches, logs, and local optimizer state

### Changed
- Renamed CLI entrypoint to `cli/src/macos-optimizer.sh` (stable name)
- Slimmed GUI dependencies to runtime essentials
- Version bumped to **2.2.0** across shared config and interfaces
- Contributing guide aligned with actual test paths

### Fixed
- Broken / corrupted GUI source that could not import or run
- README license mismatch (docs claimed MIT while tree shipped GPLv3 text)
- Missing `docs/images` assets referenced by documentation
- Incomplete CLI config and empty shared shell settings stub

### Removed
- Temporary autogen/debug scripts, log files, and oversized UI captures from the repository root
- Backup (`.bak`) and cache artifacts that should never be versioned

## [2.1.0] - 2024-12

### Added
- Interactive bash menu with system status dashboard
- Optimization categories: performance, graphics, display, storage, network
- Backup and restore helpers
- Early NiceGUI prototype and multilingual docs skeleton
