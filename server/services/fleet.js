'use strict';

const db = require('../db');
const config = require('../config');
const { getSettings } = require('./settings');
const { getSparklines } = require('./history');
const { STATE, deriveState, dayKey } = require('./workers');

let cache = { at: 0, data: null };

/** Konversi kekayaan -> WL. Rumus ditampilkan di tooltip frontend. */
function wealth(w, s) {
  const gemsWl = w.gems / s.gemsPerWl;
  const dlWl = w.dl * s.wlPerDl;
  const bglDl = w.bgl * s.dlPerBgl;
  const bglWl = bglDl * s.wlPerDl;
  return {
    fromGems: gemsWl,
    fromDl: dlWl,
    fromBgl: bglWl,
    total: gemsWl + dlWl + bglWl,
  };
}

/**
 * Skor kesehatan 0-100, rumus transparan:
 *  status      : ONLINE 40 / STALE 15 / OFFLINE 0
 *  stuck       : -25 jika stuck
 *  gems drop   : -10 jika drop
 *  latency     : 20 * clamp(1 - ping/1000)
 *  restart     : 10 - min(10, restartCount*2 depr hari ini)
 *  duplicate   : -20
 */
function healthScore(w, now) {
  const state = deriveState(w.last_seen, now);
  let score = state === STATE.ONLINE ? 40 : state === STATE.STALE ? 15 : 0;

  if (w.stuck_flag) score -= 25;
  if (w.drop_flag) score -= 10;
  if (w.duplicate_flag) score -= 20;

  // latency
  const ping = Number(w.ping_ms) || 0;
  score += Math.round(20 * Math.max(0, Math.min(1, 1 - ping / 1000)));

  // restart (dalam sesi berjalan)
  score += Math.max(0, 10 - Math.min(10, Number(w.restart_count) * 2));

  return Math.max(0, Math.min(100, score));
}

/** Deteksi stuck: activity farming tapi gems tidak naik > N menit. */
async function computeStuckFlags(workers, settings, now) {
  const thresholdMs = settings.stuckMinutes * 60 * 1000;
  const cutoff = now - thresholdMs;
  const flagged = [];

  for (const w of workers) {
    if (!w.state || w.state === STATE.OFFLINE) {
      if (w.stuck_flag) flagged.push({ userId: w.user_id, stuck: false });
      continue;
    }
    const row = await db.get(
      'SELECT MAX(gems) AS maxGems, MIN(ts) AS minTs, MAX(ts) AS maxTs FROM samples WHERE user_id = ? AND ts >= ?',
      [w.user_id, cutoff],
    );
    // Data belum cukup untuk menyimpulkan
    if (!row || row.minTs === null || row.maxTs - row.minTs < thresholdMs * 0.6) {
      continue;
    }
    const gained = Number(w.gems) - Number(row.maxGems);
    const noGain = gained <= 0;
    if (noGain !== !!w.stuck_flag) {
      flagged.push({ userId: w.user_id, stuck: noGain, fresh: Number(row.maxGems) });
    }
  }
  return flagged;
}

function pct(part, total) {
  if (!total) return 0;
  return (part / total) * 100;
}

function pick(obj, keys) {
  const out = {};
  for (const k of keys) out[k] = obj[k];
  return out;
}

