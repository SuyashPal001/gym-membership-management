const { Member, sequelize } = require('./models');

async function checkLTV() {
  try {
    const [results, metadata] = await sequelize.query(
      "SELECT id, member_name, lifetime_value FROM members WHERE id = '75e191da-b85b-4295-b774-13186c1ee1b6';"
    );
    console.log('--- DATABASE CHECK ---');
    console.log(JSON.stringify(results, null, 2));
    console.log('----------------------');
  } catch (err) {
    console.error('FAILED TO QUERY DB:', err);
  } finally {
    await sequelize.close();
  }
}

checkLTV();
