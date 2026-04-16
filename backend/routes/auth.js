const express = require('express');
const router = express.Router();
const { Gym } = require('../models');
const cognitoAuth = require('../middleware/cognitoAuth');
const resolveGymId = require('../middleware/resolveGymId');

// POST /api/auth/setup
// Protected by cognitoAuth only
router.post('/setup', cognitoAuth, async (req, res) => {
  try {
    const { gym_name, owner_name, phone, city, state } = req.body;
    const cognito_sub = req.cognitoSub;

    // Use findOrCreate for guaranteed atomicity and idempotency
    const [gym, created] = await Gym.findOrCreate({
      where: { cognito_sub },
      defaults: {
        gym_name,
        owner_name,
        phone,
        city,
        state,
        owner_email: req.cognitoEmail || null
      }
    });

    res.status(created ? 201 : 200).json({
      success: true,
      message: created ? 'Gym created successfully' : 'Gym already set up',
      data: {
        gym_id: gym.id,
        gym_name: gym.gym_name,
        owner_name: gym.owner_name
      }
    });

  } catch (err) {
    console.error('Gym Setup Error:', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/auth/me
// Protected by both cognitoAuth and resolveGymId
router.get('/me', cognitoAuth, resolveGymId, async (req, res) => {
  try {
    res.json({ success: true, data: req.gym });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
