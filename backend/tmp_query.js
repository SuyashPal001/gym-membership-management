const { sequelize } = require('./models');
async function run() {
  try {
    const vs = await sequelize.query('SELECT id, gym_id FROM "VoiceSessions" WHERE id = \'23df5de1-23ea-47b5-a711-bc7101ac0296\'', { type: sequelize.QueryTypes.SELECT });
    console.log('VOICE_SESSION:', vs);
    const m = await sequelize.query('SELECT id, member_name, gym_id FROM "members" WHERE member_name = \'abc\'', { type: sequelize.QueryTypes.SELECT });
    console.log('MEMBER_ABC:', m);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}
run();
