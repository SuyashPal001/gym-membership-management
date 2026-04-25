# Voice Feature — Gym AI Assistant

## Status: ACTIVE — In Development
Last updated: April 12, 2026

## Architecture Overview
Voice log uses device STT (speech_to_text) for recording + Google Cloud TTS 
for playback. Gemini 2.5 Flash handles conversation logic via text in/out.
No telephony needed — fully device + backend based.

## Data Flow
```
Owner speaks → speech_to_text (en_IN locale) → text
        ↓
POST /api/voice/message { session_id, text, history }
        ↓
Backend sends to Gemini with FUNCTION_DECLARATIONS (8 tools)
        ↓
Gemini calls tools directly → DB written in real time
        ↓
Backend returns { reply, tools_executed, session_complete }
        ↓
Flutter displays reply in chat bubble
        ↓
Google Cloud TTS speaks reply via just_audio
        ↓
Auto-listen activates for next owner message
```

## Session Lifecycle
1. POST /api/voice/start → creates VoiceSession, returns session_id + member list
2. POST /api/voice/message (repeated) → Gemini converses + tools write to DB
3. POST /api/voice/end → marks VoiceSession completed only (no data write)

## Tools Registered with Gemini (FUNCTION_DECLARATIONS)

### Write Tools
| Tool | Action | DB Table |
|------|--------|----------|
| log_attendance | Creates AttendanceSession | AttendanceSessions |
| log_payment | Creates Payment (status: paid) | Payments |
| log_due | Creates Payment (status: pending) | Payments |
| add_member | Creates Member | Members |
| mark_trial | Updates Member.is_trial + status | Members |

### Read Tools
| Tool | Action | Returns |
|------|--------|---------|
| lookup_member | Finds member by name | profile, status, last payment, visits |
| check_dues | Lists pending payments | all pending Payments with Member names |
| get_attendance_today | Lists today's attendance | all AttendanceSessions for today |

## Known Issues — RESOLVED THIS SESSION (April 12, 2026)

### [FIXED] Phone number not validated in add_member tool
- Where: executeTool -> case 'add_member'
- Fix applied: rawPhone strips all non-digits, rejects if < 10 digits,
  normalizes to +91 E.164 format before Member.create
- 'unknown' default string is gone — tool now returns failure and asks
  owner to provide valid number

### [FIXED] check_in_time parsing failed on AM/PM and malformed strings
- Where: executeTool -> case 'log_attendance'
- Fix applied: dayjs.utc() multi-format parsing with 8 format patterns
  covering HH:mm, h:mm A, hA, h A etc. Returns failure message if
  still invalid instead of writing NaN to DB

### [FIXED] check_out_time never written by voice tools
- Where: executeTool -> case 'log_attendance'
- Fix applied: check_out_time auto-set to check_in_time + 1 hour.
  No owner involvement needed. No new tool added.

### [FIXED] Amount not validated in log_payment
- Where: executeTool -> case 'log_payment'
- Fix applied: parseFloat with NaN + <= 0 guard. Uses paymentAmount
  variable — not args.amount — in all writes including LTV update.

### [FIXED] Amount not validated in log_due
- Where: executeTool -> case 'log_due'
- Fix applied: Same parseFloat guard as log_payment. dueAmount variable
  used in Payment.create.
- Note: Duplicate guard intentionally NOT added to log_due — dues are
  allowed to stack across months. Gemini verbal confirmation is the
  natural guard against accidental double entry.

## Known Issues — STILL OPEN

### [BUG] Tool confirmation flow
- Current: Gemini asks owner to confirm before calling tool
- Issue: Sometimes tool fires without explicit owner confirmation
- Fix needed: Investigate if additional system prompt instruction needed
- Priority: MEDIUM

### [BUG] Abandoned sessions never closed
- Where: VoiceSessions table
- Issue: Sessions where owner exits without calling /voice/end stay
  as status 'active' with ended_at null forever
- Fix needed: Either Flutter calls /voice/end on back-navigation,
  or cron closes stale active sessions older than 2 hours
- Priority: MEDIUM

## System Prompt Key Rules
- No Devanagari script ever — Roman letters only
- Mirror owner's language per turn (not carried from history)
- Short responses — max 2 sentences
- Always end with follow-up question
- Use tools for all data actions — never describe actions in text

## Files Modified
- backend/routes/voiceRoutes.js — main voice logic, tools, endpoints
- backend/models/VoiceSession.js — session model
- backend/services/aiService.js — added chat() method
- lib/screens/voice_log_screen.dart — full UI rebuild
- lib/services/api_service.dart — 3 new methods
- backend/workers/reminderCron.js — no voice changes

## API Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/voice/start | Create session, return member list |
| POST | /api/voice/message | Send message, get AI reply + tool execution |
| POST | /api/voice/end | Close session |
| POST | /api/voice/transcribe | GCP STT (available, not used in main flow) |
| POST | /api/voice/speak | GCP TTS (used for all AI voice output) |

## GCP Services Used
- Vertex AI (Gemini 2.5 Flash) — conversation + tool calling
- Cloud Text-to-Speech — Neural2 en-IN-Neural2-B voice
- Cloud Speech-to-Text — available but device STT used instead

## Flutter Packages Added
- speech_to_text: ^6.6.2 — mic recording
- flutter_tts: ^4.0.2 — kept but replaced by GCP TTS
- just_audio: ^0.9.36 — plays GCP TTS MP3 audio

## VoiceSession Model
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | Primary Key |
| gym_id | UUID | |
| started_at | DATE | |
| ended_at | DATE | |
| transcript | TEXT | Full conversation log |
| extracted_json | JSONB | Tool execution history |
| status | ENUM | initiated, active, completed, failed |
| processed | BOOLEAN | true when /voice/end called |
| processed_at | DATE | |
| total_logged | INTEGER | Incremented per successful tool call |
| total_skipped | INTEGER | |

## Next Steps (Priority Order)
1. Fix DB validation in executeTool — reject trash data
2. Add phone number validation for add_member tool
3. Improve fuzzy member name matching in all tools
4. Review tool confirmation flow — ensure AI always confirms before writing
5. Add duplicate member check improvement
6. Consider adding tool for updating existing member details
7. Multi-page scan grouping (BACKLOG from LedgerScan feature)
