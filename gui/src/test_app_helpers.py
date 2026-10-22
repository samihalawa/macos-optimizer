"""Lightweight tests that do not start NiceGUI."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

# Load settings
from config.settings import VERSION, OPTIMIZATION_CATEGORIES  # noqa: E402


def test_version_semver_shape():
    parts = VERSION.split(".")
    assert len(parts) >= 2
    assert all(p.isdigit() for p in parts)


def test_categories_complete():
    expected = {"performance", "graphics", "display", "storage", "network"}
    assert expected == set(OPTIMIZATION_CATEGORIES)


def test_app_module_compiles():
    path = Path(__file__).with_name("app.py")
    spec = importlib.util.spec_from_file_location("macos_optimizer_app", path)
    assert spec and spec.loader
    # Syntax / import surface without calling ui.run
    source = path.read_text(encoding="utf-8")
    compile(source, str(path), "exec")


if __name__ == "__main__":
    test_version_semver_shape()
    test_categories_complete()
    test_app_module_compiles()
    print("All helper tests passed")
