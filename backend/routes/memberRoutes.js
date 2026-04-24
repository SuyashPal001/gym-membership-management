const express = require('express');
const router = express.Router();
const memberService = require('../services/memberService');
const { WorkflowReminder, Member, AttendanceSession, Payment, MembershipType } = require('../models');
const { Op } = require('sequelize');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

const { memberValidationRules, validate } = require('../middleware/validators');

// ─── Membership Types ─────────────────────────────────────────────────────────

// GET /api/members/membership-types
router.get('/membership-types', async (req, res) => {
  try {
    const types = await memberService.getMembershipTypes(req.gymId);
    console.log(`[membership-types] gymId=${req.gymId} → ${types.length} plans`);
    res.json({ success: true, data: types });
  } catch (err) {
    console.error(`[membership-types] ERROR gymId=${req.gymId}:`, err.message);
    res.status(400).json({ success: false, message: err.message });
  }
});


// POST /api/members/membership-types
router.post('/membership-types', async (req, res) => {
  try {
    const { name, amount, duration_months } = req.body;
    if (!name || !amount || !duration_months) {
      return res.status(400).json({
        success: false,
        message: 'name, amount and duration_months are required'
      });
    }
    const { MembershipType } = require('../models');
    const type = await MembershipType.create({
      gym_id: req.gymId,
      name,
      amount,
      duration_months
    });
    res.status(201).json({ success: true, data: type });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// ─── Members ──────────────────────────────────────────────────────────────────

// POST /api/members — Enroll new member
router.post('/', memberValidationRules, validate, async (req, res) => {
  console.log('[enroll] body:', JSON.stringify(req.body));
  try {
    const payload = { ...req.body, gym_id: req.gymId };
    const member = await memberService.createMember(payload);
    res.status(201).json({ success: true, data: member });
  } catch (err) {
    console.error('[enroll] error:', err.message);
    res.status(400).json({ success: false, message: err.message });
  }
});

// GET /api/members (formerly /api/members/:gym_id) — Get all members of a gym
router.get('/', async (req, res) => {
  try {
    const { status, membership_type_id, expiring_in } = req.query;
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

    const members = await memberService.getAllMembers(req.gymId, { status, membership_type_id, expiring_in });
    res.json({ success: true, data: members });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/members/attention
router.get('/attention', async (req, res) => {
  try {
    const today = dayjs.utc().format('YYYY-MM-DD');
    const in2Days = dayjs.utc().add(2, 'day').format('YYYY-MM-DD');

    // Group 1 — Expiring in 1–2 days (non-trial active members only)
    const expiring = await Member.findAll({
      where: {
        gym_id: req.gymId,
        status: 'active',
        is_trial: false,
        expiry_date: {
          [Op.gte]: today,
          [Op.lte]: in2Days
        }
      },
      include: [{ model: MembershipType, as: 'MembershipType', attributes: ['name'] }],
      order: [['expiry_date', 'ASC']]
    });

    // Group 2 — Overdue (expired status or active with past expiry)
    const overdue = await Member.findAll({
      where: {
        gym_id: req.gymId,
        [Op.or]: [
          { status: 'expired' },
          {
            status: 'active',
            expiry_date: { [Op.lt]: today }
          }
        ]
      },
      include: [{ model: MembershipType, as: 'MembershipType', attributes: ['name'] }],
      order: [['expiry_date', 'ASC']]
    });

    const combinedList = [
      ...expiring.map(m => ({ ...m.toJSON(), label: 'expiring' })),
      ...overdue.map(m => ({ ...m.toJSON(), label: 'overdue' })),
    ];

    res.json({
      success: true,
      data: combinedList.map(m => ({
        id: m.id,
        member_name: m.member_name,
        phone: m.phone,
        expiry_date: m.expiry_date,
        status: m.status,
        is_trial: m.is_trial,
        label: m.label,
        membership_type: m.MembershipType?.name || null
      }))
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/members/growth — Last 3 months enrollment trend + status breakdown
router.get('/growth', async (req, res) => {
  try {
    const data = await memberService.getMemberGrowth(req.gymId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/members/:id (formerly /api/members/:gym_id/:id) — Get single member
router.get('/:id', async (req, res) => {
  try {
    const member = await memberService.getMemberById(req.params.id, req.gymId);
    res.json({ success: true, data: member });
  } catch (err) {
    res.status(404).json({ success: false, message: err.message });
  }
});

// PUT /api/members/:id — Update member details
router.put('/:id', async (req, res) => {
  try {
    const member = await memberService.updateMember(req.params.id, req.gymId, req.body);
    res.json({ success: true, data: member });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/members/:id/renew — Renew membership
router.post('/:id/renew', async (req, res) => {
  try {
    const member = await memberService.renewMembership(
      req.params.id,
      req.gymId,
      req.body.membership_type_id
    );
    res.json({ success: true, data: member });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// DELETE /api/members/:id — Delete member
router.delete('/:id', async (req, res) => {
  try {
    const result = await memberService.deleteMember(req.params.id, req.gymId);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// POST /api/members/:id/reminders/manual
router.post('/:id/reminders/manual', async (req, res) => {
  try {
    const member = await Member.findOne({ where: { id: req.params.id, gym_id: req.gymId } });
    if (!member) return res.status(404).json({ success: false, message: 'Member not found' });

    const { method, scheduled_date, payload } = req.body;
    const reminder = await WorkflowReminder.create({
      member_id: req.params.id,
      gym_id: req.gymId,
      method: method || 'WHATSAPP',
      scheduled_date: dayjs.utc(scheduled_date).toDate(),
      payload: payload || {}
    });
    res.status(201).json({ success: true, data: reminder });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
});

// GET /api/members/:member_id/attendance-summary
router.get('/:member_id/attendance-summary', async (req, res) => {
  try {
    const { member_id } = req.params;
    const member = await Member.findOne({ where: { id: member_id, gym_id: req.gymId } });
    if (!member) throw new Error('Member not found');

    const [total_visits, lastSession, currentPaymentsLtv] = await Promise.all([
      AttendanceSession.count({ where: { member_id } }),
      AttendanceSession.findOne({
        where: { member_id },
        order: [['check_in_time', 'DESC']]
      }),
      Payment.sum('amount', {
        where: { member_id, status: 'paid' }
      })
    ]);

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

// GET /api/members/:member_id/attendance-history
router.get('/:member_id/attendance-history', async (req, res) => {
  try {
    const { member_id } = req.params;
    const sessions = await AttendanceSession.findAll({
      where: { member_id, gym_id: req.gymId }, // Security: scope history to gym
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
