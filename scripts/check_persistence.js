// Bukti state shared: 2 proses Node terpisah (= 2 Lambda) baca/tulis state yang sama.
const { spawn } = require('child_process');
const http = require('http');

const APP = require('path').join(__dirname, '..', 'api', 'index.js');

async function req(port, method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const r = http.request(
      { host: '127.0.0.1', port, path, method, headers: data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {} },
      (res) => {
        let buf = '';
        res.on('data', (c) => (buf += c));
        res.on('end', () => resolve(JSON.parse(buf)));
      },
    );
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

function start(port) {
  const code = `const app=require(${JSON.stringify(APP)});require('http').createServer(app).listen(${port},()=>console.log('up ${port}'))`;
  return spawn(process.execPath, ['-e', code], { env: process.env, stdio: 'inherit' });
}

async function waitUp(port, tries = 40) {
  for (let i = 0; i < tries; i++) {
    try { return await req(port, 'GET', '/api/health'); }
    catch (_) { await new Promise((r) => setTimeout(r, 250)); }
  }
  throw new Error('port ' + port + ' never came up');
}

(async () => {
  const a = start(4001);
  const b = start(4002);
  try {
    await waitUp(4001); await waitUp(4002);

    const ia = await req(4001, 'GET', '/api/debug/instance');
    const ib = await req(4002, 'GET', '/api/debug/instance');
    console.log('instance A:', ia.instanceId.slice(0, 8), 'pid', ia.pid, 'persist', ia.persistence);
    console.log('instance B:', ib.instanceId.slice(0, 8), 'pid', ib.pid, 'persist', ib.persistence);
    console.log('instanceId berbeda?', ia.instanceId !== ib.instanceId);

    const seq = Math.floor(Date.now() / 1000) % 100000;
    const write = await req(4001, 'POST', '/api/heartbeat', {
      userId: 605634, name: 'nggaingris', instanceId: 'inst-A', seq,
      world: 'FARTLE', gems: 777000, dl: 4, bgl: 1, wl: 12, ping: 21,
    });
    console.log('POST ke A (seq ' + seq + '):', JSON.stringify(write));

    const stale = await req(4001, 'POST', '/api/heartbeat', {
      userId: 605634, name: 'nggaingris', instanceId: 'inst-A', seq: seq - 1, gems: 777000,
    });
    console.log('POST seq mundur:', JSON.stringify(stale));

    await new Promise((r) => setTimeout(r, 800));
    const fleetB = await req(4002, 'GET', '/api/fleet');
    console.log('GET /api/fleet dari B → bots:', fleetB.bots.length);
    for (const bot of fleetB.bots) {
      console.log('  ', bot.name, 'uid=' + bot.userId, 'gems=' + bot.gems, 'wlInv=' + bot.wlInv,
        'invWL=' + bot.inventoryWl, 'wealthWL=' + bot.wealthWl, 'legacy=' + bot.isLegacy);
    }
    console.log('CROSS-INSTANCE PERSISTENCE:', fleetB.bots.some((x) => String(x.userId) === '605634') ? 'PASS' : 'FAIL');
  } finally {
    a.kill('SIGKILL');
    b.kill('SIGKILL');
  }
})();