async function buildFleet({ force = false } = {}) {
  const now = Date.now();
  if (!force && cache.data && now - cache.at < config.fleetCacheMs) {
    return cache.data;
  }
  const settings = await getSettings();
  const rows = await db.all('SELECT * FROM workers WHERE archived = 0 ORDER BY user_id ASC');

  // sinkronkan state dengan waktu (tanpa tulis bila tidak berubah)
  const states = rows.map((r) => ({ ...r, state: deriveState(r.last_seen, now) }));

  // stuck detection (update flag ke DB bila berubah)
  const stuckChanges = await computeStuckFlags(states, settings, now);
  for (const c of stuckChanges) {
    await db.run('UPDATE workers SET stuck_flag = ? WHERE user_id = ?', [c.stuck ? 1 : 0, c.userId]);
    const target = states.find((s) => s.user_id === c.userId);
    if (target) target.stuck_flag = c.stuck ? 1 : 0;
  }

  const sparklines = await getSparklines('1h');

  const bots = states.map((w) => {
    const wl = wealth(w, settings);
    const target = Number(w.target_gems) || settings.globalTargetGems || 0;
    const remaining = target > 0 ? Math.max(0, target - Number(w.gems)) : 0;
    const ratePerMin = Number(w.rate_60m) || 0;
    const etaMinutes = target > 0 && ratePerMin > 0 ? Math.ceil(remaining / ratePerMin) : null;
    const trendPct =
      Number(w.rate_60m_prev) > 0
        ? ((Number(w.rate_60m) - Number(w.rate_60m_prev)) / Number(w.rate_60m_prev)) * 100
        : null;

    return {
      userId: w.user_id,
      name: w.name,
      world: w.world,
      activity: w.activity,
      level: w.level,
      gems: Number(w.gems),
      dl: Number(w.dl),
      bgl: Number(w.bgl),
      backpack: { used: w.backpack_used, total: w.backpack_total },
      pingMs: w.ping_ms,
      uptimeSec: w.uptime_sec,
      disconnects: w.disconnects,

      state: w.state,
      lastSeenAgoSec: Math.floor((now - w.last_seen) / 1000),
      lastSeen: w.last_seen,
      sessionUptimeSec: Math.floor((now - (w.session_started || now)) / 1000),
      restartCount: w.restart_count,
      duplicate: !!w.duplicate_flag,
      rejectedHeartbeats: w.rejected_heartbeats,
      stuck: !!w.stuck_flag,
      gemsDrop: !!w.drop_flag,

      instanceId: w.instance_id,
      seq: w.seq,

      rates: {
        perMin5m: Number(w.rate_5m),
        perMin15m: Number(w.rate_15m),
        perMin60m: Number(w.rate_60m),
        perMin60mPrev: Number(w.rate_60m_prev),
        perHour60m: Number(w.rate_60m) * 60,
        trendPct,
      },
      gemsToday: Number(w.gems_today),
      gems24h: Number(w.gems_24h),
      targetGems: target,
      etaMinutes,
      wealthWl: wl,
      health: healthScore(w, now),
      sparkline: sparklines.get(w.user_id) || [],
    };
  });

  const online = bots.filter((b) => b.state === STATE.ONLINE);
  const stale = bots.filter((b) => b.state === STATE.STALE);
  const offline = bots.filter((b) => b.state === STATE.OFFLINE);
  const healthy = bots.filter((b) => b.health >= 70);
  const duplicates = bots.filter((b) => b.duplicate);
  const stuckBots = bots.filter((b) => b.stuck);

  const totalGems = bots.reduce((a, b) => a + b.gems, 0);
  const totalDl = bots.reduce((a, b) => a + b.dl, 0);
  const totalBgl = bots.reduce((a, b) => a + b.bgl, 0);
  const totalGemsPerHour = bots.reduce((a, b) => a + b.rates.perHour60m, 0);
  const totalWealth = bots.reduce((a, b) => a + b.wealthWl.total, 0);

  const avgPing = bots.length
    ? bots.reduce((a, b) => a + (b.pingMs || 0), 0) / bots.length
    : 0;

  // Network Health = skor nyata, bukan statis
  const healthParts = {
    healthyRatio: bots.length ? pct(healthy.length, bots.length) : 0, // bobot 45
    latency: Math.max(0, Math.min(100, 100 - avgPing / 10)), // bobot 20
    availability: bots.length ? pct(online.length, bots.length) : 0, // bobot 25
    penalty: (stale.length * 5 + offline.length * 10 + duplicates.length * 15), // bobot 10
  };
  const rawHealth =
    healthParts.healthyRatio * 0.45 +
    healthParts.latency * 0.2 +
    healthParts.availability * 0.25 +
    Math.max(0, 10 - healthParts.penalty * 0.1) * 10 * 0.1;
  const networkScore = Math.round(Math.max(0, Math.min(100, rawHealth)));

  const label =
    bots.length === 0
      ? 'IDLE'
      : networkScore >= 85
        ? 'Excellent'
        : networkScore >= 70
          ? 'Good'
          : networkScore >= 50
            ? 'Warning'
            : 'Critical';

  const reasons = [];
  if (offline.length) reasons.push(`${offline.length} bot offline`);
  if (stale.length) reasons.push(`${stale.length} bot stale`);
  if (duplicates.length) reasons.push(`${duplicates.length} duplikat instance`);
  if (avgPing > 300) reasons.push(`latency tinggi (${Math.round(avgPing)}ms)`);
  if (stuckBots.length) reasons.push(`${stuckBots.length} bot stuck`);
  if (!reasons.length && bots.length) reasons.push('semua bot sehat');

  // Perbandingan hari ini vs kemarin (dari events/samples)
  const dayStart = dayStartWib(now);
  const yesterdayStart = dayStart - 24 * 3600 * 1000;
  const gemsTodayTotal = bots.reduce((a, b) => a + b.gemsToday, 0);
  const prevRow = await db.get(
    `SELECT COALESCE(SUM(v),0) AS total FROM (
       SELECT user_id, MAX(gems) - MIN(gems) AS v
       FROM samples WHERE ts >= ? AND ts < ? GROUP BY user_id
     )`,
    [yesterdayStart, dayStart],
  );
  const gemsYesterdayTotal = Number(prevRow?.total || 0);

  const contributions = bots
    .map((b) => ({
      userId: b.userId,
      name: b.name,
      gems: b.gems,
      gemsPerHour: b.rates.perHour60m,
      pctGems: pct(b.gems, totalGems),
      pctRate: pct(b.rates.perHour60m, totalGemsPerHour),
    }))
    .sort((a, b) => b.gems - a.gems);

  const leaderboard = [...bots]
    .sort((a, b) => b.rates.perHour60m - a.rates.perHour60m)
    .slice(0, 10)
    .map((b) => ({
      userId: b.userId,
      name: b.name,
      gemsPerHour: b.rates.perHour60m,
      gemsToday: b.gemsToday,
    }));

  const data = {
    now,
    serverTime: now,
    settings: pick(settings, [
      'gemsPerWl', 'wlPerDl', 'dlPerBgl', 'stuckMinutes', 'gemsDropPercent',
      'globalTargetGems', 'pollingMs', 'numberFormat', 'quietHours',
    ]),
    summary: {
      totalBots: bots.length,
      online: online.length,
      stale: stale.length,
      offline: offline.length,
      healthy: healthy.length,
      duplicates: duplicates.length,
      stuck: stuckBots.length,
      totalGems,
      totalDl,
      totalBgl,
      totalWealthWl: totalWealth,
      totalGemsPerHour,
      projection24h: totalGemsPerHour * 24,
      projection7d: totalGemsPerHour * 24 * 7,
      avgPingMs: Math.round(avgPing),
      gemsToday: gemsTodayTotal,
      gemsYesterday: gemsYesterdayTotal,
      deltaGemsToday: gemsTodayTotal - gemsYesterdayTotal,
      deltaGemsTodayPct:
        gemsYesterdayTotal > 0
          ? ((gemsTodayTotal - gemsYesterdayTotal) / gemsYesterdayTotal) * 100
          : null,
    },
    networkHealth: {
      score: networkScore,
      label,
      reason: reasons.join(', '),
      parts: healthParts,
    },
    contributions,
    leaderboard,
    bots,
  };

  cache = { at: now, data };
  return data;
}

function dayStartWib(ts) {
  const d = new Date(ts + 7 * 3600 * 1000);
  d.setUTCHours(0, 0, 0, 0);
  return d.getTime() - 7 * 3600 * 1000;
}

async function getBotDetail(userId) {
  const fleet = await buildFleet();
  const bot = fleet.bots.find((b) => b.userId === Number(userId));
  if (!bot) return null;
  const events = await db.all(
    'SELECT id, ts, type, message, meta FROM events WHERE user_id = ? ORDER BY ts DESC LIMIT 200',
    [Number(userId)],
  );
  return { ...bot, events: events.map((e) => ({ ...e, meta: safeJson(e.meta) })) };
}

function safeJson(t) {
  try {
    return JSON.parse(t);
  } catch {
    return {};
  }
}

function invalidateFleetCache() {
  cache = { at: 0, data: null };
}

module.exports = { buildFleet, getBotDetail, wealth, healthScore, dayStartWib, dayKey, invalidateFleetCache };
