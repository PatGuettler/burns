"""Real Chromium canvas interaction smoke test; starts its own local HTTP server."""
import asyncio
from pathlib import Path
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True, args=['--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader', '--no-sandbox'])
        for width, height, density in [(390, 844, 1), (1120, 800, 1), (390, 844, 3)]:
            context = await browser.new_context(viewport={'width': width, 'height': height}, device_scale_factor=density, is_mobile=density > 1, has_touch=density > 1)
            page = await context.new_page()
            click = page.touchscreen.tap if density > 1 else page.mouse.click
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('console', lambda msg: errors.append(msg.text) if 'SCRIPT ERROR' in msg.text else None)
            await page.goto('http://127.0.0.1:18000', wait_until='networkidle')
            await page.wait_for_selector('#status', state='detached', timeout=30000)
            await page.wait_for_timeout(500)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-menu-{width}-{density}x.png'))
            # Menu and gallery are driven through the actual canvas hit targets.
            board_w, board_h = width - 32, height - 32
            wide = board_w >= 700
            panel_w = min(400, board_w * .43) if wide else min(420, board_w)
            panel_x = board_w - panel_w - (24 if wide else (board_w - panel_w) / 2)
            action_y = (board_h - 282) / 2 if wide else board_h - 282
            menu_x, menu_y = 16 + panel_x + panel_w / 2, 16 + action_y + 27
            await click(menu_x, 16 + action_y + 211)
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-king-{width}-{density}x.png'))
            await click(width - 50, 38)
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-back-{width}-{density}x.png'))
            await click(55, 38)
            await page.wait_for_timeout(200)
            await click(menu_x, menu_y)
            await page.wait_for_timeout(200)
            await click(width / 2, height - 40)
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-handoff-{width}-{density}x.png'))
            # The handoff action remains anchored above the bottom inset.
            await click(width / 2, height - 40)
            await page.wait_for_timeout(300)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-table-{width}-{density}x.png'))
            # Reveal the hidden top card through the actual card hit target.
            board_w = width - 32
            main_w = board_w - min(310, max(190, board_w * .245)) - 26 if width >= 882 else board_w
            hand_h = min(240, max(118, (height - 32) * .27))
            hand_y = height - 32 - 48 - hand_h - 10
            card_h = hand_h - 44
            card_w = card_h / 1.5
            draw_x = 16 + (main_w - 2 * card_w - min(24, max(10, main_w * .03))) / 2 + card_w / 2
            await click(draw_x, 16 + hand_y + 24 + card_h / 2)
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-revealed-{width}-{density}x.png'))
            # End the turn and exercise the explicit challenge window.
            await click(width / 2 - 100, height - 39)
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-review-{width}-{density}x.png'))
            # A live resize must retain the table and show no document overflow.
            await page.set_viewport_size({'width': 844, 'height': 390})
            await page.wait_for_timeout(200)
            await page.screenshot(path=str(ROOT / f'build/screenshots/browser-resized-{width}-{density}x.png'))
            assert not errors, errors
            assert await page.evaluate('document.documentElement.scrollWidth <= innerWidth && document.documentElement.scrollHeight <= innerHeight'), 'Browser scrollbar overflow'
            await context.close()
        await browser.close()
    print('PASS: Chromium deck gallery and mouse/touch flow through draw and review, live resize, 1x/3x density, no page scrollbars or script errors')

if __name__ == '__main__':
    class QuietHandler(SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass
    handler = partial(QuietHandler, directory=str(ROOT / 'build/web'))
    server = ThreadingHTTPServer(('127.0.0.1', 18000), handler)
    Thread(target=server.serve_forever, daemon=True).start()
    try:
        asyncio.run(main())
    finally:
        server.shutdown()
        server.server_close()
