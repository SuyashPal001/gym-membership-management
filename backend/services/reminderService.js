const { Member, WorkflowReminder } = require('../models');
const { Op } = require('sequelize');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

const reminderService = {
  // GET upcoming scheduled reminders
  getUpcoming: async (gym_id) => {
    const now = dayjs.utc().toDate();
    return await WorkflowReminder.findAll({
      where: {
        gym_id,
        scheduled: false,
        cancelled: false,
        scheduled_date: { [Op.gte]: now }
      },
      include: [{
        model: Member,
        attributes: ['member_name', 'phone']
      }],
      order: [['scheduled_date', 'ASC']]
    });
  },

  // GET history (sent) reminders
  getHistory: async (gym_id, member_id = null) => {
    const whereClause = { gym_id, scheduled: true };
    if (member_id) {
      whereClause.member_id = member_id;
    }

    const reminders = await WorkflowReminder.findAll({
      where: whereClause,
      include: [{
        model: Member,
        attributes: ['member_name', 'phone', 'last_payment_date']
      }],
      order: [['scheduled_date', 'DESC']],
      limit: 50
    });

    // Compute conversion metrics
    return reminders.map(r => {
      const reminderJson = r.toJSON();
      const member = reminderJson.Member;
      
      let paidAfterReminder = false;
      if (member && member.last_payment_date) {
        const lastPayment = dayjs.utc(member.last_payment_date);
        const scheduledTime = dayjs.utc(r.scheduled_date);
        paidAfterReminder = lastPayment.isAfter(scheduledTime);
      }

      return {
        ...reminderJson,
        paid_after_reminder: paidAfterReminder
      };
    });
  },

  // Create manual reminder record
  createManual: async (gym_id, member_id, method, payload = {}) => {
    return await WorkflowReminder.create({
      gym_id,
      member_id,
      method,
      scheduled_date: dayjs.utc().toDate(),
      scheduled: false,
      payload: { 
        source: 'MANUAL_TRIGGER',
        ...payload
      }
    });
  },

  // Logically cancel a reminder
  cancelReminder: async (gym_id, reminder_uuid) => {
    const reminder = await WorkflowReminder.findOne({
      where: { uuid: reminder_uuid, gym_id }
    });

    if (!reminder) return null;

    return await reminder.update({ cancelled: true });
  }
};

module.exports = reminderService;
