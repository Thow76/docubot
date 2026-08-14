# ADR-0005: Riverpod, split providers, AsyncValue reads, result-returning writes

**Status:** Accepted (not yet implemented — see Status note below)

## Context

The prototype uses a single `provider` package `ChangeNotifierProvider`
(`DocumentProvider`) as one god-object holding all document/reminder state,
with ad hoc loading booleans on screens.

## Decision

State management moves to Riverpod (with codegen). Providers are split by
concern — documents, reminders, filters, capture session — rather than one
god notifier.

Every async read exposes loading/data/error via `AsyncValue`; screens hold
no separate loading booleans of their own. Writes return a result rather
than being watched, so a save/delete/update call gets a direct
success-or-failure answer instead of the caller inferring it from provider
state changes.

A single `ProviderObserver` is registered once at app startup, filtered to
failures only — unfiltered logging is noise and gets ignored in practice.
This observer is the seam a crash-reporting tool (e.g. Crashlytics) plugs
into later.

`Freezed` is used only for genuine state unions — for example, AI analysis
idle/loading/succeeded/failed — not for plain data classes like `Document`.

The in-progress multi-page capture session is its own auto-disposing
provider, not folded into the documents provider, since its lifetime is
tied to one capture flow rather than the app session.

## Status note

As of this writing the app still uses `provider` (`^6.1.2`,
`ChangeNotifierProvider`) throughout — this ADR describes the T-009 target,
not the current state. Do not assume Riverpod is present in `lib/` yet;
check `pubspec.yaml` and `lib/providers/` before writing code that depends
on it.

## Consequences

Splitting providers by concern means a change to, say, filter state doesn't
invalidate widgets only watching document data. The `AsyncValue` convention
removes an entire class of "loading flag out of sync with actual state" bugs
that ad hoc booleans allow.
