const express = require('express');
const router = express.Router();
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
dayjs.extend(utc);
const { VoiceSession, Member, AttendanceSession, Payment, sequelize, Gym } = require('../models');
const { Op } = require('sequelize');
const aiService = require('../services/aiService');
const { GoogleAuth } = require('google-auth-library');

const buildSystemPrompt = (ownerName) => `You are Gym AI, a friendly assistant for an Indian gym owner.
You help log daily gym data through natural conversation in English or Hindi.

You MUST collect this information during the session:
- Who attended today and what time they came
- Any payments received (member name, amount, method)
- Any dues or pending payments
- Any new members (name, phone, plan)
- Any trial members

PERSONALITY AND OPENING:
- You are Flexy, an enthusiastic and sharp AI assistant for this gym.
- At the very start of a new session greet the owner warmly and 
  introduce what you can do in 2-3 short sentences. Example:
  'Hey ${ownerName}! I am Flexy, your gym assistant. Tell me who walked in today, 
  any payments received, dues to record, or new members to add — 
  I will handle it all. Who do we start with?'
- Keep all responses short — max 2 sentences after the opening.
- Always end every reply with a follow-up question.
- Be encouraging and upbeat — never robotic or flat.

CONVERSATION STYLE:
- Let the owner talk naturally — they may give multiple pieces of info at once
- If owner says "hi", "how are you", or chats casually — respond warmly and briefly, then guide back
- Confirm each piece of data before logging it
- If owner gives info about multiple members in one sentence — handle all of them

DUPLICATE NAMES:
- If two members share a name, describe both: "Maine do Rahul dekhe — ek January 2025 mein join kiya phone ending 4210, doosra March 2024 mein phone ending 9876. Kaun sa?"

CORRECTIONS:
- If owner says "no", "nahi", "galat", "I meant", "correction" — fix the last entry silently
- Return action: "CORRECT" with corrected data

TIME PARSING:
- "7 baje" = 07:00, "6 sham ko" = 18:00, "morning" = 06:00, "evening" = 17:00
- If no time given — check_in_time is null

SESSION END:
- When owner says "done", "bas", "ho gaya", "that's all" — wrap up warmly and end

RESPONSE STYLE:
- Respond naturally in plain conversational text only
- Never return JSON in your reply
- Use tools to log data — do not describe actions in text

LANGUAGE RULE (STRICT):
- Look ONLY at the owner's most recent message to decide the language.
- If the most recent message is in English — respond in English only.
- If the most recent message is in Hindi (Roman script) — respond in Hindi Roman script only.
- Never carry language from previous turns.
- Never use Devanagari script under any circumstance.
- Previous conversation history does NOT influence language choice — only the last message does.
- For the opening greeting only — always combine English and 
  Hindi Roman script in one message so both language owners 
  feel immediately at home.`;

