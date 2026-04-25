# Gym-Ops Error and Troubleshooting Index

## How to use this file
Before debugging any issue, check here first.
If the error is listed, use the documented fix only.
Never suggest approaches listed under "Do not try".

---

## [ERROR] Reminder CRON Missing Member Link
- **Where**: `backend/workers/reminderCron.js` -> `processReminders()`
- **What happens**: Console logs `[CRON] Reminder <id> has no linked Member row; skipping.`
- **Root cause**: A `WorkflowReminder` exists in the database queue, but the linked `Member` was forcefully deleted (likely a Cascade failure or orphaned record).
- **Fix applied**: The row is explicitly skipped in code without crashing the 15-minute polling loop.
- **Do not try**: Do not write complex manual cascading DB cleanup inside the cron loop itself. Let the ORM constraints handle it naturally or ignore the orphans.

## [ERROR] AI Scan Failing (AI_SCAN_FAILED)
- **Where**: `backend/services/aiService.js` / `backend/routes/aiRoutes.js`
- **What happens**: API returns `{"success": false, "message": "AI_ERROR", "error": "AI_SCAN_FAILED"}`
- **Root cause**: Either the `GCP_SA_KEY` is missing/malformed or the **Vertex AI API** is not enabled in the project, or the Service Account lacks the **Vertex AI User** role.
- **Fix applied**: Migrated to `@google-cloud/vertexai` which uses IAM credentials directly. Ensure **Vertex AI API** is enabled in the Google Cloud Console for the project.
- **Do not try**: Do not attempt to use Gemini API keys with the Vertex AI SDK; they are different authentication systems.
- **Status**: WORKAROUND

## [ERROR] Reminder CRON Missing Phone Number
- **Where**: `backend/workers/reminderCron.js` -> `processReminders()`
- **What happens**: Console logs `[CRON] Reminder <id>: member has no phone; skipping.`
- **Root cause**: Attempting to schedule a WhatsApp Twilio blast or an AI outbound call to a member enrolled without a registered phone number.
- **Fix applied**: Safely intercepts the missing data, attempts to increment `retry_count`, and skips the execution logic so the server doesn't crash on the Provider's HTTP request.
- **Do not try**: Do not crash or "throw" errors inside the cron loop natively; do not attempt to prompt for a phone number asynchronously here.
- **Status**: WORKAROUND

## [ERROR] Retell AI Trigger Timeout / Credentials
- **Where**: `backend/services/retellProvider.js` -> `triggerWaitlistCall()`
- **What happens**: Console logs `Failed to trigger Retell Call [Error object]`
- **Root cause**: The API Key is completely mocked in the `.env`, or the Retell webhook endpoint times out dynamically during request.
- **Fix applied**: The method is wrapped in a discrete `try/catch` block that traps the provider crash and shields the calling Express route from returning a raw 500 automatically.
- **Do not try**: Do not alter the async/await signature of this method, and do NOT install external wrapper libraries to bypass Retell.
- **Status**: OPEN

## [ERROR] Auto-Expiry Midnight Evaluation Failure
- **Where**: `backend/app.js` -> `runDailyExpiry()`
- **What happens**: Console logs `❌ Auto-expiry cron failed: [Error message]`
- **Root cause**: Database lock or connection pool timeout occurs specifically during the daily midnight sequence executing the Member status updates.
- **Fix applied**: Caught centrally in `app.js` via `.catch()`. The Node process will stay alive.
- **Do not try**: Do not extract this midnight query into an external process or serverless function. It must remain within the active Express pool.
- **Status**: OPEN

## [ERROR] Flutter ApiException Bubbling
- **Where**: `my_app/lib/screens/member_detail_screen.dart` 
- **What happens**: UI catches HTTP failures via `on ApiException catch (e)`.
- **Root cause**: Any HTTP request containing a 4xx or 5xx code is strictly intercepted by `api_service.dart` and repackaged into an `ApiException(message, statusCode)` payload.
- **Fix applied**: Triggers a native Flutter `ScaffoldMessenger` SnackBar containing `e.message` directly parsed from the JSON server response.
- **Do not try**: Never catch raw JSON decoding errors silently inside the screens—always allow `ApiException` to bubble up natively so the user knows exactly why the request failed.
- **Status**: RESOLVED

