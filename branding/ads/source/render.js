// Renders the ad pages (ad1.html ...) to 1920x1080 PNGs with Playwright's Chromium.
//   cd branding/ads/source && node render.js ad1.html ad2.html ad3.html
// Edit the text/art in adN.html (shared drawing helpers are in art.js). Fonts: Luckiest Guy
// (Apache 2.0) and Fredoka (SIL OFL), both from Google Fonts.
const { chromium } = require("playwright");
const path = require("path");
(async () => {
  const files = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  page.on("console", (m) => console.log("console:", m.text()));
  page.on("pageerror", (e) => console.log("PAGE ERROR:", e.message));
  for (const f of files) {
    await page.goto("file://" + path.resolve(f));
    await page.evaluate(() => document.fonts.ready);
    const fonts = await page.evaluate(() => [...document.fonts].map((x) => x.family + ":" + x.status));
    console.log(f, fonts.join(", "));
    await page.waitForTimeout(200);
    const out = f.replace(/\.html$/, ".png");
    await page.screenshot({ path: out });
    console.log("wrote", out);
  }
  await browser.close();
})();
