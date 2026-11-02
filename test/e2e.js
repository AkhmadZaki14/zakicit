'use strict';

/**
 * E2E test: membuktikan bug double-online hilang.
 * Jalankan: npm test   (server dinaikkan otomatis di port acak)
 */

process.env.API_KEY = 'test-key';
process.env.DATABASE_URL = `file:${require('path').join(__dirname, 'test.db')}`;
process.env.TTL_ONLINE_MS = '8000';
process.env.TTL_STALE_MS = '20000';
process.env.DISCORD_WEBHOOK_URL = '';
process.env.PORT = '0';

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const DB = path.join(__dirname, 'test.db');
for (const f of [DB, `${DB}-wal`, `${DB}-shm`]) {
  if (fs.existsSync(f)) fs.unlinkSync(f);
}

const { start, stop } = require('../server/index');

let base;
const KEY = 'test-key';

async function hb(payload) {
  const res = await fetch(`${base}/api/heartbeat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-API-Key': KEY },
    body: JSON.stringify(payload),
  });
  return { status: res.status, body: await res.json() };
}

async function api(pathname) {
  const res = await fetch(`${base}${pathname}`, { headers: { 'X-API-Key': KEY } });
  return { status: res.status, body: await res.json() };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function payload(over = {}) {
  return {
    userId: 605634,
    name: 'nggaingris',
    instanceId: 'aaaaaaaa-1111-4111-8111-111111111111',
    seq: 1,
    world: 'FREEBFG',
    activity: 'Farming',
    level: 0,
    gems: 1000000,
    dl: 10,
    bgl: 1,
    backpack: { used: 0, total: 0 },
    pingMs: 120,
    uptimeSec: 60,
    disconnects: 0,
    ...over,
  };
}

const results = [];
function check(name, fn) {
  return (async () => {
    try {
      await fn();
      results.push({ name, ok: true });
      console.log(`  PASS  ${name}`);
    } catch (err) {
      results.push({ name, ok: false, err: err.message });
      console.log(`  FAIL  ${name}\n        ${err.message}`);
    }
  })();
}

async function main() {
  const server = await start();
  base = `http://127.0.0.1:${server.address().port}`;
  console.log(`\nTest server: ${base}\n`);

  /* ---------------- 1. bot baru ---------------- */
  await check('heartbeat pertama mendaftarkan worker', async () => {
    const r = await hb(payload({ seq: 1 }));
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.accepted, true);
  });

  /* ---------------- 2. hysteresis ---------------- */
  await check('butuh 2 heartbeat berurutan untuk ONLINE', async () => {
    const r2 = await hb(payload({ seq: 2 }));
    assert.strictEqual(r2.body.state, 'ONLINE', `state=${r2.body.state}`);
  });

  /* ---------------- 3. hanya 1 entri ---------------- */
  await check('tidak ada entri ganda setelah banyak heartbeat', async () => {
    for (let i = 3; i <= 8; i += 1) await hb(payload({ seq: i }));
    const dbg = await api('/api/debug/workers');
    assert.strictEqual(dbg.body.rawEntries, 1, `rawEntries=${dbg.body.rawEntries}`);
    assert.strictEqual(dbg.body.uniqueWorkers, 1);
  });

  /* ---------------- 4. seq out-of-order ---------------- */
  await check('heartbeat seq mundur ditolak dan dihitung', async () => {
    const before = (await api('/api/debug/workers')).body.totalRejectedHeartbeats;
    const r = await hb(payload({ seq: 3 }));
    assert.strictEqual(r.body.accepted, false);
    assert.strictEqual(r.body.reason, 'OUT_OF_ORDER');
    const after = (await api('/api/debug/workers')).body.totalRejectedHeartbeats;
    assert.strictEqual(after, before + 1);
  });

  /* ---------------- 5. restart: instanceId baru ---------------- */
  await check('instanceId baru = restart, bukan entri baru', async () => {
    const before = (await api('/api/fleet')).body;
    const botsBefore = before.bots.length;
    const r = await hb(
      payload({ instanceId: 'bbbbbbbb-2222-4222-8222-222222222222', seq: 1 }),
    );
    assert.strictEqual(r.body.accepted, true);
    assert.strictEqual(r.body.restarted, true);

    const after = (await api('/api/fleet?fresh=1')).body;
    assert.strictEqual(after.bots.length, botsBefore, 'jumlah bot berubah');
    const bot = after.bots[0];
    assert.strictEqual(bot.restartCount, 1);

    const ev = await api('/api/events?type=restarted');
    assert.ok(ev.body.events.length >= 1, 'event restarted tidak ada');
  });

  /* ---------------- 6. dua instance bersamaan = duplicate ---------------- */
  await check('dua instance aktif bersamaan ditandai DUPLICATE', async () => {
    // instance kedua balapan dengan instance pertama
    await hb(payload({ instanceId: 'cccccccc-3333-4333-8333-333333333333', seq: 1 }));
    const r = await hb(payload({ instanceId: 'dddddddd-4444-4444-8444-444444444444', seq: 1 }));
    assert.strictEqual(r.body.duplicate, true, 'duplicate tidak terdeteksi');

    const fleet = (await api('/api/fleet?fresh=1')).body;
    assert.strictEqual(fleet.bots.length, 1, 'worker jadi dobel');
    assert.strictEqual(fleet.bots[0].duplicate, true);
    assert.strictEqual(fleet.summary.duplicates, 1);
  });

  /* ---------------- 7. TTL: STALE lalu OFFLINE ---------------- */
  await check('berhenti heartbeat -> STALE lalu OFFLINE (tanpa flapping)', async () => {
    // pastikan ONLINE dulu
    await hb(payload({ instanceId: 'eeeeeeee-5555-4555-8555-555555555555', seq: 1 }));
    await hb(payload({ instanceId: 'eeeeeeee-5555-4555-8555-555555555555', seq: 2 }));
    let f = (await api('/api/fleet?fresh=1')).body;
    assert.strictEqual(f.bots[0].state, 'ONLINE');

    console.log('        menunggu 9s untuk STALE...');
    await sleep(9000);
    f = (await api('/api/fleet?fresh=1')).body;
    assert.strictEqual(f.bots[0].state, 'STALE', `state=${f.bots[0].state}`);

    console.log('        menunggu 12s lagi untuk OFFLINE...');
    await sleep(12000);
    f = (await api('/api/fleet?fresh=1')).body;
    assert.strictEqual(f.bots[0].state, 'OFFLINE', `state=${f.bots[0].state}`);
  });

  /* ---------------- 8. tidak ada flapping ---------------- */
  await check('status tidak flapping: OFFLINE tetap OFFLINE', async () => {
    for (let i = 0; i < 4; i += 1) {
      await sleep(500);
      const f = (await api('/api/fleet?fresh=1')).body;
      assert.strictEqual(f.bots[0].state, 'OFFLINE', 'status berubah-ubah');
    }
  });

  /* ---------------- 9. recovery ---------------- */
  await check('heartbeat setelah OFFLINE memulihkan ke ONLINE', async () => {
    await hb(payload({ instanceId: 'eeeeeeee-5555-4555-8555-555555555555', seq: 10 }));
    const r = await hb(payload({ instanceId: 'eeeeeeee-5555-4555-8555-555555555555', seq: 11 }));
    assert.strictEqual(r.body.state, 'ONLINE', `state=${r.body.state}`);
  });

  /* ---------------- 10. validasi payload ---------------- */
  await check('payload invalid ditolak 400', async () => {
    const r = await hb({ userId: 'x', name: '' });
    assert.strictEqual(r.status, 400);
  });

  /* ---------------- 11. auth ---------------- */
  await check('tanpa API key -> 401', async () => {
    const res = await fetch(`${base}/api/fleet`);
    assert.strictEqual(res.status, 401);
  });

  /* ---------------- 12. multi-bot scalable ---------------- */
  await check('50 bot unik -> 50 worker, tanpa duplikasi', async () => {
    for (let i = 0; i < 50; i += 1) {
      const uid = 900000 + i;
      for (let s = 1; s <= 2; s += 1) {
        await hb(
          payload({
            userId: uid,
            name: `bot${i}`,
            instanceId: `inst-${uid}-aaaaaaaaaaaa`,
            seq: s,
            gems: 1000 * i,
          }),
        );
      }
    }
    const f = (await api('/api/fleet?fresh=1')).body;
    assert.strictEqual(f.bots.length, 51, `bots=${f.bots.length}`);
    const ids = new Set(f.bots.map((b) => b.userId));
    assert.strictEqual(ids.size, 51, 'ada userID ganda');
  });

  /* ---------------- 13. settings ---------------- */
  await check('settings tersimpan dan mengubah konversi', async () => {
    const r = await fetch(`${base}/api/settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'X-API-Key': KEY },
      body: JSON.stringify({ gemsPerWl: 2200, wlPerDl: 50 }),
    });
    assert.strictEqual(r.status, 200);
    const s = await r.json();
    assert.strictEqual(s.gemsPerWl, 2200);
    assert.strictEqual(s.wlPerDl, 50);
  });

  /* ---------------- 14. history ---------------- */
  await check('history mengembalikan time-series', async () => {
    const h = await api('/api/history?bot=605634&range=1h');
    assert.strictEqual(h.status, 200);
    assert.ok(Array.isArray(h.body.points));
    assert.ok(h.body.points.length >= 1, 'tidak ada titik data');
  });

  /* ---------------- 15. LTTB downsample ---------------- */
  await check('LTTB menurunkan jumlah titik tanpa error', async () => {
    const { lttb } = require('../server/services/history');
    const data = Array.from({ length: 1000 }, (_, i) => ({ t: i, v: Math.sin(i / 20) * 100 }));
    const out = lttb(data, 100);
    assert.strictEqual(out.length, 100);
    assert.strictEqual(out[0].t, 0);
    assert.strictEqual(out[out.length - 1].t, 999);
  });

  /* ---------------- 16. quiet hours ---------------- */
  await check('quiet hours menghitung benar', async () => {
    const { inQuietHours } = require('../server/services/alerts');
    const s = { quietHours: { enabled: true, start: '23:00', end: '07:00', tzOffsetMinutes: 420 } };
    const at = (iso) => inQuietHours(s, new Date(iso));
    assert.strictEqual(at('2026-10-20T16:00:00Z'), true, '02:00 WIB harusnya quiet');
    assert.strictEqual(at('2026-10-20T05:00:00Z'), false, '12:00 WIB harusnya tidak quiet');
  });

  /* ---------------- summary ---------------- */
  await stop();
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} test lulus`);
  if (failed.length) {
    console.log('\nGagal:');
    for (const f of failed) console.log(` - ${f.name}: ${f.err}`);
    process.exit(1);
  }
  console.log('\nSemua test lulus.\n');
  process.exit(0);
}

main().catch(async (err) => {
  console.error('FATAL', err);
  await stop().catch(() => {});
  process.exit(1);
});
