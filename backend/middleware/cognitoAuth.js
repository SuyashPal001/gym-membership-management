const { CognitoJwtVerifier } = require('aws-jwt-verify');

let verifier = null;

function getVerifier() {
  if (!verifier) {
    verifier = CognitoJwtVerifier.create({
      userPoolId: process.env.COGNITO_USER_POOL_ID,
      tokenUse:   null,
      clientId:   process.env.COGNITO_CLIENT_ID,
    });
  }
  return verifier;
}

const cognitoAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Authorization token missing or invalid' });
  }

  const token = authHeader.split(' ')[1];

  if (process.env.NODE_ENV === 'development' && process.env.ALLOW_DEV_BYPASS === 'true' && token === 'DEVELOPER') {
    req.cognitoSub = process.env.DEV_COGNITO_SUB;
    req.user = { sub: req.cognitoSub, email: process.env.DEV_EMAIL || 'dev@test.com' };
    return next();
  }

  try {
    const payload = await getVerifier().verify(token);
    req.cognitoSub   = payload.sub;
    req.cognitoEmail = payload.email;
    req.user = { sub: payload.sub, email: payload.email };
    next();
  } catch (err) {
    console.error('[cognitoAuth] verification failed:', err.message);
    return res.status(401).json({ success: false, message: 'Authorization token missing or invalid' });
  }
};

module.exports = cognitoAuth;
