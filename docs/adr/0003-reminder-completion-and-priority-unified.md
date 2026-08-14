# ADR-0003: Reminder completion and document priority are one field

**Status:** Accepted

## Context

The prototype has no independent `Reminder.isCompleted` concept in the
target design — a reminder's "done" state and its parent document's
priority are the same underlying fact, and modeling them as two separate
fields invites them going out of sync.

## Decision

There is no `Reminder.isCompleted` column. A reminder is active if and only
if its parent document's priority is not Done.

Swipe-to-done (on the Reminders Home screen) and the priority chip (on the
document detail screen) both write to the same field via the same
repository method — two entry points, one operation.

Only setting priority to Done resolves a reminder; setting it to Info does
not. Reactivating a document (Done → Action or Done → Info) makes its
reminder active again, and it reappears under Overdue if the date has
already passed.

## Consequences

There's no separate completion state to migrate or keep in sync — resolving
a reminder from either entry point is the same write, so the two surfaces
can never disagree about a reminder's status. The schema migration in T-008
folds any existing `reminders.isCompleted` data into the parent document's
priority (any-complete-reminder → priority Done) as part of dropping the
column.
