'use strict';

const db = require('../db');
const config = require('../config');
const log = require('../utils/log');

/**
 * STATE MACHINE WORKER
 * --------------------
 * Identitas   : user_id (PRIMARY KEY). Register ulang = UPDATE, bukan INSERT.
 * Deteksi     : instance_id (UUID per proses bot). instanceId baru = restart.
 * Ordering    : seq naik monoton. seq <= tersimpan = ditolak (out-of-order).
 * Waktu       : SATU sumber = Date.now() server. Timestamp bot diabaikan.
 * Status      : ONLINE (<8s), STALE (8-20s), OFFLINE (>20s), dihitung saat dibaca.
 * Hysteresis  : OFFLINE/STALE -> ONLINE butuh N heartbeat berurutan.
 */

const STATE = { ONLINE: 'ONLINE', STALE: 'STALE', OFFLINE: 'OFFLINE' };

/** Turunan waktu -> status. Dipakai juga oleh read path. */
function deriveState(lastSeen, now = Date.now()) {
  const age = now - lastSeen;
  if (age < config.ttlOnlineMs) return STATE.ONLINE;
  if (age < config.ttlStaleMs) return STATE.STALE;
  return STATE.OFFLINE;
}

function parseJson(text, fallback) {
  try {
    return JSON.parse(text);
  } catch {
    return fallback;
  }
}

async function recordEvent(userId, type, message, meta = {}, ts = Date.now()) {
  await db.run('INSERT INTO events(user_id, ts, type, message, meta) VALUES(?,?,?,?,?)', [
    userId,
    ts,
    type,
    message,
    JSON.stringify(meta),
  ]);
}

/**
 * Proses satu heartbeat.
 * @param {object} hb payload tervalidasi
 * @returns {Promise<{accepted:boolean, reason?:string, state:string, duplicate:boolean, restarted:boolean}>}
 */
