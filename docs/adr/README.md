# Architecture Decision Records

These ADRs describe the **target** architecture for the DocuBot rebuild —
they describe where the app is going, not where it currently is. Compare
against `docs/poc-audit.md`, which is a read-only snapshot of what the
prototype actually did before the rebuild started.

All six were accepted together in August 2026 and are authoritative over
older requirements/gap-analysis documents where the two conflict.

| ADR | Decision |
|---|---|
| [0001](0001-android-only-for-v1.md) | Android-only for v1 |
| [0002](0002-local-first-storage-with-sync-seam.md) | Local-first storage with a sync seam |
| [0003](0003-reminder-completion-and-priority-unified.md) | Reminder completion and document priority are one field |
| [0004](0004-categories-and-priorities-as-enums.md) | Categories and priorities are Dart enums, defined exactly once |
| [0005](0005-riverpod-state-management.md) | Riverpod, split providers, AsyncValue reads, result-returning writes |
| [0006](0006-capture-strategy.md) | Capture: custom Flutter UI first, ML Kit as a recorded fallback |

Several of these (0004, 0005) describe work not yet done — check each ADR's
Status note and the current ticket backlog (GitHub issues) before assuming
a decision is already implemented in `lib/`.
