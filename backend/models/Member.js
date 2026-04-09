const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const MembershipType = sequelize.define('MembershipType', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  name: { type: DataTypes.STRING, allowNull: false, unique: true },
  amount: { type: DataTypes.FLOAT, allowNull: false },
  duration_months: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },
}, { tableName: 'membership_types', timestamps: true });

const Member = sequelize.define('Member', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  gym_id: { type: DataTypes.UUID, allowNull: false },
  member_name: { type: DataTypes.STRING, allowNull: false },
  phone: { type: DataTypes.STRING, allowNull: false },
  email: { type: DataTypes.STRING, validate: { isEmail: true } },
  avatar: { type: DataTypes.TEXT, allowNull: true },
  last_arrival: { type: DataTypes.DATE, allowNull: true },
  membership_type_id: { type: DataTypes.UUID, allowNull: true },
  join_date: { type: DataTypes.DATEONLY, defaultValue: DataTypes.NOW },
  expiry_date: { type: DataTypes.DATEONLY, allowNull: true },
  status: { type: DataTypes.ENUM('active', 'expired', 'trial'), defaultValue: 'active' },
  is_trial: { type: DataTypes.BOOLEAN, defaultValue: false },
  payment_collected: { type: DataTypes.BOOLEAN, defaultValue: false },
  last_payment_date: { type: DataTypes.DATE, allowNull: true, defaultValue: null },
  total_visits: { type: DataTypes.INTEGER, defaultValue: 0 },
  lifetime_value: { type: DataTypes.FLOAT, defaultValue: 0 },
}, { tableName: 'members', timestamps: true });

// --- New Model Imports ---
const WorkflowReminder = require('./WorkflowReminder');
const Call = require('./Call');
const AttendanceSession = require('./AttendanceSession');
const Payment = require('./Payment');

// Associations
Member.belongsTo(MembershipType, { foreignKey: 'membership_type_id' });
MembershipType.hasMany(Member, { foreignKey: 'membership_type_id' });

// Member <-> WorkflowReminder
Member.hasMany(WorkflowReminder, { foreignKey: 'member_id', onDelete: 'CASCADE' });
WorkflowReminder.belongsTo(Member, { foreignKey: 'member_id' });

// Member <-> Call
Member.hasMany(Call, { foreignKey: 'member_id', onDelete: 'CASCADE' });
Call.belongsTo(Member, { foreignKey: 'member_id' });

Member.hasMany(AttendanceSession, { foreignKey: 'member_id', onDelete: 'CASCADE' });
AttendanceSession.belongsTo(Member, { foreignKey: 'member_id' });

// Member <-> Payment
Member.hasMany(Payment, { foreignKey: 'member_id', onDelete: 'CASCADE' });
Payment.belongsTo(Member, { foreignKey: 'member_id' });

module.exports = { Member, MembershipType, WorkflowReminder, Call, AttendanceSession, Payment };
