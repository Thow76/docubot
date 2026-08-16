# AGENTS.md

Instructions for any AI coding agent working in this repository.

## What this project is

DocuBot (GitHub repo: `Thow76/docubot`) is a single-user Android Flutter app
for photographing paper documents (letters, bills) and tracking what to do
about them: category, priority, optional reminders. It runs on-device except
for calls to OpenAI's API for AI-assisted analysis and search.

The Android `applicationId` and Kotlin namespace are `com.thow76.docubot`.

## Current state vs. target state — read this before changing anything

This repo is mid-rebuild from a working prototype toward a target
architecture. Two documents disagree with each other on purpose:

- **`docs/poc-audit.md`** — a read-only description of what the prototype
  actually did, before the rebuild started. Old branding ("DocSafe"), old
  category set (Financial/Medical/Bills/Other as free strings), `provider`
  package for state, no multi-page capture, no real edge detection.
- **`docs/adr/`** — six Architecture Decision Records describing the
  *target* the rebuild is working toward: Riverpod, enum-based
  categories/priorities, a repository interface over SQLite, unified
  reminder/priority state, and a real guided capture flow.

**Do not assume an ADR is already implemented.** Check `pubspec.yaml` and
the relevant `lib/` files first. As of this writing the app still uses the
`provider` package and free-text category/priority strings — ADR-0004 and
ADR-0005 are accepted decisions, not yet-built code.

## Backlog and ticket sequence

Work is tracked as GitHub issues (T-001 through T-010) on `Thow76/docubot`.
The sequence matters — several tickets have a hard dependency on the one
before it:

- **T-001** (data extraction) must be verified complete before **T-002**
  (the `applicationId` change) — changing the application ID installs a
  second, separate app rather than upgrading the existing one, so the old
  install's data must be safely extracted first.
- **T-006** (enums) introduces the category/priority enum conversion;
  **T-008** (schema migration) is what actually migrates stored rows and
  applies the real T-001 export — it must run against that real export, not
  synthetic data.
- **T-009** (Riverpod) and **T-010** (unified save/edit form) both assume
  the app already holds the real migrated document set from T-008.

Check `gh issue list --repo Thow76/docubot` for current ticket status before
starting work — don't assume ticket state from this file, which will drift.

## Things that must never happen

- **Never commit anything under `data-migration/`.** This directory holds a
  real personal document export (SQLite DB + images) pulled from a physical
  device for the T-001→T-008 migration. It is git-ignored; keep it that way.
- **Never delete or modify the original phone install's data** as a side
  effect of testing the new `com.thow76.docubot` build. The two apps are
  expected to coexist side by side until T-008 confirms the migrated import
  is correct.
- **Never delete `ios/`.** Per ADR-0001 this project is Android-only for v1,
  but the Flutter-generated `ios/` directory is left in place untouched, not
  removed.

## Build, test, and verify

```bash
flutter analyze          # static analysis — must be clean
flutter test              # unit/widget tests
flutter build apk --debug # Android debug build
```

CI (`.github/workflows/ci.yml`) runs `flutter analyze` and `flutter test` on
every push/PR to `main` — but `main` has no branch protection requiring it to
pass (an explicit, deliberate decision; see issue #4), so still run these
locally before opening a PR rather than relying on CI to catch it first.

## Conventions

- Platform-specific behavior (camera, notifications, file storage) sits
  behind service interfaces (`lib/services/`), not called directly from
  screens or providers — this is what ADR-0001 depends on for a future iOS
  port to stay tedious rather than a rewrite.
- Category and priority will become Dart enums per ADR-0004, with display
  label, stored DB value, color, and icon as properties on each case — not
  separate lookup tables. See that ADR for the exact prototype→enum value
  mapping.
- New async state should be written with the target Riverpod/`AsyncValue`
  pattern in ADR-0005 in mind, even before the T-009 migration lands,
  where it doesn't conflict with the current `provider`-based code it sits
  next to.
