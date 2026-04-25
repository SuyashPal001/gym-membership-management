const { sequelize } = require('../models');

async function fixDb() {
  try {
    await sequelize.authenticate();
    console.log('Connection established.');
    
    try {
      await sequelize.query('ALTER TABLE payments ADD COLUMN IF NOT EXISTS plan_name TEXT;');
      console.log('Column plan_name added.');
    } catch (e) {}

    try {
      await sequelize.query('ALTER TABLE payments ADD COLUMN IF NOT EXISTS membership_type_id UUID;');
      console.log('Column membership_type_id added.');
    } catch (e) {}

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

fixDb();
