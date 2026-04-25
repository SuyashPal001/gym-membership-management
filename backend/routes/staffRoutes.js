const express = require('express');
const router = express.Router();
const staffService = require('../services/staffService');

// GET /api/staff
router.get('/', async (req, res) => {
  try {
    const data = await staffService.getAllStaff(req.gymId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/staff
router.post('/', async (req, res) => {
  console.log('[staff/add] body:', JSON.stringify(req.body), 'gymId:', req.gymId);
  try {
    const staff = await staffService.addStaff({ ...req.body, gym_id: req.gymId });
    res.status(201).json({ success: true, data: staff });
  } catch (err) {
    console.error('[staff/add] error:', err.message, err.stack);
    res.status(400).json({ success: false, message: err.message });
  }
});

// GET /api/staff/:id/stats — before /:id to avoid conflict
router.get('/:id/stats', async (req, res) => {
  try {
    const data = await staffService.getStaffStats(req.params.id, req.gymId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// PUT /api/staff/:id
router.put('/:id', async (req, res) => {
  try {
    const staff = await staffService.updateStaff(req.params.id, req.gymId, req.body);
    res.json({ success: true, data: staff });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// DELETE /api/staff/:id
router.delete('/:id', async (req, res) => {
  try {
    await staffService.deleteStaff(req.params.id, req.gymId);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/staff/:id/attendance — toggle present/absent
router.post('/:id/attendance', async (req, res) => {
  try {
    const result = await staffService.toggleAttendance(req.params.id, req.gymId);
    res.json({ success: true, data: result });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/staff/:id/salary/pay
router.post('/:id/salary/pay', async (req, res) => {
  try {
    const record = await staffService.markSalaryPaid(req.params.id, req.gymId);
    res.json({ success: true, data: record });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

module.exports = router;
