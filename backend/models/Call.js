const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Call = sequelize.define('Call', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  member_id: { type: DataTypes.UUID, allowNull: false },
  gym_id: { type: DataTypes.UUID, allowNull: false },
  description: { type: DataTypes.TEXT, allowNull: true },
  type: { type: DataTypes.ENUM('manual', 'ai'), defaultValue: 'manual' },
  called_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  duration: { type: DataTypes.INTEGER, defaultValue: 0 },
  transcript: { type: DataTypes.TEXT, allowNull: true },
  external_call_id: { type: DataTypes.STRING, allowNull: true }, // For provider tracking
}, { tableName: 'calls', timestamps: true });

module.exports = Call;
