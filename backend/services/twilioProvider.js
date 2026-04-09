const twilio = require('twilio');

// Simplified exact emulation of Cal.com's twilioProvider.ts
const createTwilioClient = () => {
  if (process.env.TWILIO_SID && process.env.TWILIO_TOKEN) {
    return twilio(process.env.TWILIO_SID, process.env.TWILIO_TOKEN);
  }
  console.log('[Twilio DEV] Missing TWILIO_SID. Mocking client.');
  return null;
};

const scheduleSMS = async (twilioData) => {
  const client = createTwilioClient();

  const raw = twilioData.phoneNumber;
  if (raw == null || String(raw).trim() === '') {
    throw new Error('scheduleSMS: phoneNumber is required');
  }

  // Format for WhatsApp correctly
  const num = String(raw);
  const toPhone = num.includes('whatsapp:')
    ? num
    : `whatsapp:${num}`;

  const messageOptions = {
    messagingServiceSid: process.env.TWILIO_MESSAGING_SID,
    to: toPhone,
    // Exact UTC fixed scheduling payload over API
    scheduleType: "fixed",
    sendAt: new Date(twilioData.scheduledDate).toISOString(),
    contentSid: twilioData.contentSid,
    contentVariables: JSON.stringify(twilioData.contentVariables || {}),
  };

  if (!client) {
    console.log('[Twilio DEV] Mocking message schedule:', messageOptions);
    return { sid: `SM_DEV_MOCK_${Date.now()}` };
  }

  const response = await client.messages.create(messageOptions);
  return response; // returns { sid: 'SM...' }
};

const cancelSMS = async (messageSid) => {
  const client = createTwilioClient();
  if (!client) {
    console.log(`[Twilio DEV] Mocking cancellation for ${messageSid}`);
    return;
  }
  await client.messages(messageSid).update({ status: 'canceled' });
};

module.exports = { scheduleSMS, cancelSMS };
