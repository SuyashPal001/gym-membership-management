'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    // Drop the global unique constraint on name (wrong — breaks multi-tenancy)
    await queryInterface.removeConstraint('membership_types', 'membership_types_name_key');

    // Add gym_id column if it doesn't already exist
    const tableDesc = await queryInterface.describeTable('membership_types');
    if (!tableDesc.gym_id) {
      await queryInterface.addColumn('membership_types', 'gym_id', {
        type: Sequelize.UUID,
        allowNull: true,
      });
    }

    // Add correct composite unique constraint
    await queryInterface.addConstraint('membership_types', {
      fields: ['gym_id', 'name'],
      type: 'unique',
      name: 'membership_types_gym_id_name_unique',
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeConstraint('membership_types', 'membership_types_gym_id_name_unique');
    await queryInterface.addConstraint('membership_types', {
      fields: ['name'],
      type: 'unique',
      name: 'membership_types_name_key',
    });
  },
};
