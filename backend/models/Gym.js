'use strict';
const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Gym = sequelize.define('Gym', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    owner_name: {
      type: DataTypes.STRING,
      allowNull: false
    },
    gym_name: {
      type: DataTypes.STRING,
      allowNull: false
    },
    phone: {
      type: DataTypes.STRING,
      allowNull: true
    },
    city: {
      type: DataTypes.STRING,
      allowNull: true
    },
    state: {
      type: DataTypes.STRING,
      allowNull: true
    },
    owner_email: {
      type: DataTypes.STRING,
      allowNull: false
    },
    cognito_sub: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true
    }
  }, {
    tableName: 'gyms',
    timestamps: true
  });

  return Gym;
};
