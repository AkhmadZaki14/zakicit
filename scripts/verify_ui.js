// Verifikasi render dashboard production pakai Chrome headless (puppeteer-core).
const puppeteer = require('puppeteer-core');

const CHROME =
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const URL = process.argv[2] || 'https://gt-pi-ten.vercel.app';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 1000 });

  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push('console: ' + m.text());
  });

  await page.goto(URL, { waitUntil: 'networkidle2', timeout: 60000 });
  await new Promise((r) => setTimeout(r, 4000));

  const info = await page.evaluate(() => {
    const txt = document.body.innerText;
    const kpis = [...document.querySelectorAll('#kpis > *')].map((el) =>
      el.innerText.replace(/\n+/g, ' | ')
    );
    const rows = [...document.querySelectorAll('#worker-body tr')].map((tr) =>
      [...tr.children].map((td) => td.innerText.trim()).join(' | ')
    );
    return {
      title: document.title,
      botCount: (txt.match(/Total Bot/gi) || []).length,
      kpis,
      rows,
      hasDelta: txt.includes('Per menit (delta)'),
      hasLegacyBadge: txt.toLowerCase().includes('legacy'),
      hasDash: txt.includes('—'),
      nav: [...document.querySelectorAll('nav a, .nav a, aside a')].map((a) => a.innerText.trim()),
      bodyHead: txt.slice(0, 700),
    };
  });

  console.log('TITLE:', info.title);
  console.log('KPIS:', JSON.stringify(info.kpis, null, 1));
  console.log('ROWS:', JSON.stringify(info.rows, null, 1));
  console.log('NAV:', info.nav.join(' / '));
  console.log('has "Per menit (delta)":', info.hasDelta);
  console.log('has legacy badge:', info.hasLegacyBadge);
  console.log('ERRORS:', errors.length ? errors.join('\n  ') : 'none');
  console.log('BODY HEAD:\n' + info.bodyHead);

  await page.screenshot({ path: '/tmp/gt_dash.png', fullPage: false });
  console.log('screenshot: /tmp/gt_dash.png');

  await browser.close();
})().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
