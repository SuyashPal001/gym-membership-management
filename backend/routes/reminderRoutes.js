const express = require('express');
const router = express.Router();
const reminderService = require('../services/reminderService');

// GET /api/reminders (formerly /api/reminders/:gym_id)
// Uses req.gymId from resolveGymId middleware
router.get('/', async (req, res) => {
  try {
    const reminders = await reminderService.getUpcoming(req.gymId);
    res.json({ success: true, data: reminders });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/reminders/history (formerly /api/reminders/:gym_id/history)
// Uses req.gymId from resolveGymId middleware
router.get('/history', async (req, res) => {
  try {
    const { member_id } = req.query;
    const history = await reminderService.getHistory(req.gymId, member_id);
    res.json({ success: true, data: history });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/reminders/:member_id (formerly /api/reminders/:gym_id/:member_id)
// Uses req.gymId from resolveGymId middleware
router.post('/:member_id', async (req, res) => {
  try {
    const { member_id } = req.params;
    const { method, payload } = req.body;

    const validMethods = ['WHATSAPP', 'AI_CALL'];
    if (!validMethods.includes(method)) {
      return res.status(400).json({ success: false, message: 'Invalid method. Use WHATSAPP or AI_CALL' });
    }

    const reminder = await reminderService.createManual(req.gymId, member_id, method, payload);
    res.status(201).json({ success: true, data: reminder });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/reminders/:reminder_uuid (formerly /api/reminders/:gym_id/:reminder_uuid)
// Uses req.gymId from resolveGymId middleware
router.delete('/:reminder_uuid', async (req, res) => {
  try {
    const { reminder_uuid } = req.params;
    const result = await reminderService.cancelReminder(req.gymId, reminder_uuid);
    if (!result) {
      return res.status(404).json({ success: false, message: 'Reminder not found' });
    }
    res.json({ success: true, message: 'Reminder cancelled successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
