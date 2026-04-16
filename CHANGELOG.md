# Gym-Ops Action & Changelog Registry

## AI Rule for this file
* **Never suggest reverting a [DECIDED] item.**
* **Never activate a [REJECTED] pattern.**
* **Always check Mocked Registry before assuming a live integration works.**
* **Mark anything uncertain as UNCLEAR: rather than guessing.**

---

## Architectural Decisions Log

* **[RESOLVED]** AI Voice Log full backend pipeline confirmed working April 11 2026. /voice/start, /voice/message, /voice/end all verified via Bruno. Transaction commits correctly with idempotency checks passing.
* **[DECIDED]** aiService.chat() method uses self reference pattern to avoid this binding loss. Called via aiService.chat.call(aiService, contents) from voiceRoutes.js.
* **[DECIDED]** Gemini conversation structure: system prompt injected as first user message with hardcoded model acknowledgment response. Conversation history appended after. Owner message prefixed with "Owner says:" to force JSON response format.
* **[DECIDED]** gym_id passed to /voice/start must be the actual gym UUID from the Gyms table — not a member ID. Flutter uses ApiService.defaultGymId for this.
* **[DECIDED]** Utilize robust `node-cron` executed within the Express thread → Overcomes the lack of distributed external Cron architecture and keeps background intervals synchronized perfectly with the Express lifecycle.
* **[DECIDED]** Native HTTP service abstraction in Flutter throwing `ApiException` → Guarantees UI consistency via centralized Snack bar interception rather than silent `try/catch` UI masking.
* **[DECIDED]** Exclusive reliance on `dayjs.utc()` → Avoids Node.js time zone drift by normalizing all scheduling dates against absolute zero-offset strings.
* **[DECIDED]** Sovereign Vertex AI Integration (`aiService.js`) → Migrated from Secret Manager + API Key to direct Vertex AI authentication using the Service Account from `.env`. This simplifies the architecture by removing the dependency on external secret syncing.
* **[DECIDED]** Extract "Intent" vs "Execution" in `WorkflowReminder` → Mimics Cal.com structuring by letting routes instantly compute dates, dropping them asynchronously into Postgres for the Cron execution payload later.
* **[DECIDED]** GET /members/:gym_id validates UUIDs and Enum values (status, expiring_in) at route level — returns 400 for malformed input, 500 for unexpected server errors only.
* **[DECIDED]** GET /members/:gym_id supports 3 optional filters: `status`, `membership_type_id`, and `expiring_in` (today, this_week, this_month), using `dayjs.utc()` rolling 7/30 day windows for consistent filtering.
* **[DECIDED]** GET /api/payments/:gym_id supports `expiry_filter` (today, this_week, overdue) with route-level validation to identify upcoming and outstanding payments without affecting standard member rosters.
* **[DECIDED]** Implement a logical delete pattern for task cancellations. Setting `cancelled: true` on `WorkflowReminder` ensures we maintain a full audit trail of scheduled communication while safely removing records from active polling intervals.
* **[DECIDED]** Compute `paid_after_reminder` by comparing `Member.last_payment_date` against `WorkflowReminder.scheduled_date`. This provides an absolute 'conversion' signal without complex state machine tracking during actual payment settlement.
* **[DECIDED]** Manual reminder triggers must flow through the database queue rather than calling providers directly. By inserting a `WorkflowReminder` set for 'now', we maintain a single execution bottleneck (the cron), preventing duplicate logic and ensuring all outgoing traffic is logged in PG.
* **[DECIDED]** Utilize `Future.wait` for parallel data retrieval in `MemberDetailScreen`. Fetching member stats and reminder history simultaneously ensures a high-performance profile view with minimal latency.
* **[DECIDED]** Standardize all outbound communication buttons (WhatsApp, AI Call) to use the centralized backend queuing system. By replacing direct provider calls with task record generation, we ensure that every single interaction is captured for conversion tracking.
* **[DECIDED]** Implement the "AttendanceSession" model with a natural 'date' reset field. By utilizing a `DATEONLY` column separate from timestamps, we enable efficient daily check-in lookups and group-by logic without complex range queries or manual midnight data purges.
* **[DECIDED]** Adopt a "phone-first" idempotent check-in/out workflow via a single POST endpoint (`/api/attendance/scan`). This allows a single physical scanner or keypad entry to intelligently toggle a member's state between 'checked_in' and 'checked_out' based on their current daily record, reducing API surface area and simplifying client-side logic.
* **[DECIDED]** Implement high-performance Attendance Summary and History endpoints. De-normalizing visitation counts and LTV calculations into a dedicated summary payload provides the Member Detail UI with immediate, low-latency metrics while reserving full history fetching for the audit sub-view.
* **[DECIDED]** Adopt a "Hybrid LTV Summation" strategy in the backend. By combining the `Member.lifetime_value` (Legacy) with granular `Payment.sum()` (Granular), we ensure total financial accuracy during the transition from ad-hoc status markers to transactional accounting.
* **[DECIDED]** Implement the "Resilient Parallel Hydration" pattern in Flutter using `Future.wait` combined with atomic `.catchError()` handlers. This allows multiple analytical endpoints to be fetched simultaneously (Legacy Stats, Reminders, Attendance) without a single-point-of-failure crashing the UI.
* **[DECIDED]** Redesign the Member Detail stat grid with a high-density, emoji-based 4-card pattern. Standardizing on a uniform GridView layout with semantic colors and relative temporal formatting (e.g. '3d ago', 'Yesterday') significantly enhances scannability and user engagement.
* **[DECIDED]** Standardize member renewal logic explicitly off the current `new Date()` instead of the old `expiry_date`. Additionally, tie LTV and `last_payment_date` directly to the `renewMembership` function to maintain parity with standalone payment collection.
* **[DECIDED]** Adopt the Indian Rupee (₹) as the active currency symbol over USD ($) explicitly for live data fields and reporting across both the CRM API models and Flutter client.
* **[DECIDED]** Pitch Plan WhatsApp Integration (`attendance_screen.dart`): Wired the in-app active floor Pitch Plan button directly into the `ApiService.createManualReminder` WhatsApp flow to mirror the capability previously isolated to `member_detail_screen.dart`.
* **[DECIDED]** Enhanced Floor Activity Tracking (`attendance_screen.dart`): Replaced mock "Arrived today" descriptors with real-time `checkInTime` tracking mapped from `/api/attendance/:gym_id/today`. Removed redundant "Profile" button by unifying to full-card navigation. Introduced parallel searching + categorical filtering (Active, Trial, Debt) against hydrated live session state.
* **[DECIDED]** LedgerScan model stores all raw AI extraction results as JSONB before owner confirmation. Two-phase pattern: extract saves with confirmed: false, owner confirm sets confirmed: true.
* **[DECIDED]** extractGymRecords migrated from old @google/generative-ai SDK to @google/genai Vertex AI SDK. Response text read via response.text directly — not via candidates chain.
* **[DECIDED]** Fuzzy name matching via fuse.js threshold 0.4, top 3 matches per entry with confidence score, phone, status, join_date as differentiators. requires_manual_selection flag blocks auto-select when 2+ members score 85%+.
* **[DECIDED]** Sequelize transaction wrapping on confirm endpoint. Full rollback on any failure — no partial writes possible.
* **[DECIDED]** LedgerScan cleanup cron at 2am daily removes unconfirmed scans older than 7 days.
* **[DECIDED]** Payment method extracted dynamically by Gemini. Defaults to ledger_scan if not visible in image.
* **[DECIDED]** Due/outstanding amounts map to Payment.status: pending. Only paid status updates Member.lifetime_value and Member.payment_collected.
* **[DECIDED]** Trial status visible in logbook updates Member.is_trial: true and Member.status: trial directly on confirm.
* **[REJECTED]** Raw PostgreSQL string querying → Banned to prevent unmitigated injection and sync bugs. Sequelize ORM is aggressively required.
* **[REJECTED]** Complex cascading DB cleanup inside background workers → Rejected in `reminderCron.js`; if a member is forcefully deleted mid-queue, the loop will safely detect the orphan, skip it, and resume polling rather than attempting resource-heavy cascade handling mid-interval.
* **[BACKLOG]** Multi-page scan grouping via ScanSession model. Multiple LedgerScan records linked under one session_id. Owner reviews all pages together and confirms in single transaction. Do not build until AI Voice feature is complete. Pattern: ScanSession table → session_id foreign key on LedgerScan → Flutter groups entries by session before showing review screen.
* **[DECIDED]** AI Voice Log uses device-native speech_to_text and flutter_tts — no telephony needed. Gemini handles conversation via text in/out only.
* **[DECIDED]** Voice session question flow: new members → payments → dues → attendance → trial → end. Gemini adapts if owner jumps ahead.
* **[DECIDED]** check_in_time extracted from speech in HH:mm format. Parsed on backend to exact UTC timestamp using dayjs.
* **[DECIDED]** Duplicate member name handling in voice — AI verbally describes both members with join_date and phone ending. Owner picks verbally. member_id used for exact DB lookup on confirm avoiding name ambiguity.
* **[DECIDED]** Correction handling uses CORRECT action — Flutter removes wrong entry from collectedEntries and adds corrected one silently. No extra confirmation exchange needed.
* **[DECIDED]** Voice session uses same idempotency checks as ledger scan — duplicate attendance and payment guards on /voice/end endpoint.
* **[DECIDED]** VoiceSession processed flag blocks double processing — returns 409 if /voice/end called twice on same session.
* **[DECIDED]** Voice log upgraded to Gemini function calling (tools). Real-time DB writes on every confirmed entry — no end-session batch. 8 tools defined: log_attendance, log_payment, log_due, add_member, mark_trial, lookup_member, check_dues, get_attendance_today. Tool execution loop handles up to 5 sequential tool calls per turn.
* **[DECIDED]** Member list loaded fresh from DB on every /voice/message call — not passed from Flutter. Ensures AI always has current data.
* **[DECIDED]** /voice/end simplified to session close only — no data processing. All data already written to DB via tools during conversation.
* **[DECIDED]** Op.iLike used for member name matching in tool executor — handles partial names and case insensitivity for voice input accuracy.
* **[DECIDED]** Voice feature uses Gemini function calling with 8 registered tools (FUNCTION_DECLARATIONS). Real-time DB writes on every confirmed entry. No end-session batch needed.
* **[DECIDED]** All voice AI responses in Roman script only — no Devanagari. Language mirrors owner's current message per turn.
* **[DECIDED]** GCP Text-to-Speech Neural2 en-IN-Neural2-B used for AI voice. Audio returned as MP3 base64 from /api/voice/speak and played via just_audio in Flutter.
* **[DECIDED]** Device speech_to_text with en_IN locale used for recording. Recognizes both English and Hindi speech.
* **[DECIDED]** check_out_time auto-computed as check_in_time + 1 hour 
  inside log_attendance tool. No owner input needed, no new tool added. 
  Voice logging is check-in driven — check-out is always inferred.
