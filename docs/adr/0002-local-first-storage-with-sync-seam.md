# ADR-0002: Local-first storage with a sync seam

**Status:** Accepted

## Context

Cloud sync is a plausible future feature (multi-device access, backup) but
building it now would add a second storage backend, conflict resolution, and
auth-to-storage plumbing before v1's core rebuild (T-006–T-010) is even
done.

## Decision

Cloud sync is v2, not built now. v1 has exactly one repository
implementation — local SQLite — behind an async-shaped interface with no
SQLite types leaking out of it.

Page images are addressed by identifier, never by filesystem path, so a
document is one entity (metadata + pages) whose images could later resolve
to remote objects with zero changes to screens or providers.

Signing in on a new device shows an empty app by design — documents are
account-gated but device-local in v1. No "your documents are safe in the
cloud" copy should appear anywhere in the UI, since it would be false.

Conflict resolution is deferred entirely. Last-write-wins is the presumed
(but unconfirmed) default for whenever a paid sync tier arrives.

## Consequences

The repository interface and identifier-based image addressing are the seam
a v2 sync backend plugs into. Until then, every screen and provider talks to
"the repository," not "SQLite," so the eventual second implementation is
additive rather than a rewrite of call sites.
