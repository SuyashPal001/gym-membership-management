const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Payment = sequelize.define('Payment', {
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
  amount: {
    type: DataTypes.FLOAT,
    allowNull: false
  },
  status: {
    type: DataTypes.ENUM('paid', 'pending', 'failed', 'refunded'),
    defaultValue: 'paid'
  },
  payment_date: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  method: {
    type: DataTypes.STRING,
    allowNull: true
  }
}, {
  tableName: 'payments',
  timestamps: true
});

module.exports = Payment;
