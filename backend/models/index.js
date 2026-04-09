const sequelize = require('../config/database');
const { Sequelize } = require('sequelize');

// Import active model files manually
// Note: MembershipType is defined and exported from Member.js in this project structure.
const { Member, MembershipType, WorkflowReminder, Call, AttendanceSession, Payment } = require('./Member');

const db = {
  Member,
  MembershipType,
  WorkflowReminder,
  Call,
  AttendanceSession,
  Payment,
  sequelize,
  Sequelize
};

// Run associations if defined in the standard .associate(db) pattern
// (Though our current models define them inline, this ensures forward compatibility)
Object.keys(db).forEach(modelName => {
  if (db[modelName] && typeof db[modelName].associate === 'function') {
    db[modelName].associate(db);
  }
});

module.exports = db;
