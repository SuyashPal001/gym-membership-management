const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    ),
    new winston.transports.Console(),
  ],
});

// For development convenience, we'll use a simpler console output
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple(),
  }));
}

module.exports = logger;
