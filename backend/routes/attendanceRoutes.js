const express = require('express');
const router = express.Router();
const { Member, AttendanceSession } = require('../models');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

// POST /api/attendance/scan
// Uses req.gymId from resolveGymId middleware
router.post('/scan', async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, message: 'Phone number is required' });
    }

    // Security fix: filter member lookup by the authenticated gym
    const member = await Member.findOne({ where: { phone, gym_id: req.gymId } });
    if (!member) {
      return res.status(404).json({ success: false, message: 'Member not found in this gym' });
    }

    const today = dayjs.utc().format('YYYY-MM-DD');
    const existingSession = await AttendanceSession.findOne({ 
      where: { 
        member_id: member.id, 
        date: today 
      } 
    });

    if (!existingSession) {
      // Check-in
      const checkInTime = dayjs.utc().toDate();
      const newSession = await AttendanceSession.create({
        gym_id: req.gymId,
        member_id: member.id,
        check_in_time: checkInTime,
        date: today
      });

      // Increment total visits for the member
      await member.increment('total_visits');

      return res.json({ 
        success: true, 
        action: 'checked_in', 
        member_name: member.member_name, 
        check_in_time: newSession.check_in_time 
      });
    }

    if (existingSession.check_out_time === null) {
      // Check-out
      const checkOutTime = dayjs.utc().toDate();
      await existingSession.update({ check_out_time: checkOutTime });
      
      const duration_minutes = dayjs.utc(checkOutTime).diff(dayjs.utc(existingSession.check_in_time), 'minute');

      return res.json({ 
        success: true, 
        action: 'checked_out', 
        member_name: member.member_name, 
        check_in_time: existingSession.check_in_time, 
        check_out_time: existingSession.check_out_time,
        duration_minutes
      });
    }

    // Already completed
    return res.json({ 
      success: false, 
      message: 'Already completed session today', 
      action: 'already_done' 
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/attendance/today (formerly /api/attendance/:gym_id/today)
// Uses req.gymId from resolveGymId middleware
router.get('/today', async (req, res) => {
  try {
    const today = dayjs.utc().format('YYYY-MM-DD');
    const sessions = await AttendanceSession.findAll({
      where: { gym_id: req.gymId, date: today },
      include: [{
        model: Member,
        attributes: ['member_name', 'avatar', 'phone', 'status', 'total_visits']
      }]
    });

    const currently_in = [];
    const checked_out = [];

    sessions.forEach(session => {
      const sessionData = session.toJSON();
      if (session.check_out_time) {
        sessionData.duration_minutes = dayjs.utc(session.check_out_time).diff(dayjs.utc(session.check_in_time), 'minute');
        checked_out.push(sessionData);
      } else {
        currently_in.push(sessionData);
      }
    });

    res.json({
      success: true,
      data: {
        currently_in,
        checked_out,
        total_today: sessions.length
      }
    });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/attendance/history (formerly /api/attendance/:gym_id/history)
// Uses req.gymId from resolveGymId middleware
router.get('/history', async (req, res) => {
  try {
    const { date, member_id } = req.query;
    const where = { gym_id: req.gymId };
    
    if (date) where.date = date;
    if (member_id) {
      where.member_id = member_id;
    }

    const history = await AttendanceSession.findAll({
      where,
      include: [{
        model: Member,
        attributes: ['member_name', 'avatar', 'phone']
      }],
      order: [['date', 'DESC'], ['check_in_time', 'DESC']],
      limit: 100
    });

    res.json({ success: true, data: history });

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
