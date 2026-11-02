'use strict';

const fs = require('fs');
const path = require('path');
const { createClient } = require('@libsql/client');
const config = require('../config');
const log = require('../utils/log');
const { SCHEMA } = require('./schema');

// Pastikan folder data ada untuk mode file:
if (config.dbUrl.startsWith('file:')) {
  const dir = path.dirname(config.dbUrl.slice('file:'.length));
  fs.mkdirSync(dir, { recursive: true });
}

const client = createClient({
  url: config.dbUrl,
  authToken: config.dbToken,
});

let ready = null;

/** Tunggu inisialisasi schema selesai. */
function init() {
  if (ready) return ready;
  ready = (async () => {
    for (const sql of SCHEMA) {
      await client.execute(sql);
    }
    log.ok('Database siap', { url: config.dbUrl.startsWith('file:') ? 'local file' : 'remote' });
  })().catch((err) => {
    ready = null;
    throw err;
  });
  return ready;
}

/**
 * Helper query. Selalu await init() supaya schema dijamin ada.
 * @returns {Promise<Array<Object>>} rows
 */
async function all(sql, args = []) {
  await init();
  const res = await client.execute({ sql, args });
  return res.rows;
}

async function get(sql, args = []) {
  const rows = await all(sql, args);
  return rows[0] || null;
}

async function run(sql, args = []) {
  await init();
  const res = await client.execute({ sql, args });
  return { changes: res.rowsAffected, lastId: Number(res.lastInsertRowid || 0) };
}

/** Batch dalam satu transaksi. */
async function batch(statements) {
  await init();
  return client.batch(statements, 'write');
}

module.exports = { client, init, all, get, run, batch };
