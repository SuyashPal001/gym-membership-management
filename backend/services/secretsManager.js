const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const SECRET_ID = process.env.AWS_SECRET_NAME || 'gymops/production';
const REGION = process.env.AWS_REGION || 'ap-south-1';

let _loaded = false;

async function loadSecrets() {
  if (_loaded) return;
  try {
    const client = new SecretsManagerClient({ region: REGION });
    const res = await client.send(new GetSecretValueCommand({ SecretId: SECRET_ID }));
    Object.assign(process.env, JSON.parse(res.SecretString));
    _loaded = true;
    console.log('[Boot] Configuration loaded');
  } catch (err) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('[Boot] Using local config (dev mode)');
      _loaded = true;
    } else {
      throw new Error(`[Boot] Failed to load configuration: ${err.message}`);
    }
  }
}

module.exports = { loadSecrets };
