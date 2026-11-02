'use strict';

const express = require('express');
const { validateHeartbeat } = require('../utils/validate');
const { processHeartbeat } = require('../services/workers');
const { sendAlert } = require('../services/alerts');
const { invalidateFleetCache } = require('../services/fleet');
const { limiter } = require('../utils/security');

const router = express.Router();

router.post(
  '/heartbeat',
  limiter({ windowMs: 60000, max: 600, keyPrefix: 'hb' }),
  async (req, res, next) => {
    try {
      const check = validateHeartbeat(req.body);
      if (!check.ok) {
        return res.status(400).json({ error: 'INVALID_PAYLOAD', details: check.errors });
      }

      const hb = check.data;
      const result = await processHeartbeat(hb);
      invalidateFleetCache();

      // Alert async — jangan blokir response heartbeat
      if (!result.accepted && result.reason === 'OUT_OF_ORDER') {
        // tidak perlu alert, hanya counter
      } else if (result.duplicate) {
        setImmediate(() =>
          sendAlert({
            userId: hb.userId,
            name: hb.name,
            world: hb.world,
            type: 'duplicate',
            detail: 'Dua proses bot aktif untuk User ID yang sama. Matikan salah satu.',
          }).catch(() => {}),
        );
      }

      return res.json({
        ok: true,
        accepted: result.accepted,
        reason: result.reason || null,
        state: result.state,
        duplicate: result.duplicate,
        restarted: result.restarted,
        // Bot bisa menyesuaikan interval berikutnya
        nextPollMs: 5000,
      });
    } catch (err) {
      return next(err);
    }
  },
);

module.exports = router;
