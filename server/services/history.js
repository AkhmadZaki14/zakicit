'use strict';

const db = require('../db');
const log = require('../utils/log');

/**
 * Downsampling LTTB (Largest-Triangle-Three-Buckets).
 * Menjaga bentuk grafik dengan N titik, bukan rata-rata yang menghapus puncak.
 */
function lttb(data, threshold) {
  const n = data.length;
  if (threshold >= n || threshold <= 2) return data;

  const sampled = [];
  const every = (n - 2) / (threshold - 2);
  let a = 0;

  sampled.push(data[0]);

  for (let i = 0; i < threshold - 2; i += 1) {
    // rata-rata bucket berikutnya
    let avgX = 0;
    let avgY = 0;
    const start = Math.floor((i + 1) * every) + 1;
    const end = Math.min(Math.floor((i + 2) * every) + 1, n);
    const len = Math.max(1, end - start);
    for (let j = start; j < end; j += 1) {
      avgX += data[j].t;
      avgY += data[j].v;
    }
    avgX /= len;
    avgY /= len;

    const rangeStart = Math.floor(i * every) + 1;
    const rangeEnd = Math.floor((i + 1) * every) + 1;

    const pointAX = data[a].t;
    const pointAY = data[a].v;

    let maxArea = -1;
    let maxIdx = rangeStart;

    for (let j = rangeStart; j < rangeEnd; j += 1) {
      const area = Math.abs(
        (pointAX - avgX) * (data[j].v - pointAY) - (pointAX - data[j].t) * (avgY - pointAY),
      );
      if (area > maxArea) {
        maxArea = area;
        maxIdx = j;
      }
    }
    sampled.push(data[maxIdx]);
    a = maxIdx;
  }

  sampled.push(data[n - 1]);
  return sampled;
}

const RANGES = {
  '1h': { ms: 3600 * 1000, points: 120 },
  '6h': { ms: 6 * 3600 * 1000, points: 180 },
  '24h': { ms: 24 * 3600 * 1000, points: 240 },
  '7d': { ms: 7 * 24 * 3600 * 1000, points: 300 },
};

/**
 * Time-series gems untuk satu bot atau seluruh fleet.
 * @param {object} opts { userId?, range, interval }
 */
async function getHistory({ userId = null, range = '1h' } = {}) {
  const spec = RANGES[range] || RANGES['1h'];
  const now = Date.now();
  const since = now - spec.ms;
  const bucketMs = Math.max(60000, Math.floor(spec.ms / spec.points));

  let rows;
  if (userId) {
    // gunakan agregasi menit untuk rentang panjang (jauh lebih ringan)
    if (spec.ms > 2 * 3600 * 1000) {
      rows = await db.all(
        `SELECT (minute / ?) * ? AS bucket, MAX(gems) AS v, AVG(ping_ms) AS p
         FROM samples_minute WHERE user_id = ? AND minute >= ?
         GROUP BY bucket ORDER BY bucket ASC`,
        [bucketMs, bucketMs, userId, since],
      );
    } else {
      rows = await db.all(
        `SELECT (ts / ?) * ? AS bucket, MAX(gems) AS v, AVG(ping_ms) AS p
         FROM samples WHERE user_id = ? AND ts >= ?
         GROUP BY bucket ORDER BY bucket ASC`,
        [bucketMs, bucketMs, userId, since],
      );
    }
  } else {
    rows = await db.all(
      `SELECT (ts / ?) * ? AS bucket, SUM(v) AS v
       FROM (
         SELECT (ts / ?) * ? AS ts, MAX(gems) AS v
         FROM samples WHERE ts >= ? GROUP BY user_id, (ts / ?)
       )
       GROUP BY bucket ORDER BY bucket ASC`,
      [bucketMs, bucketMs, bucketMs, bucketMs, since, bucketMs],
    );
  }

  const series = rows.map((r) => ({ t: Number(r.bucket), v: Number(r.v) }));
  const downsampled = lttb(series, spec.points);

  return {
    range,
    bucketMs,
    points: downsampled,
    rawCount: series.length,
  };
}

/** Per-bot series, dipakai untuk chart perbandingan (multi-line). */
async function getMultiHistory({ range = '1h', limit = 12 } = {}) {
  const spec = RANGES[range] || RANGES['1h'];
  const since = Date.now() - spec.ms;
  const workers = await db.all(
    'SELECT user_id, name FROM workers WHERE archived = 0 ORDER BY user_id ASC LIMIT ?',
    [limit],
  );
  const out = [];
  for (const w of workers) {
    const h = await getHistory({ userId: w.user_id, range });
    out.push({ userId: w.user_id, name: w.name, points: h.points });
  }
  return { range, bots: out };
}

/** Sparkline ringkas (1 jam terakhir, 24 titik). */
async function getSparklines(range = '1h') {
  const rows = await db.all(
    `SELECT user_id, (ts / 150000) * 150000 AS bucket, MAX(gems) AS v
     FROM samples WHERE ts >= ?
     GROUP BY user_id, bucket ORDER BY bucket ASC`,
    [Date.now() - (RANGES[range] || RANGES['1h']).ms],
  );
  const map = new Map();
  for (const r of rows) {
    if (!map.has(r.user_id)) map.set(r.user_id, []);
    map.get(r.user_id).push(Number(r.v));
  }
  return map;
}

/** Bersihkan data lama. */
async function purge() {
  const now = Date.now();
  const raw = await db.run('DELETE FROM samples WHERE ts < ?', [
    now - require('../config').rawRetentionMs,
  ]);
  await db.run('DELETE FROM samples_minute WHERE minute < ?', [
    now - require('../config').minuteRetentionMs,
  ]);
  if (raw.changes) log.info('Purge sampel mentah', { rows: raw.changes });
}

module.exports = { lttb, getHistory, getMultiHistory, getSparklines, purge, RANGES };
