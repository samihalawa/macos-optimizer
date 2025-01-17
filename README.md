# macOS Optimizer

A powerful tool to optimize and enhance your macOS experience, available in both CLI and GUI versions.

## Two Powerful Interfaces

### Command Line Interface
![CLI Screenshot](docs/images/cli-screenshot.png)

A traditional command-line interface using Bash scripts (`cli/src/script.sh`), perfect for:
- Server environments
- Terminal power users
- Automation scripts
- Remote administration

### Graphical Interface
![GUI Screenshot](docs/images/gui-screenshot.png)

A modern graphical interface built with Python and NiceGUI (`gui/src/python-app-nicegui.py`), ideal for:
- Desktop users
- Visual feedback
- Real-time monitoring
- User-friendly controls

## Project Structure

This monorepo contains two main implementations of the macOS Optimizer:

```
macos-optimizer/
├── cli/                  # Command-line interface version
│   ├── src/             # CLI source code
│   └── README.md        # CLI-specific documentation
├── gui/                 # Graphical interface version
│   ├── src/            # GUI source code
│   └── README.md       # GUI-specific documentation
├── docs/               # Documentation
│   ├── en/            # English documentation
│   ├── es/            # Spanish documentation
│   └── zh/            # Chinese documentation
├── tests/             # Test suites
├── config/            # Shared configuration files
└── README.md          # This file
```

## Versions

### CLI Version (`cli/`)
A traditional command-line interface using Bash scripts, perfect for:
- Server environments
- Terminal power users
- Automation scripts
- Remote administration

### GUI Version (`gui/`)
A modern graphical interface built with Python and NiceGUI, ideal for:
- Desktop users
- Visual feedback
- Real-time monitoring
- User-friendly controls

## Quick Start

### Prerequisites
- macOS 10.15 (Catalina) or later
- For GUI version: Python 3.7+ and pip

### CLI Version
```bash
cd cli
chmod +x src/script.sh
./src/script.sh
```

### GUI Version
```bash
cd gui
pip install -r requirements.txt
python src/python-app-nicegui.py
```

## Documentation

- [English Documentation](docs/en/README.md)
- [Documentación en Español](docs/es/README.md)
- [中文文档](docs/zh/README.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to either version of the project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Special thanks to all contributors who have helped shape both versions of macOS Optimizer.
