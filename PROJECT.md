# Gym-Ops

## 1. AI Usage Rules

**Strict Operations Guardrails (DO NOT DEVIATE):**
*   **NEVER** introduce external process schedulers (BullMQ, Redis, Vercel Crons) without direct user approval. We strictly run `node-cron` inside the active Express thread.
*   **NEVER** write raw `sequelize.query('SELECT...')` strings. Every database interaction must funnel through proper Sequelize ORM models.
*   **NEVER** throw standard `Exception(msg)` strings in Flutter API calls. You must always throw an instance of `ApiException` containing an exact message to bubble to UI Snackbars.
*   **NEVER** use standard javascript `new Date()`. You must strictly enforce `dayjs.utc()` arrays to calculate differences.
*   **Unsure?** Ask. Never guess or try to silently shim missing credentials. 

---

## 2. Environment Variables

*   `DATABASE_URL` → Primary Neon PostgreSQL connection pool limit string (SSL enforced).
*   `DB_HOST` → Local DB Hostname.
*   `DB_PORT` → Local DB Port.
*   `DB_NAME` → Local DB schema name.
*   `DB_USER` → Local DB user.
*   `DB_PASSWORD` → Local DB password lock.
*   `PORT` → Node.js Express server access port.
*   `NODE_ENV` → Dictates `development` (enables `console.log` syncing) vs `production`.
*   `TWILIO_SID` → Twilio Main Account identifier. **⚠️ MOCKED**
*   `TWILIO_TOKEN` → Twilio Root connection token. **⚠️ MOCKED**
*   `TWILIO_MESSAGING_SID` → Active Twilio Sending API Gateway for WhatsApp blast. **⚠️ MOCKED**

*(Note: `RETELL_AI_KEY` is completely missing from `.env` and defaults to mocked implementations in the codebase).*

---

## 3. Data Flow

### Flow A: Standard CRUD (Sync Profile Details)
1. **Flutter Button Tap** → Triggers `_loadData()` in `member_detail_screen.dart`
2. **Dart API Service** → Calls `ApiService.fetchMemberStats` enforcing a strict 25s timeout via `http.get`.
3. **Express Node Router** → Hits `GET /members/:gym_id/:member_id/stats`
4. **Node Service Layer** → `memberService.getMemberStats()` executes DB query.
5. **Sequelize ORM** → Translates query to Postgres via `pooler` adapter.
6. **PostgreSQL** → Resolves and aggregates lifetime value tables.
7. **Return Channel** → Route returns `res.status(200).json({ success: true, data })`.
8. **Dart Deserializer** → `crm_models.dart` `MemberStats.fromJson` handles string truncations safely.
9. **Flutter UI State** → Calls `setState()` resolving the `CircularProgressIndicator()`.

### Flow B: Cron Worker Cycle (Scheduling Outbound AI)
1. **Cron Tick** → `reminderCron.js` fires every 15 minutes.
2. **Sequelize Lookahead** → DB selects `WorkflowReminder` where `scheduled: false` and date is `<=` `NOW() + 2 hours`.
3. **Iteration Check** → Validates `Member.phone` exists; increments `retry_count` if it fails natively.
4. **Provider Wrapper** → Dispatches payload payload variables dynamically via `retellProvider.js`.
5. **DB Mutability** → Executes `reminder.update({ scheduled: true, reference_id: callId })` successfully.

---

## 4. Database Relationships
*   `Member` → belongsTo → `MembershipType` (cascade: no)
*   `MembershipType` → hasMany → `Member` (cascade: no)
*   `Member` → hasMany → `WorkflowReminder` (cascade: yes)
*   `Member` → hasMany → `Call` (cascade: yes)

---

## 5. Background Workers
*   **Initialization**: Initialized securely in `/backend/app.js` using `require('./workers/reminderCron')()`.
*   **Target Table**: Polls the Postgres `WorkflowReminder` module.
*   **Execution Rate**: `*/15 * * * *` (Top of every 15 minutes) and `1 0 * * *` (Daily Midnight checks).
*   **Behavior Check**: Skips any task without an active `Member.phone`. Directly integrates `sendAt` fixed delays to Third-Party wrappers to offset node lag.
*   **Limitations**: Code resides in a single monolith. It is **NOT** horizontally scalable (multiple instances will cause DB race conditions as there are no Redis `SETNX` distributed locks).
*   **Hard Rule**: Do not extract, decouple, or alter the `node-cron` integration framework unless explicitly commanded.

