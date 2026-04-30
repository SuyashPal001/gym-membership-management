const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({
    cognitoUserPoolId: process.env.COGNITO_USER_POOL_ID || '',
    cognitoClientId:   process.env.COGNITO_CLIENT_ID   || '',
    cognitoDomain:     process.env.COGNITO_DOMAIN       || '',
    cognitoRegion:     process.env.COGNITO_REGION       || '',
  });
});

module.exports = router;
