// Screenshots for autonomous-build-loop UI checks. Resolves Playwright from the project itself.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';

const require = createRequire(path.join(process.cwd(), 'package.json'));
let chromium = null;
for (const name of ['playwright', '@playwright/test', 'playwright-core']) {
  try { chromium = require(name).chromium; if (chromium) break; } catch { /* try next */ }
}
if (!chromium) {
  console.error('ui-snap: Playwright not found in this project. Install: npm i -D @playwright/test && npx playwright install chromium');
  process.exit(3);
}

const [base, outDir, viewports, ...routes] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });
const storageState = process.env.UI_STORAGE_STATE && fs.existsSync(process.env.UI_STORAGE_STATE)
  ? process.env.UI_STORAGE_STATE : undefined;

let failures = 0;
const browser = await chromium.launch();
try {
  for (const vp of viewports.split(/\s+/).filter(Boolean)) {
    const [width, height] = vp.split('x').map(Number);
    const context = await browser.newContext({ viewport: { width, height }, reducedMotion: 'reduce', storageState });
    const page = await context.newPage();
    const consoleErrors = [];
    page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
    for (const route of routes) {
      const url = new URL(route, base).toString();
      const slug = route.replace(/^\/+/, '').replace(/[^a-zA-Z0-9]+/g, '-').replace(/-+$/, '') || 'root';
      const file = path.join(outDir, `${slug}-${width}x${height}.png`);
      consoleErrors.length = 0;
      try {
        const res = await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
        await page.waitForTimeout(400);
        await page.screenshot({ path: file, fullPage: true });
        const finalUrl = page.url();
        const note = [
          res && !res.ok() ? `HTTP ${res.status()}` : '',
          finalUrl !== url ? `redirected to ${finalUrl}` : '',
          consoleErrors.length ? `${consoleErrors.length} console error(s): ${consoleErrors[0].slice(0, 160)}` : '',
        ].filter(Boolean).join('; ');
        console.log(note ? `${file}  (${note})` : file);
      } catch (err) {
        failures++;
        console.error(`ui-snap: ${url} at ${width}x${height}: ${String(err.message).split('\n')[0]}`);
      }
    }
    await context.close();
  }
} finally {
  await browser.close();
}
process.exit(failures ? 2 : 0);
