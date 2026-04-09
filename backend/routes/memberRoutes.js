const express = require('express');
const router = express.Router();
const memberService = require('../services/memberService');
const { WorkflowReminder, Member, AttendanceSession, Payment } = require('../models');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

const { memberValidationRules, validate } = require('../middleware/validators');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ─── Multer Setup ─────────────────────────────────────────────────────────────
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = 'uploads/avatars/';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, 'avatar-' + uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('Only images are allowed'));
  }
});

// ─── Membership Types ─────────────────────────────────────────────────────────

// GET /api/members/membership-types
router.get('/membership-types', async (req, res) => {
  try {
    const types = await memberService.getMembershipTypes();
    res.json({ success: true, data: types });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// ─── Members ──────────────────────────────────────────────────────────────────

// POST /api/members — Enroll new member
router.post('/', memberValidationRules, validate, async (req, res) => {
  try {
    const member = await memberService.createMember(req.body);
    res.status(201).json({ success: true, data: member });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// GET /api/members/:gym_id — Get all members of a gym
router.get('/:gym_id', async (req, res) => {
  try {
    const { gym_id } = req.params;
    const { status, membership_type_id, expiring_in } = req.query;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    
    if (!uuidRegex.test(gym_id)) {
      return res.status(400).json({ success: false, message: 'Invalid gym_id format' });
    }
    
    if (membership_type_id && !uuidRegex.test(membership_type_id)) {
      return res.status(400).json({ success: false, message: 'Invalid membership_type_id format' });
    }

    const validStatuses = ['active', 'trial', 'expired'];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value' });
    }

    const validExpiry = ['today', 'this_week', 'this_month'];
    if (expiring_in && !validExpiry.includes(expiring_in)) {
      return res.status(400).json({ success: false, message: 'Invalid expiring_in value' });
    }

    const members = await memberService.getAllMembers(gym_id, { status, membership_type_id, expiring_in });
    res.json({ success: true, data: members });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/members/:gym_id/:id — Get single member
router.get('/:gym_id/:id', async (req, res) => {
  try {
    const member = await memberService.getMemberById(req.params.id, req.params.gym_id);
    res.json({ success: true, data: member });
  } catch (err) {
    res.status(404).json({ success: false, message: err.message });
  }
});

// PUT /api/members/:gym_id/:id — Update member details
router.put('/:gym_id/:id', memberValidationRules, validate, async (req, res) => {
  try {
    const member = await memberService.updateMember(req.params.id, req.params.gym_id, req.body);
    res.json({ success: true, data: member });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/members/:gym_id/:id/renew — Renew membership
router.post('/:gym_id/:id/renew', async (req, res) => {
  try {
    const member = await memberService.renewMembership(
      req.params.id,
      req.params.gym_id,
      req.body.membership_type_id
    );
    res.json({ success: true, data: member });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// DELETE /api/members/:gym_id/:id — Delete member
router.delete('/:gym_id/:id', async (req, res) => {
  try {
    const result = await memberService.deleteMember(req.params.id, req.params.gym_id);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// ─── Streamlined Profile Routes ──────────────────────────────────────────────────

// GET /api/members/:gym_id/:id/stats — Get simplified stats
router.get('/:gym_id/:id/stats', async (req, res) => {
  try {
    const stats = await memberService.getMemberStats(req.params.id, req.params.gym_id);
    res.json({ success: true, data: stats });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/members/:gym_id/:id/avatar — Upload avatar
router.post('/:gym_id/:id/avatar', upload.single('avatar'), async (req, res) => {
  try {
    if (!req.file) throw new Error('No file uploaded');
    const avatarUrl = `/uploads/avatars/${req.file.filename}`;
    await memberService.updateMember(req.params.id, req.params.gym_id, { avatar: avatarUrl });
    res.json({ success: true, data: { avatarUrl } });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/members/:gym_id/:id/reminders/manual — Mode 1: Manual Scheduling
router.post('/:gym_id/:id/reminders/manual', async (req, res) => {
  try {
    const { method, scheduled_date, payload } = req.body;
    const reminder = await WorkflowReminder.create({
      member_id: req.params.id,
      gym_id: req.params.gym_id,
      method: method || 'WHATSAPP',
      scheduled_date: dayjs.utc(scheduled_date).toDate(), // Lock to UTC exactly
      payload: payload || {}
    });
    res.status(201).json({ success: true, data: reminder });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// GET /api/members/:gym_id/:member_id/attendance-summary
router.get('/:gym_id/:member_id/attendance-summary', async (req, res) => {
  try {
    const { gym_id, member_id } = req.params;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    
    if (!uuidRegex.test(gym_id) || !uuidRegex.test(member_id)) {
      return res.status(400).json({ success: false, message: 'Invalid UUID format' });
    }

    const [member, total_visits, lastSession, currentPaymentsLtv] = await Promise.all([
      Member.findByPk(member_id),
      AttendanceSession.count({ where: { member_id } }),
      AttendanceSession.findOne({ 
        where: { member_id }, 
        order: [['check_in_time', 'DESC']] 
      }),
      Payment.sum('amount', { 
        where: { member_id, status: 'paid' } 
      })
    ]);

    if (!member) {
      return res.status(404).json({ success: false, message: 'Member not found' });
    }

    // Combine legacy LTV with any new Payment records
    const totalLtv = (member.lifetime_value || 0) + (currentPaymentsLtv || 0);

    res.json({ 
      success: true, 
      data: { 
        total_visits, 
        last_arrival: lastSession ? lastSession.check_in_time : null, 
        ltv: totalLtv
      } 
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/members/:gym_id/:member_id/attendance-history
router.get('/:gym_id/:member_id/attendance-history', async (req, res) => {
  try {
    const { gym_id, member_id } = req.params;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    
    if (!uuidRegex.test(gym_id) || !uuidRegex.test(member_id)) {
      return res.status(400).json({ success: false, message: 'Invalid UUID format' });
    }

    const sessions = await AttendanceSession.findAll({
      where: { member_id },
      order: [['date', 'DESC'], ['check_in_time', 'DESC']]
    });

    const formattedSessions = sessions.map(s => {
      const data = s.get({ plain: true });
      if (data.check_out_time) {
        data.duration_minutes = dayjs(data.check_out_time).diff(data.check_in_time, 'minute');
      }
      return data;
    });

    res.json({ success: true, data: formattedSessions });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
