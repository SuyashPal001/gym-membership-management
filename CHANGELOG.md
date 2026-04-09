# Gym-Ops Action & Changelog Registry

## AI Rule for this file
* **Never suggest reverting a [DECIDED] item.**
* **Never activate a [REJECTED] pattern.**
* **Always check Mocked Registry before assuming a live integration works.**
* **Mark anything uncertain as UNCLEAR: rather than guessing.**

---

## Architectural Decisions Log

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
* **[REJECTED]** Raw PostgreSQL string querying → Banned to prevent unmitigated injection and sync bugs. Sequelize ORM is aggressively required.
* **[REJECTED]** Complex cascading DB cleanup inside background workers → Rejected in `reminderCron.js`; if a member is forcefully deleted mid-queue, the loop will safely detect the orphan, skip it, and resume polling rather than attempting resource-heavy cascade handling mid-interval.

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
