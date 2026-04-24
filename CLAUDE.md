# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Backend (Node.js — run from `backend/`)
```bash
npm run dev          # nodemon (development, auto-reload)
npm start            # node app.js (production)
npm run db:sync      # Sync Sequelize schema (dev only)
npm run db:migrate   # Run pending migrations
npm run db:rollback  # Undo last migration
```

### Frontend (Flutter — run from `gym-membership-management/my_app/`)
```bash
make run-web         # Flutter web on Chrome, port 8080 (required for OAuth callback)
flutter test         # Run all tests
flutter test test/widget_test.dart   # Run a single test file
flutter build apk    # Build Android APK
```

Port 8080 is hardcoded for the OAuth callback URI — always use `make run-web`, not an arbitrary port.

## Architecture Overview

Gym-Ops is a multi-tenant SaaS gym management platform. Each gym is a tenant identified by `gym_id` (UUID), derived from the owner's AWS Cognito identity.

### Stack
- **Backend:** Node.js + Express + Sequelize ORM + PostgreSQL
- **Frontend:** Flutter (web + mobile)
- **Auth:** AWS Cognito (OAuth 2.0 PKCE) with federated Google login
- **AI:** Google Vertex AI (Gemini 2.5) via `@google/genai`
- **Comms:** Twilio (WhatsApp/SMS) + Retell AI (voice calls) — both mocked in dev
- **Background jobs:** `node-cron` embedded in the Express process (no external schedulers)

### Request Lifecycle (Backend)
Every API request passes through:
1. CORS + JSON parsing (10 MB limit)
2. `cognitoAuth` — verifies Cognito JWT; in dev, token `"DEVELOPER"` bypasses verification
3. `resolveGymId` — looks up `Gym` by `cognito_sub`, injects `req.gymId`
4. Route-specific validators / rate limiters
5. Route handler → service layer → Sequelize ORM → PostgreSQL

### Multi-Tenancy
All Sequelize queries must include a `gym_id` WHERE clause. The `resolveGymId` middleware injects `req.gymId`; routes pass it into every service call. `MembershipType` is scoped per gym and has a UNIQUE(gym_id, name) constraint.

### Key Features & Their Data Flows

**Attendance (toggle check-in/out)**
`POST /api/attendance/scan` is idempotent per day — checks for an open `AttendanceSession` (no `check_out_time`) for that member on the current date (DATEONLY), then either creates a check-in or closes with a check-out time. A cron job auto-checks-out sessions open for 1+ hours (every 5 min).

**Ledger Scan (AI OCR → two-phase commit)**
1. `POST /api/ai/scan-book` — sends base64 image to Gemini; returns extracted member data fuzzy-matched against the DB (fuse.js, threshold 0.4); creates a `LedgerScan` record.
2. `POST /api/ai/scan/:scan_id/confirm` — owner reviews matches, confirms; a Sequelize transaction writes Members + Payments atomically. Unconfirmed scans older than 7 days are purged by nightly cron.

**Voice Logging (speech-to-text → Gemini function calling)**
`POST /api/voice/start|message|end` — Flutter sends device speech-to-text transcripts; the backend calls Gemini with 8 registered tool definitions (createMember, recordPayment, markAttendance, etc.); Gemini returns function_call responses that are executed against the DB in real-time during the session, not batched at end.

**Reminders (two-component queuing)**
`WorkflowReminder` records are created with a `scheduled_date`. Every 15 minutes, `reminderCron` polls for reminders due within a 2-hour lookahead window and dispatches via Twilio (WhatsApp) or Retell (AI voice call).

### Frontend Architecture
- `main.dart` → `ApiConfig.initialize()` → `RouteGuard.determineStartScreen()` → Navigator
- `ApiService` is a singleton HTTP wrapper with automatic token refresh on 401 (retries the original request after refreshing).
- OAuth uses a popup window on web: Flutter opens Cognito in `window.open`, `callback.html` in `web/` intercepts the redirect and `postMessage`s the auth code back to the Flutter app.
- All HTTP errors must be thrown as `ApiException` — never raw `Exception`.

### Cron Jobs (all in `backend/workers/reminderCron.js`)
| Schedule | Job |
|---|---|
| `*/15 * * * *` | Dispatch pending WorkflowReminders (2-hr lookahead) |
| `*/5 * * * *` | Auto-checkout sessions open > 1 hour |
| `0 2 * * *` | Delete LedgerScans unconfirmed for > 7 days |

## Strict Guardrails

These are intentional architectural constraints — do not work around them:

- **Date/time:** Always use `dayjs.utc()` in Node.js. Never `new Date()`.
- **Database:** Always use Sequelize ORM. Never raw SQL.
- **Schedulers:** Only `node-cron`. Never BullMQ, Redis queues, or external cron services.
- **Flutter errors:** Always throw `ApiException`. Never `Exception`.
- **Phone numbers:** Store and send in E.164 format (`+91XXXXXXXXXX`); strip non-digits before prefixing.
- **Member avatars:** No image upload or display anywhere in the app. Every member avatar shows name initials only. Do not re-add `image`/`avatar` fields to `Member`, `AttendanceSession`, or any screen. The `lib/utils/member_avatar.dart` utility has been deleted.

## Environment Variables

Backend `.env` (see `.env.example` for the full list):
```
DATABASE_URL=postgresql://...   # Production (takes precedence over individual DB_* vars)
DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASSWORD   # Local dev
PORT=5001
NODE_ENV=development|production
GCP_PROJECT_ID / GCP_LOCATION / GCP_SA_KEY   # Vertex AI (base64-encoded SA JSON)
COGNITO_USER_POOL_ID / COGNITO_CLIENT_ID / COGNITO_REGION
TWILIO_SID / TWILIO_TOKEN / TWILIO_MESSAGING_SID   # Mocked — any value works in dev
```

## Key Documentation Files

The repo root contains extensive decision logs — read these before making architectural changes:

- `CHANGELOG.md` — 100+ decision entries covering every major design choice
- `PROJECT.md` — Architecture overview and guardrails
- `SCHEMA.md` — Full database schema reference
- `AUTH.md` — OAuth/Cognito flow details and production checklist
- `ERRORS.md` — Known issues and workarounds
- `VOICE_FEATURE.md` — Voice logging feature design
