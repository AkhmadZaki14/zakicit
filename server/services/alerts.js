'use strict';

const config = require('../config');
const log = require('../utils/log');
const { getSettings } = require('./settings');

/**
 * Alert Discord + browser notification.
 * Anti-spam: cooldown per (userId, type). Recovery dikirim sekali.
 */

const lastSent = new Map(); // key -> ts

const COLORS = {
  offline: 0xef4444,
  stale: 0xf5b942,
  stuck: 0xef4444,
  gems_drop: 0xf97316,
  duplicate: 0xa855f7,
  recovered: 0x22c55e,
  online: 0x22c55e,
  restarted: 0x38bdf8,
};

const TITLES = {
  offline: 'Bot Offline',
  stale: 'Bot Tidak Merespons',
  stuck: 'Bot Stuck',
  gems_drop: 'Gems Turun Drastis',
  duplicate: 'Duplicate Instance',
  recovered: 'Bot Pulih',
  online: 'Bot Online',
  restarted: 'Bot Restart',
};

/** Apakah sekarang masuk jam senyap? */
function inQuietHours(settings, now = new Date()) {
  const q = settings.quietHours;
  if (!q || !q.enabled) return false;
  const local = new Date(now.getTime() + q.tzOffsetMinutes * 60000);
  const minutes = local.getUTCHours() * 60 + local.getUTCMinutes();
  const [sh, sm] = q.start.split(':').map(Number);
  const [eh, em] = q.end.split(':').map(Number);
  const start = sh * 60 + sm;
  const end = eh * 60 + em;
  if (start === end) return false;
  return start < end ? minutes >= start && minutes < end : minutes >= start || minutes < end;
}

function cooldownOk(userId, type, cooldownMs) {
  const key = `${userId}:${type}`;
  const last = lastSent.get(key) || 0;
  if (Date.now() - last < cooldownMs) return false;
  lastSent.set(key, Date.now());
  return true;
}

async function postDiscord(payload) {
  if (!config.discordWebhookUrl) return false;
  try {
    const res = await fetch(config.discordWebhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      log.warn('Discord webhook gagal', { status: res.status });
      return false;
    }
    return true;
  } catch (err) {
    log.warn('Discord webhook error', { error: err.message });
    return false;
  }
}

/**
 * Kirim alert. Mengembalikan {sent, reason} supaya bisa dites.
 */
async function sendAlert({ userId, name, world, type, detail, force = false }) {
  const settings = await getSettings();

  if (!force) {
    if (inQuietHours(settings)) return { sent: false, reason: 'QUIET_HOURS' };
    if (!cooldownOk(userId, type, config.alertCooldownMs)) {
      return { sent: false, reason: 'COOLDOWN' };
    }
  }

  const color = COLORS[type] || 0x7c5cff;
  const title = TITLES[type] || type;

  await postDiscord({
    username: 'GT Fleet Monitor',
    embeds: [
      {
        title,
        color,
        description: detail || '',
        fields: [
          { name: 'Bot', value: `\`${name || '-'}\``, inline: true },
          { name: 'User ID', value: `\`${userId}\``, inline: true },
          { name: 'World', value: `\`${world || '-'}\``, inline: true },
        ],
        timestamp: new Date().toISOString(),
      },
    ],
  });

  log.info('Alert terkirim', { userId, type });
  return { sent: true };
}

/** Dipanggil saat bot kembali ONLINE setelah OFFLINE/STALE. */
async function sendRecovery({ userId, name, world, downForSec }) {
  lastSent.delete(`${userId}:offline`);
  lastSent.delete(`${userId}:stale`);
  lastSent.delete(`${userId}:stuck`);
  return sendAlert({
    userId,
    name,
    world,
    type: 'recovered',
    detail: downForSec ? `Kembali online setelah ~${Math.round(downForSec / 60)} menit` : 'Kembali online',
    force: true,
  });
}

function resetCooldowns() {
  lastSent.clear();
}

module.exports = { sendAlert, sendRecovery, inQuietHours, resetCooldowns, cooldownOk };
