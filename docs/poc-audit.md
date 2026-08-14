# DocSafe Prototype — Architecture Audit

Scope: everything under `lib/` (14 Dart files, 4,299 lines) plus the Android
manifest, `pubspec.yaml`/`pubspec.lock`, and `test/`. Read-only — no code was
changed to produce this report. This is a description of what exists, not a
recommendation for what should exist.

---

## 1. What the app currently does

DocSafe is a single-user Android app (app title "DocSafe", package name
`document_organisation`) for photographing paper letters/bills and tracking
what to do about them. It runs entirely on-device except for calls to
OpenAI's API.

**Home screen.** Two tabs: *Documents* and *Reminders*. The Documents tab
shows a search bar and an expandable list grouped under four fixed
categories — Financial, Medical, Bills, Other — each showing a count and,
when expanded, one row per document (title, capture date, optional letter
date, a coloured priority chip, a bell icon if a reminder exists). Tapping a
document opens the viewer. A toggle next to the search box switches between
local substring search and "AI search," which sends the query plus every
document's title/summary/tags to GPT-4o and displays its free-text answer
about which documents match and why (local search still runs underneath
regardless). The Reminders tab lists all non-completed reminders sorted by
date, each with a checkbox to mark it done and a tap-through to the source
document. The app bar also currently carries two debug-only buttons ("test
immediate notification" / "test scheduled notification") that are visible in
the shipped UI, not hidden behind any debug flag.

**Capture flow.** The floating action button opens a full-screen camera
(front/back flip, flash toggle, a static dashed-rectangle "position document
here" overlay — cosmetic only, no real edge detection). Taking a photo saves
a compressed copy to app storage and moves to a "Save Document" form. There
the user enters a title, picks one of the four categories and one of three
priorities (Action Required / Completed / Informational), optionally sets a
letter date and an "actionable date" (a deadline/appointment/expiry date)
with a free-text context note, writes notes, and can tap "Analyse with AI" to
have GPT-4o pre-fill all of the above from the photo. If an actionable date
is set, a reminder toggle appears, letting the user schedule a local
notification for 0/1/3/7 days before that date. Saving writes the document
(and reminder, if enabled) to a local SQLite database and returns to the home
list.

**Viewing and editing.** The viewer shows a pinch-to-zoom image, the
priority badge, capture/letter/actionable dates, AI-suggested tags (if any),
notes, and — if a reminder exists — a reminder card with a "Mark Complete"
button. A "Share" button is present but does nothing (explicitly a
placeholder in code). An "Edit" button opens a near-identical form to the
capture-flow form, pre-filled from the existing document, with an added
"Delete Document" button (confirmation dialog) and an unsaved-changes guard
that intercepts the back button/gesture if any field changed.

**What doesn't work today:** the gallery-picker icon in the camera screen is
a no-op; the "Share" button in the viewer is a no-op; AI search and AI
analysis silently fall back to safe defaults if no API key is configured or
the network call fails, rather than surfacing an error to the user.

---

## 2. Structural inventory

All 14 files under `lib/`, by directory.

### `lib/` (root)

| File | Lines | Responsibility |
|---|---|---|
| `main.dart` | 44 | App entry point: loads `.env`, initialises notifications, wires the single `DocumentProvider` via `ChangeNotifierProvider`, declares the named-route table. |

### `lib/models/`

| File | Lines | Responsibility |
|---|---|---|
| `document.dart` | 106 | `Document` data class: fields, `toMap`/`fromMap` (SQLite serialisation), `copyWith`. |
| `reminder.dart` | 66 | `Reminder` data class: fields, `toMap`/`fromMap`, `copyWith`. |

### `lib/providers/`

| File | Lines | Responsibility |
|---|---|---|
| `document_provider.dart` | 197 | `ChangeNotifier` holding the in-memory document/reminder lists; mediates `DatabaseService`, `ImageService`, `NotificationService`; exposes filtering/sorting/search getters. |

### `lib/screens/`

| File | Lines | Responsibility |
|---|---|---|
| `home_screen.dart` | 496 ⚑ | Document list + tabs + local search + inline AI-search feature (its own network orchestration and state) + two debug notification-test buttons. **Multiple responsibilities.** |
| `camera_screen.dart` | 489 ⚑ | Camera preview/controls/lifecycle **and** a standalone `CustomPainter` class for the frame-guide overlay, bundled in one file. **Two responsibilities.** |
| `categorize_screen.dart` | 711 ⚑ | New-document form UI, AI-analysis orchestration, reminder creation, save/validate logic. **Multiple responsibilities.** |
| `document_viewer_screen.dart` | 496 ⚑ | Document display, pinch-zoom, and a reminder card with its own completion-mutation call into the provider. |
| `edit_screen.dart` | 913 ⚑ | Almost entirely duplicated from `categorize_screen.dart` (same category/priority tuples, same AI-analysis flow, same reminder-section widget logic) plus edit-specific delete flow and an unsaved-changes guard. **Largest file, several responsibilities, and the dominant duplication point in the codebase.** |

### `lib/services/`

| File | Lines | Responsibility |
|---|---|---|
| `ai_service.dart` | 166 | Two independent OpenAI HTTP calls (document analysis, AI search) with duplicated request-building code between them. |
| `database_service.dart` | 177 | SQLite schema, migrations, and CRUD for documents and reminders. |
| `image_service.dart` | 73 | Image compression and on-disk storage/deletion. |
| `notification_service.dart` | 218 ⚑ | Local notification scheduling **and** leftover debug/test code (two test-notification methods, extensive `debugPrint` instrumentation marked "REMOVE BEFORE RELEASE"). **Two responsibilities.** |

### `lib/theme/`

| File | Lines | Responsibility |
|---|---|---|
| `app_theme.dart` | 147 | Colour constants, `ThemeData`, and category/priority → colour/icon lookup tables (a second, independent enumeration of the four categories and three priorities). |

**Files over 300 lines:** `edit_screen.dart` (913), `categorize_screen.dart`
(711), `home_screen.dart` (496), `document_viewer_screen.dart` (496),
`camera_screen.dart` (489) — 5 of 9 non-trivial files.

**Files with more than one clear responsibility:** `home_screen.dart`,
`camera_screen.dart`, `categorize_screen.dart`, `edit_screen.dart`,
`notification_service.dart`, as noted above.

---

## 3. Architectural choices actually present

### State management

**What it uses:** the `provider` package (`ChangeNotifier` +
`ChangeNotifierProvider`). One provider, `DocumentProvider`, created once in
`main.dart` and read via `Provider.of<DocumentProvider>(context)` /
`Provider.of<DocumentProvider>(context, listen: false)`. Ephemeral UI state
(search text, form field values, camera state, loading flags) stays as local
`StatefulWidget` state via `setState`.

**Consistency:** applied uniformly — every screen that needs shared document
or reminder data (Home, Categorize, Edit, Viewer) goes through the same
`DocumentProvider`; the one screen that doesn't need it (Camera) doesn't use
it. The global-state/local-state split is consistent throughout.

**Why it plausibly ended up this way:** `provider` is the state-management
approach most commonly demonstrated in official Flutter documentation and
introductory tutorials — a low-friction default for a small, prompt-driven
app with one real entity.

**What it does well here:** for a single-entity CRUD app with one shared
list, a single `ChangeNotifier` is proportionate. `notifyListeners()`-driven
rebuilds are easy to trace, and there's no code-generation step to maintain.

**What it costs:** every mutation — `addDocument`, `updateDocument`,
`deleteDocument`, `addReminder`, `updateReminder`, `deleteReminder`,
`markReminderCompleted` — ends by calling `loadDocuments()`, which re-queries
*both* tables from disk and calls
`_notificationService.rescheduleAllReminders(...)`, which itself cancels
*every* scheduled notification and re-schedules every active reminder from
scratch. A single checkbox tap in the Reminders tab currently triggers a full
database reload and a full notification cancel/reschedule cycle. This is
invisible at the current data volume and will become visible lag as the
document/reminder count grows. `DocumentProvider` also already mixes
document CRUD, reminder CRUD, search, sort, and filter concerns in one
197-line class — a single growing surface rather than several smaller ones.

**Realistic alternatives:** a more granular state layer (Riverpod, Bloc, or
several smaller `ChangeNotifier`s split by concern) would remove the
god-object growth path and make optimistic (non-full-reload) updates
natural, at the cost of a migration and, for Riverpod/Bloc, more ceremony.
Keeping `provider` as-is is defensible while the entity model stays this
small — the cost is in the reload pattern, not the package choice itself.

### Local persistence

**What it uses:** `sqflite` (SQLite) behind a hand-written singleton,
`DatabaseService`, with raw SQL `CREATE TABLE` and `ALTER TABLE` statements —
no ORM, no code generation. Current schema version is 3. Dates are stored as
ISO-8601 strings (except `actionableDate`, stored as `YYYY-MM-DD` — see §5).
Booleans are stored as `0`/`1` integers. `aiTags` (a `List<String>`) is
stored as a single comma-joined `TEXT` column.

**Consistency:** every DB access funnels through `DatabaseService`; every
model has matching `toMap`/`fromMap`. Consistent throughout.

**Why it plausibly ended up this way:** `sqflite` with hand-written SQL is
the default, most-tutorialised path for local relational storage in Flutter,
and the app's shape (two related tables, a foreign key) fits SQL naturally.

**What it does well here:** the schema is small and legible, and — notably —
the migration path is real, not just an `onCreate`: three schema iterations
are captured (`v1→2` adds actionable-date columns, `v2→3` renames a category
value), which is more forward planning than a purely disposable prototype
typically shows.

**What it costs:** comma-joined tag storage will silently corrupt on
round-trip if a tag ever contains a comma (currently harmless because tags
are only AI-generated short words, not user-entered). The `reminders` table
declares `FOREIGN KEY (documentId) REFERENCES documents(id)` in SQL, but
`sqflite` does not enforce foreign keys unless `PRAGMA foreign_keys = ON` is
explicitly set, and it isn't — `deleteDocument` compensates by manually
deleting the associated reminder rather than relying on a cascade. There's
no encryption at rest for a database that stores metadata about financial
and medical documents. `getAllDocuments()` has no pagination or limit.

**Realistic alternatives:** a schema-aware layer (`drift`, `floor`) would
give compile-time-checked queries and migrations at the cost of a
code-generation build step; a NoSQL store (`Hive`, `Isar`) would remove SQL
and migrations entirely but weaken the relational (document↔reminder) shape
the data already has. Keeping `sqflite` is defensible given how small and
relational the current schema is.

### Networking / AI integration

**What it uses:** the raw `http` package, POSTing directly to
`https://api.openai.com/v1/chat/completions` from `AiService` — no OpenAI
SDK, no retry, no request cancellation. The model (`gpt-4o`) and endpoint are
hardcoded constants. The API key is read from `.env` via `flutter_dotenv`;
`.env` is declared as a Flutter **asset** in `pubspec.yaml`, meaning it is
bundled inside the compiled app rather than fetched from anywhere at
runtime.

**Consistency:** the two methods on `AiService` (`analyseDocument`,
`searchDocumentsWithAI`) independently duplicate the header-building,
timeout, and error-handling shape rather than sharing a helper, and have
already diverged slightly — one builds a single user message with mixed
text/image content, the other builds a system + user message pair.

**Why it plausibly ended up this way:** `http` + `flutter_dotenv` is the
standard minimal-dependency pattern shown in most "Flutter + OpenAI"
tutorials; no SDK dependency was taken.

**What it does well here:** failure handling is consistently fail-soft —
missing key, non-200 response, timeout, and malformed JSON all return a
default/fallback value rather than throwing, so the rest of the app stays
usable without AI.

**What it costs:** bundling a live API key as a Flutter asset means it ships
inside the installed APK — extractable by unzipping the package and reading
`.env` — with no backend standing between the key and anyone who has the
app installed. The duplicated request-building code between the two methods
is a second thing to update if the request shape ever needs to change, and
they will keep drifting unless someone consolidates them.

**Realistic alternatives:** a thin backend/serverless proxy holding the key
server-side removes the extraction risk entirely at the cost of standing up
and paying for that infrastructure; consolidating the two request-builders
into one shared helper removes the duplication without changing the
client-side-key trade-off. Keeping a client-embedded key is a common and
reasonable trade for a private prototype that never leaves the developer's
own device — it stops being defensible the moment the app is installed on
anyone else's phone.

### Navigation

**What it uses:** Navigator 1.0 with named routes — a static `routes: {}`
map in `MaterialApp` and `Navigator.pushNamed` / `pushReplacementNamed` /
`popUntil`. Arguments are passed as untyped `Object?` and read back with
unchecked casts, e.g. `ModalRoute.of(context)!.settings.arguments as
Document` / `as String`.

**Consistency:** the same pattern (push with an argument, cast it back on
the receiving screen) is used identically at every navigation point:
camera→categorize (a `String` path), home→viewer, viewer→edit (a
`Document`).

**Why it plausibly ended up this way:** named routes with cast arguments are
the first pattern shown in the official Flutter navigation cookbook — a
plausible default for a small, fixed set of screens.

**What it does well here:** legible and adequate for five screens; no extra
router dependency required.

**What it costs:** the unchecked `as` casts are a latent runtime-crash
surface — nothing currently guards against a route being pushed without its
expected argument (there is no such call site today, but nothing prevents
one being added later without the compiler catching it). There is no
deep-linking or URL-based navigation.

**Realistic alternatives:** `go_router` would add URL-based/deep-link
navigation and typed extras at the cost of more setup for a five-screen app;
small per-route typed argument classes would remove the casts without a new
dependency. Keeping Navigator 1.0 with named routes is reasonable at this
screen count.

### Folder structure

**What it uses:** flat, type-based top-level folders —
`lib/{models,providers,screens,services,theme}` — rather than feature-first
grouping.

**Consistency:** every file fits cleanly into exactly one of the five
folders by *kind*, not by feature. Consistent throughout, but the categories
and priorities themselves are enumerated independently in four separate
places that this structure does nothing to connect: `app_theme.dart`
(`CategoryStyles.accents`, `BadgeStyles.badgeColors`),
`categorize_screen.dart` (`_categories`, `_priorities` tuples),
`edit_screen.dart` (its own separately-declared, not shared, `_categories`/
`_priorities` tuples), and `ai_service.dart`'s hardcoded prompt text. There
is no `enum Category`/`enum Priority` — both are plain `String` fields on
`Document`.

**Why it plausibly ended up this way:** type-based top-level folders are the
structure shown by `flutter create`-adjacent tooling and nearly every
"Flutter app structure" tutorial — a plausible default with no explicit
direction given.

**What it does well here:** at 14 files, navigation by folder is trivial —
one glance at the tree says where any class lives by kind.

**What it costs:** as file count grows, type-based folders separate related
code by feature — understanding "reminders" already means reading across
`models/reminder.dart`, the reminder methods inside
`providers/document_provider.dart`, `services/notification_service.dart`,
and three separate screen files. Separately, the four independent
enumerations of category/priority strings mean adding or renaming a category
requires editing four unconnected files with no compiler check that all four
were updated; a typo'd category string would silently fall through to
whatever default each lookup table defines, rather than failing to compile.

**Realistic alternatives:** feature-first folders would co-locate a
feature's model/service/screen (easier to reason about or delete a whole
feature) at the cost of more folders for a project this size. Introducing
real `enum` types for category/priority would give one compiler-checked
source of truth but touches every read/write site, including DB
serialisation. Keeping flat type-based folders is fine at this size — the
string-enumeration duplication is a separate, independent issue from the
folder layout.

### Dependency access / service instantiation

**What it uses:** no DI container. Each consumer constructs the service it
needs directly. Three different singleton conventions coexist:
`DatabaseService()` is a factory constructor returning a cached singleton;
`NotificationService.instance` is an explicit static-instance accessor;
`ImageService()` and `AiService()` are plain stateless classes constructed
fresh wherever needed (harmless since they hold no state, but still a third
pattern). `AiService()` in particular is independently instantiated inside
`home_screen.dart`, `categorize_screen.dart`, and `edit_screen.dart`.

**Consistency:** inconsistent as *pattern* (three different singleton/
construction styles), though harmless in *effect* since none of the classes
involved hold meaningful per-instance state.

**Why it plausibly ended up this way:** no DI framework (`get_it`, a service
locator, etc.) was reached for; each service was most likely added
independently across separate prompts as features were requested one at a
time, without revisiting the pattern used for the services already in
place.

**What it does well here:** for four small services, manual construction is
completely legible — no hidden wiring, no runtime DI failures to debug.

**What it costs:** because `AiService` is constructed directly inside
`State` classes, it can't be swapped for a test double without editing the
screen; a reader has to check each service's source individually to learn
how to obtain an instance rather than relying on one convention. This cost
is currently invisible because there is exactly one test file and it
exercises none of these screens or services.

**Realistic alternatives:** a lightweight service locator (`get_it`) would
give one lookup convention and easier test substitution at the cost of an
added dependency and some setup; passing services in explicitly through
constructors would be more explicit but adds plumbing through the widget
tree. Keeping direct construction as-is is workable as long as nothing
requires substituting a service under test.

### Error handling

**What it uses:** three different strategies, applied at three different
layers. `AiService` is fully try/catch-wrapped and fails soft everywhere
(returns a default map or fallback string, never throws). `DatabaseService`
and `ImageService` have no try/catch at all — a `sqflite` or filesystem
exception propagates straight up unmodified. `DocumentProvider` only wraps
`loadDocuments()` in try/catch (setting `_errorMessage`, rendered as a
full-screen error state by `HomeScreen`); its other methods
(`addDocument`, `updateDocument`, `deleteDocument`, `addReminder`, etc.)
have no try/catch of their own. Screens compensate individually —
`categorize_screen._save`, `edit_screen._save`, and `edit_screen._confirmDelete`
each wrap their own calls into the provider in try/catch and show a
`SnackBar` on failure.

**Consistency:** inconsistent — which layer catches a given failure depends
entirely on which method threw it, and there is no single logging or crash-
reporting hook that sees all of them.

**Why it plausibly ended up this way:** a typical shape for unstructured,
per-feature prompting — each screen or service was most likely generated
against a self-contained "add save with error handling" style request,
producing locally-plausible handling that was never reconciled against the
other layers.

**What it does well here:** the two operations a user is most likely to
notice failing — loading the list, and saving/deleting a document — do have
handling and do show feedback rather than crashing outright. AI failures
specifically are handled gracefully everywhere they occur.

**What it costs:** a database failure during `loadDocuments()` produces a
full-screen error state; the identical underlying failure during
`addDocument()` produces a `SnackBar` on whichever screen called it — two
different user experiences for the same class of failure, with no unified
observability. Any future call site that forgets its own try/catch is
unhandled by default.

**Realistic alternatives:** centralising all repository calls inside
`DocumentProvider` so every provider method always try/catches and screens
only ever render `provider.errorMessage` would give one place to check, at
the cost of a fatter provider class; a `Result`/`Either`-style return type
from services would make success/failure explicit without exceptions, at the
cost of a larger and more unfamiliar-feeling refactor for idiomatic Flutter
code. Keeping the current split is workable today because the two highest-
traffic paths (load, save) already have handling — just not through one
shared mechanism.

---

## 4. Coupling and dependency access

- **`AiService` is called directly from three screens** — `home_screen.dart`
  (AI search), `categorize_screen.dart` and `edit_screen.dart` (document
  analysis) — never through `DocumentProvider`. This breaks the otherwise
  general rule that `DocumentProvider` mediates access to
  `DatabaseService`/`ImageService`/`NotificationService`; `AiService` is the
  one service screens reach past the provider to use directly.
- **`CameraScreen` calls `ImageService` directly** (`saveAndCompressImage`)
  rather than through `DocumentProvider`, because no `Document` exists yet
  at capture time. `ImageService` is therefore reachable from both the UI
  layer (`CameraScreen`) and the provider layer (`DocumentProvider.deleteDocument`).
- **`HomeScreen` imports `NotificationService` directly** for its two
  debug-only test-notification buttons, bypassing the provider — a
  debug-only exception to the same rule above.
- **`DocumentProvider` is the single highest-fan-in non-leaf file**: it's
  imported by `home_screen.dart`, `categorize_screen.dart`,
  `edit_screen.dart`, and `document_viewer_screen.dart` — 4 of the 5
  screens (`CameraScreen` is the only one that doesn't depend on it).
  Changes to its public API ripple to all four.
- **`theme/app_theme.dart` and both model files have the highest overall
  fan-in** (imported by nearly every screen, the provider, and/or the
  services) but are leaf nodes themselves — they import nothing else inside
  `lib/`, so the high fan-in carries low risk.
- **No circular imports** were found. The import graph is a clean DAG:
  screens depend on providers/services/models/theme; providers depend on
  services and models; services depend on models; models depend on nothing
  inside `lib/`. Nothing in `services/` or `models/` imports anything from
  `screens/` or `providers/`.
- **The sharpest duplication point**, distinct from the import graph itself:
  the four categories and three priorities are independently re-declared in
  `app_theme.dart`, `categorize_screen.dart`, `edit_screen.dart` (its own
  separate copy, not shared with `categorize_screen.dart`), and hardcoded
  into the AI prompt string in `ai_service.dart` — five places with the same
  information and no shared source or compiler link between them.

---

## 5. Hard-won implementation detail

### The OpenAI request

Model, endpoint, and timeout (`lib/services/ai_service.dart:8-10`):

```dart
static const String _endpoint = 'https://api.openai.com/v1/chat/completions';
static const String _model = 'gpt-4o';
static const Duration _timeout = Duration(seconds: 30);
```

The document-analysis prompt (`lib/services/ai_service.dart:39-49`):

```dart
const systemPrompt =
    'You are a document analysis assistant. Analyse this letter/document image and extract ALL of the following information. Respond ONLY with valid JSON, no markdown or other text:\n'
    '{\n'
    '  "suggestedTitle": "A short descriptive title for this document, e.g. \'Chase Bank Statement - March 2026\' or \'GP Appointment Letter\'",\n'
    '  "suggestedCategory": "Category must be exactly one of: Financial, Medical, Bills, Other — Financial: bank statements, account letters, investment correspondence, tax documents, insurance policies; Medical: appointment letters, test results, prescriptions, hospital correspondence, referrals; Bills: utility bills, invoices, payment demands, subscription charges, council tax, phone/broadband bills; Other: anything that does not fit the above categories",\n'
    '  "suggestedPriority": "One of: Action Required, Informational, Completed — use \'Action Required\' if there is a deadline, payment due, appointment, or any response needed. Use \'Informational\' if it is a statement, summary, or record with no action needed. Use \'Completed\' only if the document confirms something already done.",\n'
    '  "letterDate": "The date printed on the letter/document in YYYY-MM-DD format, or null if no date is visible",\n'
    '  "actionableDate": "Any deadline, due date, appointment date, payment date, or expiry date found in the document in YYYY-MM-DD format, or null if none found. Examples: \'pay by\' dates, appointment dates, renewal deadlines, response deadlines.",\n'
    '  "actionableDateContext": "A short explanation of what the actionable date relates to, e.g. \'Payment due for invoice #1234\', \'GP appointment at City Medical Centre\', \'Insurance renewal deadline\'. Set to null if no actionable date found.",\n'
    '  "notes": "A 2-3 sentence summary of what this document is about. If action is required, explain what needs to be done and why. If informational, summarise the key details. Keep it concise and useful."\n'
    '}';
```

Message structure and image encoding (`lib/services/ai_service.dart:51-66`):

```dart
final requestBody = jsonEncode({
  'model': _model,
  'messages': [
    {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': systemPrompt},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
      ],
    },
  ],
  'max_tokens': 600,
});
```

Response parsing strips markdown code fences before decoding
(`lib/services/ai_service.dart:89-96`):

```dart
final fencePattern = RegExp(r'^```(?:json)?\s*\n?(.*?)\n?\s*```$', dotAll: true);
final match = fencePattern.firstMatch(content);
if (match != null) {
  content = match.group(1)!.trim();
}

final parsed = jsonDecode(content) as Map<String, dynamic>;
```

The second method, `searchDocumentsWithAI`, uses a different message shape —
a `system` message plus a `user` message, rather than a single `user`
message with mixed content (`lib/services/ai_service.dart:132-143`):

```dart
final requestBody = jsonEncode({
  'model': _model,
  'messages': [
    {
      'role': 'system',
      'content':
          'You are a helpful document search assistant. Given a list of document summaries and a search query, identify the most relevant documents and briefly explain why they match.',
    },
    {'role': 'user', 'content': userMessage},
  ],
  'max_tokens': 400,
});
```

### Image compression

`lib/services/image_service.dart:41-48`, using the `image` package:

```dart
final resizedImage = img.copyResize(
  image,
  width: image.width > image.height ? 1500 : null,
  height: image.height > image.width ? 1500 : null,
);

// Compress the image to JPEG at 70% quality
final compressedImageBytes = img.encodeJpg(resizedImage, quality: 70);
```

Longest edge capped at 1500px (aspect ratio preserved by only setting the
larger dimension), JPEG quality 70. On any failure during decode/resize/
encode, it falls back to copying the original file uncompressed
(`lib/services/image_service.dart:52-56`):

```dart
} catch (e) {
  // Fallback: copy original file without compression
  debugPrint('Image compression failed, saving original: $e');
  await sourceFile.copy(savedImagePath);
}
```

Saved files go to `<app documents dir>/docsafe_images/<uuid>.jpg`.

### Camera / document scanning

Uses the `camera` package's `CameraController` directly — there is no
document-edge-detection or auto-crop library. The "document frame guide" is
a purely cosmetic `CustomPainter` overlay
(`lib/screens/camera_screen.dart:274-285,351-489`) drawing a dashed rectangle
and corner accents at a fixed 0.85×(width×1.35) proportion; it does not
analyse the camera feed.

Lifecycle handling disposes and reinitialises the controller around
backgrounding (`lib/screens/camera_screen.dart:42-50`):

```dart
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (_controller == null || !_controller!.value.isInitialized) return;

  if (state == AppLifecycleState.inactive) {
    _controller?.dispose();
  } else if (state == AppLifecycleState.resumed) {
    _initCameraController(_cameras[_currentCameraIndex]);
  }
}
```

The gallery-picker button is a literal no-op
(`lib/screens/camera_screen.dart:301-304`):

```dart
onPressed: () {
  // Placeholder — gallery picker not yet implemented
},
```

### Notification scheduling

Channel definition (`lib/services/notification_service.dart:18-34`):

```dart
static const String _channelId = 'docsafe_reminders';
static const String _channelName = 'Document Reminders';
static const String _channelDescription =
    'Reminders for actionable dates in your documents';

static const AndroidNotificationDetails _androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
```

Timezone setup and the only permission request made at init
(`lib/services/notification_service.dart:38-49`):

```dart
Future<void> init() async {
  tz.initializeTimeZones();
  final localTimeZone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTimeZone));

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await _plugin.initialize(initSettings);

  // Request POST_NOTIFICATIONS permission (Android 13+)
  await Permission.notification.request();
}
```

Fire-time calculation and scheduling call
(`lib/services/notification_service.dart:60-99`):

```dart
final notifyDate = reminder.actionableDate.subtract(
  Duration(days: reminder.notifyDaysBefore),
);
...
final scheduledDate = tz.TZDateTime(
  tz.local,
  notifyDate.year,
  notifyDate.month,
  notifyDate.day,
  9, // 9:00 AM
);
...
await _plugin.zonedSchedule(
  _reminderNotificationId(reminder.id),
  'DocSafe Reminder',
  '$documentTitle — ${reminder.contextReason}',
  scheduledDate,
  _notificationDetails,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
);
```

Both the raw `notifyDate` and the constructed `scheduledDate` are checked
against "now" and the schedule call is skipped silently (only a
`debugPrint`, no user-facing signal) if either is already in the past.

Notification IDs are derived from the reminder's UUID string
(`lib/services/notification_service.dart:216-217`):

```dart
int _reminderNotificationId(String reminderId) =>
    reminderId.hashCode.abs() % 2147483647;
```

`AndroidManifest.xml` declares `SCHEDULE_EXACT_ALARM` and
`RECEIVE_BOOT_COMPLETED`, and registers `flutter_local_notifications`'
`ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` (the
latter's intent filter listens for `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`,
and — per the currently staged manifest change — `QUICKBOOT_POWERON` and
`com.htc.intent.action.QUICKBOOT_POWERON`). Nowhere in the Dart code is
`Permission.scheduleExactAlarm` requested or `canScheduleExactAlarms`
checked — only `Permission.notification.request()` is called.

The file also contains, verbatim, extensive debug instrumentation still
present in the current code, e.g.:

```dart
// DEBUG: REMOVE BEFORE RELEASE
debugPrint('DEBUG: scheduleReminder() called for reminder ${reminder.id} ("$documentTitle")');
```

and two standalone debug methods, `showTestNotification()` (fires
immediately) and `showScheduledTestNotification()` (fires one minute out),
both wired to visible buttons in `HomeScreen`'s app bar.

`rescheduleAllReminders()` is called from `DocumentProvider.loadDocuments()`
— i.e. on every app start and after every single document/reminder mutation
— and unconditionally calls `_plugin.cancelAll()` before rescheduling every
active reminder.

### Local database schema

Version 3, created with (`lib/services/database_service.dart:29-56`):

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT,
  category TEXT,
  captureDate TEXT,
  letterDate TEXT,
  priority TEXT,
  notes TEXT,
  imagePath TEXT,
  aiSummary TEXT,
  aiTags TEXT,
  actionableDate TEXT,
  actionableDateContext TEXT
)
```

```sql
CREATE TABLE reminders (
  id TEXT PRIMARY KEY,
  documentId TEXT,
  actionableDate TEXT,
  contextReason TEXT,
  notifyDaysBefore INTEGER,
  isCompleted INTEGER,
  createdAt TEXT,
  FOREIGN KEY (documentId) REFERENCES documents(id)
)
```

Migration code (`lib/services/database_service.dart:58-66`):

```dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE documents ADD COLUMN actionableDate TEXT');
    await db.execute('ALTER TABLE documents ADD COLUMN actionableDateContext TEXT');
  }
  if (oldVersion < 3) {
    await db.execute("UPDATE documents SET category = 'Financial' WHERE category = 'Banking'");
  }
},
```

`captureDate`/`letterDate` are stored via `.toIso8601String()`, but
`actionableDate` is stored differently, re-formatted to a bare date
(`lib/models/document.dart:45-47`):

```dart
'actionableDate': actionableDate != null
    ? '${actionableDate!.year.toString().padLeft(4, '0')}-${actionableDate!.month.toString().padLeft(2, '0')}-${actionableDate!.day.toString().padLeft(2, '0')}'
    : null,