---

## 6. Folder Structure (With Exact Files)

### Backend
*   `/config/` (`database.js`)
*   `/middleware/` (`validators.js`)
*   `/models/` (`Member.js`, `WorkflowReminder.js`, `Call.js`)
*   `/routes/` (`memberRoutes.js`, `reminderRoutes.js`)
*   `/scripts/` (`seed.js`, `syncDb.js`)
*   `/services/` (`memberService.js`, `reminderService.js`, `twilioProvider.js`, `retellProvider.js`, `notificationService.js`)
*   `/uploads/` (Stores local raw OS images e.g., `/avatars/1722.png`)
*   `/workers/` (`reminderCron.js`)

### Frontend (my_app)
*   `/lib/config/` (`api_config.dart`)
*   `/lib/models/` (`member.dart`, `crm_models.dart`, `payment_models.dart`, `reminder_models.dart`)
*   `/lib/screens/` (`home_screen.dart`, `add_member_screen.dart`, `member_detail_screen.dart`, `member_list_screen.dart`, `payments_screen.dart`, `main_scaffold.dart`)
*   `/lib/services/` (`api_service.dart`, `api_exception.dart`)
*   `/lib/utils/` (`member_avatar.dart`)
*   `/lib/widgets/` (`api_server_dialog.dart`)

---

## 7. Key Patterns with Code Snippets

**Express Route Encapsulation:**
```javascript
router.get('/:gym_id/:id/stats', async (req, res) => {
  try {
    const stats = await memberService.getMemberStats(req.params.id, req.params.gym_id);
    res.json({ success: true, data: stats });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
```

**Sequelize Filtering Constraint:**
```javascript
const member = await Member.findOne({
  where: { id, gym_id },
  include: [{ model: MembershipType, attributes: ['name', 'amount'] }],
});
```

**Payment Expiry Filtering (paymentRoutes.js):**
```javascript
// GET /api/payments/:gym_id?expiry_filter=overdue
const validFilters = ['today', 'this_week', 'overdue'];
// today: expiry = current UTC day
// this_week: expiry in next 7 days
// overdue: expiry < today AND payment_collected = false
```

**Flutter API Safety Wrapper Validation (`api_service.dart`):**
```dart
static Future<MemberStats> fetchMemberStats(String gymId, String memberId) async {
  final uri = Uri.parse('$baseUrl/members/$gymId/$memberId/stats');
  try {
    final response = await _get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return MemberStats.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException(_errorMessage(response.body, 'Failed to load stats'), response.statusCode);
  } on ApiException {
    rethrow;
  } catch (e) {
    _throwUnreachable(uri, e);
  }
}
```

**Accurate Timezone Structuring:**
```javascript
const expiryDayjs = dayjs.utc(expiry_date);
const targetDate = expiryDayjs.subtract(7, 'day').toDate();
```

**Recent API Changes (Reminders Module):**
*   `GET /api/reminders/:gym_id` — Fetch upcoming non-cancelled task queue.
*   `GET /api/reminders/:gym_id/history` — Fetch last 50 sent tasks with `paid_after_reminder` signal.
*   `POST /api/reminders/:gym_id/:member_id` — Queue an immediate manual WhatsApp/AI_CALL task.
*   `DELETE /api/reminders/:gym_id/:reminder_uuid` — Logically cancel a pending task via public UUID.

**Recent Frontend Changes (Reminders Integration):**
*   **Payments Screen**: Added a method-selection bottom sheet (WhatsApp/AI Call) to the Unpaid roster.
*   **Member Profile**: Integrated a new "Reminder History" feed showing the last 4 follow-ups with conversion/payment indicators.
*   **Audit Logic**: Switched all direct communication buttons to use the new centralized task queuing system.
```

---

## 8. What We Never Do

*   ❌ **Never** write raw SQL database commands `sequelize.query('...')` — use proper `Model.findAll()` constructs instead.
*   ❌ **Never** dispatch a flutter error raw. — use `ApiException(message)` so it properly displays in UI.
*   ❌ **Never** handle local JS Dates (`new Date()`). — use `dayjs.utc()` securely logic to protect background jobs.
*   ❌ **Never** implement remote Queue Schedulers (AWS SQS, Vercel). — use `node-cron` integrated locally instead.
*   ❌ **Never** install authentication frameworks (Passport.js). — leave endpoints fully accessible to the Intranet context.
