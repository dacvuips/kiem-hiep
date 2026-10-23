import time
from playwright.sync_api import sync_playwright

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
    time.sleep(5)

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

    # Click "TẠO NHÂN VẬT" (center: x=496, y=652)
    print('6. Clicking CharacterRoster CreateArea (496, 652)...')
    canvas.click(position={'x': 496, 'y': 652})
    time.sleep(4)

    # In CharacterCreate:
    # Click NameInput at (615, 678)
    print('7. Clicking NameInput at (615, 678) and typing character name...')
    canvas.click(position={'x': 615, 'y': 678})
    time.sleep(0.3)
    page.keyboard.type('KiemHiep01')
    time.sleep(0.5)

    # Click EnterButton in CharacterCreate (x=975, y=678)
    print('8. Clicking EnterButton (975, 678) in CharacterCreate...')
    canvas.click(position={'x': 975, 'y': 678})
    time.sleep(5)
    page.screenshot(path='test_after_enter_create.png')

    # If it goes back to Roster or Hub:
    # If in Roster, click "VÀO GAME" (208, 652)
    print('9. Clicking Vào Game (208, 652)...')
    canvas.click(position={'x': 208, 'y': 652})
    time.sleep(6)

    # Now capture final in-game world HUD!
    page.screenshot(path='test_final_world_hud.png')
    print('Captured test_final_world_hud.png!')

    with open('browser_hud_logs.txt', 'w', encoding='utf-8') as f:
        for l in all_logs:
            f.write(l + '\n')

    browser.close()
    print('Done!')
