const express = require('express');
const router = express.Router();
const aiService = require('../services/aiService');

const { scanRateLimiter, validateImagePayload } = require('../middleware/aiControl');

// POST /api/ai/scan-book (Protected)
router.post('/scan-book', scanRateLimiter, validateImagePayload, async (req, res) => {
  try {
    const { image } = req.body;
    const data = await aiService.extractGymRecords(image);
    res.status(200).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/ai/test (Simple Connectivity Check)
router.get('/test', async (req, res) => {
  try {
    const text = await aiService.ping();
    res.status(200).json({ 
      success: true, 
      status: "Sovereign AI is ALIVE",
      aiContent: text 
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
