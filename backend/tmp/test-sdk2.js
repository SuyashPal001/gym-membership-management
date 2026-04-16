require('dotenv').config();
const aiService = require('../services/aiService');
const fs = require('fs');

async function test() {
  try {
    const dummyImage = "a".repeat(600);
    await aiService.extractGymRecords(dummyImage);
  } catch (e) {
    // we don't care about this catch, because Winston already logged the object
  }
}

// Intercept console.error or Winston and write to a clean file
const winston = require('winston');
const logger = require('../utils/logger');
logger.add(new winston.transports.File({ filename: 'test-error-clean.log' }));

test();
