'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // ─── Membership Types ─────────────────────────────────────────────────────────
    await queryInterface.createTable('membership_types', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
        unique: true,
      },
      amount: {
        type: Sequelize.FLOAT,
        allowNull: false,
      },
      duration_months: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    // ─── Members ──────────────────────────────────────────────────────────────────
    await queryInterface.createTable('members', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
      },
      gym_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      member_name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      phone: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      email: {
        type: Sequelize.STRING,
      },
      image: {
        type: Sequelize.STRING,
      },
      membership_type_id: {
        type: Sequelize.UUID,
        references: {
          model: 'membership_types',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      join_date: {
        type: Sequelize.DATEONLY,
        allowNull: false,
        defaultValue: Sequelize.NOW,
      },
      expiry_date: {
        type: Sequelize.DATEONLY,
      },
      status: {
        type: Sequelize.ENUM('active', 'trial', 'expired', 'halted'),
        defaultValue: 'active',
      },
      is_trial: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
      },
      payment_collected: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
      },
      total_visits: {
        type: Sequelize.INTEGER,
        defaultValue: 0,
      },
      lifetime_value: {
        type: Sequelize.FLOAT,
        defaultValue: 0,
      },
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    // Indexes
    await queryInterface.addIndex('members', ['gym_id']);
    await queryInterface.addIndex('members', ['phone']);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('members');
    await queryInterface.dropTable('membership_types');
  }
};
