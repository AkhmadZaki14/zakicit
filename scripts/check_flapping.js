// Uji flapping status: kirim heartbeat tiap 10s selama ~90s, poll fleet tiap 5s.
const BASE = 'https://gt-pi-ten.vercel.app';
const UID = '999777';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const states = [];
  const t0 = Date.now();
  let seq = 0;
  let gems = 100000;

  const hb = setInterval(async () => {
    seq += 1;
    gems += 2500;
    try {
      const r = await fetch(BASE + '/api/heartbeat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: UID, name: 'flaptest', instanceId: 'flap-1', seq, gems, wl: 2 }),
      });
      const j = await r.json();
      if (j.ignored) console.log('  heartbeat ignored:', j.reason);
    } catch (e) { console.log('  hb err', e.message); }
  }, 10000);

  const poll = setInterval(async () => {
    try {
      const r = await fetch(BASE + '/api/fleet');
      const j = await r.json();
      const b = (j.bots || []).find((x) => String(x.userId) === UID);
      const t = ((Date.now() - t0) / 1000).toFixed(0).padStart(3);
      states.push(b ? b.state : 'MISSING');
      console.log(`${t}s state=${b ? b.state : 'MISSING'} rate/h=${b ? b.ratePerHour : '-'} stuck=${b ? b.stuck : '-'}`);
    } catch (e) { console.log('  poll err', e.message); }
  }, 5000);

  await sleep(95000);
  clearInterval(hb); clearInterval(poll);

  const online = states.filter((s) => s === 'ONLINE').length;
  const flips = states.filter((s, i) => i > 0 && s !== states[i - 1]).length;
  console.log(`\nRESULT: ${online}/${states.length} sampel ONLINE, ${flips} transisi`);
  console.log('urutan:', states.join(' → '));
  console.log(flips === 0 && online === states.length ? 'PASS — tidak flapping' : 'PERIKSA — masih ada transisi');

  // bersihkan
  await fetch(BASE + '/api/workers/' + UID, { method: 'DELETE' });
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
