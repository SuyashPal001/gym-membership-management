module.exports = (sequelize, DataTypes) => {
  const LedgerScan = sequelize.define('LedgerScan', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    gym_id: { type: DataTypes.UUID, allowNull: false },
    scanned_at: { type: DataTypes.DATE, allowNull: false },
    raw_extracted_json: { type: DataTypes.JSONB, allowNull: true },
    confirmed: { type: DataTypes.BOOLEAN, defaultValue: false },
    confirmed_at: { type: DataTypes.DATE, allowNull: true },
    total_entries: { type: DataTypes.INTEGER, defaultValue: 0 },
    processed_entries: { type: DataTypes.INTEGER, defaultValue: 0 },
    skipped_entries: { type: DataTypes.INTEGER, defaultValue: 0 }
  }, {
    tableName: 'ledger_scans',
    timestamps: true
  });
  return LedgerScan;
};
