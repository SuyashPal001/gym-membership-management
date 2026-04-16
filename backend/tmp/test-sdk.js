require('dotenv').config();
const aiService = require('../services/aiService');

async function test() {
  try {
    const dummyImage = "a".repeat(600);
    await aiService.extractGymRecords(dummyImage);
  } catch (e) {
    // Expected to catch AI_GATEWAY_TIMEOUT after Winston logs the error
  }
}
test();
