const express = require('express');
const cors = require('cors');
const path = require('path');
const dotenv = require('dotenv');
const { sequelize } = require('./models');
const cron = require('node-cron');
const memberRoutes = require('./routes/memberRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const reminderRoutes = require('./routes/reminderRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');
const aiRoutes = require('./routes/aiRoutes');
const voiceRoutes = require('./routes/voiceRoutes');
const gymRoutes = require('./routes/gymRoutes');
const staffRoutes = require('./routes/staffRoutes');
const initCron = require('./workers/reminderCron');
const memberService = require('./services/memberService');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5001;

// Trust nginx reverse proxy so req.ip returns real client IP (required for rate limiting)
app.set('trust proxy', 1);

const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : ['*'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`CORS blocked: ${origin}`));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request Logger ( Troubleshooting )
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Serve static uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const authRoutes = require('./routes/auth');
const cognitoAuth = require('./middleware/cognitoAuth');
const resolveGymId = require('./middleware/resolveGymId');

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Routes
app.use('/api/auth', authRoutes);

// Protected Routes (Authentication + Gym Identity Resolution Required)
app.use('/api/members', cognitoAuth, resolveGymId, memberRoutes);
app.use('/api/payments', cognitoAuth, resolveGymId, paymentRoutes);
app.use('/api/reminders', cognitoAuth, resolveGymId, reminderRoutes);
app.use('/api/attendance', cognitoAuth, resolveGymId, attendanceRoutes);
app.use('/api/gym', cognitoAuth, resolveGymId, gymRoutes);
app.use('/api/staff', cognitoAuth, resolveGymId, staffRoutes);

// AI & Voice Routes
app.use('/api/ai', cognitoAuth, resolveGymId, aiRoutes);
app.use('/api/voice', cognitoAuth, resolveGymId, voiceRoutes);

// Daily membership lifecycle sweep (Midnight UTC)
cron.schedule('0 0 * * *', () => {
  memberService.autoExpireMembers()
    .then(() => console.log('[CRON] Membership expiry sweep completed'))
    .catch((err) => console.error('[CRON] Membership expiry sweep failed:', err.message));
});

// Database sync and Start
sequelize.authenticate()
  .then(() => {
    console.log('Database Connected Successfully.');
    return sequelize.sync();
  })
  .then(() => {
    memberService.autoExpireMembers()
      .then(() => console.log('[BOOT] Membership expiry sweep completed'))
      .catch((err) => console.error('[BOOT] Membership expiry sweep failed:', err.message));
    initCron();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Rocket Server running on http://0.0.0.0:${PORT}`);
    });
  })
  .catch(err => {
    console.error('Database connection failed:', err);
  });
 
