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

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5001;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request Logger ( Troubleshooting )
app.use((req, res, next) => {
  console.log(`[${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  next();
});

// Serve static uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/api/members', memberRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/reminders', reminderRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/ai', aiRoutes);

// Daily Reset Cron (Midnight UTC)
cron.schedule('0 0 * * *', () => {
  console.log('[CRON] New day started - attendance reset naturally');
});

// Database sync and Start
sequelize.authenticate()
  .then(() => {
    console.log('Database Connected Successfully.');
    return sequelize.sync();
  })
  .then(() => {
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Rocket Server running on http://0.0.0.0:${PORT}`);
    });
  })
  .catch(err => {
    console.error('Database connection failed:', err);
  });
