const express = require('express');
const router = express.Router();
const https = require('https');
const querystring = require('querystring');
const { Gym, MembershipType } = require('../models');
const cognitoAuth = require('../middleware/cognitoAuth');
const resolveGymId = require('../middleware/resolveGymId');

// POST /api/auth/exchange
// Exchanges OAuth authorization code for tokens server-side so the client secret never leaves the server.
router.post('/exchange', async (req, res) => {
  try {
    const { code, code_verifier, redirect_uri } = req.body;
    if (!code || !code_verifier || !redirect_uri) {
      return res.status(400).json({ error: 'Missing code, code_verifier, or redirect_uri' });
    }

    const clientId = process.env.COGNITO_CLIENT_ID;
    const clientSecret = process.env.COGNITO_CLIENT_SECRET;
    // Derive domain from COGNITO_DOMAIN or from the user pool id (ap-south-1_XXXXX → ap-south-1xxxxx.auth.ap-south-1.amazoncognito.com)
    const domain = process.env.COGNITO_DOMAIN ||
      (() => {
        const poolId = process.env.COGNITO_USER_POOL_ID || '';
        const [region, suffix] = poolId.split('_');
        return `${region}${(suffix || '').toLowerCase()}.auth.${region}.amazoncognito.com`;
      })();

    const body = querystring.stringify({
      grant_type: 'authorization_code',
      client_id: clientId,
      code,
      code_verifier,
      redirect_uri,
      ...(clientSecret ? { client_secret: clientSecret } : {}),
    });

    const options = {
      hostname: domain,
      path: '/oauth2/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const tokens = await new Promise((resolve, reject) => {
      const req = https.request(options, (cognitoRes) => {
        let data = '';
        cognitoRes.on('data', chunk => data += chunk);
        cognitoRes.on('end', () => {
          const parsed = JSON.parse(data);
          if (cognitoRes.statusCode === 200) resolve(parsed);
          else reject({ status: cognitoRes.statusCode, body: parsed });
        });
      });
      req.on('error', reject);
      req.write(body);
      req.end();
    });

    res.json(tokens);
  } catch (err) {
    const status = err.status || 500;
    const message = err.body || { error: err.message };
    console.error('[AUTH] Token exchange failed:', message);
    res.status(status).json(message);
  }
});

// POST /api/auth/setup
// Protected by cognitoAuth only
router.post('/setup', cognitoAuth, async (req, res) => {
  try {
    const { gym_name, owner_name, phone, city, state } = req.body;
    const cognito_sub = req.cognitoSub;

    // Use findOrCreate for guaranteed atomicity and idempotency
    const [gym, created] = await Gym.findOrCreate({
      where: { cognito_sub },
      defaults: {
        gym_name,
        owner_name,
        phone,
        city,
        state,
        owner_email: req.cognitoEmail || null
      }
    });

    // Ensure default membership types exist — bulkCreate with ignoreDuplicates avoids
    // the concurrent findOrCreate race condition that causes spurious ValidationErrors
    await MembershipType.bulkCreate([
      { gym_id: gym.id, name: '1 Month',  amount: 1000, duration_months: 1  },
      { gym_id: gym.id, name: '3 Months', amount: 2500, duration_months: 3  },
      { gym_id: gym.id, name: '12 Months',amount: 8000, duration_months: 12 },
    ], { ignoreDuplicates: true });

    if (created) {
      console.log(`[SETUP] New gym registered: "${gym.gym_name}" (${gym.id}) owner=${gym.owner_email}`);
    }

    res.status(created ? 201 : 200).json({
      success: true,
      message: created ? 'Gym created successfully' : 'Gym already set up',
      data: {
        gym_id: gym.id,
        gym_name: gym.gym_name,
        owner_name: gym.owner_name
      }
    });

  } catch (err) {
    console.error('[SETUP] Error — message:', err.message);
    console.error('[SETUP] Error — stack:', err.stack);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/auth/me
// Protected by both cognitoAuth and resolveGymId
router.get('/me', cognitoAuth, resolveGymId, async (req, res) => {
  try {
    res.json({ success: true, data: req.gym });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
