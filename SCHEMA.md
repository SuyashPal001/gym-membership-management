# Database Schema

## Active Models

### MembershipType

**Status:** ACTIVE

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | UUID | No | UUIDV4 | Primary Key |
| name | STRING | No | null | Unique constraint |
| amount | FLOAT | No | null | |
| duration_months | INTEGER | No | 1 | |

### Member

**Status:** ACTIVE

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | UUID | No | UUIDV4 | Primary Key |
| gym_id | UUID | No | null | |
| member_name | STRING | No | null | |
| phone | STRING | No | null | |
| email | STRING | Yes | null | Validates isEmail |
| avatar | TEXT | Yes | null | |
| last_arrival | DATE | Yes | null | |
| membership_type_id | UUID | Yes | null | Foreign Key |
| join_date | DATEONLY | Yes | NOW | |
| expiry_date | DATEONLY | Yes | null | |
| status | ENUM | Yes | 'active' | active, expired, trial |
| is_trial | BOOLEAN | Yes | false | |
| payment_collected | BOOLEAN | Yes | false | |
| total_visits | INTEGER | Yes | 0 | |
| lifetime_value | FLOAT | Yes | 0 | |
| last_payment_date | DATE | Yes | null | Tracks the exact UTC timestamp of most recent settlement |

### WorkflowReminder

**Status:** ACTIVE

- **Indexes:**
  - `['method', 'scheduled', 'scheduled_date']`
  - `['cancelled', 'scheduled_date']`
- **Unique Constraints:** `uuid`, `reference_id`

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | INTEGER | No | autoInc | Primary Key |
| uuid | UUID | Yes | UUIDV4 | Unique constraint |
| member_id | UUID | No | null | Foreign Key |
| gym_id | UUID | No | null | |
| method | ENUM | No | null | WHATSAPP, AI_CALL, SMS, EMAIL |
| scheduled_date | DATE | No | null | Exact UTC time |
| reference_id | STRING | Yes | null | Twilio/Retell tracking ID (Unique) |
| scheduled | BOOLEAN | No | false | Picked up by CRON marker |
| cancelled | BOOLEAN | Yes | false | |
| retry_count | INTEGER | Yes | 0 | |
| payload | JSONB | Yes | null | Dynamic template variables |

### Call

**Status:** ACTIVE

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | UUID | No | UUIDV4 | Primary Key |
| member_id | UUID | No | null | Foreign Key |
| gym_id | UUID | No | null | |
| description | TEXT | Yes | null | |
| type | ENUM | Yes | 'manual' | manual, ai |
| called_at | DATE | Yes | NOW | |
| duration | INTEGER | Yes | 0 | |
| transcript | TEXT | Yes | null | |
| external_call_id | STRING | Yes | null | Provider tracking ID |

### AttendanceSession

**Status:** ACTIVE

- **Indexes:** `['member_id', 'date']` (Daily lookups)

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | UUID | No | UUIDV4 | Primary Key |
| gym_id | UUID | No | null | |
| member_id | UUID | No | null | Foreign Key |
| check_in_time | DATE | No | null | Exact UTC check-in |
| check_out_time | DATE | Yes | null | Exact UTC check-out |
| date | DATEONLY | No | null | Today's date (UTC reset) |

### Payment

**Status:** ACTIVE

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | UUID | No | UUIDV4 | Primary Key |
| gym_id | UUID | No | null | |
| member_id | UUID | No | null | Foreign Key |
| amount | FLOAT | No | null | |
| status | ENUM | No | 'paid' | paid, pending, failed, refunded |
| payment_date | DATE | No | NOW | UTC timestamp |
| method | STRING | Yes | null | |

---

## Relationships Map

MembershipType >──< Member
Member ──< WorkflowReminder
Member ──< Call
Member ──< AttendanceSession
Member ──< Payment
