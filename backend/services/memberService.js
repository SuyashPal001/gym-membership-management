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

const getDayDiffFromToday = (dateValue) => {
  if (!dateValue) return null;
  const target = dayjs.utc(dateValue).startOf('day');
  if (!target.isValid()) return null;
  return target.diff(dayjs.utc().startOf('day'), 'day');
};

// Returns 'inactive' for expired members whose plan ended >30 days ago
const getEffectiveStatus = (member) => {
  if (member.status === 'expired' && member.expiry_date) {
    const diff = getDayDiffFromToday(member.expiry_date); // negative = past
    if (diff !== null && diff < -30) return 'inactive';
  }
  return member.status;
};

const buildUrgencyLabel = ({ status, expiryDate, lifetimeValue = 0, joinDate }) => {
  const difference = getDayDiffFromToday(expiryDate);

  if (status === 'trial') {
    if (difference === null || difference >= 0) return 'TRIAL ONGOING';
    const days = Math.abs(difference);
    return `TRIAL OVERDUE ${days} ${days === 1 ? 'DAY' : 'DAYS'}`;
  }

  // Type 3: never paid — overdue from enrollment day
  if (lifetimeValue === 0) {
    const enrolledAt = joinDate ? dayjs.utc(joinDate).startOf('day') : null;
    const overdueDays = enrolledAt ? dayjs.utc().startOf('day').diff(enrolledAt, 'day') : 0;
    if (overdueDays === 0) return 'DUE TODAY';
    return `OVERDUE ${overdueDays} ${overdueDays === 1 ? 'DAY' : 'DAYS'}`;
  }

  if (difference === null) return 'NO EXPIRY';
  if (difference === 0) return 'DUE TODAY';
  if (difference === 1) return 'DUE TOMORROW';
  if (difference === -1) return 'OVERDUE 1 DAY';
  if (difference < -1) return `OVERDUE ${Math.abs(difference)} DAYS`;
  if (difference > 1 && difference < 31) return `DUE IN ${difference} DAYS`;

  return dayjs.utc(expiryDate).format('YYYY-MM-DD');
};

const formatDisplayPlanName = (member) => {
  if (member.status === 'trial') {
    const difference = getDayDiffFromToday(member.expiry_date);
    if (difference !== null && difference < 0) {
      return `Trial Overdue by ${Math.abs(difference)} days`;
    }
    return 'Ongoing Trial';
  }

  const months = member.MembershipType?.duration_months;
  if (months) return `${months} Month`;
  return member.MembershipType?.name ?? '—';
};

const buildPaymentSummaryViewModel = (member) => {
  const plainMember = member.get({ plain: true });
  const hasMembershipPlan = !!plainMember.MembershipType;
  const lifecycleType = plainMember.status === 'trial'
    ? 'trial'
    : hasMembershipPlan
      ? 'plan_due'
      : 'unplanned';

  return {
    ...plainMember,
    has_membership_plan: hasMembershipPlan,
    lifecycle_type: lifecycleType,
    primary_action: plainMember.status === 'trial' ? 'convert' : 'mark_paid',
    display_plan_name: formatDisplayPlanName(plainMember),
    display_amount: plainMember.status === 'trial'
      ? null
      : (hasMembershipPlan ? plainMember.MembershipType.amount : 0),
    urgency_label: buildUrgencyLabel({
      status: plainMember.status,
      expiryDate: plainMember.expiry_date,
      lifetimeValue: plainMember.lifetime_value,
      joinDate: plainMember.join_date,
    }),
  };
};

// ─── Service ──────────────────────────────────────────────────────────────────

