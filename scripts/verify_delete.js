const p = require('puppeteer-core');
(async () => {
  const b = await p.launch({
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: 'new',
    args: ['--no-sandbox'],
  });
  const pg = await b.newPage();
  const errs = [];
  pg.on('pageerror', (e) => errs.push(e.message));
  await pg.goto('https://gt-pi-ten.vercel.app', { waitUntil: 'networkidle2', timeout: 60000 });
  await new Promise((r) => setTimeout(r, 4000));

  await pg.evaluate(() => { const el = document.querySelector('.bot-item'); if (el) el.click(); });
  await new Promise((r) => setTimeout(r, 1500));

  const del = await pg.evaluate(() => {
    const btn = document.getElementById('dp-del');
    return btn ? { text: btn.textContent.trim(), visible: !!btn.offsetParent, cls: btn.className } : null;
  });
  console.log('DELETE BTN:', JSON.stringify(del));
  console.log('DRAWER OPEN:', await pg.evaluate(() => document.getElementById('drawer').classList.contains('on')));
  console.log('BOT ITEMS:', await pg.evaluate(() => document.querySelectorAll('.bot-item').length));
  console.log('KPI FLEET:', await pg.evaluate(() => (document.querySelector('#kpis .kpi') || {}).innerText || ''));
  console.log('ERR:', errs.length ? errs.join(' | ') : 'none');
  await b.close();
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
