const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const AttendanceSession = sequelize.define('AttendanceSession', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  gym_id: {
    type: DataTypes.UUID,
    allowNull: false
  },
  member_id: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'members',
      key: 'id'
    }
  },
  check_in_time: {
    type: DataTypes.DATE,
    allowNull: false
  },
  check_out_time: {
    type: DataTypes.DATE,
    allowNull: true
  },
  date: {
    type: DataTypes.DATEONLY,
    allowNull: false
  }
}, {
  tableName: 'attendance_sessions',
  timestamps: true
});

module.exports = AttendanceSession;
