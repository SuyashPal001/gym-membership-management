const express = require('express');
const router = express.Router();
const reminderService = require('../services/reminderService');

const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// GET /api/reminders/:gym_id — Get upcoming queue
router.get('/:gym_id', async (req, res) => {
  try {
    const { gym_id } = req.params;
    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }

    const reminders = await reminderService.getUpcoming(gym_id);
    res.json({ success: true, data: reminders });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/reminders/:gym_id/history — Get sent reminders
router.get('/:gym_id/history', async (req, res) => {
  try {
    const { gym_id } = req.params;
    const { member_id } = req.query;

    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }

    if (member_id && !uuidRegex.test(member_id)) {
      return res.status(400).json({ success: false, message: 'Invalid member_id format' });
    }

    const history = await reminderService.getHistory(gym_id, member_id);
    res.json({ success: true, data: history });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/reminders/:gym_id/:member_id — Manual immediate trigger
router.post('/:gym_id/:member_id', async (req, res) => {
  try {
    const { gym_id, member_id } = req.params;
    const { method } = req.body;

    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }
    if (!uuidRegex.test(member_id)) {
      return res.status(400).json({ success: false, message: 'Invalid member_id format' });
    }

    const validMethods = ['WHATSAPP', 'AI_CALL'];
    if (!validMethods.includes(method)) {
      return res.status(400).json({ success: false, message: 'Invalid method. Use WHATSAPP or AI_CALL' });
    }

    const reminder = await reminderService.createManual(gym_id, member_id, method);
    res.status(201).json({ success: true, data: reminder });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/reminders/:gym_id/:reminder_uuid — Cancel reminder logicsically
router.delete('/:gym_id/:reminder_uuid', async (req, res) => {
  try {
    const { gym_id, reminder_uuid } = req.params;

    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }
    if (!uuidRegex.test(reminder_uuid)) {
      return res.status(400).json({ success: false, message: 'Invalid reminder UUID format' });
    }

    const result = await reminderService.cancelReminder(gym_id, reminder_uuid);
    if (!result) {
      return res.status(404).json({ success: false, message: 'Reminder not found' });
    }

    res.json({ success: true, message: 'Reminder cancelled successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
