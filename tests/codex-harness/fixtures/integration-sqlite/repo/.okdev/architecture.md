# Architecture: subscriptions

## Components
- `svc/store.py` — the only component that talks to the database.

## Boundaries
1. service -> database (SQLite): schema migration, plan creation, subscribe,
   change plan, revenue aggregation.

## Data rules enforced by the database
- A plan name is unique.
- A plan price cannot be negative.
- An email address may hold at most one subscription.
- A subscription must reference a plan that exists.

## Notes
`change_plan` is expected to fail loudly when the subscriber does not exist,
so a caller cannot silently no-op.
