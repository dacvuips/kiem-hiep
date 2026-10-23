import sys
import time
from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(encoding='utf-8')

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        headless=True
    )
    context = browser.new_context(viewport={'width': 1280, 'height': 720})
    page = context.new_page()

    all_logs = []
    page.on('console', lambda msg: all_logs.append(f'[{msg.type}] {msg.text}'))

    print('1. Navigating to http://localhost:8088/index.html...')
    page.goto('http://localhost:8088/index.html')
    time.sleep(4)

    canvas = page.locator('#canvas')

    # Policy agreement
    print('2. Accepting policy...')
    canvas.click(position={'x': 320, 'y': 520})
    time.sleep(0.3)
    canvas.click(position={'x': 675, 'y': 602})
    time.sleep(1.5)

    # Login
    print('3. Entering credentials...')
    canvas.click(position={'x': 840, 'y': 330})
    time.sleep(0.2)
    page.keyboard.type('tester01')
    time.sleep(0.2)

    canvas.click(position={'x': 840, 'y': 386})
    time.sleep(0.2)
    page.keyboard.type('Password123')
    time.sleep(0.2)

    print('4. Submitting login...')
    canvas.click(position={'x': 840, 'y': 486})
    time.sleep(4)

    # Click Server Select EnterButton (640, 514)
    print('5. Clicking Server Select EnterButton (640, 514)...')
    canvas.click(position={'x': 640, 'y': 514})
    time.sleep(4)

    # In Character Roster:
    # Click "VAO GAME" (208, 652)
    print('6. Clicking Vao Game (208, 652)...')
    canvas.click(position={'x': 208, 'y': 652})
    time.sleep(5)

    # Check if Sect dialog is open: click "Gia nhap Cai Bang" at (195, 580)
    print('7. Clicking Gia nhap Cai Bang (195, 580)...')
    canvas.click(position={'x': 195, 'y': 580})
    time.sleep(1)

    # Click Dong Y (450, 590)
    print('8. Clicking Dong Y (450, 590)...')
    canvas.click(position={'x': 450, 'y': 590})
    time.sleep(2)
    page.screenshot(path='hub_sect_confirmed.png')
    print('Captured hub_sect_confirmed.png')

    # Click "Vuot Ai" at (175, 45)
    print('9. Clicking Vuot Ai (175, 45)...')
    canvas.click(position={'x': 175, 'y': 45})
    time.sleep(2)
    page.screenshot(path='map_select_window.png')
    print('Captured map_select_window.png')

    browser.close()
    print('Done phase 2!')
