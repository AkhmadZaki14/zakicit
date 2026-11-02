'use strict';

const db = require('../db');

/** Timeline event untuk fleet atau satu bot. */
async function listEvents({ userId = null, type = null, limit = 100, since = null } = {}) {
  const lim = Math.min(500, Math.max(1, Number(limit) || 100));
  const clauses = [];
  const args = [];

  if (userId) {
    clauses.push('e.user_id = ?');
    args.push(Number(userId));
  }
  if (type) {
    clauses.push('e.type = ?');
    args.push(String(type));
  }
  if (since) {
    clauses.push('e.ts >= ?');
    args.push(Number(since));
  }

  const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
  const rows = await db.all(
    `SELECT e.id, e.user_id AS userId, w.name, e.ts, e.type, e.message, e.meta
     FROM events e LEFT JOIN workers w ON w.user_id = e.user_id
     ${where} ORDER BY e.ts DESC LIMIT ?`,
    [...args, lim],
  );

  return rows.map((r) => ({ ...r, meta: safeJson(r.meta) }));
}

async function eventTypes() {
  const rows = await db.all('SELECT type, COUNT(*) AS n FROM events GROUP BY type ORDER BY n DESC');
  return rows.map((r) => ({ type: r.type, count: Number(r.n) }));
}

function safeJson(t) {
  try {
    return JSON.parse(t);
  } catch {
    return {};
  }
}

module.exports = { listEvents, eventTypes };
