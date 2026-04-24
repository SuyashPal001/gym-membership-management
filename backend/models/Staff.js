const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Staff = sequelize.define('Staff', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  gym_id: { type: DataTypes.UUID, allowNull: false },
  name: { type: DataTypes.STRING, allowNull: false },
  phone: { type: DataTypes.STRING },
  role: {
    type: DataTypes.ENUM('Trainer', 'Receptionist', 'Cleaner', 'Manager', 'Other'),
    defaultValue: 'Other',
  },
  monthly_salary: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  status: { type: DataTypes.ENUM('active', 'inactive'), defaultValue: 'active' },
  join_date: { type: DataTypes.DATEONLY },
}, { tableName: 'staff', timestamps: true });

const StaffAttendance = sequelize.define('StaffAttendance', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  gym_id: { type: DataTypes.UUID, allowNull: false },
  staff_id: { type: DataTypes.UUID, allowNull: false },
  date: { type: DataTypes.DATEONLY, allowNull: false },
  status: { type: DataTypes.ENUM('present', 'absent', 'half_day'), defaultValue: 'present' },
  check_in_time: { type: DataTypes.DATE },
}, { tableName: 'staff_attendance', timestamps: true });

const StaffSalary = sequelize.define('StaffSalary', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  gym_id: { type: DataTypes.UUID, allowNull: false },
  staff_id: { type: DataTypes.UUID, allowNull: false },
  month: { type: DataTypes.STRING(7), allowNull: false },
  amount: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  paid: { type: DataTypes.BOOLEAN, defaultValue: false },
  paid_at: { type: DataTypes.DATE },
}, { tableName: 'staff_salary', timestamps: true });

Staff.hasMany(StaffAttendance, { foreignKey: 'staff_id' });
StaffAttendance.belongsTo(Staff, { foreignKey: 'staff_id' });
Staff.hasMany(StaffSalary, { foreignKey: 'staff_id' });
StaffSalary.belongsTo(Staff, { foreignKey: 'staff_id' });

module.exports = { Staff, StaffAttendance, StaffSalary };
