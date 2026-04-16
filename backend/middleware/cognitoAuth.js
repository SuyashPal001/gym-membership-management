const { CognitoJwtVerifier } = require('aws-jwt-verify');

const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID,
  tokenUse: 'access',
  clientId: process.env.COGNITO_CLIENT_ID,
});

const cognitoAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Authorization token missing or invalid' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = await verifier.verify(token);
    req.user = { sub: payload.sub, email: payload.email };
    next();
  } catch (err) {
    console.error('[cognitoAuth] verification failed:', err.message);
    return res.status(401).json({ success: false, message: 'Authorization token missing or invalid' });
  }
};

module.exports = cognitoAuth;
