# Gym-Ops AI Prompt Library

## 1. Session Start
Use this to prime a fresh LLM session before asking it to do any work on Gym-Ops.

```text
You are assisting with the Gym-Ops codebase. Before writing any code or analyzing the issue, you MUST read the following architecture files to understand the rigid environment constraints:
1. Read `PROJECT.md` for core rules, stack patterns, and environment variable maps.
2. Read `SCHEMA.md` to perfectly understand all database relations, constraints, and DORMANT/Off-Limit models.
3. Read `PROMPTS.md` to see if there is an exact prompt template for the task I am about to request.

Additionally, observe these strict backend rules:
- fuse.js must be imported as const Fuse = require('fuse.js') — never destructured
- _modelId must be gemini-2.5-flash — never gemini-1.5-flash or aliases
- AI bridge test endpoint is GET /api/ai/test — always check this first before debugging scan failures

## Voice Feature Context (April 2026)
- Voice uses Gemini function calling — 8 tools in FUNCTION_DECLARATIONS
- Tools write to DB in real time — no batch at end
- System prompt: no Devanagari, mirror owner language per turn, Roman script only
- FUNCTION_DECLARATIONS uses parametersJsonSchema not parameters
- generateContent tools passed as: config: { tools: [{ functionDeclarations: FUNCTION_DECLARATIONS }] }
- response.functionCalls used to detect tool calls (not candidates[0].content.parts)
- aiService.init() must be called before accessing aiService._ai
- Known bugs in VOICE_FEATURE.md — fix those next session

Confirm that you have read these files, summarize the major architectural constraints you found, and tell me you are ready. Do not write any code yet.
```

## 2. New Express Route
Use this when adding a new endpoint to the Node.js backend.

```text
I need to add a new Express route to the backend.

Strict Constraints:
- Use the exact try/catch wrapper format found in `/backend/routes/memberRoutes.js`.
- Never crash the node thread; always catch and return `res.status(500).json({ success: false, message: err.message })`.
- Do not write raw `sequelize.query('...')`. Use proper Sequelize ORM functions.
- If handling dates, strictly utilize `dayjs.utc()`.
- Do not add any new authentication middlewares (Passport/JWT), the API is internal-only.

Ensure you check the `payload` validators being used in existing routes to maintain request safety. Write the route using these constraints.
```

## 3. New Flutter Screen
Use this when expanding the mobile app.

```text
I need to build a new Flutter screen for Gym-Ops.

Strict Constraints:
- Look at `/lib/screens/member_detail_screen.dart` and `add_member_screen.dart` to match the exact dark-theme visual aesthetics (#0A0A0A background, #00C853 accents).
- Strictly use the `ApiService` wrapper pattern found in `/lib/services/api_service.dart`.
- Any network or HTTP parsing errors must throw the custom `ApiException` class so the UI catches it gracefully via Snackbars.
- Do not use any third-party UI framework (like Tailwind or predefined material bloat). Stick to the existing minimalistic UI patterns.

Provide the minimal, perfectly styled Flutter code matching this standard.
```

## 4. Sequelize Model Change
Use this when altering database structures.

```text
I need to modify the Sequelize schema in `/backend/models`.

Strict Constraints:
- Check `SCHEMA.md` extensively before proceeding.
- You are strictly forbidden from hooking into or trying to revive the `Loan.js`, `Goal.js`, `Streak.js`, or `ActivityFeed.js` models. As per PROJECT.md, they are ðŸ’€ SCHEDULED FOR REMOVAL. Do not build on them.
- Ensure any `hasMany` relationships include exactly the required `{ foreignKey: '...', onDelete: 'CASCADE' }` logic where appropriate.
- Write the exact Node.js Sequelize model code, and provide the command needed for Postgres to sync the schema without nuking data (e.g., `alter: true`).
```

## 5. Cron / Worker Change
Use this when adjusting background logic constraints.

```text
I need to update the background worker logic.

Strict Constraints:
- Look strictly at `/backend/workers/reminderCron.js`.
- Gym-Ops uses a localized `node-cron` architecture running exclusively within the Express thread.
- You MUST NOT suggest installing external queues (like BullMQ, Redis, or RabbitMQ) or migrating to AWS/Vercel serverless crons.
- If you touch date calculations, you must use `dayjs.utc()` and evaluate strictly against `NOW()`. Double-check the `is_scheduled` offset logic.

Provide the updated code for the local Express cron adhering entirely to these boundaries.
```

## 6. Debugging
Use this when you hit a wall or error stack trace in the app.

```text
I have hit a bug/error stack trace while running Gym-Ops.

Strict Constraints:
- Before guessing, read the `ERRORS.md` file (if it exists) to see if this is a known architectural bug.
- Do NOT randomly suggest `npm install [new-library]` as a fix unless the exact functionality does not currently exist in the `PROJECT.md` stack.
- Check the Dart `ApiException` bubble up flow or the Express `try/catch` router flow to locate specifically where the trace was logged.
- Give me a step-by-step diagnostic process to find the failure without altering the core architecture.
```

## 7. Twilio / Retell Integration
Use this when working with the external integrations.

```text
I need to extend or debug the Twilio / Retell AI communication layer.

Strict Constraints:
- Specifically read `/backend/services/twilioProvider.js` and `/backend/services/retellProvider.js`.
- Acknowledge that the keys `TWILIO_SID`, `TWILIO_TOKEN`, and `TWILIO_MESSAGING_SID` in `.env` are currently MOCKED placeholders.
- Do NOT assume live API calls are working; ensure your code safely catches 'Mocked Credential' routes or handles mock strings without breaking.
- Ensure the `reference_id` from the provider uniquely identifies against the `WorkflowReminder` database.

Provide the backend execution code.
```

## 8. Docs Update
Use this whenever completing a successful task to keep instructions alive.

```text
I have successfully implemented a change to the Gym-Ops codebase.

Strict Constraints:
- Review the changes that were just made.
- Update `PROJECT.md` with any new strict AI Rules, Env variables, or Folder structure additions.
- Update `SCHEMA.md` with any new tables, columns, or relations.
- Only touch the `.md` documentation files right now. Do not write any `.js` or `.dart` source code.

Provide the exact markdown replacements or complete files to keep the architecture documentation pristine.
```

## AI Ledger Scan Feature (April 2026)
Full two-phase ledger scan implemented. Key architectural decisions:
- LedgerScan model persists all scans before confirmation
- fuse.js fuzzy matching handles handwriting OCR errors
- Sequelize transactions prevent partial data on confirm
- extractGymRecords uses @google/genai Vertex SDK — response.text is 
  a direct string, not a function, not nested under candidates
- _post in ApiService supports per-call timeout override via 
  optional timeout parameter
- scan_book_screen.dart handles requires_manual_selection flag to 
  force manual member selection when duplicate names exist

