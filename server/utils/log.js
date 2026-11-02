'use strict';

/**
 * Log berwarna sederhana. Tidak ada dependency.
 * Dipakai untuk menandai duplikat / restart / out-of-order di konsol.
 */

const enabled = process.env.NO_COLOR !== '1';

const C = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
};

const paint = (color, text) => (enabled ? `${color}${text}${C.reset}` : text);

const ts = () => new Date().toISOString().slice(11, 23);

function line(level, color, msg, extra) {
  const head = paint(C.gray, ts());
  const tag = paint(color, level.padEnd(7));
  const body = extra ? `${msg} ${paint(C.gray, JSON.stringify(extra))}` : msg;
  // eslint-disable-next-line no-console
  console.log(`${head} ${tag} ${body}`);
}

const log = {
  info: (m, x) => line('INFO', C.blue, m, x),
  ok: (m, x) => line('OK', C.green, m, x),
  warn: (m, x) => line('WARN', C.yellow, m, x),
  error: (m, x) => line('ERROR', C.red, m, x),
  /** Duplikat instance terdeteksi */
  dup: (m, x) => line('DUPLICATE', C.magenta, m, x),
  /** Bot restart (instanceId baru) */
  restart: (m, x) => line('RESTART', C.cyan, m, x),
  /** Heartbeat ditolak karena seq out-of-order */
  ooo: (m, x) => line('OOO', C.yellow, m, x),
};

module.exports = log;
