import sys
import time
from PIL import Image
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
    
    print('Waiting for canvas to load and status to hide...')
    page.wait_for_selector('#canvas', timeout=120000)
    page.wait_for_selector('#status', state='hidden', timeout=120000)
    time.sleep(3)

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

    # Click "Vuot Ai" at (175, 45)
    print('7. Clicking Vuot Ai (175, 45)...')
    canvas.click(position={'x': 175, 'y': 45})
    time.sleep(2)

    # Click "Vao" button of Giang Tan Thon (965, 245)
    print('8. Clicking Vao Giang Tan Thon (965, 245)...')
    canvas.click(position={'x': 965, 'y': 245})
    time.sleep(1.5)

    # If confirm popup shows up (567, 440)
    print('9. Clicking Dong Y if confirm popup exists (567, 440)...')
    canvas.click(position={'x': 567, 'y': 440})
    time.sleep(6)

    # Capture in-game battle world!
    page.screenshot(path='battle_scene.png')
    print('Captured battle_scene.png!')

    # Crop Chat box and Skill bar
    im = Image.open('battle_scene.png')
    
    # Bottom left: Chat (x: 0..450, y: 500..720)
    chat_crop = im.crop((0, 500, 450, 720))
    chat_crop.save('crop_chat_final.png')
    
    # Bottom right: Skills (x: 800..1280, y: 450..720)
    skills_crop = im.crop((800, 450, 1280, 720))
    skills_crop.save('crop_skills_final.png')

    browser.close()
    print('Done all!')
