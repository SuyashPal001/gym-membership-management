const { GoogleGenAI } = require('@google/genai');
const logger = require('../utils/logger');

class AIService {
  constructor() {
    this.isInitialized = false;
    this._ai = null;
    this._modelId = 'gemini-2.5-flash';
    this.chat = this.chat.bind(this);
  }

  async init() {
    if (this.isInitialized && this._ai) return;

    // CRITICAL: Overriding GOOGLE_API_KEY ensures the SDK enters Vertex AI mode
    delete process.env.GOOGLE_API_KEY;

    const saKeyBase64 = process.env.GCP_SA_KEY;
    const projectId = process.env.GCP_PROJECT_ID;
    const location = process.env.GCP_LOCATION || 'us-central1';

    if (!saKeyBase64 || !projectId) {
      logger.error('CRITICAL: GCP_SA_KEY or GCP_PROJECT_ID is missing');
      throw new Error('CONFIG_ERROR');
    }

    try {
      // 1. Decode base64 service account key
      const credentials = JSON.parse(
        Buffer.from(saKeyBase64, 'base64').toString('utf-8')
      );

      // 2. Init with correct syntax — googleAuthOptions takes credentials directly
      this._ai = new GoogleGenAI({
        vertexai: true,
        project: projectId,
        location: location,
        googleAuthOptions: { credentials }
      });

      this.isInitialized = true;
      logger.info('Sovereign AI Service Initialized (@google/genai SDK)', { 
        project: projectId, 
        location: location 
      });
    } catch (e) {
      logger.error('Sovereign AI Init Failed', { error: e.message });
      throw new Error('AUTH_INITIALIZATION_FAILED');
    }
  }

  async extractGymRecords(base64Image, options = {}) {
    if (!base64Image || base64Image.length < 500) {
      logger.warn('AI Extraction Aborted: Image data too short');
      throw new Error('IMAGE_DATA_TOO_SHORT');
    }

    await this.init();

    try {
      const cleanedBase64 = base64Image
        .trim()
        .replace(/^data:image\/\w+;base64,/, '')
        .replace(/\s/g, '');

      const prompt = options.text || 'Extract gym attendance ledger data from this image. Return ONLY a JSON array with: name, phone, amount, status (paid/unpaid). If no names are found, return [].';
      const mimeType = options.mimeType || 'image/jpeg';

      // Corrected SDK Syntax for Vertex mode
      const response = await this._ai.models.generateContent({
        model: this._modelId,
        contents: [
          {
            role: 'user',
            parts: [
              { text: prompt },
              { inlineData: { data: cleanedBase64, mimeType: mimeType } },
            ],
          },
        ],
      });

      const rawText = response.text ?? '';
      const cleanJson = rawText.replace(/```json|```/g, '').trim();
      
      try {
        const parsed = JSON.parse(cleanJson);
        logger.info('AI Ledger Extraction Successful', { count: parsed.length });
        return parsed;
      } catch (parseError) {
        logger.error('AI Ledger Parsing Failed', { raw: rawText.substring(0, 100) });
        return [];
      }
    } catch (error) {
      logger.error('AI Ledger SDK Failed', { error: error.message });
      throw new Error('AI_GATEWAY_TIMEOUT');
    }
  }

  async ping() {
    await this.init();
    try {
      const response = await this._ai.models.generateContent({
        model: this._modelId,
        contents: [{ role: 'user', parts: [{ text: 'ping' }] }]
      });

      // Handle both standard and direct response structures
      const rawText = response.text ?? '';

      return rawText.trim();
    } catch (error) {
      logger.error('AI Ping Failed', { 
        error: error.message,
        stack: error.stack
      });
      throw new Error('AI_OFFLINE');
    }
  }

  async chat(contents, systemInstruction) {
    const self = this;
    await self.init();
    if (!self._ai) throw new Error('AI_STATIC_INITIALIZATION_ERROR_NULL_INSTANCE');
    const response = await self._ai.models.generateContent({
      model: self._modelId,
      contents,
      config: {
        systemInstruction: systemInstruction || ''
      }
    });
    return response.text ?? '';
  }
}

module.exports = new AIService();
