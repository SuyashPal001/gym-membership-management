const express = require('express');
const router = express.Router();
const { Gym } = require('../models');

// GET /api/gym (formerly /api/gym/:gym_id)
// Now uses req.gymId from resolveGymId middleware
router.get('/', async (req, res) => {
  try {
    const gym = await Gym.findOne({ 
      where: { id: req.gymId } 
    });
    if (!gym) return res.status(404).json({ 
      success: false, message: 'Gym not found' 
    });
    res.json({ success: true, data: gym });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/gym (formerly /api/gym/:gym_id)
// Now uses req.gymId from resolveGymId middleware
router.put('/', async (req, res) => {
  try {
    const gym = await Gym.findOne({ 
      where: { id: req.gymId } 
    });
    if (!gym) return res.status(404).json({ 
      success: false, message: 'Gym not found' 
    });
    const { owner_name, gym_name, phone, city, state } = req.body;
    await gym.update({ owner_name, gym_name, phone, city, state });
    res.json({ success: true, data: gym });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/gym
router.delete('/', async (req, res) => {
  try {
    const gym = await Gym.findOne({ where: { id: req.gymId } });
    if (!gym) return res.status(404).json({ success: false, message: 'Gym not found' });
    
    await gym.destroy();
    res.json({ success: true, message: 'Gym account deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
