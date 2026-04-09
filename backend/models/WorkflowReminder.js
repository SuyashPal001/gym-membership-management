const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const WorkflowReminder = sequelize.define('WorkflowReminder', {
  id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
  uuid: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, unique: true },
  
  // Relates to a booking in Cal.com, here it relates to the Member
  member_id: { type: DataTypes.UUID, allowNull: false },
  gym_id: { type: DataTypes.UUID, allowNull: false },
  
  // The channel
  method: { type: DataTypes.ENUM('WHATSAPP', 'AI_CALL', 'SMS', 'EMAIL'), allowNull: false },
  
  // The exactly computed UTC time this needs to fire
  scheduled_date: { type: DataTypes.DATE, allowNull: false },
  
  // The ID returned by Twilio/Retell after it is scheduled or sent
  reference_id: { type: DataTypes.STRING, unique: true },
  
  // Indicates if this was picked up by the CRON
  scheduled: { type: DataTypes.BOOLEAN, defaultValue: false, allowNull: false },
  
  // Lifecycle flags
  cancelled: { type: DataTypes.BOOLEAN, defaultValue: false },
  retry_count: { type: DataTypes.INTEGER, defaultValue: 0 },
  
  // Since Cal.com uses this for templates, we store dynamic variables here
  payload: { type: DataTypes.JSONB }
}, {
  tableName: 'workflow_reminders',
  timestamps: true,
  indexes: [
    // CRITICAL: Perfect index for the cron worker exactly like Cal.com
    { fields: ['method', 'scheduled', 'scheduled_date'] },
    { fields: ['cancelled', 'scheduled_date'] }
  ]
});

module.exports = WorkflowReminder;
