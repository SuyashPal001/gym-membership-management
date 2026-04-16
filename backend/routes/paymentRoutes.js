const express = require('express');
const router = express.Router();
const memberService = require('../services/memberService');

// GET /api/payments (formerly /api/payments/:gym_id)
// Uses req.gymId from resolveGymId middleware
router.get('/', async (req, res) => {
  try {
    const { expiry_filter } = req.query;
    
    if (expiry_filter) {
      const validFilters = ['today', 'this_week', 'overdue'];
      if (!validFilters.includes(expiry_filter)) {
        return res.status(400).json({ success: false, message: 'Invalid expiry_filter value' });
      }
    }

    const members = await memberService.getPaymentSummaries(req.gymId, expiry_filter);
    res.json({ success: true, data: members });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST or PATCH /api/payments/:member_id (formerly /api/payments/:gym_id/:member_id)
// Uses req.gymId from resolveGymId middleware
router.post('/:member_id', async (req, res) => {
  try {
    const { member_id } = req.params;
    const member = await memberService.processPaymentReceived(req.gymId, member_id);
    res.json({ success: true, data: member });
  } catch (err) {
    const statusCode = err.message.includes('not found') ? 404 : 500;
    res.status(statusCode).json({ success: false, message: err.message });
  }
});

// Adding compatibility for PATCH as well
router.patch('/:member_id', async (req, res) => {
  try {
    const { member_id } = req.params;
    const member = await memberService.processPaymentReceived(req.gymId, member_id);
    res.json({ success: true, data: member });
  } catch (err) {
    const statusCode = err.message.includes('not found') ? 404 : 500;
    res.status(statusCode).json({ success: false, message: err.message });
  }
});

module.exports = router;