async function processHeartbeat(hb) {
  const now = Date.now();
  const userId = hb.userId;

  const row = await db.get('SELECT * FROM workers WHERE user_id = ?', [userId]);

  // ---------- BOT BARU ----------
  if (!row) {
    await db.run(
      `INSERT INTO workers (
        user_id, name, world, activity, level, gems, dl, bgl,
        backpack_used, backpack_total, ping_ms, uptime_sec, disconnects,
        instance_id, seq, state, online_streak, first_seen, last_seen,
        last_state_change, session_started, today_day
      ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [
        userId, hb.name, hb.world, hb.activity, hb.level, hb.gems, hb.dl, hb.bgl,
        hb.backpack.used, hb.backpack.total, hb.pingMs, hb.uptimeSec, hb.disconnects,
        hb.instanceId, hb.seq,
        STATE.OFFLINE, // belum memenuhi hysteresis
        1,
        now, now, now, now,
        dayKey(now),
      ],
    );
    await recordEvent(userId, 'registered', `${hb.name} mendaftar dari world ${hb.world}`);
    log.ok('Worker baru terdaftar', { userId, name: hb.name, instanceId: hb.instanceId.slice(0, 8) });
    return { accepted: true, state: STATE.OFFLINE, duplicate: false, restarted: false, streak: 1 };
  }

  // ---------- IDENTITAS: RESTART vs DUPLIKAT ----------
  // Spek:
  //   - Instance yang terakhir mendaftar yang menang (row.instance_id = hb.instanceId).
  //   - Tiap instanceId dicatat timestamp-nya.
  //   - Jika ada >1 instanceId berbeda aktif dalam 10 detik terakhir -> DUPLICATE flag aktif.
  //   - instanceId berubah -> restartCount++.
  let restarted = false;
  let restartCount = row.restart_count;

  if (row.instance_id && row.instance_id !== hb.instanceId) {
    restarted = true;
    restartCount += 1;
    log.restart('Bot restart', {
      userId,
      name: hb.name,
      old: (row.instance_id || '').slice(0, 8),
      new: hb.instanceId.slice(0, 8),
      restartCount,
    });
    await recordEvent(userId, 'restarted', `Bot restart (total ${restartCount}x)`, {
      oldInstance: row.instance_id,
      newInstance: hb.instanceId,
    });
  }

  // Update daftar instance aktif dalam window
  let duplicateInstances = parseJson(row.duplicate_instances, []);
  duplicateInstances = duplicateInstances.filter((d) => now - d.seen < config.duplicateWindowMs);

  const existingIdx = duplicateInstances.findIndex((d) => d.instanceId === hb.instanceId);
  if (existingIdx >= 0) {
    duplicateInstances[existingIdx].seen = now;
  } else {
    duplicateInstances.push({ instanceId: hb.instanceId, seen: now });
  }

  const distinctInstances = new Set(duplicateInstances.map((d) => d.instanceId));
  const duplicate = distinctInstances.size > 1;

  if (duplicate && !row.duplicate_flag) {
    log.dup('Dua instance aktif untuk userID yang sama', {
      userId,
      name: hb.name,
      instances: Array.from(distinctInstances).map((id) => id.slice(0, 8)),
    });
    await recordEvent(userId, 'duplicate', `Dua proses bot aktif bersamaan (${distinctInstances.size} proses)`, {
      instances: Array.from(distinctInstances),
    });
  }

  // ---------- OUT-OF-ORDER / DUPLIKAT SEQ ----------
  const sameInstance = row.instance_id === hb.instanceId;
  if (sameInstance && hb.seq <= row.seq) {
    await db.run('UPDATE workers SET rejected_heartbeats = rejected_heartbeats + 1 WHERE user_id = ?', [
      userId,
    ]);
    log.ooo('Heartbeat ditolak (seq out-of-order)', {
      userId,
      name: hb.name,
      incoming: hb.seq,
      stored: row.seq,
    });
    return {
      accepted: false,
      reason: 'OUT_OF_ORDER',
      state: deriveState(row.last_seen, now),
      duplicate,
      restarted: false,
    };
  }

  // ---------- HYSTERESIS ----------
  const derived = deriveState(row.last_seen, now);
  const controllerAlive = derived === STATE.ONLINE;
  const nextStreak = restarted ? 1 : controllerAlive ? row.online_streak + 1 : row.online_streak + 1;

  let nextState;
  if (derived === STATE.OFFLINE || derived === STATE.STALE) {
    // Naik ke ONLINE hanya setelah N heartbeat berurutan
    nextState = nextStreak >= config.onlineStreakRequired ? STATE.ONLINE : STATE.STALE;
  } else {
    // Sudah ONLINE: cukup diperpanjang oleh last_seen, tidak bisa turun oleh 1 paket
    nextState = STATE.ONLINE;
  }

  const stateChanged = nextState !== row.state;
  const sessionStarted = restarted || row.session_started === 0 ? now : row.session_started;

  // ---------- ANALYTICS: rate & per hari ----------
  const day = dayKey(now);
  const newDay = row.today_day !== day;
  const baseGemsToday = newDay ? 0 : row.gems_today;
  // Perubahan gems sejak heartbeat sebelumnya (hanya jika tidak restart)
  const gemDelta = restarted ? 0 : Math.max(0, hb.gems - row.gems);
  const gemsToday = baseGemsToday + gemDelta;

  const { rate5m, rate15m, rate60m, rate60mPrev } = await computeRates(userId, now, hb.gems, restarted);

  // ---------- UPDATE (bukan INSERT) ----------
  await db.run(
    `UPDATE workers SET
      name=?, world=?, activity=?, level=?, gems=?, dl=?, bgl=?,
      backpack_used=?, backpack_total=?, ping_ms=?, uptime_sec=?, disconnects=?,
      instance_id=?, seq=?, state=?, online_streak=?, duplicate_flag=?,
      duplicate_instances=?, last_seen=?, last_state_change=?, session_started=?,
      restart_count=?, rate_5m=?, rate_15m=?, rate_60m=?, rate_60m_prev=?,
      gems_today=?, today_day=?
    WHERE user_id=?`,
    [
      hb.name, hb.world, hb.activity, hb.level, hb.gems, hb.dl, hb.bgl,
      hb.backpack.used, hb.backpack.total, hb.pingMs, hb.uptimeSec, hb.disconnects,
      hb.instanceId, hb.seq, nextState, nextStreak, duplicate ? 1 : 0,
      JSON.stringify(duplicateInstances), now, stateChanged ? now : row.last_state_change,
      sessionStarted, restartCount,
      rate5m, rate15m, rate60m, rate60mPrev,
      gemsToday, day,
      userId,
    ],
  );

  // ---------- SAMPLE TIME-SERIES ----------
  await db.run('INSERT INTO samples(user_id, ts, gems, ping_ms, rate) VALUES(?,?,?,?,?)', [
    userId,
    now,
    hb.gems,
    hb.pingMs,
    rate60m,
  ]);
  const minute = Math.floor(now / 60000) * 60000;
  await db.run(
    `INSERT INTO samples_minute(user_id, minute, gems, ping_ms) VALUES(?,?,?,?)
     ON CONFLICT(user_id, minute) DO UPDATE SET gems = excluded.gems, ping_ms = excluded.ping_ms`,
    [userId, minute, hb.gems, hb.pingMs],
  );

  // ---------- EVENT TRANSISI ----------
  if (stateChanged) {
    if (nextState === STATE.ONLINE) {
      await recordEvent(userId, 'online', `${hb.name} online di ${hb.world}`, { world: hb.world });
    } else if (nextState === STATE.STALE) {
      await recordEvent(userId, 'stale', `${hb.name} mulai tidak merespons`);
    }
  }
  if (row.world && hb.world && row.world !== hb.world) {
    await recordEvent(userId, 'world', `Pindah world: ${row.world} -> ${hb.world}`, {
      from: row.world,
      to: hb.world,
    });
  }
  if (!restarted && gemDelta > 0 && hb.gems < row.gems) {
    // tidak mungkin (dijaga Math.max) — jaga-jaga
  }
  if (!restarted && hb.gems < row.gems) {
    const dropPct = row.gems > 0 ? ((row.gems - hb.gems) / row.gems) * 100 : 0;
    const threshold = (await require('./settings').getSettings()).gemsDropPercent;
    if (dropPct >= threshold) {
      await recordEvent(userId, 'gems_drop', `Gems turun ${dropPct.toFixed(1)}%`, {
        from: row.gems,
        to: hb.gems,
      });
      await db.run('UPDATE workers SET drop_flag = 1 WHERE user_id = ?', [userId]);
    }
  } else if (hb.gems >= row.gems) {
    await db.run('UPDATE workers SET drop_flag = 0 WHERE user_id = ?', [userId]);
  }

  return { accepted: true, state: nextState, duplicate, restarted, streak: nextStreak };
}

/** Kunci hari menurut WIB (UTC+7) supaya "hari ini" konsisten. */
function dayKey(ts) {
  const d = new Date(ts + 7 * 3600 * 1000);
  return d.toISOString().slice(0, 10);
}

/**
 * Rate dari sampel DB (bukan window memori) supaya konsisten
 * dan tidak terpengaruh restart server.
 */
async function computeRates(userId, now, currentGems, restarted) {
  const windowRate = async (ms, prevOffsetMs = 0) => {
    const end = now - prevOffsetMs;
    const start = end - ms;
    const first = await db.get(
      'SELECT gems, ts FROM samples WHERE user_id = ? AND ts >= ? AND ts <= ? ORDER BY ts ASC LIMIT 1',
      [userId, start, end],
    );
    if (!first) return 0;
    const minutes = (now - first.ts) / 60000;
    if (minutes < 0.5) return 0;
    const delta = currentGems - first.gems;
    if (delta <= 0) return 0;
    return delta / minutes; // gems per menit
  };

  return {
    rate5m: restarted ? 0 : await windowRate(5 * 60000),
    rate15m: restarted ? 0 : await windowRate(15 * 60000),
    rate60m: restarted ? 0 : await windowRate(60 * 60000),
    rate60mPrev: restarted ? 0 : await windowRate(60 * 60000, 60 * 60000),
  };
}

/**
 * Sinkronkan status semua worker berdasarkan waktu.
 * Dipanggil oleh ticker server + saat read request.
 */
async function sweepStates() {
  const now = Date.now();
  const rows = await db.all(
    `SELECT user_id, name, world, state, last_seen FROM workers WHERE archived = 0`,
  );
  const changed = [];
  for (const r of rows) {
    const derived = deriveState(r.last_seen, now);
    if (derived === r.state) continue;
    // ONLINE -> STALE/OFFLINE hanya karena waktu (bukan 1 paket hilang)
    if (r.state === STATE.STALE && derived === STATE.OFFLINE) {
      await db.run('UPDATE workers SET state = ?, last_state_change = ? WHERE user_id = ?', [
        STATE.OFFLINE,
        now,
        r.user_id,
      ]);
      await recordEvent(r.user_id, 'offline', `${r.name} offline (heartbeat berhenti)`, {
        world: r.world,
      });
      changed.push({ userId: r.user_id, from: r.state, to: STATE.OFFLINE });
      log.warn('Worker offline', { userId: r.user_id, name: r.name });
    } else if (r.state === STATE.ONLINE && derived === STATE.STALE) {
      await db.run('UPDATE workers SET state = ?, last_state_change = ? WHERE user_id = ?', [
        STATE.STALE,
        now,
        r.user_id,
      ]);
      await recordEvent(r.user_id, 'stale', `${r.name} tidak merespons`);
      changed.push({ userId: r.user_id, from: r.state, to: STATE.STALE });
      log.warn('Worker stale', { userId: r.user_id, name: r.name });
    } else if (r.state === STATE.OFFLINE && derived === STATE.ONLINE) {
      // heartbeat masuk tanpa lewat processHeartbeat (mis. dari versi lama)
      await db.run('UPDATE workers SET state = ?, last_state_change = ? WHERE user_id = ?', [
        STATE.ONLINE,
        now,
        r.user_id,
      ]);
      await recordEvent(r.user_id, 'online', `${r.name} kembali online`);
    }
  }
  return changed;
}

/** Arsipkan worker yang offline > 24 jam. Event tetap disimpan. */
async function archiveStale() {
  const cutoff = Date.now() - config.offlineArchiveMs;
  const res = await db.run(
    `UPDATE workers SET archived = 1
     WHERE archived = 0 AND state = 'OFFLINE' AND last_seen < ?`,
    [cutoff],
  );
  return res.changes;
}

module.exports = {
  STATE,
  deriveState,
  processHeartbeat,
  sweepStates,
  archiveStale,
  recordEvent,
  dayKey,
};
