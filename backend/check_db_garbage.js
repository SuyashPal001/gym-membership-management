const { VoiceSession, Member, AttendanceSession, Payment, sequelize } = require('./models/index');
const { Op } = require('sequelize');

async function runQueries() {
  try {
    console.log('--- 1. VoiceSessions (All) ---');
    const q1 = await VoiceSession.findAll({ order: [['started_at', 'DESC']], raw: true });
    console.log(JSON.stringify(q1, null, 2));

    console.log('\n--- 2. AttendanceSessions (All) ---');
    const q2 = await AttendanceSession.findAll({ order: [['check_in_time', 'DESC']], raw: true });
    console.log(JSON.stringify(q2, null, 2));

    console.log('\n--- 3. Payments (voice_log or NULL method) ---');
    const q3 = await Payment.findAll({
      where: {
        [Op.or]: [
          { method: 'voice_log' },
          { method: { [Op.is]: null } }
        ]
      },
      order: [['payment_date', 'DESC']],
      raw: true
    });
    console.log(JSON.stringify(q3, null, 2));

    console.log('\n--- 4. Members (Garbage/Unknown) ---');
    const q4 = await Member.findAll({
      attributes: ['id', 'gym_id', 'member_name', 'phone', 'status', 'is_trial', 'join_date', 'total_visits', 'lifetime_value', 'last_payment_date'],
      where: {
        [Op.or]: [
          { phone: 'unknown' },
          { phone: { [Op.is]: null } },
          { lifetime_value: { [Op.lt]: 0 } },
          { total_visits: { [Op.lt]: 0 } },
          { join_date: { [Op.is]: null } }
        ]
      },
      raw: true
    });
    console.log(JSON.stringify(q4, null, 2));

    console.log('\n--- 5. Payments (Garbage/Orphan) ---');
    const q5 = await sequelize.query(`
      SELECT * FROM payments 
      WHERE amount IS NULL 
      OR amount <= 0 
      OR member_id NOT IN (SELECT id FROM members)
    `, { type: sequelize.QueryTypes.SELECT });
    console.log(JSON.stringify(q5, null, 2));

    console.log('\n--- 6. AttendanceSessions (Garbage/Orphan) ---');
    const q6 = await sequelize.query(`
      SELECT * FROM attendance_sessions 
      WHERE member_id NOT IN (SELECT id FROM members) 
      OR check_in_time IS NULL 
      OR date IS NULL
    `, { type: sequelize.QueryTypes.SELECT });
    console.log(JSON.stringify(q6, null, 2));

    console.log('\n--- 7. VoiceSessions (Completed/Processed) ---');
    const q7 = await VoiceSession.findAll({
      attributes: ['id', 'status', 'total_logged', 'total_skipped', 'transcript', 'extracted_json'],
      where: {
        [Op.or]: [
          { status: 'completed' },
          { processed: true }
        ]
      },
      raw: true
    });
    console.log(JSON.stringify(q7, null, 2));

  } catch (err) {
    console.error('ERROR RUNNING QUERIES:', err);
  } finally {
    await sequelize.close();
  }
}

runQueries();
