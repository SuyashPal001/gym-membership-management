const { CognitoJwtVerifier } = require('aws-jwt-verify');

const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID,
  tokenUse: 'id', // FIX (Bug 2): Use 'id' token to ensure email is present in payload
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
    
    // FIX (Bug 1): Populate properties expected by resolveGymId and auth routes
    req.cognitoSub = payload.sub;
    req.cognitoEmail = payload.email;
    
    // Keep req.user for backward compatibility
    req.user = { sub: payload.sub, email: payload.email };
    
    next();
  } catch (err) {
    console.error('[cognitoAuth] verification failed:', err.message);
    return res.status(401).json({ success: false, message: 'Authorization token missing or invalid' });
  }
};

module.exports = cognitoAuth;
