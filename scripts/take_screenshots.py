#!/usr/bin/env python3
"""Optional helper to capture GUI screenshots when the app is running."""

from __future__ import annotations

import argparse
from pathlib import Path

def main() -> None:
    parser = argparse.ArgumentParser(description="Capture GUI screenshot via Playwright")
    parser.add_argument("--url", default="http://127.0.0.1:8080")
    parser.add_argument("--out", default="docs/images/gui-screenshot.png")
    args = parser.parse_args()

    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:  # pragma: no cover
        raise SystemExit("Install playwright first: pip install playwright && playwright install chromium") from exc

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1280, "height": 800})
        page.goto(args.url, wait_until="networkidle")
        page.screenshot(path=str(out), full_page=True)
        browser.close()
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
