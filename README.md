# Gym-Ops Full-Stack Project

Centralized gym management with automated messaging (WhatsApp/AI Voice).

## Developer Resources
- [PROJECT.md](file:///c:/Users/USER/Desktop/flutter_projects/gym-ops/PROJECT.md) - Architecture & Stack
- [SCHEMA.md](file:///c:/Users/USER/Desktop/flutter_projects/gym-ops/SCHEMA.md) - Database Models & Relationships
- [CHANGELOG.md](file:///c:/Users/USER/Desktop/flutter_projects/gym-ops/CHANGELOG.md) - History of Design Decisions
- [ERRORS.md](file:///c:/Users/USER/Desktop/flutter_projects/gym-ops/ERRORS.md) - Known Issues & Troubleshooting
- [PROMPTS.md](file:///c:/Users/USER/Desktop/flutter_projects/gym-ops/PROMPTS.md) - Contextual Prompts for Future Changes

## Recent API Changes
- `GET /api/members/:gym_id`: Fetches the specialized member view for the flutter list screen.
  - Returns: `id`, `name`, `status`, `avatar`, and `MembershipType.name`.
  - Pattern: Enforces 500 error reporting for protocol-level developer mismatches.
