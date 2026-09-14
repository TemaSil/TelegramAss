// Captures UI screenshots of the web preview build for the README.
//
//   flutter build web --release --dart-define=DEMO_AUTOLOGIN=true
//   (cd build/web && python3 -m http.server 8791) &
//   node shots.js
//
// The web build renders glass through the package's lightweight fallback —
// Impeller, and therefore the real refraction, is Android/iOS only.
const { chromium } = require('playwright');

const OUT = 'docs/screenshots';
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function capture(browser, scheme, suffix) {
  const page = await browser.newPage({
    viewport: { width: 393, height: 852 },
    deviceScaleFactor: 2,
    colorScheme: scheme,
  });
  const shot = async (name) => {
    await page.screenshot({ path: `${OUT}/${name}-${suffix}.png` });
    console.log('shot', name, suffix);
  };

  await page.goto('http://127.0.0.1:8791/index.html');
  await wait(15000);
  await shot('01-chats');

  await page.mouse.move(196, 500);
  await page.mouse.wheel(0, 300);
  await wait(3000);
  await shot('02-chats-scrolled');

  // Tabs first: no back navigation needed, so nothing can get stuck.
  await page.mouse.click(154, 802);
  await wait(6000);
  await shot('03-contacts');

  await page.mouse.click(240, 802);
  await wait(6000);
  await shot('04-calls');

  await page.mouse.click(326, 802);
  await wait(6000);
  await shot('05-settings');

  await page.mouse.move(196, 500);
  await page.mouse.wheel(0, 520);
  await wait(3000);
  await shot('06-settings-scrolled');

  // Back to the chat list, then into a conversation.
  await page.mouse.click(66, 802);
  await wait(6000);
  await page.mouse.click(196, 320);
  await wait(6000);
  await shot('07-chat');

  await page.mouse.click(196, 818);
  await wait(1500);
  await page.keyboard.type('Liquid glass, on Android', { delay: 55 });
  await wait(2500);
  await shot('08-composer');

  await page.keyboard.press('Enter');
  await wait(6000);
  await shot('09-sent');

  await page.close();
}

(async () => {
  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
  });
  await capture(browser, 'dark', 'dark');
  await capture(browser, 'light', 'light');
  await browser.close();
})().catch((e) => {
  console.error('FAILED', e.message);
  process.exit(1);
});
