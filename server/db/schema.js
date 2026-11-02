'use strict';

/**
 * Tabel & migrasi. Aman dijalankan berulang (idempotent).
 *
 * workers       : satu baris per userID (sumber kebenaran fleet)
 * samples       : time-series mentah (gems/rate/ping) — retensi 7 hari
 * samples_minute: agregasi per menit — retensi 30 hari
 * events        : timeline (online/offline/restart/stuck/dup/...)
 * settings      : key-value JSON
 */

const SCHEMA = [
  `CREATE TABLE IF NOT EXISTS workers (
    user_id           INTEGER PRIMARY KEY,
    name              TEXT    NOT NULL DEFAULT '',
    world             TEXT    NOT NULL DEFAULT '',
    activity          TEXT    NOT NULL DEFAULT '',
    level             INTEGER NOT NULL DEFAULT 0,
    gems              INTEGER NOT NULL DEFAULT 0,
    dl                INTEGER NOT NULL DEFAULT 0,
    bgl               INTEGER NOT NULL DEFAULT 0,
    backpack_used     INTEGER NOT NULL DEFAULT 0,
    backpack_total    INTEGER NOT NULL DEFAULT 0,
    ping_ms           INTEGER NOT NULL DEFAULT 0,
    uptime_sec        INTEGER NOT NULL DEFAULT 0,
    disconnects       INTEGER NOT NULL DEFAULT 0,

    instance_id       TEXT    NOT NULL DEFAULT '',
    seq               INTEGER NOT NULL DEFAULT 0,

    -- machine state
    state             TEXT    NOT NULL DEFAULT 'OFFLINE',
    online_streak     INTEGER NOT NULL DEFAULT 0,
    duplicate_flag    INTEGER NOT NULL DEFAULT 0,
    duplicate_instances TEXT  NOT NULL DEFAULT '[]',
    rejected_heartbeats INTEGER NOT NULL DEFAULT 0,

    first_seen        INTEGER NOT NULL DEFAULT 0,
    last_seen         INTEGER NOT NULL DEFAULT 0,
    last_state_change INTEGER NOT NULL DEFAULT 0,
    session_started   INTEGER NOT NULL DEFAULT 0,
    restart_count     INTEGER NOT NULL DEFAULT 0,
    archived          INTEGER NOT NULL DEFAULT 0,

    -- analytics cache
    rate_5m           REAL NOT NULL DEFAULT 0,
    rate_15m          REAL NOT NULL DEFAULT 0,
    rate_60m          REAL NOT NULL DEFAULT 0,
    rate_60m_prev     REAL NOT NULL DEFAULT 0,
    gems_today        INTEGER NOT NULL DEFAULT 0,
    gems_24h          INTEGER NOT NULL DEFAULT 0,
    today_day         TEXT    NOT NULL DEFAULT '',
    stuck_flag        INTEGER NOT NULL DEFAULT 0,
    drop_flag         INTEGER NOT NULL DEFAULT 0,
    target_gems       INTEGER NOT NULL DEFAULT 0
  )`,

  `CREATE TABLE IF NOT EXISTS samples (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id   INTEGER NOT NULL,
    ts        INTEGER NOT NULL,
    gems      INTEGER NOT NULL,
    ping_ms   INTEGER NOT NULL DEFAULT 0,
    rate      REAL    NOT NULL DEFAULT 0
  )`,
  `CREATE INDEX IF NOT EXISTS idx_samples_user_ts ON samples(user_id, ts)`,

  `CREATE TABLE IF NOT EXISTS samples_minute (
    user_id  INTEGER NOT NULL,
    minute   INTEGER NOT NULL,
    gems     INTEGER NOT NULL,
    ping_ms  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, minute)
  )`,
  `CREATE INDEX IF NOT EXISTS idx_samples_minute_ts ON samples_minute(minute)`,

  `CREATE TABLE IF NOT EXISTS events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER NOT NULL,
    ts         INTEGER NOT NULL,
    type       TEXT    NOT NULL,
    message    TEXT    NOT NULL DEFAULT '',
    meta       TEXT    NOT NULL DEFAULT '{}'
  )`,
  `CREATE INDEX IF NOT EXISTS idx_events_user_ts ON events(user_id, ts)`,
  `CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts)`,

  `CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )`,
];

module.exports = { SCHEMA };
