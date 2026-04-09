const { Call } = require('../models/Member');
const activityService = require('./activityService');

const notificationService = {

  // WhatsApp Integration (Placeholder for actual API like Twilio)
  sendWhatsApp: async (member_id, gym_id, phone, message) => {
    console.log(`📱 Sending WhatsApp to ${phone}: ${message}`);
    
    // Simulate API call to provider
    const success = true; 

    if (success) {
      await activityService.logActivity(member_id, gym_id, 'system', `WhatsApp message sent to ${phone}: "${message.substring(0, 50)}..."`);
    }
    
    return { success };
  },

  // AI Call Triggering (Placeholder for provider like Vapi)
  triggerAICall: async (member_id, gym_id, phone, description) => {
    console.log(`🤖 Triggering AI Call for ${phone}...`);

    // Simulate API call to provider (e.g. Vapi)
    const external_call_id = 'vapi_' + Math.random().toString(36).substring(7);
    
    const call = await Call.create({
      member_id,
      gym_id,
      phone,
      description,
      type: 'ai',
      called_at: new Date(),
      external_call_id
    });

    await activityService.logActivity(member_id, gym_id, 'call', `AI Call triggered for ${phone}. Reason: ${description}`);

    return call;
  }
};

module.exports = notificationService;