---

## [ERROR] Member Not Found by Phone
- **Where**: `backend/routes/attendanceRoutes.js` -> `POST /scan`
- **What happens**: API returns 404 with message "Member not found".
- **Root cause**: The provided phone number during the attendance scan does not exactly match any registered member in the database.
- **Fix applied**: Explicit 404 response allows the scanner UI to trigger an 'Enroll Member' or 'Retry' prompt.
- **Do not try**: Do not attempt to auto-create a member row from a scan. Enrollments must follow the full `/api/members` workflow.
- **Status**: RESOLVED

## [ERROR] Already Completed Daily Session
- **Where**: `backend/routes/attendanceRoutes.js` -> `POST /scan`
- **What happens**: API returns 200 with message "Already completed session today" and `action: 'already_done'`.
- **Root cause**: A member who has already checked-in and checked-out for the current UTC date attempts to scan again.
- **Fix applied**: Logic specifically blocks a third scan per day to prevent data pollution; returns a success:false flag but with a 200 code to allow predictable UI messaging.
- **Do not try**: Do not delete previous sessions to allow "re-entry"; re-entry should be handled by a separate multi-session model if requested in the future.
- **Status**: RESOLVED

---

## [ERROR] Malformed Gym ID UUID Format
- **Where**: `backend/routes/memberRoutes.js` -> `GET /:gym_id`
- **What happens**: API returns 400 with message "Invalid gym_id format", "Invalid status value", etc.
- **Root cause**: Request parameters or query strings contain a value that is not a valid UUID or not in the allowed list of enums.
- **Fix applied**: Added regex and enum value validation for query parameters before database query; returns 400 immediately.
- **Do not try**: Do not manually validate these values in any service method; always handle format validation at the route/middleware layer.
- **Status**: RESOLVED

## [ERROR] Analytic Summary Model Drift (LTV)
- **Where**: `backend/routes/memberRoutes.js` -> `GET /attendance-summary`
- **What happens**: LTV returns lower than expected totals.
- **Root cause**: Historical payments existed only as an aggregate `lifetime_value` field on the Member record, while new payments are discrete `Payment` records.
- **Fix applied**: Implemented "Hybrid LTV Summation" logic that combines the legacy field with the new transaction sum.
- **Do not try**: Do not wipe the legacy `lifetime_value` field until a full migration task is executed as part of a future deployment.
- **Status**: RESOLVED

- **Status**: RESOLVED

---

## [ERROR] Ledger Scan Parse Failed
- Where: backend/routes/aiRoutes.js -> POST /api/ai/scan-book/:gym_id
- What happens: Returns { success: false, error: "PARSE_FAILED" }
- Root cause: Blurry or low contrast image
- Fix: Flutter shows retake prompt
- Do not try: Do not regex parse raw string — require full rescan
- Status: KNOWN

## [ERROR] Ledger Confirm Transaction Rollback
- Where: backend/routes/aiRoutes.js -> POST /api/ai/scan/:scan_id/confirm
- What happens: Returns 500, nothing written to DB
- Root cause: DB constraint violation or timeout mid-confirm
- Fix: Owner retries — transaction ensures no partial writes exist
- Do not try: Do not retry individual entries — always retry full confirm
- Status: KNOWN

## [ERROR] Duplicate Member Names in Fuzzy Match
- Where: backend/routes/aiRoutes.js -> fuzzy match logic
- What happens: Two members return identical high confidence scores
- Root cause: Two members registered with identical names
- Fix: requires_manual_selection flag forces owner to pick using 
  phone and join_date as differentiators
