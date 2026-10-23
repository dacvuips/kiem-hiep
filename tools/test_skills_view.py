import time, sys
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        headless=True
    )
    context = browser.new_context(viewport={'width': 1280, 'height': 720})
    page = context.new_page()

    print('1. Navigating to http://localhost:8088/index.html...')
    page.goto('http://localhost:8088/index.html')
    
    print('Waiting for game to load (#status hidden)...')
    page.wait_for_selector('#status', state='hidden', timeout=60000)
    print('Game loaded!')
    time.sleep(2)

    canvas = page.locator('#canvas')

    # Policy
    print('Accepting policy...')
    canvas.click(position={'x': 320, 'y': 520})
    time.sleep(0.3)
    canvas.click(position={'x': 675, 'y': 602})
    time.sleep(1.5)

    # Login
    print('Logging in...')
    canvas.click(position={'x': 840, 'y': 330})
    time.sleep(0.2)
    page.keyboard.type('tester01')
    time.sleep(0.2)
    canvas.click(position={'x': 840, 'y': 386})
    time.sleep(0.2)
    page.keyboard.type('Password123')
    time.sleep(0.2)
    canvas.click(position={'x': 840, 'y': 486})
    time.sleep(4)

    # Server Select -> Enter
    print('Server select enter...')
    canvas.click(position={'x': 640, 'y': 514})
    time.sleep(4)

    # In CharacterRoster: click EnterArea ("VÀO GAME") at (208, 652)
    print('Character roster enter...')
    canvas.click(position={'x': 208, 'y': 652})
    time.sleep(5)

    page.screenshot(path='hub_main.png')
    print('Captured hub_main.png!')

    # Click NavButton2 (Kỹ Năng) at (1161, 292)
    print('Clicking Ky Nang tab at (1161, 292)...')
    canvas.click(position={'x': 1161, 'y': 292})
    time.sleep(3)

    page.screenshot(path='hub_skills_view.png')
    print('Captured hub_skills_view.png!')

    browser.close()
    print('Done!')
