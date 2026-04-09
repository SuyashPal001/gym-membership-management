const express = require('express');
const router = express.Router();
const memberService = require('../services/memberService');

const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// GET /api/payments/:gym_id — Get all members with payment status/lifetime value
router.get('/:gym_id', async (req, res) => {
  try {
    const { gym_id } = req.params;
    const { expiry_filter } = req.query;
    
    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }

    if (expiry_filter) {
      const validFilters = ['today', 'this_week', 'overdue'];
      if (!validFilters.includes(expiry_filter)) {
        return res.status(400).json({ success: false, message: 'Invalid expiry_filter value' });
      }
    }

    const members = await memberService.getPaymentSummaries(gym_id, expiry_filter);
    res.json({ success: true, data: members });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PATCH /api/payments/:gym_id/:member_id — Mark payment as received
router.patch('/:gym_id/:member_id', async (req, res) => {
  try {
    const { gym_id, member_id } = req.params;

    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }
    
    if (!uuidRegex.test(member_id)) {
      return res.status(400).json({ success: false, message: 'Invalid member_id format' });
    }

    const member = await memberService.processPaymentReceived(gym_id, member_id);
    res.json({ success: true, data: member });
  } catch (err) {
    const statusCode = err.message.includes('not found') ? 404 : 500;
    res.status(statusCode).json({ success: false, message: err.message });
  }
});

module.exports = router;