```

`aiTags` (a `List<String>`) is stored as a single comma-joined column and
split back out on read (`lib/models/document.dart:44,65-68`):

```dart
'aiTags': aiTags.join(','),
...
aiTags: (map['aiTags'] as String)
    .split(',')
    .where((tag) => tag.isNotEmpty)
    .toList(),
```

---

## 6. Dependencies

From `pubspec.yaml`, with resolved versions from `pubspec.lock`.

| Package | Constraint | Resolved | Used for | Maintenance status |
|---|---|---|---|---|
| `cupertino_icons` | ^1.0.8 | 1.0.8 | iOS-style icon set (unused visually — app is dark Material throughout) | Official Flutter-org package, active |
| `camera` | ^0.11.0+2 | 0.11.4 | Camera capture screen | Official `flutter/packages` plugin, active |
| `path_provider` | ^2.1.4 | 2.1.5 | Resolving the app documents directory for image storage | Official `flutter/packages` plugin, active |
| `sqflite` | ^2.3.3+2 | 2.4.2 | SQLite database access | Actively maintained (tekartik), widely used |
| `flutter_dotenv` | ^5.2.1 | 5.2.1 | Loading the OpenAI key from a bundled `.env` asset | Maintained, modest scope — the risk here is architectural (bundling a secret client-side), not package upkeep |
| `http` | ^1.2.2 | 1.6.0 | OpenAI REST calls | Official `dart-lang` package, active |
| `image` | ^4.3.0 | 4.8.0 | JPEG decode/resize/encode for compression | Actively maintained, pure-Dart |
| `intl` | ^0.19.0 | 0.19.0 | Date formatting throughout the UI | Official `dart-lang` package, active |
| `uuid` | ^4.5.1 | 4.5.3 | Document/reminder ID generation | Actively maintained |
| `permission_handler` | ^11.3.1 | 11.4.0 | Camera and notification runtime permissions | Actively maintained (Baseflow), large surface area |
| `flutter_local_notifications` | ^19.1.0 | 19.5.0 | Local notification scheduling | Actively maintained (MaikuB), widely used; has a history of breaking API changes across majors |
| `flutter_timezone` | ^4.0.2 | 4.1.1 | Reading the device's IANA timezone | Actively maintained; this is the current successor to the now-deprecated `flutter_native_timezone`, so this is an up-to-date choice rather than a legacy one |
| `timezone` | ^0.10.1 | 0.10.1 | IANA timezone database/`TZDateTime` math for scheduling | Maintained, bundles a sizeable timezone data asset |
| `provider` | ^6.1.2 | 6.1.5+1 | App-wide state management | Stable, mature API; low churn (not abandoned, but not actively gaining new features either) |
| `path` | ^1.9.0 | 1.9.1 | Filesystem path joining | Official `dart-lang` package, active |
| `flutter_lints` (dev) | ^6.0.0 | 6.0.0 | Lint ruleset | Official Flutter-org package, active |

No dependency here is abandoned. The one notable positive: `flutter_timezone`
was chosen over the older, now-deprecated `flutter_native_timezone` that
still appears in a lot of older tutorials — a correctly up-to-date pick.

---

## 7. Known-broken and unverified

### Notification scheduling

The scheduling *logic* — date-minus-offset math, timezone conversion via
`tz.TZDateTime`, the DB round trip, past-date guards — is fully implemented
and internally consistent (see §5 for the exact code). The concrete,
code-confirmed gap is the Android runtime permission for **exact alarms**:
the manifest declares `SCHEDULE_EXACT_ALARM` and the scheduling call uses
`AndroidScheduleMode.exactAllowWhileIdle`, but the only permission actually
requested at runtime, in `NotificationService.init()`, is
`Permission.notification` (`POST_NOTIFICATIONS`). `Permission.scheduleExactAlarm`
is never requested and `canScheduleExactAlarms` is never checked anywhere in
the codebase. On Android 13+, exact-alarm scheduling additionally requires
the user to grant "Alarms & reminders" separately in system settings; if it
isn't granted, the `zonedSchedule` call can throw or fail to actually fire
the alarm at the scheduled time — and because the call sits inside a
try/catch that only `debugPrint`s on failure, this would fail invisibly to
the end user. This lines up with a "broken on real device" report without
requiring any other explanation. The extensive `// DEBUG: REMOVE BEFORE
RELEASE` instrumentation still present throughout the file, plus two
debug-only test-notification methods wired into the live `HomeScreen` app
bar, corroborates that this exact path was under active troubleshooting when
work paused.

### Reminders tab

Reading `HomeScreen._buildRemindersTab` and
`DocumentProvider.upcomingReminders`, this tab is fully implemented, not
stubbed: it filters non-completed reminders from the loaded state, sorts by
`actionableDate`, renders a checkbox wired to
`provider.markReminderCompleted`, and a tap-through to the source document
via `Navigator.pushNamed('/view', ...)`. Its rendering is independent of
whether the underlying OS notification ever actually fires — it reads
directly from the `reminders` table through the provider, not from
notification-plugin state. Nothing in this code path is missing or
placeholder; "unverified" most plausibly refers to it not having been
exercised against a real device/dataset, not to incomplete code.

### Actionable-date feature

Also fully implemented end-to-end, not stubbed: `Document` carries
`actionableDate`/`actionableDateContext` fields; the database schema has
matching columns (added in the v1→2 migration); `AiService`'s prompt asks
GPT-4o to extract both; `categorize_screen.dart` and `edit_screen.dart` both
have a complete UI for them (date picker, context text field, and a reminder
toggle gated on the actionable date being set); `document_viewer_screen.dart`
displays the date with an icon, label, and the context text. Every layer
(model → DB → AI prompt → both forms → viewer) is present and mutually
consistent. As with the Reminders tab, "unverified" most plausibly means
this hasn't been confirmed against a real photographed document and a real
GPT-4o response on-device — not that the implementation is incomplete.

---

## 8. Appropriateness assessment

Assessed against a single goal: a shippable Android app, one developer.
"Adequate" means *would not prevent shipping* — not *ideal*.

### Adequate as they stand

- **`provider`/`ChangeNotifier` state management** — proportionate to one
  shared entity list; would not block shipping.
- **Flat, type-based folder structure** — trivial to navigate at 14 files;
  unconventional only relative to larger-scale conventions, not a problem
  at this size.
- **`sqflite` with hand-written schema/migrations** — the two-table,
  foreign-keyed shape fits SQL, and the migration mechanism already works
  across three real schema versions.
- **Navigator 1.0 with named routes and cast arguments** — works for five
  screens; the unchecked casts are a latent risk, not an active one, since
  every current call site supplies the right argument type.
- **Fail-soft AI error handling** — the app remains fully usable with AI
  disabled or failing.
- **Manual service construction (no DI)** — legible and sufficient while
  nothing needs a test double.

None of the above are "how it's usually done" at larger scale, but none of
them will cause real problems at the app's current size — this is the
unconventional-but-fine category.

### Would actively obstruct further development

- **The OpenAI API key is bundled client-side as a Flutter asset
  (`.env`).** Any Android release build is a package anyone with the
  installed app can unzip and read `.env` from directly. This is not a
  style concern — it's exposed billing on the developer's own OpenAI
  account the moment the app is installed on any device that isn't the
  developer's, including a beta tester's phone or a lost/resold device.
- **The exact-alarm permission is never requested.** Reminders are the
  entire point of the actionable-date feature, and on Android 13+ they will
  silently fail to fire unless the user separately finds and enables
  "Alarms & reminders" in system settings on their own initiative — nothing
  in the app prompts for it. This breaks the feature the reminder subsystem
  exists to deliver, not just a corner case.
- **`applicationId` is still `com.example.document_organisation`.** Google
  Play rejects publishing under the `com.example.*` namespace. Trivial to
  fix, but blocking as it stands.
- **Debug instrumentation and test controls are live in the shipped UI** —
  the two notification-test buttons sit in `HomeScreen`'s app bar with no
  debug-flag gate, and `notification_service.dart` is full of
  production-path `debugPrint` calls explicitly marked for removal before
  release. Anyone installing the current build sees developer-only controls.

### In between — workable now, will need attention as it grows

- **Category/priority as duplicated `String` literals across five
  locations** instead of a shared `enum` — fine at four categories and
  three priorities; each additional category/priority, or any typo in one
  of the five spots, becomes a silent-fallback bug rather than a compile
  error.
- **`DocumentProvider`'s reload-everything-on-every-mutation pattern** —
  invisible at today's document counts; will visibly slow down (full DB
  reload plus a full notification cancel/reschedule cycle) as the
  document/reminder count grows into the hundreds.
- **`AiService`'s two independently-built, already-diverging request
  paths** — harmless today; two things to keep in sync in parallel if
  OpenAI's request contract changes.
- **Comma-joined tag storage and unenforced foreign keys** — latent, not
  live, since tags are currently AI-generated single words and there's no
  user-entered-tag path yet; would surface the moment either assumption
  changes.
- **Gallery-picker and Share buttons that are visible but non-functional
  no-ops** — not a structural problem, but a real user tapping either gets
  silence, which reads as a bug regardless of it being a known stub.
