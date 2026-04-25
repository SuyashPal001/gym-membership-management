# GPT.md

High-signal implementation notes for working safely in this repo.

---

## Project Shape

* Frontend: Flutter app in `gym-membership-management/my_app`
* Backend: Express + Sequelize in `backend`
* Core domains: members, membership plans, payments, attendance, reminders, voice, ledger scan
* Multi-tenancy model: all protected business data is scoped by `gym_id`

---

## Non-Negotiable Rules

* Do not treat trial as a fake paid membership plan.
* Do not create or persist a synthetic `Trial Plan` just to simplify UI.
* Keep `membership_type_id = null` for trial members.
* Always scope backend member/payment/attendance queries by `gym_id`.
* Use `dayjs.utc()` for date math and scheduling logic.
* `payment_collected` and `Payment` records must stay consistent.

---

## Member Enrollment Truth

Trial member:

* `status = 'trial'`
* `is_trial = true`
* `membership_type_id = null`
* `payment_collected = false`
* expiry is trial-based, not plan-based

Paid-plan member:

* `status = 'active'`
* `is_trial = false`
* `membership_type_id = <real plan id>`
* `payment_collected` depends on whether money was collected at enrollment

Do not collapse these two states into one concept.

---

## Payments / Collect Contract

`/api/payments` is not just raw data anymore. It returns a UI-ready row contract.

Important derived fields:

* `has_membership_plan`
* `lifecycle_type`
* `primary_action`
* `display_plan_name`
* `display_amount`
* `urgency_label`

Meaning:

* Raw domain fields remain honest
* UI should render from the derived fields
* Trial rows should not rely on patching `"No Plan"` inside Flutter

Current intent:

* Trial row label: `ON TRIAL` or `TRIAL ENDED`
* Trial badge: `TRIAL ONGOING` or `TRIAL OVERDUE X DAYS`
* Trial CTA: `CONVERT`
* Trial amount: hidden via `display_amount = null`

---

## Frontend Guidance

When working on Collect or Payments screens:

* Prefer `displayPlanName` over `planName`
* Prefer `displayAmount` over `planAmount` for row rendering
* Prefer `urgencyLabel` over recomputing date text in the widget
* Prefer `primaryAction` over branching directly on `status == 'trial'`

The shared model for this is:

* `gym-membership-management/my_app/lib/models/payment_models.dart`

Main consumers:

* `gym-membership-management/my_app/lib/screens/unpaid_payments_screen.dart`
* `gym-membership-management/my_app/lib/screens/payments_screen.dart`

---

## Backend Guidance

When changing payment summary behavior, update:

* `backend/services/memberService.js`

Do not push row-label business logic into multiple Flutter screens if the backend can define it once.

The preferred pattern is:

1. Keep DB/storage fields semantically correct
2. Build a derived response view-model in backend
3. Let Flutter render that contract directly

---

## Known Traps

* A trial member without a plan is valid. A non-trial member without a plan is usually bad data.
* `planName = "No Plan"` is raw fallback data, not a presentation decision.
* Mixed frontend logic across screens causes drift fast. Centralize semantics.
* Some files contain older encoding artifacts for the rupee symbol. Be careful when doing exact-string patches.
* The repo may already have unrelated local changes. Do not revert them casually.

---

## Docs Worth Reading

* `COLLECT_SCREEN_UX.md`
* `CHANGELOG.md`
* `SCHEMA.md`
* `PROJECT.md`
* `ERRORS.md`

---

## If You Change Core Trial/Payment Logic

Update all of these together:

* backend payment/member service logic
* Flutter payment summary model
* Collect screen
* Payments screen
* `COLLECT_SCREEN_UX.md`

If you only change one layer, the system will drift.
