/**
 * scripts/syncDb.js
 *
 * Run once to create / sync all tables in the database.
 * Usage: node scripts/syncDb.js
 *
 * Options:
 *   force=true  — DROP and re-create all tables (destructive, dev only)
 *   alter=true  — Apply safe column changes without dropping tables (default)
 */

require('dotenv').config({ path: '../.env' });
const sequelize = require('../config/database');

// FIX: Import the full models index so ALL models are synced, including Gym
require('../models');

const FORCE = process.argv.includes('--force');

const syncDatabase = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection established');

    if (FORCE) {
      console.log('⚠️  Running with --force: all tables will be DROPPED and re-created');
    }

    // Reverted back to the original dynamic logic (without alter: true override)
    await sequelize.sync({ force: FORCE, alter: !FORCE });
    
    console.log('✅ All models synced successfully');
    process.exit(0);
  } catch (err) {
    console.error('❌ Sync failed:', err.message);
    process.exit(1);
  }
};

syncDatabase();
