
from playwright.sync_api import sync_playwright

def take_screenshot(url, output_path):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url)
        page.screenshot(path=output_path)
        browser.close()

take_screenshot("https://example.com", "example_screenshot.png")
