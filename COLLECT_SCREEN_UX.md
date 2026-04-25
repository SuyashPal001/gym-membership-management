# GymOps: Collect Screen UX & Business Logic

This document captures the current business rules, rendering contract, and prioritization logic for the **Collect (Unpaid Payments)** screen.

---

## 1. Design Philosophy: "Lead vs. Debt"
The screen is intentionally split into two mental buckets:

* **Financial Debt (Red/Emerald/Grey)**: paid-plan members whose payment is due, overdue, or approaching renewal.
* **Sales Opportunity (Yellow)**: trial members who should be converted into paying members.

---

## 2. Color-Coded Urgency System & Prioritization

The overall priority order is strictly fixed by colors. Red is always at the absolute top, followed by Yellow, Emerald, and finally Grey/White.

| Priority | Category | Color | Business Trigger |
| :--- | :--- | :--- | :--- |
| **1** | **RED** | `AppColors.error` | Overdue paid plan, Due Today, Trial Ended, or Enrolled with No Initial Payment. Always displays right at the top. |
| **2** | **BLUE** | `AppColors.infoBlue` | Paid plan due in 1, 2, or 3 days, OR Trial Ongoing. |
| **3** | **EMERALD** | `AppColors.emerald` | Paid plan due in 4, 5, or 6 days. |
| **4** | **GREY/WHITE** | `Silver/Grey` | Paid plan due in exactly 7 days (1 week). |

---

## 3. Labeling & Display Rules by Member Type

### Type 1: Regular Member (With Plan & Initial Payment Done)
* **Elements**: Name, Avatar, Membership Plan Name, Plan Amount, Color Badge.
* **Buttons**: `REMIND` and `MARK PAID`.
* **Badge Pattern**:
  - `OVERDUE X DAYS` (Red)
  - `DUE TODAY` (Red)
  - `DUE IN X DAYS` (Color relative to 1-3 [**Blue**], 4-6 [Emerald], 7 [Grey]).

### Type 2: Trial Member
* **Elements**: Name, Avatar, Default Plan Name (`ON TRIAL`), NO Amount, Color Badge.
* **Buttons**: `REMIND` and `CONVERT`.
* **Badge Pattern**:
  - `TRIAL OVERDUE X DAYS` (Red - Trial Ended)
  - `TRIAL ONGOING` (**Blue** - Trial Ongoing)

### Type 3: Enrolled Member (1st Payment Mapped but NOT Collected)
* **Elements**: Name, Avatar, Membership Plan Name, Plan Amount, Color Badge.
* **Buttons**: `REMIND` and `MARK PAID`.
* **Badge Pattern**:
  - `OVERDUE X DAYS` (Always Red, treating the uncollected initial payment as an immediate debt).

---

## 4. Sorting Logic

1. **Top Section (RED)**: Overdue members, Due Today, Trial Ended, and No Initial Payment.
2. **Second Section (BLUE)**: Due in 1, 2, 3 days, and Ongoing Trials.
3. **Third Section (EMERALD)**: Due in 4, 5, 6 days.
4. **Bottom Section (GREY)**: Due exactly in 7 days.

---

## 6. Data Filtering Logic
The Collect screen hides noise aggressively:

* Members already marked paid: `payment_collected = true`
* Members without a membership plan who are not trials
* Members whose expiry is more than 7 days away

---

## 7. API View-Model Contract
The Collect screen now renders from an explicit backend view-model instead of guessing from raw plan fields.

### Raw Domain Data
* `MembershipType`: actual paid plan relation, or `null` for trials
* `status`: member lifecycle state such as `active`, `expired`, or `trial`
* `is_trial`: persisted trial flag

### Derived UI Fields
* `has_membership_plan`: distinguishes real plan-backed members from unplanned records
* `lifecycle_type`: semantic row class, currently `trial`, `plan_due`, or `unplanned`
* `primary_action`: explicit call-to-action, currently `convert` or `mark_paid`
* `display_plan_name`: final label such as `ON TRIAL`, `TRIAL ENDED`, or normalized plan labels
* `display_amount`: nullable rupee amount; `null` for trials
* `urgency_label`: final badge text such as `TRIAL ONGOING`, `INITIAL DUE`, or `OVERDUE 3 DAYS`

This keeps the database model honest: trial members still do not receive a fake membership plan, but the frontend gets a stable display contract.

---

## 8. DB Verification Queries
Use these to simulate common states:

```sql
-- RED: Initial Due
UPDATE members
SET status = 'active', lifetime_value = 0, payment_collected = false
WHERE member_name = 'batman';

-- RED: Overdue
UPDATE members
SET status = 'active', expiry_date = '2026-04-12', payment_collected = false
WHERE member_name = 'polio';

-- YELLOW: Trial
UPDATE members
SET status = 'trial', is_trial = true, expiry_date = '2026-04-22', payment_collected = false
WHERE member_name = 'vids';

-- EMERALD/GREY: Approaching renewals
UPDATE members
SET status = 'active', expiry_date = '2026-04-26', payment_collected = false
WHERE member_name = 'testpaid';
```

---

## 9. Trial Member Pricing
Trial rows do not show a rupee amount on the card.

* Reason: trials are a conversion lead, not an outstanding billed plan. Showing `₹0` or a fake price adds noise and weakens the conversion-focused UX.
