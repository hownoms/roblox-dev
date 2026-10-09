const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require(process.argv[2]);
(async () => {
  const book = path.resolve(__dirname, '../docs/game-bible');
  const browser = await chromium.launch({ executablePath: process.argv[3], headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    await page.goto(pathToFileURL(path.join(book, 'GAME_BIBLE.html')).href);
    await page.screenshot({ path: path.join(book, 'preview-desktop.png') });
    await page.evaluate(() => {
      document.documentElement.style.scrollBehavior = 'auto';
      document.getElementById('03-future-content-catalog').scrollIntoView();
    });
    await page.screenshot({ path: path.join(book, 'preview-catalog.png') });
    const sections = await page.locator('section').count();
    const tables = await page.locator('table').count();
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(pathToFileURL(path.join(book, 'GAME_BIBLE.html')).href);
    await page.locator('section').first().scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(book, 'preview-mobile.png') });
    const widths = await page.evaluate(() => ({ width: document.documentElement.clientWidth, scroll: document.documentElement.scrollWidth }));
    if (sections !== 8 || widths.scroll > widths.width) throw new Error(JSON.stringify({ sections, tables, widths }));
    console.log(JSON.stringify({ sections, tables, mobile: widths, screenshots: 3 }));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
