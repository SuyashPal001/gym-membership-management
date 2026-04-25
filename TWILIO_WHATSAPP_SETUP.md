# WhatsApp Reminder Setup (Twilio + Retell)

Reminder dispatch is intentionally disabled. The database infrastructure is fully in place
(WorkflowReminder model, reminder routes, reminder service). This doc covers what you need
to re-enable it.

---

## What's already built

- `WorkflowReminder` model and migrations
- `reminderService` — create, list, cancel reminders
- `reminderRoutes` — POST/GET/DELETE endpoints
- Flutter UI — member detail screen sends reminders, reminder history screen shows results
- The 15-minute cron slot is removed but easy to add back

---

## What you need before re-enabling

### 1. Twilio account
- Sign up at twilio.com
- Fund your balance (WhatsApp messages cost ~₹0.50–₹4 each depending on type)

### 2. WhatsApp Business API approval (Meta)
- Apply through Twilio console → Messaging → Senders → WhatsApp
- You need: business name, a working website URL, and a privacy policy URL
- Meta reviews take 1–7 business days
- Your website must mention that you collect member phone numbers for gym communication

### 3. Approved message templates
- Go to Twilio console → Content Template Builder
- Create a template — example:
  > "Hi {{1}}, your membership at {{2}} expires in 3 days. Reply to renew."
- Submit for Meta approval (1–3 days)
- The approved template gives you a Content SID starting with `HX...`

### 4. Environment variables to add
```
TWILIO_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_TOKEN=your_auth_token
TWILIO_MESSAGING_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   # Messaging Service SID
TWILIO_CONTENT_SID=HXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    # Approved template SID
```

---

## Re-enabling dispatch

1. Re-create `backend/services/twilioProvider.js`:

```js
const twilio = require('twilio');

const createTwilioClient = () => {
  if (process.env.TWILIO_SID && process.env.TWILIO_TOKEN) {
    return twilio(process.env.TWILIO_SID, process.env.TWILIO_TOKEN);
  }
  return null;
};

const scheduleSMS = async ({ phoneNumber, scheduledDate, contentVariables }) => {
  const client = createTwilioClient();
  const toPhone = `whatsapp:${phoneNumber}`;

  if (!client) {
    return { sid: `SM_DEV_MOCK_${Date.now()}` };
  }

  return await client.messages.create({
    messagingServiceSid: process.env.TWILIO_MESSAGING_SID,
    to: toPhone,
    scheduleType: 'fixed',
    sendAt: new Date(scheduledDate).toISOString(),
    contentSid: process.env.TWILIO_CONTENT_SID,
    contentVariables: JSON.stringify(contentVariables || {}),
  });
};

const cancelSMS = async (messageSid) => {
  const client = createTwilioClient();
  if (!client) return;
  await client.messages(messageSid).update({ status: 'canceled' });
};

module.exports = { scheduleSMS, cancelSMS };
```

2. Add back the 15-minute cron in `reminderCron.js` that calls `scheduleSMS` for WHATSAPP reminders and marks them `scheduled: true` with the returned `sid` as `reference_id`.

3. Hook `cancelSMS` into `reminderService.cancelReminder` — if the reminder has a `reference_id`, call `cancelSMS(referenceId)` before updating the DB.

---

## Retell AI calls (AI_CALL method)

Retell is also not implemented. When ready:
- Sign up at retellai.com
- Create an agent with your gym prompt
- Add `RETELL_API_KEY` to env
- Re-create `backend/services/retellProvider.js` using the Retell SDK

The `AI_CALL` branch in the cron dispatch loop is the correct place to call it.