* **[DECIDED]** Phone validation enforced in add_member tool before 
  Member.create. Strips non-digits, requires minimum 10 digits, 
  normalizes to +91 E.164 format. Literal string 'unknown' as phone 
  is permanently rejected.
* **[DECIDED]** Amount validation enforced in log_payment and log_due 
  before Payment.create. parseFloat + NaN + <= 0 guard on both. 
  log_due intentionally has no today-duplicate guard — dues stack 
  by design to support multi-month debt recording.
* **[DECIDED]** Time parsing in log_attendance uses dayjs.utc() 
  multi-format array covering 8 patterns including AM/PM, 12hr, 
  and bare hour formats. Invalid time strings return failure to AI 
  which re-asks owner — NaN is never written to the DATE column.
* **[DECIDED]** Gym model created as the canonical identity layer for the platform. Single table (gyms) with id, owner_name, gym_name, phone. The existing gym_id UUID floating across all tables now has a real backing row. No existing queries or models changed.
* **[DECIDED]** Gym model seeded with findOrCreate using the hardcoded Flutter UUID '550e8400-e29b-41d4-a716-446655440000' — safe to run multiple times without duplication.
* **[DECIDED]** /api/gym/:gym_id GET and PUT routes added for profile reads and updates. Registered in app.js alongside existing routes.
* **[DECIDED]** /voice/start fetches owner_name from Gym table as primary source. Flutter-sent owner_name is fallback. 'there' is final fallback. gym_id guard hoisted to top of handler before any DB query.
* **[DECIDED]** globalOwnerName in Flutter overridden from DB on app launch via fetchGymProfile() before runApp() executes. Volatile RAM is no longer the source of truth for owner identity.
* **[DECIDED]** buildSystemPrompt(ownerName) replaces static SYSTEM_PROMPT string. Owner name injected dynamically into Flexy greeting on every session start.
* **[COMPLETED]** Hardcoded gym_id UUID '550e8400-e29b-41d4-a716-446655440000' removed from api_config.dart. gym_id now read from SharedPreferences populated by /api/auth/setup response. cognito_sub column added to Gym model. seed.js and Bruno tests retain UUID for dev use only.
* **[BACKLOG]** Gym logo/avatar upload feature. Owner should be able to upload gym logo from profile screen avatar tap. Needs: image_picker Flutter package, multipart POST endpoint /api/gym/:gym_id/avatar, Express static serving for /uploads/avatars/, avatar_url column on Gym model, avatar displayed in profile and home screen top bar. Do not build until auth feature is complete.
---

