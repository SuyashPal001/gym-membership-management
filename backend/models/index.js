const sequelize = require('../config/database');
const { Sequelize } = require('sequelize');

// Import active model files manually
// Note: MembershipType is defined and exported from Member.js in this project structure.
const { Member, MembershipType, WorkflowReminder, Call, AttendanceSession, Payment } = require('./Member');

const LedgerScan = require('./LedgerScan')(sequelize, Sequelize.DataTypes);
const VoiceSession = require('./VoiceSession')(sequelize, Sequelize.DataTypes);
const Gym = require('./Gym')(sequelize, Sequelize.DataTypes);
const { Staff, StaffAttendance, StaffSalary } = require('./Staff');

const db = {
  Member,
  MembershipType,
  WorkflowReminder,
  Call,
  AttendanceSession,
  Payment,
  LedgerScan,
  VoiceSession,
  Gym,
  Staff,
  StaffAttendance,
  StaffSalary,
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

db.Gym.hasMany(db.Member, { foreignKey: 'gym_id', sourceKey: 'id' });

module.exports = db;
