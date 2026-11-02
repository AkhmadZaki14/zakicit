'use strict';

const express = require('express');
const { buildFleet, getBotDetail } = require('../services/fleet');
const { getHistory, getMultiHistory } = require('../services/history');
const { listEvents, eventTypes } = require('../services/events');
const { getSettings, updateSettings } = require('../services/settings');
const { validateSettings } = require('../utils/validate');
const { deriveState } = require('../services/workers');
const db = require('../db');
const config = require('../config');

const router = express.Router();

/* ------------------------------- fleet -------------------------------- */
router.get('/fleet', async (req, res, next) => {
  try {
    const fleet = await buildFleet({ force: req.query.fresh === '1' });
    res.setHeader('Cache-Control', 'no-store');
    res.json(fleet);
  } catch (err) {
    next(err);
  }
});

/* -------------------------------- bot --------------------------------- */
router.get('/bot/:userId', async (req, res, next) => {
  try {
    const detail = await getBotDetail(req.params.userId);
    if (!detail) return res.status(404).json({ error: 'NOT_FOUND' });
    return res.json(detail);
  } catch (err) {
    return next(err);
  }
});

/* ------------------------------ history -------------------------------- */
router.get('/history', async (req, res, next) => {
  try {
    const { bot = null, range = '1h', multi = null } = req.query;
    if (multi === '1') {
      const data = await getMultiHistory({ range });
      return res.json(data);
    }
    const data = await getHistory({ userId: bot ? Number(bot) : null, range });
    return res.json(data);
  } catch (err) {
    return next(err);
  }
});

/* ------------------------------- events -------------------------------- */
router.get('/events', async (req, res, next) => {
  try {
    const { bot = null, type = null, limit = 100 } = req.query;
    const events = await listEvents({
      userId: bot ? Number(bot) : null,
      type: type || null,
      limit: Number(limit),
    });
    res.json({ events, types: await eventTypes() });
  } catch (err) {
    next(err);
  }
});

/* ------------------------------ settings ------------------------------- */
router.get('/settings', async (req, res, next) => {
  try {
    res.json(await getSettings());
  } catch (err) {
    next(err);
  }
});

router.put('/settings', async (req, res, next) => {
  try {
    const check = validateSettings(req.body);
    if (!check.ok) return res.status(400).json({ error: 'INVALID_SETTINGS', details: check.errors });
    const next = await updateSettings(check.data);
    return res.json(next);
  } catch (err) {
    return next(err);
  }
});

/* ------------------------------- health -------------------------------- */
router.get('/health', async (req, res) => {
  try {
    const row = await db.get('SELECT COUNT(*) AS n FROM workers');
    res.json({
      ok: true,
      uptimeSec: Math.round(process.uptime()),
      workers: Number(row?.n || 0),
      memMB: Math.round(process.memoryUsage().rss / 1048576),
      db: config.dbUrl.startsWith('file:') ? 'file' : 'remote',
      version: require('../../package.json').version,
    });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

/* -------------------------------- debug -------------------------------- */
router.get('/debug/workers', async (req, res, next) => {
  try {
    const now = Date.now();
    const rows = await db.all('SELECT * FROM workers ORDER BY last_seen DESC');
    const map = new Map();
    let duplicates = 0;
    let rejected = 0;

    for (const r of rows) {
      rejected += Number(r.rejected_heartbeats) || 0;
      if (r.duplicate_flag) duplicates += 1;

      const inst = JSON.parse(r.duplicate_instances || '[]');
      const activeInstances = inst.filter((d) => now - d.seen < config.duplicateWindowMs);

      map.set(r.user_id, {
        userId: r.user_id,
        name: r.name,
        state: deriveState(r.last_seen, now),
        storedState: r.state,
        archived: !!r.archived,
        instanceId: r.instance_id,
        lastSeq: r.seq,
        rejectedHeartbeats: r.rejected_heartbeats,
        duplicateFlag: !!r.duplicate_flag,
        activeInstances: activeInstances.map((d) => ({
          instanceId: d.instanceId,
          ageSec: Math.round((now - d.seen) / 1000),
        })),
        lastSeenAgoSec: Math.round((now - r.last_seen) / 1000),
        seq: r.seq,
        restartCount: r.restart_count,
      });
    }

    res.json({
      now,
      rawEntries: rows.length,
      uniqueWorkers: map.size,
      duplicateWorkers: duplicates,
      totalRejectedHeartbeats: rejected,
      windowMs: config.duplicateWindowMs,
      workers: [...map.values()],
    });
  } catch (err) {
    next(err);
  }
});

/* -------------------------------- stream -------------------------------- */
/**
 * Server-Sent Events: kirim ringkasan fleet tiap 2 detik.
 * Frontend otomatis fallback ke polling bila koneksi gagal.
 */
const sseClients = new Set();

router.get('/stream', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders?.();

  const client = { res };
  sseClients.add(client);

  const ping = setInterval(() => {
    try {
      res.write(': ping\n\n');
    } catch {
      /* ignore */
    }
  }, 15000);

  req.on('close', () => {
    clearInterval(ping);
    sseClients.delete(client);
  });
});

async function broadcastFleet() {
  if (sseClients.size === 0) return;
  try {
    const fleet = await buildFleet();
    const payload = `event: fleet\ndata: ${JSON.stringify(fleet)}\n\n`;
    for (const c of sseClients) {
      try {
        c.res.write(payload);
      } catch {
        sseClients.delete(c);
      }
    }
  } catch {
    /* ignore */
  }
}

module.exports = router;
module.exports.broadcastFleet = broadcastFleet;
