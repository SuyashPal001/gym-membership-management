'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('staff', {
      id: { type: Sequelize.UUID, defaultValue: Sequelize.UUIDV4, primaryKey: true },
      gym_id: { type: Sequelize.UUID, allowNull: false },
      name: { type: Sequelize.STRING, allowNull: false },
      phone: { type: Sequelize.STRING },
      role: { type: Sequelize.ENUM('Trainer', 'Receptionist', 'Cleaner', 'Manager', 'Other'), defaultValue: 'Other' },
      monthly_salary: { type: Sequelize.DECIMAL(10, 2), defaultValue: 0 },
      status: { type: Sequelize.ENUM('active', 'inactive'), defaultValue: 'active' },
      join_date: { type: Sequelize.DATEONLY },
      createdAt: { type: Sequelize.DATE, allowNull: false },
      updatedAt: { type: Sequelize.DATE, allowNull: false },
    });

    await queryInterface.createTable('staff_attendance', {
      id: { type: Sequelize.UUID, defaultValue: Sequelize.UUIDV4, primaryKey: true },
      gym_id: { type: Sequelize.UUID, allowNull: false },
      staff_id: { type: Sequelize.UUID, allowNull: false, references: { model: 'staff', key: 'id' }, onDelete: 'CASCADE' },
      date: { type: Sequelize.DATEONLY, allowNull: false },
      status: { type: Sequelize.ENUM('present', 'absent', 'half_day'), defaultValue: 'present' },
      check_in_time: { type: Sequelize.DATE },
      createdAt: { type: Sequelize.DATE, allowNull: false },
      updatedAt: { type: Sequelize.DATE, allowNull: false },
    });

    await queryInterface.createTable('staff_salary', {
      id: { type: Sequelize.UUID, defaultValue: Sequelize.UUIDV4, primaryKey: true },
      gym_id: { type: Sequelize.UUID, allowNull: false },
      staff_id: { type: Sequelize.UUID, allowNull: false, references: { model: 'staff', key: 'id' }, onDelete: 'CASCADE' },
      month: { type: Sequelize.STRING(7), allowNull: false },
      amount: { type: Sequelize.DECIMAL(10, 2), allowNull: false },
      paid: { type: Sequelize.BOOLEAN, defaultValue: false },
      paid_at: { type: Sequelize.DATE },
      createdAt: { type: Sequelize.DATE, allowNull: false },
      updatedAt: { type: Sequelize.DATE, allowNull: false },
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('staff_salary');
    await queryInterface.dropTable('staff_attendance');
    await queryInterface.dropTable('staff');
  },
};
