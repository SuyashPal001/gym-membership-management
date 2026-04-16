module.exports = (sequelize, DataTypes) => {
  const VoiceSession = sequelize.define('VoiceSession', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    gym_id: { type: DataTypes.UUID, allowNull: false },
    started_at: { type: DataTypes.DATE, allowNull: false },
    ended_at: { type: DataTypes.DATE, allowNull: true },
    transcript: { type: DataTypes.TEXT, allowNull: true },
    extracted_json: { type: DataTypes.JSONB, allowNull: true },
    status: {
      type: DataTypes.ENUM('initiated', 'active', 'completed', 'failed'),
      defaultValue: 'initiated'
    },
    processed: { type: DataTypes.BOOLEAN, defaultValue: false },
    processed_at: { type: DataTypes.DATE, allowNull: true },
    total_logged: { type: DataTypes.INTEGER, defaultValue: 0 },
    total_skipped: { type: DataTypes.INTEGER, defaultValue: 0 }
  });
  return VoiceSession;
};
