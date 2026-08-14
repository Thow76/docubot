# ADR-0004: Categories and priorities are Dart enums, defined exactly once

**Status:** Accepted

## Context

The prototype stores category and priority as free-text strings on the
`Document` model, with the permitted values duplicated wherever they're
checked (UI, AI prompt, storage). That duplication is a source of drift.

## Decision

Category and priority are Dart enums, not strings, on the model. Each enum
case carries its own display label, stored DB value, color, and icon as
properties directly on the case — there are no separate lookup tables
mapping enum values to any of those.

Exactly two string-conversion boundaries are allowed:

1. **DB serialization** — converting to/from the stored string value. This
   boundary must handle an unrecognized stored value explicitly (e.g. from
   an old schema version); it must not crash or silently default.
2. **AI prompt/response** — the permitted-values list sent to the AI is
   generated from the enum, never typed out separately. An AI response
   value that doesn't match a known enum case counts as a failed extraction
   for that field, not a silent fallback.

Stored value and display label are decoupled, so relabeling a category or
priority in the UI never requires a data migration.

## Decision detail: value mapping from the prototype

T-006 (enum introduction) and T-008 (schema migration) use this mapping
from the prototype's four categories and three priorities:

| Prototype value | Enum case |
|---|---|
| Category: Financial | `Category.work` |
| Category: Bills | `Category.money` |
| Category: Medical | `Category.medical` |
| Category: Other | `Category.other` |
| Priority: Action Required | `Priority.action` |
| Priority: Informational | `Priority.info` |
| Priority: Completed | `Priority.done` |

## Consequences

Adding, removing, or relabeling a category/priority is a one-place enum
edit instead of a hunt across UI strings, AI prompt text, and storage code.
The tradeoff is the two conversion boundaries need explicit unrecognized-value
handling, since enums can't silently accept an arbitrary string the way the
prototype's free-text fields did.
