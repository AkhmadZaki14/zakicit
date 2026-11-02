'use strict';

const path = require('path');
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');

const config = require('./config');
const log = require('./utils/log');
const db = require('./db');
const { sweepStates, archiveStale } = require('./services/workers');
const { purge } = require('./services/history');
const { buildFleet } = require('./services/fleet');
const { apiKeyAuth, limiter } = require('./utils/security');
const heartbeatRoutes = require('./routes/heartbeat');
const apiRoutes = require('./routes/api');

const app = express();

app.disable('x-powered-by');
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'", 'https://cdn.jsdelivr.net'],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com'],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'"],
        objectSrc: ["'none'"],
      },
    },
    crossOriginEmbedderPolicy: false,
  }),
);
app.use(compression());
app.use(express.json({ limit: '64kb' }));

// CORS terbatas: hanya origin sendiri (dashboard) atau tanpa origin (bot/curl)
app.use((req, res, next) => {
  const origin = req.get('origin');
  if (origin) {
    const allowed = process.env.ALLOWED_ORIGIN || '';
    if (!allowed || origin === allowed) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type,X-API-Key,Authorization');
    }
  }
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  return next();
});

/* --------------------------- static dashboard --------------------------- */
const publicDir = path.join(__dirname, '..', 'public');
app.use(express.static(publicDir, { maxAge: '1h', index: 'index.html' }));

/* -------------------------------- routes -------------------------------- */
app.use('/api', limiter({ windowMs: 60000, max: 1200, keyPrefix: 'api' }));
app.use('/api', apiKeyAuth);

app.use('/api', heartbeatRoutes);
app.use('/api', apiRoutes);

/* ------------------------------ error handler --------------------------- */
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  log.error('Unhandled error', { path: req.path, error: err.message });
  if (res.headersSent) return;
  res.status(500).json({ error: 'INTERNAL', message: err.message });
});

app.use((req, res) => {
  res.status(404).json({ error: 'NOT_FOUND', path: req.path });
});

/* ------------------------------- lifecycle ------------------------------ */
let timers = [];

async function start() {
  await db.init();

  // Ticker: sinkronkan status + broadcast SSE
  timers.push(
    setInterval(() => {
      sweepStates().catch((e) => log.error('sweep gagal', { e: e.message }));
      apiRoutes.broadcastFleet?.();
    }, 1000),
  );

  // Cache priming supaya request pertama tidak lambat
  await buildFleet({ force: true }).catch(() => {});

  // Maintenance tiap 10 menit
  timers.push(
    setInterval(() => {
      purge().catch(() => {});
      archiveStale().catch(() => {});
    }, 10 * 60 * 1000),
  );

  return new Promise((resolve) => {
    const server = app.listen(config.port, config.host, () => {
      log.ok(`Server jalan di http://${config.host}:${config.port}`);
      if (!config.apiKey) log.warn('API_KEY kosong — dashboard terbuka untuk localhost');
      resolve(server);
    });
    app.locals.server = server;
  });
}

function stop() {
  for (const t of timers) clearInterval(t);
  timers = [];
  const server = app.locals.server;
  if (server) return new Promise((r) => server.close(r));
  return Promise.resolve();
}

if (require.main === module) {
  start().catch((err) => {
    log.error('Gagal start', { error: err.message });
    process.exit(1);
  });

  const shutdown = async (sig) => {
    log.warn(`Menerima ${sig}, mematikan...`);
    await stop();
    process.exit(0);
  };
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

module.exports = { app, start, stop };
