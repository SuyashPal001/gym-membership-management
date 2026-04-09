const rateLimit = require('express-rate-limit');
const logger = require('../utils/logger');

// 1. Rate Limiter: Max 5 scans per minute per IP to prevent billing spikes
const scanRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5, 
  message: { success: false, error: 'Too many scans. Please Wait.' },
  handler: (req, res, next, options) => {
    logger.warn('Rate Limit Tripped', { ip: req.ip });
    res.status(429).json(options.message);
  }
});

// 2. Image Validator: Check size and MIME type
const validateImagePayload = (req, res, next) => {
  const { image } = req.body;

  if (!image) {
    return res.status(400).json({ success: false, error: 'No image data provided' });
  }

  // Check Size: Base64 length is ~1.33x actual size. 5MB ~= 6.7M characters
  if (image.length > 7 * 1024 * 1024) {
    logger.warn('Payload too large', { size: image.length, ip: req.ip });
    return res.status(413).json({ success: false, error: 'Image too large (Max 5MB)' });
  }

  // Basic MIME check if data URI is present
  if (image.startsWith('data:') && !image.includes('image/')) {
     return res.status(400).json({ success: false, error: 'Invalid file type. Only images allowed.' });
  }

  next();
};

module.exports = {
  scanRateLimiter,
  validateImagePayload
};
