const { MembershipType } = require('../models/Member');
const sequelize = require('../config/database');

const seed = async () => {
  try {
    await sequelize.authenticate();
    console.log('Connected to DB for seeding...');

    const count = await MembershipType.count();
    if (count > 0) {
      console.log('Membership types already exist. Skipping seed.');
      process.exit(0);
    }

    await MembershipType.bulkCreate([
      { name: '1-Month Premium', amount: 50, duration_months: 1 },
      { name: '3-Month Bundle', amount: 130, duration_months: 3 },
      { name: 'Annual VIP', amount: 400, duration_months: 12 },
    ]);

    console.log('✅ Default membership plans seeded successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Seeding failed:', err.message);
    process.exit(1);
  }
};

seed();