- Do not try: Do not auto-select when multiple high confidence 
  matches exist
- Status: KNOWN

## [ERROR] AI_GATEWAY_TIMEOUT
- Where: backend/services/aiService.js -> extractGymRecords
- What happens: Gemini call fails, returns AI_GATEWAY_TIMEOUT error
- Root cause: Vertex AI connectivity issue or malformed image data
- Fix: Check GCP credentials, retry with fresh image
- Do not try: Do not increase Node timeout beyond 60s
- Status: KNOWN

## [ERROR] IMAGE_DATA_TOO_SHORT
- Where: backend/services/aiService.js -> extractGymRecords
- What happens: Extraction aborted before reaching Gemini
- Root cause: Empty or corrupt base64 string sent from Flutter
- Fix: Verify image picker is reading bytes correctly before encoding
- Do not try: Do not lower the 500 character minimum threshold
- Status: KNOWN

## [ERROR] AI Model Not Found on Vertex AI
- Where: backend/services/aiService.js -> _modelId
- What happens: 404 NOT_FOUND, AI_OFFLINE on test endpoint
- Root cause: Model alias like gemini-1.5-flash not accepted by 
  Vertex AI — requires exact model string
- Fix: Use gemini-2.5-flash as _modelId
- Do not try: Do not use gemini-1.5-flash or unversioned aliases
- Status: RESOLVED

---

## [ERROR] Voice Session Gemini Parse Failed
- Where: backend/routes/voiceRoutes.js -> POST /api/voice/message
- What happens: Returns safe fallback "Sorry, I didn't catch that"
- Root cause: Gemini returned non-JSON conversational text
- Fix: Automatic — fallback triggers re-listening
- Do not try: Do not regex parse — fallback is cleaner
- Status: KNOWN

## [ERROR] speech_to_text not initializing
- Where: lib/screens/voice_log_screen.dart -> _startSession
- What happens: Microphone unavailable error shown
- Root cause: Microphone permission not granted
- Fix: Add to AndroidManifest.xml:
  <uses-permission android:name="android.permission.RECORD_AUDIO"/>
  Add to Info.plist:
  NSMicrophoneUsageDescription
- Status: KNOWN

## [ERROR] flutter_tts completion handler not firing
- Where: lib/screens/voice_log_screen.dart -> _initTts
- What happens: Auto-listen after TTS does not trigger
- Root cause: Some Android versions have TTS completion issues
- Fix: Add manual mic button as fallback — already implemented
- Status: KNOWN

---

## TODOs, FIXMEs, HACKs, and BUGs
- **NONE FOUND** (No lingering codebase markers were found outside of standard auto-generated Window/Mac compilation templates).

---

## [ERROR] Voice End — member not found
- Where: backend/routes/voiceRoutes.js -> POST /voice/end
- What happens: processed: 0, all entries skipped
- Root cause: Wrong gym_id passed to /voice/start — member lookup fails because session gym_id doesn't match member gym_id
- Fix: Always use correct gym UUID for /voice/start not a member ID
- Do not try: Do not debug the member lookup code — check gym_id first
- Status: KNOWN

## [ERROR] Tool executor member not found
- Where: voiceRoutes.js -> executeTool
- What happens: Tool returns { success: false, message: "Member X not found" }
- Root cause: Owner said name differently from how it's stored in DB
- Fix: Op.iLike with % wildcard handles partial matches — if still 
  failing, member may not exist — AI will ask owner to add them first
- Do not try: Do not skip the not-found check — always return clear message
- Status: KNOWN

## [ERROR] Gemini tool loop exceeds max rounds
- Where: voiceRoutes.js -> /voice/message tool loop
- What happens: Loop exits after 5 rounds without final text reply
- Root cause: Gemini keeps calling tools without producing text
- Fix: maxToolRounds = 5 cap prevents infinite loop — finalReply 
  will be empty string, Flutter shows nothing, mic reactivates
- Status: KNOWN
