const cron = require('node-cron');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

const { LedgerScan, AttendanceSession } = require('../models');
const memberService = require('../services/memberService');
const { Op } = require('sequelize');

// Daily 2am — remove stale unconfirmed scans older than 7 days
const initCron = () => {
  cron.schedule('0 2 * * *', async () => {
    try {
      const cutoff = dayjs.utc().subtract(7, 'day').toDate();
      await LedgerScan.destroy({
        where: {
          confirmed: false,
          scanned_at: { [Op.lt]: cutoff }
        }
      });
      console.log('[CRON] Stale unconfirmed LedgerScans cleaned up');
    } catch (err) {
      console.error('[CRON] LedgerScan cleanup failed:', err.message);
    }
  });

  // Auto-expire members whose expiry date has passed — runs every hour
  cron.schedule('0 * * * *', async () => {
    try {
      const [count] = await memberService.autoExpireMembers();
      if (count > 0) console.log(`[CRON] Auto-expired ${count} members`);
    } catch (err) {
      console.error('[CRON] Auto-expire error:', err.message);
    }
  });

  // Auto checkout members after 1 hour — runs every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    try {
      const oneHourAgo = dayjs.utc().subtract(1, 'hour').toDate();
      await AttendanceSession.update(
        { check_out_time: dayjs.utc().toDate() },
        {
          where: {
            check_out_time: null,
            check_in_time: { [Op.lte]: oneHourAgo }
          }
        }
      );
    } catch (err) {
      console.error('[CRON] Auto-checkout cron error:', err.message);
    }
  });

  console.log('[CRON] Worker initialized.');
};

module.exports = initCron;
