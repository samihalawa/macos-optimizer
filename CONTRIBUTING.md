# Contributing to macOS Optimizer

Thank you for your interest in contributing to macOS Optimizer! This document provides guidelines and instructions for contributing to both the CLI and GUI versions of the project.

## Project Structure

The project is organized as a monorepo with two main components:

```
macos-optimizer/
├── cli/                  # Command-line interface version
├── gui/                 # Graphical interface version
├── docs/               # Documentation
├── tests/             # Test suites
└── config/            # Shared configuration files
```

## Development Setup

1. Fork and clone the repository
2. Set up your development environment:
   ```bash
   # For CLI development
   cd cli
   chmod +x src/script.sh
   
   # For GUI development
   cd gui
   pip install -r requirements.txt
   ```

## Contributing Guidelines

### For Both Versions
- Follow the existing code style
- Add tests for new features
- Update documentation as needed
- Keep commits atomic and messages clear

### CLI Version
- Use shellcheck for bash script linting
- Follow POSIX compliance where possible
- Add error handling for all operations

### GUI Version
- Follow PEP 8 style guide
- Use type hints
- Keep the UI consistent with existing design

## Testing

```bash
# Run CLI tests
cd tests
./test_cli.sh

# Run GUI tests
python -m pytest tests/test_gui.py
```

## Documentation

- Update relevant documentation in the `docs/` directory
- Maintain documentation in all supported languages (en, es, zh)
- Follow the existing documentation style

## Pull Request Process

1. Create a feature branch
2. Make your changes
3. Run tests
4. Update documentation
5. Submit a pull request

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.

## Questions?

Feel free to open an issue for any questions about contributing. 