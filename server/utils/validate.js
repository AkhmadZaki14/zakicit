'use strict';

const { z } = require('zod');

/**
 * Skema validasi payload heartbeat.
 * Semua angka dipaksa integer non-negatif supaya tidak ada NaN masuk DB.
 */

const int = (max) =>
  z
    .number()
    .int()
    .min(0)
    .max(max)
    .default(0);

const heartbeatSchema = z.object({
  userId: z.coerce.number().int().positive(),
  name: z
    .string()
    .min(1)
    .max(64)
    .transform((s) => s.replace(/[\u0000-\u001f\u007f<>]/g, '').trim()),
  instanceId: z.string().min(8).max(64),
  seq: z.coerce.number().int().min(0),
  world: z
    .string()
    .max(64)
    .default('')
    .transform((s) => s.replace(/[\u0000-\u001f\u007f<>]/g, '').trim()),
  activity: z.string().max(64).default(''),
  level: int(10000),
  gems: int(1e12),
  dl: int(1e9),
  bgl: int(1e9),
  backpack: z
    .object({ used: int(10000), total: int(10000) })
    .default({ used: 0, total: 0 }),
  pingMs: int(600000),
  uptimeSec: int(1e9),
  disconnects: int(1e6),
  // diabaikan untuk keputusan status, hanya untuk deteksi drift
  clientTime: z.coerce.number().optional(),
});

const settingsSchema = z
  .object({
    gemsPerWl: z.coerce.number().optional(),
    wlPerDl: z.coerce.number().optional(),
    dlPerBgl: z.coerce.number().optional(),
    stuckMinutes: z.coerce.number().optional(),
    gemsDropPercent: z.coerce.number().optional(),
    globalTargetGems: z.coerce.number().optional(),
    pollingMs: z.coerce.number().optional(),
    numberFormat: z.enum(['full', 'compact']).optional(),
    theme: z.enum(['dark']).optional(),
    browserNotifications: z.boolean().optional(),
    alertSound: z.boolean().optional(),
    quietHours: z
      .object({
        enabled: z.boolean().optional(),
        start: z.string().optional(),
        end: z.string().optional(),
        tzOffsetMinutes: z.coerce.number().optional(),
      })
      .optional(),
  })
  .strict();

function validateHeartbeat(body) {
  const parsed = heartbeatSchema.safeParse(body);
  if (!parsed.success) {
    return { ok: false, errors: parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`) };
  }
  return { ok: true, data: parsed.data };
}

function validateSettings(body) {
  const parsed = settingsSchema.safeParse(body);
  if (!parsed.success) {
    return { ok: false, errors: parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`) };
  }
  return { ok: true, data: parsed.data };
}

module.exports = { validateHeartbeat, validateSettings, heartbeatSchema, settingsSchema };