## Removed Modules (Post-Stable Migration)

* **[REMOVED]** `/backend/models/Goal.js` (and Streak) → Legacy CRM Fitness Tracking Module.
* **[REMOVED]** `/backend/models/Loan.js` → Legacy Debt/Finances Tracker.
* **[REMOVED]** `/backend/models/ActivityFeed.js` → Legacy System Event Stream Module.
* **[REMOVED]** `/backend/services/activityService.js` → Legacy logic for dormant models.
* **[REMOVED]** Associations in `Member.js` → Cleared all hasMany references to orphaned tables to reduce query overhead.

---

## Known Workarounds

* **`/backend/workers/reminderCron.js`** → Allows missing/invalid Member phone numbers to increment a `retry_count` buffer and gracefully skip. → **Why**: A crash inside the cron interval destroys the polling loop for all other members globally.
* **`/backend/app.js` (initReminderCron)** → Cron mounts identically to existing Node process. → **Why**: Local/Sandbox configuration. This workaround lacks a Redis lock; horizontal scaling will cause multiple Node clones to duplicate sending queues simultaneously.
* **`/lib/services/api_service.dart`** → Hardcoded `baseUrl` pointing to internal `192.168.*.*`. → **Why**: Safely points the physical or emulated Android client at the development tower's LAN node without relying on dynamic DNS forwarding.
* **`/backend/services/twilioProvider.js`** → E.164 numbering bypass. → **Why**: Simplistic `+91` injection handles local string prefixes without heavily formatting the raw UI output.

---

## Mocked / Placeholder Registry

* **`/backend/.env` (TWILIO_SID, TWILIO_TOKEN)** → Twilio Gateway is currently mocked. → **Needs**: Real `AC...` SID strings to establish actual WhatsApp/SMS network connection hooks.
* **`/backend/services/retellProvider.js`** → Retell voice webhook calls execute purely on internal stubs wrapping `console.log`. → **Needs**: Legitimate Retell AI integration keys (`RETELL_AI_KEY`).
* **`/backend/workers/reminderCron.js` (Payload Method Switch)** → `contentSid` dynamically binds to exactly "MOCK_SID" strings. → **Needs**: Actual pre-approved Twilio WhatsApp Template ID codes to authorize messages natively against WhatsApp policies. 
