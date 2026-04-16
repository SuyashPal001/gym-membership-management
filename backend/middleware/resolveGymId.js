const { Gym } = require('../models');

const resolveGymId = async (req, res, next) => {
  try {
    if (!req.cognitoSub) {
      return res.status(401).json({ success: false, message: 'Authentication required' });
    }

    const gym = await Gym.findOne({
      where: { cognito_sub: req.cognitoSub }
    });

    if (!gym) {
      return res.status(404).json({ success: false, message: 'Gym not set up yet' });
    }

    req.gymId = gym.id;
    req.gym = gym;

    if (req.cognitoEmail && gym.owner_email !== req.cognitoEmail) {
      await gym.update({ owner_email: req.cognitoEmail });
      req.gym = await gym.reload();
    }

    next();
  } catch (err) {
    console.error('Resolve Gym ID Error:', err.message);
    res.status(500).json({ success: false, message: 'Internal server error resolving gym identity' });
  }
};

module.exports = resolveGymId;