// POST /api/voice/start
// Now uses req.gymId from resolveGymId middleware
router.post('/start', async (req, res) => {
  try {
    const gym = await Gym.findByPk(req.gymId);
    if (!gym) {
      return res.status(404).json({ success: false, message: 'Gym identity not found' });
    }

    const ownerName = gym.owner_name?.trim() || 'there';

    const members = await Member.findAll({
      where: { gym_id: req.gymId },
      attributes: ['id', 'member_name', 'phone', 'status', 'is_trial', 'join_date']
    });

    const session = await VoiceSession.create({
      gym_id: req.gymId,
      started_at: dayjs.utc().toDate(),
      status: 'active'
    });

    let openingMessage = `Hey ${ownerName}! Main hoon Flexy, aapka gym assistant. Aaj kaun aaya, koi payment mili, koi due hai, ya naya member add karna hai — sab batao, main sab handle kar lunga. Kahan se shuru karein?`;

    try {
      const greetingResponse = await aiService.chat.call(
        aiService,
        [
          {
            role: 'user',
            parts: [{ text: buildSystemPrompt(ownerName) }]
          },
          {
            role: 'model',
            parts: [{ text: 'Understood. I am Flexy, ready to assist.' }]
          },
          {
            role: 'user',
            parts: [{ text: '__START__ Greet the owner in both English and Hindi Roman script combined in one short message. Never use Devanagari.' }]
          }
        ]
      );
      if (greetingResponse) openingMessage = greetingResponse;
    } catch (_) {}

    res.json({
      success: true,
      session_id: session.id,
      members: members.map(m => m.toJSON()),
      opening_message: openingMessage
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/voice/transcribe
router.post('/transcribe', async (req, res) => {
  try {
    const { audioBase64, languageCode } = req.body;
    if (!audioBase64) return res.status(400).json({ success: false, message: 'audioBase64 required' });

    if (!process.env.GCP_SA_KEY) return res.status(500).json({ success: false, message: 'GCP_SA_KEY missing' });

    const credentials = JSON.parse(Buffer.from(process.env.GCP_SA_KEY, 'base64').toString('utf-8'));
    const auth = new GoogleAuth({ credentials, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });

    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    const response = await fetch('https://speech.googleapis.com/v1/speech:recognize', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        config: {
          encoding: 'WEBM_OPUS',
          sampleRateHertz: 48000,
          languageCode: languageCode || 'hi-IN',
          alternativeLanguageCodes: ['en-IN'],
          model: 'latest_long',
          enableAutomaticPunctuation: true
        },
        audio: { content: audioBase64 }
      })
    });

    const data = await response.json();
    if (!data.results || data.results.length === 0) return res.json({ success: true, text: '' });

    const transcript = data.results.map(r => r.alternatives[0].transcript).join(' ');
    res.json({ success: true, text: transcript });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/voice/speak
router.post('/speak', async (req, res) => {
  try {
    const { text, languageCode } = req.body;
    if (!text) return res.status(400).json({ success: false, message: 'text required' });

    if (!process.env.GCP_SA_KEY) return res.status(500).json({ success: false, message: 'GCP_SA_KEY missing' });

    const credentials = JSON.parse(Buffer.from(process.env.GCP_SA_KEY, 'base64').toString('utf-8'));
    const auth = new GoogleAuth({ credentials, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });

    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    const response = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        input: { text },
        voice: {
          languageCode: languageCode || 'en-IN',
          name: 'en-IN-Neural2-B',
          ssmlGender: 'MALE'
        },
        audioConfig: { audioEncoding: 'MP3', speakingRate: 0.95, pitch: 0 }
      })
    });

    const data = await response.json();
    if (!data.audioContent) return res.status(500).json({ success: false, message: 'TTS failed', detail: data });

    res.json({ success: true, audioBase64: data.audioContent });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Tool definitions for Gemini
const FUNCTION_DECLARATIONS = [
  {
    name: 'log_attendance',
    description: 'Log that a member attended the gym today.',
    parametersJsonSchema: {
      type: 'object',
      properties: {
        member_name: { type: 'string', description: 'Name of the member' },
        check_in_time: { type: 'string', description: 'Time in HH:mm 24hr format, null if not mentioned' }
      },
      required: ['member_name']
    }
  },
  {
    name: 'log_payment',
    description: 'Log a payment received from a member.',
    parametersJsonSchema: {
      type: 'object',
      properties: {
        member_name: { type: 'string', description: 'Name of the member' },
        amount: { type: 'number', description: 'Amount paid in rupees' },
        method: { type: 'string', description: 'Payment method: cash, upi, or bank' }
      },
      required: ['member_name', 'amount']
    }
  },
  {
    name: 'log_due',
    description: 'Log a pending or due payment for a member.',
    parametersJsonSchema: {
      type: 'object',
      properties: {
        member_name: { type: 'string', description: 'Name of the member' },
        amount: { type: 'number', description: 'Amount due in rupees' }
      },
      required: ['member_name', 'amount']
    }
  },
  {
    name: 'add_member',
    description: 'Add a new member to the gym.',
    parametersJsonSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Full name of new member' },
        phone: { type: 'string', description: 'Phone number' },
        plan: { type: 'string', description: 'Membership plan type' }
      },
      required: ['name']
    }
  },
  {
    name: 'mark_trial',
    description: 'Mark a member as on trial period.',
    parametersJsonSchema: {
      type: 'object',
      properties: {
        member_name: { type: 'string', description: 'Name of the member' }
      },
      required: ['member_name']
    }
  },
  {
    name: 'lookup_member',
    description: 'Look up a member profile including status and stats.',
    parametersJsonSchema: {
      type: 'object',
      properties: {
        member_name: { type: 'string', description: 'Name of the member' }
      },
      required: ['member_name']
    }
  },
  {
    name: 'check_dues',
    description: 'Get list of all members with pending payments.',
    parametersJsonSchema: { type: 'object', properties: {} }
  },
  {
    name: 'get_attendance_today',
    description: 'Get list of all members who attended today.',
    parametersJsonSchema: { type: 'object', properties: {} }
  }
];

// Tool executor
async function executeTool(toolName, args, gymId) {
  switch (toolName) {
    case 'log_attendance': {
      const member = await Member.findOne({ where: { gym_id: gymId, member_name: { [Op.iLike]: `%${args.member_name}%` } } });
      if (!member) return { success: false, message: `Member ${args.member_name} not found` };
      const date = dayjs.utc().format('YYYY-MM-DD');
      const existing = await AttendanceSession.findOne({ where: { member_id: member.id, date } });
      if (existing) return { success: false, message: `${member.member_name} already logged` };

      let checkInTime = dayjs.utc();
      if (args.check_in_time) {
        const parsed = dayjs.utc(`${dayjs.utc().format('YYYY-MM-DD')} ${args.check_in_time.toString().trim()}`, ['HH:mm', 'H:mm', 'h:mm A', 'h:mm a']);
        if (parsed.isValid()) checkInTime = parsed;
      }
      await AttendanceSession.create({ gym_id: gymId, member_id: member.id, check_in_time: checkInTime.toDate(), check_out_time: checkInTime.add(1, 'hour').toDate(), date });
      await member.increment('total_visits');
      return { success: true, message: `${member.member_name} attendance logged` };
    }
    case 'log_payment': {
      const member = await Member.findOne({ where: { gym_id: gymId, member_name: { [Op.iLike]: `%${args.member_name}%` } } });
      if (!member) return { success: false, message: `Member ${args.member_name} not found` };
      const paymentAmount = parseFloat(args.amount);
      if (!paymentAmount || isNaN(paymentAmount) || paymentAmount <= 0) return { success: false, message: 'Invalid amount' };
      await Payment.create({ gym_id: gymId, member_id: member.id, amount: paymentAmount, status: 'paid', payment_date: dayjs.utc().toDate(), method: args.method || 'voice_log' });
      await member.update({ payment_collected: true, last_payment_date: dayjs.utc().toDate(), lifetime_value: member.lifetime_value + paymentAmount });
      return { success: true, message: `Payment of ₹${paymentAmount} logged` };
    }
    case 'log_due': {
      const member = await Member.findOne({ where: { gym_id: gymId, member_name: { [Op.iLike]: `%${args.member_name}%` } } });
      if (!member) return { success: false, message: `Member ${args.member_name} not found` };
      const dueAmount = parseFloat(args.amount);
      if (!dueAmount || isNaN(dueAmount) || dueAmount <= 0) return { success: false, message: 'Invalid due amount' };
      await Payment.create({ gym_id: gymId, member_id: member.id, amount: dueAmount, status: 'pending', payment_date: dayjs.utc().toDate(), method: 'voice_log' });
      return { success: true, message: `Due of ₹${dueAmount} recorded` };
    }
    case 'add_member': {
      const rawPhone = args.phone?.toString().replace(/\D/g, '');
      if (!rawPhone || rawPhone.length < 10) return { success: false, message: 'Valid 10-digit phone required' };
      const phone = `+91${rawPhone.slice(-10)}`;
      await Member.create({ gym_id: gymId, member_name: args.name, phone, status: 'active', join_date: dayjs.utc().format('YYYY-MM-DD') });
      return { success: true, message: `New member ${args.name} added` };
    }
    case 'mark_trial': {
      const member = await Member.findOne({ where: { gym_id: gymId, member_name: { [Op.iLike]: `%${args.member_name}%` } } });
      if (!member) return { success: false, message: 'Member not found' };
      await member.update({ is_trial: true, status: 'trial' });
      return { success: true, message: `${member.member_name} marked as trial` };
    }
    case 'lookup_member': {
      const member = await Member.findOne({ where: { gym_id: gymId, member_name: { [Op.iLike]: `%${args.member_name}%` } } });
      if (!member) return { success: false, message: 'Member not found' };
      return { success: true, member: { name: member.member_name, phone: member.phone, status: member.status, visits: member.total_visits } };
    }
    case 'check_dues': {
      const pending = await Payment.findAll({ where: { gym_id: gymId, status: 'pending' }, include: [{ model: Member, as: 'Member', attributes: ['member_name'] }] });
      return { success: true, dues: pending.map(p => ({ member: p.Member?.member_name, amount: p.amount })) };
    }
    case 'get_attendance_today': {
      const sessions = await AttendanceSession.findAll({ where: { gym_id: gymId, date: dayjs.utc().format('YYYY-MM-DD') }, include: [{ model: Member, as: 'Member', attributes: ['member_name'] }] });
      return { success: true, attended: sessions.map(s => ({ member: s.Member?.member_name, check_in_time: s.check_in_time })) };
    }
    default: return { success: false, message: `Unknown tool: ${toolName}` };
  }
}

// POST /api/voice/message
router.post('/message', async (req, res) => {
  try {
    const { session_id, text, history } = req.body;
    const session = await VoiceSession.findOne({ where: { id: session_id, gym_id: req.gymId } });
    if (!session) return res.status(404).json({ success: false, message: 'Session not found or unauthorized' });

    const gym = await Gym.findByPk(req.gymId);
    const ownerName = gym?.owner_name || 'there';

    const members = await Member.findAll({ where: { gym_id: req.gymId }, attributes: ['id', 'member_name', 'phone', 'status', 'is_trial', 'join_date'] });
    const memberListText = JSON.stringify(members.map(m => m.toJSON()), null, 2);

    const contents = [
      { role: 'user', parts: [{ text: buildSystemPrompt(ownerName) + '\n\nMember list:\n' + memberListText }] },
      { role: 'model', parts: [{ text: 'Ready to help.' }] },
      ...(history || []).slice(-8).map(turn => ({ role: turn.role === 'ai' ? 'model' : 'user', parts: [{ text: turn.text }] })),
      { role: 'user', parts: [{ text }] }
    ];

    await aiService.init();
    const ai = aiService._ai;
    let response = await ai.models.generateContent({ model: aiService._modelId, contents, config: { tools: [{ functionDeclarations: FUNCTION_DECLARATIONS }] } });

    let finalReply = '';
    let toolsExecuted = [];
    let round = 0;
    while (round < 5) {
      round++;
      const functionCalls = response.functionCalls;
      if (!functionCalls || functionCalls.length === 0) { finalReply = response.text ?? ''; break; }
      for (const fnCall of functionCalls) {
        const toolResult = await executeTool(fnCall.name, fnCall.args, req.gymId);
        toolsExecuted.push({ tool: fnCall.name, args: fnCall.args, result: toolResult });
        contents.push({ role: 'model', parts: [{ functionCall: { name: fnCall.name, args: fnCall.args } }] });
        contents.push({ role: 'user', parts: [{ functionResponse: { name: fnCall.name, response: { result: JSON.stringify(toolResult) } } }] });
      }
      response = await ai.models.generateContent({ model: aiService._modelId, contents, config: { tools: [{ functionDeclarations: FUNCTION_DECLARATIONS }] } });
    }

    await session.update({ transcript: (session.transcript || '') + `\nOwner: ${text}\nAI: ${finalReply}` });
    const successfulCount = toolsExecuted.filter(t => t.result.success).length;
    if (successfulCount > 0) await session.increment('total_logged', { by: successfulCount });

    res.json({ success: true, reply: finalReply, tools_executed: toolsExecuted, session_complete: ['done', 'bas', 'ho gaya'].some(k => text.toLowerCase().includes(k)) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.post('/end', async (req, res) => {
  try {
    const { session_id } = req.body;
    const session = await VoiceSession.findOne({ where: { id: session_id, gym_id: req.gymId } });
    if (!session) return res.status(404).json({ success: false, message: 'Session not found' });
    if (session.processed) return res.status(409).json({ success: false, message: 'Session already ended' });

    await session.update({ status: 'completed', ended_at: dayjs.utc().toDate(), processed: true, processed_at: dayjs.utc().toDate() });
    res.json({ success: true, message: 'Session ended', total_logged: session.total_logged });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