const memberService = {

  // Create new member enrollment
  createMember: async (data) => {
    const { gym_id, member_name, phone, email, membership_type_id, is_trial, payment_collected } = data;

    // Validations
    if (!member_name || !phone || !gym_id) {
      throw new Error('Name, phone and gym_id are required');
    }
    if (email && !validateEmail(email)) {
      throw new Error('Invalid email format');
    }

    // Enforce that member must either have a membership plan or be a trial
    if (!is_trial && !membership_type_id) {
      throw new Error('Member must either have a membership plan or be enrolled as a trial');
    }

    // Check duplicate phone in same gym
    const existing = await Member.findOne({ where: { phone, gym_id } });
    if (existing) throw new Error('Member with this phone already exists');

    // Fetch membership type for expiry calculation
    let expiry_date = null;
    let membershipType = null;
    if (membership_type_id && !is_trial) {
      membershipType = await MembershipType.findByPk(membership_type_id);
      if (!membershipType) throw new Error('Invalid membership type');
      expiry_date = calculateExpiryDate(dayjs.utc().toDate(), membershipType.duration_months); // BUG 1 FIX
    }

    // Trials expire after 1 day
    if (is_trial) {
      expiry_date = dayjs.utc().add(1, 'day').toDate();
    }

    const initialLtv = (payment_collected && membershipType && !is_trial) 
      ? membershipType.amount 
      : 0;

    const firstLetter = member_name.trim().charAt(0).toUpperCase();

    const member = await Member.create({
      gym_id,
      member_name,
      phone,
      email,
      avatar: firstLetter,
      membership_type_id: is_trial ? null : membership_type_id,
      join_date: dayjs.utc().toDate(), // BUG 1 FIX
      expiry_date,
      status: is_trial ? 'trial' : 'active',
      is_trial,
      payment_collected,
      lifetime_value: initialLtv,
    });

    // Create Payment record for audit trail if payment collected
    if (payment_collected && membershipType && !is_trial) {
      await Payment.create({
        gym_id,
        member_id: member.id,
        amount: membershipType.amount,
        status: 'paid',
        payment_date: dayjs.utc().toDate(),
        method: 'enrollment',
        plan_name: membershipType.name,
        membership_type_id: membershipType.id
      });
    }


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

    const raw = await Member.findAll({
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
        attributes: ['name', 'duration_months'],
        required: false
      }],
      order: [['join_date', 'DESC'], ['createdAt', 'DESC']],
    });
    return raw.map(m => {
      const plain = m.toJSON();
      plain.status = getEffectiveStatus(plain);
      return plain;
    });
  },

  // Get single member by ID
  getMemberById: async (id, gym_id) => {
    const member = await Member.findOne({
      where: { id, gym_id },
      include: [{ model: MembershipType, attributes: ['name', 'amount', 'duration_months'] }],
    });
    if (!member) throw new Error('Member not found');
    const plain = member.toJSON();
    plain.status = getEffectiveStatus(plain);
    return plain;
  },

  // Renew membership (blocks renewal if not expiring within 30 days — ERPNext logic)
  renewMembership: async (id, gym_id, membership_type_id) => {
    const member = await Member.findOne({ where: { id, gym_id } });
    if (!member) throw new Error('Member not found');
    const wasTrialConversion = member.is_trial;

    // Skip expiry check for trial members — they can convert anytime.
    // However, if already active and not a trial, enforce the 30-day renewal rule.
    if (!member.is_trial && member.status === 'active' && !isExpiringWithin30Days(member.expiry_date)) {
      throw new Error('Membership cannot be renewed — not expiring within 30 days');
    }

    const membershipType = await MembershipType.findByPk(membership_type_id);
    if (!membershipType) throw new Error('Invalid membership type');

    const newExpiry = calculateExpiryDate(dayjs.utc().toDate(), membershipType.duration_months);

    await member.update({
      membership_type_id,
      expiry_date: newExpiry,
      status: 'active',
      is_trial: false,
      payment_collected: true,
      last_payment_date: dayjs.utc().toDate(),
      lifetime_value: member.lifetime_value + membershipType.amount
    });

    await Payment.create({
      gym_id,
      member_id: member.id,
      amount: membershipType.amount,
      status: 'paid',
      payment_date: dayjs.utc().toDate(),
      method: wasTrialConversion ? 'trial_conversion' : 'renewal',
      plan_name: membershipType.name,
      membership_type_id: membershipType.id
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

    const allowed = ['member_name', 'phone', 'email', 'membership_type_id', 'notes'];
    const updates = {};
    for (const key of allowed) {
      if (data[key] !== undefined) updates[key] = data[key];
    }
    if (updates.member_name) {
      updates.avatar = updates.member_name.trim().charAt(0).toUpperCase();
    }

    await member.update(updates);
    return member;
  },

  // Delete member
  deleteMember: async (id, gym_id) => {
    const member = await Member.findOne({ where: { id, gym_id } });
    if (!member) throw new Error('Member not found');
    await member.destroy();
    return { message: 'Member deleted successfully' };
  },

  // Get all membership types — seeds defaults if gym has none
  getMembershipTypes: async (gymId) => {
    let types = await MembershipType.findAll({
      where: { gym_id: gymId },
      order: [['amount', 'ASC']]
    });

    if (types.length === 0) {
      await MembershipType.bulkCreate([
        { gym_id: gymId, name: '1 Month',  amount: 1000, duration_months: 1  },
        { gym_id: gymId, name: '3 Months', amount: 2500, duration_months: 3  },
        { gym_id: gymId, name: '12 Months',amount: 8000, duration_months: 12 },
      ], { ignoreDuplicates: true });

      types = await MembershipType.findAll({
        where: { gym_id: gymId },
        order: [['amount', 'ASC']]
      });
    }

    return types;
  },

  // Auto-expire members whose expiry date has passed (run as a cron job)
  autoExpireMembers: async () => {
    // BUG 1 FIX: Use dayjs.utc()
    const today = dayjs.utc().format('YYYY-MM-DD');
    const updated = await Member.update(
      {
        status: 'expired',
        payment_collected: false,
      },
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
  getPaymentSummaries: async (gym_id, expiry_filter = null, paid = false) => {
    const todayStr = dayjs.utc().startOf('day').format('YYYY-MM-DD');

    const where = paid
      ? { gym_id, payment_collected: true }
      : {
          gym_id,
          payment_collected: false,
          // Exclude ongoing trials — nothing to collect yet.
          // Only overdue trials (expiry_date < today) appear in the unpaid queue.
          [Op.or]: [
            { status: { [Op.ne]: 'trial' } },
            { expiry_date: { [Op.lt]: todayStr } },
          ],
        };

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
      }
    }

    const members = await Member.findAll({
      where,
      attributes: [
        'id',
        'member_name',
        'phone',
        'payment_collected',
        'last_payment_date',
        'lifetime_value',
        'expiry_date',
        'status',
        'join_date'
      ],
      include: [{
        model: MembershipType,
        attributes: ['name', 'amount', 'duration_months'],
        required: false
      }],
      order: [['payment_collected', 'ASC'], ['member_name', 'ASC']]
    });

    return members.map(buildPaymentSummaryViewModel);
  },

  // Idempotent payment recording: set collected=true, increment LTV, and reactivate if expired
  processPaymentReceived: async (gym_id, member_id) => {
    const member = await Member.findOne({
      where: { id: member_id, gym_id },
      include: [{ model: MembershipType }]
    });

    if (!member) throw new Error('Member not found');

    if (member.payment_collected) {
      return member;
    }

    const planAmount = member.MembershipType ? member.MembershipType.amount : 0;

    await Payment.create({
      gym_id,
      member_id,
      amount: planAmount,
      status: 'paid',
      payment_date: dayjs.utc().toDate(),
      plan_name: member.MembershipType ? member.MembershipType.name : 'Custom Plan',
      membership_type_id: member.membership_type_id
    });

    const isExpired = member.status === 'expired' ||
      (member.expiry_date && dayjs.utc(member.expiry_date).isBefore(dayjs.utc()));

    const updates = {
      payment_collected: true,
      last_payment_date: dayjs.utc().toDate(),
      lifetime_value: member.lifetime_value + planAmount,
    };

    // Reactivate and extend expiry from today when marking an expired member as paid
    if (isExpired && member.MembershipType) {
      updates.status = 'active';
      updates.expiry_date = dayjs.utc().add(member.MembershipType.duration_months, 'month').toDate();
    }

    await member.update(updates);
    return member;
  },

  // Member growth: last 3 months enrollments + current status breakdown
  getMemberGrowth: async (gym_id) => {
    const monthly = [];
    for (let i = 2; i >= 0; i--) {
      const monthStart = dayjs.utc().subtract(i, 'month').startOf('month');
      const monthEnd = dayjs.utc().subtract(i, 'month').endOf('month');
      const count = await Member.count({
        where: {
          gym_id,
          join_date: { [Op.between]: [monthStart.toDate(), monthEnd.toDate()] }
        }
      });
      monthly.push({
        month: monthStart.format('MMM YYYY'),
        month_short: monthStart.format('MMM'),
        new_members: count,
      });
    }

    const inactiveThreshold = dayjs.utc().subtract(30, 'day').startOf('day').toDate();
    const [total, active, trial, expired, inactive, nonTrialMembers] = await Promise.all([
      Member.count({ where: { gym_id } }),
      Member.count({ where: { gym_id, status: 'active' } }),
      Member.count({ where: { gym_id, status: 'trial' } }),
      Member.count({ where: { gym_id, status: 'expired', expiry_date: { [Op.gte]: inactiveThreshold } } }),
      Member.count({ where: { gym_id, status: 'expired', expiry_date: { [Op.lt]: inactiveThreshold } } }),
      Member.findAll({
        where: { gym_id, is_trial: false },
        attributes: ['lifetime_value'],
        include: [{ model: MembershipType, attributes: ['amount'], required: false }],
        raw: true,
        nest: true,
      }),
    ]);

    // For each paid member: use lifetime_value if payments were tracked,
    // otherwise use the plan amount as the minimum expected value.
    const totalLtv = nonTrialMembers.reduce((sum, m) => {
      const lv = parseFloat(m.lifetime_value) || 0;
      const planAmt = m.MembershipType ? parseFloat(m.MembershipType.amount) || 0 : 0;
      return sum + (lv > planAmt ? lv : planAmt);
    }, 0);

    return { monthly, totals: { total, active, trial, expired, inactive, total_ltv: totalLtv } };
  },

  // Total payments collected in the current calendar month
  getMonthlyStats: async (gym_id) => {
    const startOfMonth = dayjs.utc().startOf('month').toDate();
    const endOfMonth = dayjs.utc().endOf('month').toDate();

    const monthlyCollected = await Payment.sum('amount', {
      where: {
        gym_id,
        status: 'paid',
        payment_date: { [Op.between]: [startOfMonth, endOfMonth] },
      },
    });

    return { monthly_collected: monthlyCollected || 0 };
  },

  getMemberPayments: async (gym_id, member_id) => {
    const member = await Member.findOne({
      where: { id: member_id, gym_id },
      include: [{ model: MembershipType, attributes: ['name'] }]
    });

    const payments = await Payment.findAll({
      where: { gym_id, member_id },
      include: [{ model: MembershipType, attributes: ['name', 'duration_months'] }],
      order: [['payment_date', 'DESC']]
    });

    return payments.map(p => {
      const plain = p.toJSON();
      // Intelligent fallback for legacy records that don't have plan_name or membership_type_id populated
      if (!plain.plan_name && !plain.MembershipType && member && member.MembershipType) {
        plain.plan_name = member.MembershipType.name;
      }
      return plain;
    });
  },
};

module.exports = memberService;
