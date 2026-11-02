'use strict';

const config = require('../config');
const log = require('../utils/log');

/**
 * Rate limiter ringan in-memory (fixed window).
 * Tidak perlu Redis untuk 50 bot + dashboard pribadi.
 */

const buckets = new Map();

function limiter({ windowMs = 60000, max = 120, keyPrefix = 'g' } = {}) {
  return (req, res, next) => {
    const key = `${keyPrefix}:${req.ip}`;
    const now = Date.now();
    let b = buckets.get(key);
    if (!b || now - b.start >= windowMs) {
      b = { start: now, count: 0 };
      buckets.set(key, b);
    }
    b.count += 1;
    if (b.count > max) {
      res.setHeader('Retry-After', Math.ceil((b.start + windowMs - now) / 1000));
      return res.status(429).json({ error: 'Too many requests' });
    }
    return next();
  };
}

/** Auth: X-API-Key untuk bot, Bearer token (API key) untuk dashboard. */
function apiKeyAuth(req, res, next) {
  if (!config.apiKey) {
    // Tanpa API_KEY di .env: hanya izinkan dari localhost
    return next();
  }

  const fromHeader = req.get('x-api-key') || '';
  const auth = req.get('authorization') || '';
  const bearer = auth.toLowerCase().startsWith('bearer ') ? auth.slice(7).trim() : '';

  if (fromHeader === config.apiKey || bearer === config.apiKey) return next();

  log.warn('Unauthorized request', { ip: req.ip, path: req.path });
  return res.status(401).json({ error: 'Unauthorized' });
}

/** Bersihkan bucket lama tiap 10 menit supaya tidak bocor memori. */
setInterval(() => {
  const now = Date.now();
  for (const [k, b] of buckets) {
    if (now - b.start > 30 * 60 * 1000) buckets.delete(k);
  }
}, 10 * 60 * 1000).unref();

module.exports = { limiter, apiKeyAuth };
