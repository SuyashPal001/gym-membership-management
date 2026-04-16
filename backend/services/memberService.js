const { Member, MembershipType, Payment, AttendanceSession } = require('../models/Member');
const WorkflowReminder = require('../models/WorkflowReminder');
const { Op } = require('sequelize');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Calculate expiry date based on membership type duration
const calculateExpiryDate = (joinDate, durationMonths) => {
  // BUG 1 & 3 FIX: Use dayjs.utc() for addition to avoid setMonth edge cases
  return dayjs.utc(joinDate).add(durationMonths, 'month').toDate();
};

// Validate email format
const validateEmail = (email) => {
  if (!email) return true;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

// Check if membership is expiring within 30 days (ERPNext renewal logic)
const isExpiringWithin30Days = (expiryDate) => {
  if (!expiryDate) return true;
  const today = dayjs.utc(); // BUG 1 FIX: Use UTC
  const expiry = dayjs.utc(expiryDate); // BUG 1 FIX: Use UTC
  const diffDays = Math.ceil(expiry.diff(today, 'day', true));
  return diffDays <= 30;
};

// ─── Service ──────────────────────────────────────────────────────────────────

const memberService = {

  // Create new member enrollment
  createMember: async (data) => {
    const { gym_id, member_name, phone, email, avatar, membership_type_id, is_trial, payment_collected } = data;

    // Validations
    if (!member_name || !phone || !gym_id) {
      throw new Error('Name, phone and gym_id are required');
    }
    if (email && !validateEmail(email)) {
      throw new Error('Invalid email format');
    }

    // Check duplicate phone in same gym
    const existing = await Member.findOne({ where: { phone, gym_id } });
    if (existing) throw new Error('Member with this phone already exists');

    // Fetch membership type for expiry calculation
    let expiry_date = null;
    if (membership_type_id && !is_trial) {
      const membershipType = await MembershipType.findByPk(membership_type_id);
      if (!membershipType) throw new Error('Invalid membership type');
      expiry_date = calculateExpiryDate(dayjs.utc().toDate(), membershipType.duration_months); // BUG 1 FIX
    }

    // If trial, set 30 day expiry by default (1 month)
    if (is_trial) {
      expiry_date = calculateExpiryDate(dayjs.utc().toDate(), 1); // BUG 1 FIX
    }

    const member = await Member.create({
      gym_id,
      member_name,
      phone,
      email,
      avatar,
      membership_type_id: is_trial ? null : membership_type_id,
      join_date: dayjs.utc().toDate(), // BUG 1 FIX
      expiry_date,
      status: is_trial ? 'trial' : 'active',
      is_trial,
      payment_collected,
    });

    // MODE 2: AUTO REMINDERS (Execute async without blocking the response)
    if (expiry_date) {
      const expiryDayjs = dayjs.utc(expiry_date);
      await WorkflowReminder.bulkCreate([
        {
          member_id: member.id,
          gym_id: gym_id,
          method: 'WHATSAPP',
          scheduled_date: expiryDayjs.subtract(7, 'day').toDate(),
          payload: { message: "Your membership expires in 7 days!" }
        },
        {
          member_id: member.id,
          gym_id: gym_id,
          method: 'AI_CALL',
          scheduled_date: expiryDayjs.subtract(3, 'day').toDate(),
          payload: { guestName: member.member_name, type: "expiry_warning" }
        }
      ]);
    }

    return member;
  },

  // Get all members of a gym with specific UI fields and optional filters
  getAllMembers: async (gym_id, filters = {}) => {
    const { status, membership_type_id, expiring_in } = filters;
    const where = { gym_id };

    if (status) {
      where.status = status;
    }

    if (membership_type_id) {
      where.membership_type_id = membership_type_id;
    }

    if (expiring_in) {
      const todayStart = dayjs.utc().startOf('day');
      const todayEnd = dayjs.utc().endOf('day');

      if (expiring_in === 'today') {
        where.expiry_date = {
          [Op.between]: [todayStart.format('YYYY-MM-DD'), todayEnd.format('YYYY-MM-DD')]
        };
      } else if (expiring_in === 'this_week') {
        const nextWeek = todayStart.add(7, 'day').endOf('day');
        where.expiry_date = {
          [Op.between]: [todayStart.format('YYYY-MM-DD'), nextWeek.format('YYYY-MM-DD')]
        };
      } else if (expiring_in === 'this_month') {
        const nextMonth = todayStart.add(30, 'day').endOf('day');
        where.expiry_date = {
          [Op.between]: [todayStart.format('YYYY-MM-DD'), nextMonth.format('YYYY-MM-DD')]
        };
      }
    }

    return await Member.findAll({
      where,
      attributes: [
        'id', 
        'member_name', 
        'phone', 
        'avatar', 
        'status', 
        'expiry_date', 
        'is_trial', 
        'payment_collected', 
        'join_date'
      ],
      include: [{ 
        model: MembershipType, 
        attributes: ['name'],
        required: false
      }],
      order: [['join_date', 'DESC'], ['createdAt', 'DESC']],
    });
  },

  // Get single member by ID
  getMemberById: async (id, gym_id) => {
    const member = await Member.findOne({
      where: { id, gym_id },
      include: [{ model: MembershipType, attributes: ['name', 'amount', 'duration_months'] }],
    });
    if (!member) throw new Error('Member not found');
    return member;
  },

  // Get clean member stats profile
  getMemberStats: async (id, gym_id) => {
    const member = await Member.findOne({
      where: { id, gym_id },
      include: [{ model: MembershipType, attributes: ['name', 'amount'] }],
    });
    if (!member) throw new Error('Member not found');

    const planName = member.MembershipType ? member.MembershipType.name : (member.is_trial ? 'Free Trial' : 'No Plan');
    const planAmount = member.MembershipType ? `₹${member.MembershipType.amount}` : '₹0.00';

    return {
      join_date: member.join_date,
      total_visits: member.total_visits,
      lifetime_value: member.lifetime_value,
      status: member.status,
      last_arrival: member.last_arrival,
      plan_badge: `${planName} - ${planAmount}`
    };
  },

  // Renew membership (blocks renewal if not expiring within 30 days — ERPNext logic)
  renewMembership: async (id, gym_id, membership_type_id) => {
    const member = await Member.findOne({ where: { id, gym_id } });
    if (!member) throw new Error('Member not found');

    if (!isExpiringWithin30Days(member.expiry_date)) {
      throw new Error('Membership cannot be renewed — not expiring within 30 days');
    }

    const membershipType = await MembershipType.findByPk(membership_type_id);
    if (!membershipType) throw new Error('Invalid membership type');

    const newExpiry = calculateExpiryDate(new Date(), membershipType.duration_months);

    await member.update({
      membership_type_id,
      expiry_date: newExpiry,
      status: 'active',
      is_trial: false,
      payment_collected: true,
      last_payment_date: dayjs.utc().toDate(),
      lifetime_value: member.lifetime_value + membershipType.amount
    });

    // Clear old reminders and setup new ones
    await WorkflowReminder.update(
      { cancelled: true },
      { where: { member_id: id, scheduled: false } }
    );

    const expiryDayjs = dayjs.utc(newExpiry);
    await WorkflowReminder.bulkCreate([
      {
        member_id: member.id,
        gym_id: gym_id,
        method: 'WHATSAPP',
        scheduled_date: expiryDayjs.subtract(7, 'day').toDate(),
        payload: { message: "Your membership expires in 7 days!" }
      },
      {
        member_id: member.id,
        gym_id: gym_id,
        method: 'AI_CALL',
        scheduled_date: expiryDayjs.subtract(3, 'day').toDate(),
        payload: { guestName: member.member_name, type: "expiry_warning" }
      }
    ]);

    return member;
  },

  // Update member details
  updateMember: async (id, gym_id, data) => {
    const member = await Member.findOne({ where: { id, gym_id } });
    if (!member) throw new Error('Member not found');
    if (data.email && !validateEmail(data.email)) throw new Error('Invalid email format');
    await member.update(data);
    return member;
  },

  // Delete member
  deleteMember: async (id, gym_id) => {
    const member = await Member.findOne({ where: { id, gym_id } });
    if (!member) throw new Error('Member not found');
    await member.destroy();
    return { message: 'Member deleted successfully' };
  },

  // Get all membership types
  getMembershipTypes: async (gymId) => {
    // BUG 5 FIX: Added gymId parameter and where clause for isolation
    return await MembershipType.findAll({ 
      where: { gym_id: gymId },
      order: [['amount', 'ASC']] 
    });
  },

  // Auto-expire members whose expiry date has passed (run as a cron job)
  autoExpireMembers: async () => {
    // BUG 1 FIX: Use dayjs.utc()
    const today = dayjs.utc().format('YYYY-MM-DD');
    const updated = await Member.update(
      { status: 'expired' },
      {
        where: {
          expiry_date: { [Op.lt]: today },
          status: { [Op.in]: ['active', 'trial'] },
        },
      }
    );
    return updated;
  },
  
  // --- Payment Operations ---

  // Get members with payment-specific attributes for audit view
  getPaymentSummaries: async (gym_id, expiry_filter = null) => {
    const where = { gym_id };

    if (expiry_filter) {
      const todayStart = dayjs.utc().startOf('day');
      const todayEnd = dayjs.utc().endOf('day');

      if (expiry_filter === 'today') {
        where.expiry_date = {
          [Op.between]: [todayStart.format('YYYY-MM-DD'), todayEnd.format('YYYY-MM-DD')]
        };
      } else if (expiry_filter === 'this_week') {
        const nextWeek = todayStart.add(7, 'day').endOf('day');
        where.expiry_date = {
          [Op.between]: [todayStart.format('YYYY-MM-DD'), nextWeek.format('YYYY-MM-DD')]
        };
      } else if (expiry_filter === 'overdue') {
        where.expiry_date = { [Op.lt]: todayStart.format('YYYY-MM-DD') };
        where.payment_collected = false;
      }
    }

    return await Member.findAll({
      where,
      attributes: [
        'id',
        'member_name',
        'phone',
        'payment_collected',
        'last_payment_date',
        'lifetime_value',
        'expiry_date',
        'status'
      ],
      include: [{
        model: MembershipType,
        attributes: ['name', 'amount'],
        required: false
      }],
      order: [['payment_collected', 'ASC'], ['member_name', 'ASC']]
    });
  },

  // Idempotent payment recording: set collected=true and increment lifetime_value
  processPaymentReceived: async (gym_id, member_id) => {
    const member = await Member.findOne({
      where: { id: member_id, gym_id },
      include: [{ model: MembershipType }]
    });

    if (!member) throw new Error('Member not found');

    // If already marked as collected, return early (idempotent)
    if (member.payment_collected) {
      return member;
    }

    const planAmount = member.MembershipType ? member.MembershipType.amount : 0;
    
    // Create new Payment record for audit
    await Payment.create({
      gym_id,
      member_id,
      amount: planAmount,
      status: 'paid',
      payment_date: dayjs.utc().toDate(),
    });

    await member.update({
      payment_collected: true,
      last_payment_date: dayjs.utc().toDate(),
      lifetime_value: member.lifetime_value + planAmount
    });

    return member;
  }
};

module.exports = memberService;
