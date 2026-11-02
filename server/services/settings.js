'use strict';

const db = require('../db');
const config = require('../config');
const log = require('../utils/log');

let cache = null;

/** Deep-merge: nilai dari DB menimpa default, objek bersarang ikut digabung. */
function merge(base, override) {
  if (override === null || override === undefined) return base;
  if (typeof base !== 'object' || base === null || Array.isArray(base)) return override;
  if (typeof override !== 'object' || Array.isArray(override)) return override;
  const out = { ...base };
  for (const [k, v] of Object.entries(override)) {
    out[k] = k in base ? merge(base[k], v) : v;
  }
  return out;
}

/** Batas wajar supaya setting tidak bisa merusak dashboard. */
function sanitize(s) {
  const clamp = (v, lo, hi, def) => {
    const n = Number(v);
    if (!Number.isFinite(n)) return def;
    return Math.min(hi, Math.max(lo, n));
  };
  const out = { ...s };
  out.gemsPerWl = Math.round(clamp(s.gemsPerWl, 1, 1e9, 1100));
  out.wlPerDl = Math.round(clamp(s.wlPerDl, 1, 1e6, 100));
  out.dlPerBgl = Math.round(clamp(s.dlPerBgl, 1, 1e6, 100));
  out.stuckMinutes = clamp(s.stuckMinutes, 1, 1440, 5);
  out.gemsDropPercent = clamp(s.gemsDropPercent, 0.1, 100, 5);
  out.globalTargetGems = Math.round(clamp(s.globalTargetGems, 0, 1e12, 0));
  out.pollingMs = Math.round(clamp(s.pollingMs, 1000, 60000, 2000));
  out.numberFormat = s.numberFormat === 'full' ? 'full' : 'compact';
  out.theme = 'dark';
  const q = s.quietHours || {};
  out.quietHours = {
    enabled: !!q.enabled,
    start: /^\d{2}:\d{2}$/.test(q.start || '') ? q.start : '23:00',
    end: /^\d{2}:\d{2}$/.test(q.end || '') ? q.end : '07:00',
    tzOffsetMinutes: Math.round(clamp(q.tzOffsetMinutes, -720, 840, 420)),
  };
  out.browserNotifications = !!s.browserNotifications;
  out.alertSound = !!s.alertSound;
  return out;
}

async function load() {
  if (cache) return cache;
  const row = await db.get('SELECT value FROM settings WHERE key = ?', ['app']);
  let stored = {};
  if (row) {
    try {
      stored = JSON.parse(row.value);
    } catch {
      log.warn('Settings tersimpan rusak, memakai default');
    }
  }
  cache = sanitize(merge(config.defaults, stored));
  return cache;
}

async function getSettings() {
  return load();
}

async function updateSettings(patch) {
  const current = await load();
  const next = sanitize(merge(current, patch));
  await db.run(
    'INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    ['app', JSON.stringify(next)],
  );
  cache = next;
  log.ok('Settings diperbarui');
  return next;
}

/** Dipakai test / reset. */
function invalidate() {
  cache = null;
}

module.exports = { getSettings, updateSettings, invalidate, sanitize, merge };
