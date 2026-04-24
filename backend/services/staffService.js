const { Staff, StaffAttendance, StaffSalary } = require('../models/Staff');
const { Op } = require('sequelize');
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);

const staffService = {

  getAllStaff: async (gym_id) => {
    const today = dayjs.utc().format('YYYY-MM-DD');
    const staff = await Staff.findAll({
      where: { gym_id, status: 'active' },
      include: [{
        model: StaffAttendance,
        where: { date: today },
        required: false,
      }],
      order: [['name', 'ASC']],
    });
    return staff.map(s => {
      const plain = s.toJSON();
      const todayRecord = plain.StaffAttendances?.[0] || null;
      return {
        ...plain,
        today_attendance: todayRecord?.status || null,
        check_in_time: todayRecord?.check_in_time || null,
        StaffAttendances: undefined,
      };
    });
  },

  addStaff: async (data) => {
    const { gym_id, name, phone, role, monthly_salary } = data;
    if (!name || !gym_id) throw new Error('Name is required');
    let formattedPhone = null;
    if (phone) {
      const digits = phone.replace(/\D/g, '');
      if (digits.length >= 10) {
        formattedPhone = `+91${digits.slice(-10)}`;
      }
    }
    if (formattedPhone) {
      const existing = await Staff.findOne({ where: { phone: formattedPhone, gym_id, status: 'active' } });
      if (existing) throw new Error('A staff member with this phone number already exists');
    }
    return await Staff.create({
      gym_id,
      name: name.trim(),
      phone: formattedPhone,
      role: role || 'Other',
      monthly_salary: monthly_salary || 0,
      join_date: dayjs.utc().format('YYYY-MM-DD'),
    });
  },

  updateStaff: async (id, gym_id, data) => {
    const staff = await Staff.findOne({ where: { id, gym_id } });
    if (!staff) throw new Error('Staff not found');
    const allowed = ['name', 'phone', 'role', 'monthly_salary'];
    const updates = Object.fromEntries(Object.entries(data).filter(([k]) => allowed.includes(k)));
    await staff.update(updates);
    return staff;
  },

  deleteStaff: async (id, gym_id) => {
    const staff = await Staff.findOne({ where: { id, gym_id } });
    if (!staff) throw new Error('Staff not found');
    await staff.update({ status: 'inactive' });
    return { message: 'Staff member removed' };
  },

  toggleAttendance: async (id, gym_id) => {
    const staff = await Staff.findOne({ where: { id, gym_id } });
    if (!staff) throw new Error('Staff not found');
    const today = dayjs.utc().format('YYYY-MM-DD');
    const existing = await StaffAttendance.findOne({ where: { staff_id: id, date: today } });

    if (!existing) {
      const record = await StaffAttendance.create({
        gym_id,
        staff_id: id,
        date: today,
        status: 'present',
        check_in_time: dayjs.utc().toDate(),
      });
      return { status: 'present', check_in_time: record.check_in_time };
    } else if (existing.status === 'present') {
      await existing.update({ status: 'absent', check_in_time: null });
      return { status: 'absent', check_in_time: null };
    } else {
      await existing.update({ status: 'present', check_in_time: dayjs.utc().toDate() });
      return { status: 'present', check_in_time: existing.check_in_time };
    }
  },

  getStaffStats: async (id, gym_id) => {
    const staff = await Staff.findOne({ where: { id, gym_id } });
    if (!staff) throw new Error('Staff not found');

    const currentMonth = dayjs.utc().format('YYYY-MM');
    const monthStart = dayjs.utc().startOf('month').format('YYYY-MM-DD');
    const today = dayjs.utc().format('YYYY-MM-DD');

    const daysPresent = await StaffAttendance.count({
      where: {
        staff_id: id,
        status: 'present',
        date: { [Op.between]: [monthStart, today] },
      },
    });

    const totalWorkingDays = dayjs.utc().date();

    const last7Dates = Array.from({ length: 7 }, (_, i) =>
      dayjs.utc().subtract(6 - i, 'day').format('YYYY-MM-DD')
    );
    const last7Records = await StaffAttendance.findAll({
      where: { staff_id: id, date: { [Op.in]: last7Dates } },
      attributes: ['date', 'status'],
    });
    const recordMap = Object.fromEntries(last7Records.map(r => [r.date, r.status]));
    const last7 = last7Dates.map(date => ({ date, status: recordMap[date] || null }));

    let salaryRecord = await StaffSalary.findOne({ where: { staff_id: id, month: currentMonth } });
    if (!salaryRecord) {
      salaryRecord = await StaffSalary.create({
        gym_id,
        staff_id: id,
        month: currentMonth,
        amount: staff.monthly_salary,
        paid: false,
      });
    }

    return {
      staff: staff.toJSON(),
      days_present: daysPresent,
      total_working_days: totalWorkingDays,
      salary: {
        amount: parseFloat(salaryRecord.amount),
        paid: salaryRecord.paid,
        paid_at: salaryRecord.paid_at,
        month: salaryRecord.month,
      },
      last_7_days: last7,
    };
  },

  markSalaryPaid: async (id, gym_id) => {
    const staff = await Staff.findOne({ where: { id, gym_id } });
    if (!staff) throw new Error('Staff not found');
    const currentMonth = dayjs.utc().format('YYYY-MM');
    const [record] = await StaffSalary.findOrCreate({
      where: { staff_id: id, month: currentMonth },
      defaults: { gym_id, amount: staff.monthly_salary, paid: false },
    });
    await record.update({ paid: true, paid_at: dayjs.utc().toDate() });
    return record;
  },
};

module.exports = staffService;
