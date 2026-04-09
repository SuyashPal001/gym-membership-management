const { JWT } = require('google-auth-library');
const axios = require('axios');
const logger = require('../utils/logger');

class AIService {
  constructor() {
    this.isInitialized = false;
    this._credentials = null;
    this._projectNumber = process.env.GCP_PROJECT_NUMBER || '129404364493';
    this._location = process.env.GCP_LOCATION || 'us-central1';
    this._model = 'gemini-2.5-flash';
  }

  async init() {
    if (this.isInitialized) return;

    const saKey = process.env.GCP_SA_KEY;
    if (!saKey) {
      logger.error('CRITICAL: GCP_SA_KEY is missing from environment');
      throw new Error('CONFIG_ERROR');
    }

    try {
      const cleaned = saKey.trim().replace(/^['"]|['"]$/g, '');
      this._credentials = JSON.parse(cleaned);
      
      this.jwtClient = new JWT({
        email: this._credentials.client_email,
        key: this._credentials.private_key.replace(/\\n/g, '\n'),
        scopes: ['https://www.googleapis.com/auth/cloud-platform'],
      });

      this.isInitialized = true;
      logger.info('Sovereign AI Service Initialized', { 
        project: this._projectNumber, 
        location: this._location 
      });
    } catch (e) {
      logger.error('Sovereign AI Init Failed', { error: e.message });
      throw new Error('AUTH_INITIALIZATION_FAILED');
    }
  }

  async extractGymRecords(base64Image) {
    if (!base64Image || base64Image.length < 500) {
      logger.warn('AI Extraction Aborted: Image data too short or missing');
      throw new Error('IMAGE_DATA_TOO_SHORT');
    }

    await this.init();

    try {
      const cleanedBase64 = base64Image
        .trim()
        .replace(/^['"]|['"]$/g, '')
        .replace(/^data:image\/\w+;base64,/, '')
        .replace(/[\n\r\t]/g, '')
        .replace(/\s/g, '');

      const tokenResponse = await this.jwtClient.authorize();
      const accessToken = tokenResponse.access_token;

      const url = `https://${this._location}-aiplatform.googleapis.com/v1/projects/${this._projectNumber}/locations/${this._location}/publishers/google/models/${this._model}:generateContent`;

      const response = await axios.post(url, {
        contents: [
          {
            role: 'user',
            parts: [
              { text: 'Extract gym attendance ledger data from this image. Return ONLY a JSON array with: name, phone, amount, status (paid/unpaid). If no names are found, return [].' },
              { inline_data: { data: cleanedBase64, mime_type: 'image/jpeg' } },
            ],
          },
        ],
      }, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      });

      const rawText = response.data.candidates?.[0]?.content?.parts?.[0]?.text || '[]';
      const cleanJson = rawText.replace(/```json|```/g, '').trim();
      
      try {
        const parsed = JSON.parse(cleanJson);
        logger.info('AI Extraction Successful', { count: parsed.length });
        return parsed;
      } catch (parseError) {
        logger.error('AI Response Parsing Failed', { raw: rawText.substring(0, 100) });
        return [];
      }
    } catch (error) {
      const status = error.response?.status;
      const data = error.response?.data;
      logger.error('AI Vertex Request Failed', { status, data: JSON.stringify(data) });
      throw new Error('AI_GATEWAY_TIMEOUT');
    }
  }

  async ping() {
    await this.init();
    try {
      const tokenResponse = await this.jwtClient.authorize();
      const accessToken = tokenResponse.access_token;
      const url = `https://${this._location}-aiplatform.googleapis.com/v1/projects/${this._projectNumber}/locations/${this._location}/publishers/google/models/${this._model}:generateContent`;

      const response = await axios.post(url, {
        contents: [{ role: 'user', parts: [{ text: 'Respond with exactly: ALIVE' }] }]
      }, {
        headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        timeout: 10000
      });

      return response.data.candidates[0].content.parts[0].text.trim();
    } catch (error) {
      logger.error('AI Ping Failed', { error: error.message });
      throw new Error('AI_OFFLINE');
    }
  }
}

module.exports = new AIService();
