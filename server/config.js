'use strict';

require('dotenv').config();

const path = require('path');

const num = (v, d) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
};

const config = {
  port: num(process.env.PORT, 3000),
  host: process.env.HOST || '127.0.0.1',

  // Auth
  apiKey: process.env.API_KEY || '',
  allowAnon: process.env.ALLOW_ANON_HEARTBEAT === '1',

  // Storage: file: for local, libsql:// for Turso
  dbUrl: process.env.DATABASE_URL || `file:${path.join(__dirname, '..', 'data', 'gt.db')}`,
  dbToken: process.env.DATABASE_AUTH_TOKEN || undefined,

  // TTL (ms) — default: online <8s, stale <20s, offline >20s
  ttlOnlineMs: num(process.env.TTL_ONLINE_MS, 8000),
  ttlStaleMs: num(process.env.TTL_STALE_MS, 20000),

  // Hysteresis: heartbeat berurutan sebelum OFFLINE/STALE -> ONLINE
  onlineStreakRequired: num(process.env.ONLINE_STREAK_REQUIRED, 2),

  // Duplicate instance window (ms)
  duplicateWindowMs: num(process.env.DUPLICATE_WINDOW_MS, 10000),

  // Alert cooldown per (userId, type)
  alertCooldownMs: num(process.env.ALERT_COOLDOWN_MS, 5 * 60 * 1000),

  // Retention
  rawRetentionMs: 7 * 24 * 3600 * 1000,
  minuteRetentionMs: 30 * 24 * 3600 * 1000,
  offlineArchiveMs: 24 * 3600 * 1000,

  // Fleet cache
  fleetCacheMs: 1000,

  // Discord
  discordWebhookUrl: process.env.DISCORD_WEBHOOK_URL || '',

  // Default settings (overridable via /api/settings)
  defaults: {
    gemsPerWl: 1100,          // 11k gems = 10 WL
    wlPerDl: 100,
    dlPerBgl: 100,
    stuckMinutes: 5,
    gemsDropPercent: 5,
    globalTargetGems: 0,
    pollingMs: 2000,
    numberFormat: 'compact',   // 'full' | 'compact'
    theme: 'dark',
    quietHours: { enabled: false, start: '23:00', end: '07:00', tzOffsetMinutes: 420 },
    browserNotifications: false,
    alertSound: false,
  },
};

module.exports = config;
