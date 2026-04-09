const cron = require('node-cron');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

const WorkflowReminder = require('../models/WorkflowReminder');
const { Member } = require('../models/Member');
const { Op } = require('sequelize');
const { scheduleSMS } = require('../services/twilioProvider');
const { handleCreatePhoneCall } = require('../services/retellProvider');

async function safeIncrementRetry(reminder, label) {
  try {
    await reminder.increment('retry_count');
  } catch (e) {
    console.error(`[CRON] Could not increment retry_count for ${label}:`, e.message);
  }
}

// Emulate scheduleWhatsappReminders.ts + Cron Execution
const processReminders = async () => {
  console.log(`[CRON] Polling WorkflowReminders at ${new Date().toISOString()}`);

  try {
    // 1. SELECT FOR UPDATE (Polling the 2 hr lookahead window securely)
    const upperLimit = dayjs().add(2, 'hour').toDate();

    const unscheduledReminders = await WorkflowReminder.findAll({
      where: {
        scheduled: false,
        cancelled: false,
        retry_count: { [Op.lt]: 3 },
        scheduled_date: { [Op.lte]: upperLimit }
      },
      include: [{ model: Member, attributes: ['id', 'phone', 'member_name'] }]
    });

    if (unscheduledReminders.length === 0) return;
    console.log(`[CRON] Found ${unscheduledReminders.length} jobs to process.`);

    for (const reminder of unscheduledReminders) {
      try {
        if (!reminder.Member) {
          console.error(`[CRON] Reminder ${reminder.id} has no linked Member row; skipping.`);
          await safeIncrementRetry(reminder, reminder.id);
          continue;
        }

        const phone = reminder.Member.phone;
        if (!phone || String(phone).trim() === '') {
          console.error(`[CRON] Reminder ${reminder.id}: member has no phone; skipping.`);
          await safeIncrementRetry(reminder, reminder.id);
          continue;
        }

        let referenceId = null;

        if (reminder.method === 'WHATSAPP') {
          // Push securely to Twilio with exact 'sendAt'
          const twilioData = {
            phoneNumber: phone,
            scheduledDate: reminder.scheduled_date,
            contentSid: process.env.TWILIO_MESSAGING_SID ? "HX..." : "MOCK_SID",
            contentVariables: reminder.payload || { "1": reminder.Member.member_name }
          };
          const response = await scheduleSMS(twilioData);
          referenceId = response && response.sid ? response.sid : `MOCK_${Date.now()}`;

        } else if (reminder.method === 'AI_CALL') {
          // AI Calls execute intimately so we only run if it's PAST the target
          if (dayjs().isBefore(reminder.scheduled_date)) {
            continue; // Skip this tick, wait until the time actually passes
          }
          const callData = await handleCreatePhoneCall({
            numberToCall: phone,
            generalPrompt: "Gym membership expiring template",
            dynamicVariables: reminder.payload || { guestName: reminder.Member.member_name }
          });
          referenceId = callData && callData.callId ? callData.callId : null;
        } else {
          console.log(`[CRON] Skipping unsupported method ${reminder.method} for reminder ${reminder.id}`);
          continue;
        }

        // 2. Mark processed exactly like Cal.com updates
        await reminder.update({
          scheduled: true,
          reference_id: referenceId
        });

      } catch (err) {
        console.error(`[CRON] Error processing reminder ${reminder.id}:`, err);
        await safeIncrementRetry(reminder, reminder.id);
      }
    }
  } catch (dbErr) {
    console.error('[CRON] Database poll error:', dbErr);
  }
};

const runReminderJobSafely = () => {
  processReminders().catch((e) => {
    console.error('[CRON] Unhandled worker error (process will stay up):', e);
  });
};

// Mount cron to run every 15 minutes
const initCron = () => {
  cron.schedule('*/15 * * * *', runReminderJobSafely);

  // Sweep the backlog immediately on server start!
  setTimeout(runReminderJobSafely, 2000);

  console.log('[CRON] Scheduled Reminder Worker initialized.');
};

module.exports = initCron;
