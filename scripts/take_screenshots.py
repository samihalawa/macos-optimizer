import asyncio
from playwright.async_api import async_playwright
import os
from pathlib import Path

async def take_cli_screenshot():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context()
        page = await context.new_page()
        
        # Launch terminal with custom size for better menu visibility
        await page.evaluate('''() => {
            const terminal = window.open('', '', 'width=800,height=600');
            terminal.document.write(`
                <div style="background: black; color: white; font-family: monospace; padding: 20px; height: 100%;">
                    <pre>
macOS Optimizer CLI v1.0
------------------------
Please select an option:

1. System Optimization
   - Disable unnecessary services
   - Clean system caches
   - Optimize system settings

2. Network Optimization
   - Configure DNS settings
   - Optimize TCP parameters
   - Enhance Wi-Fi performance

3. Power Management
   - Battery optimization
   - Energy saving settings
   - Performance profiles

4. Performance Boost
   - Memory management
   - Disk optimization
   - App launch speed

5. View Current Status
6. Help
7. Exit

Enter your choice (1-7): _
                    </pre>
                </div>
            `);
        }''')
        
        # Create images directory if it doesn't exist
        Path('docs/images').mkdir(parents=True, exist_ok=True)
        
        # Take screenshot with padding and proper sizing
        await page.screenshot(path='docs/images/cli-screenshot.png', full_page=True)
        await browser.close()

async def take_gui_screenshot():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        context = await browser.new_context(viewport={'width': 1200, 'height': 800})
        page = await context.new_page()
        
        # Wait for the GUI to load and be fully rendered
        await page.goto('http://localhost:8080')
        await page.wait_for_load_state('networkidle')
        await page.wait_for_timeout(2000)  # Wait for animations
        
        # Create images directory if it doesn't exist
        Path('docs/images').mkdir(parents=True, exist_ok=True)
        
        # Take screenshot
        await page.screenshot(path='docs/images/gui-screenshot.png')
        await browser.close()

async def main():
    # Take CLI screenshot first
    print("Taking CLI screenshot...")
    await take_cli_screenshot()
    print("CLI screenshot saved to docs/images/cli-screenshot.png")
    
    # Then take GUI screenshot
    print("Taking GUI screenshot...")
    await take_gui_screenshot()
    print("GUI screenshot saved to docs/images/gui-screenshot.png")

if __name__ == "__main__":
    asyncio.run(main()) 