# ADR-0006: Capture — custom Flutter UI first, ML Kit as a recorded fallback

**Status:** Accepted

## Context

The prototype's capture flow is a static camera view with a cosmetic
dashed-rectangle overlay — no real edge detection. The target design calls
for a real guided-capture flow: live detection pills, Accept/Retake/Edit,
manual corner adjustment, a page thumbnail strip, a 6-page cap, and
reordering.

That flow is only buildable on a package that renders capture as Flutter
widgets under app control. A package that instead launches a platform
scanner's own full-screen UI (e.g. Google's ML Kit document scanner
activity) can't host that custom flow — the app doesn't control what's on
screen during capture.

## Decision

Primary: `flutter_document_scanner`, since it renders capture as Flutter
widgets and can host the designed flow.

Recorded fallback: `cunning_document_scanner` (ML Kit-backed), if detection
quality on `flutter_document_scanner` proves inadequate.

Detection quality must be validated in the T-005 spike, against realistic
capture conditions, *before* the six capture screens are built — building
the UI first and discovering detection doesn't work would waste that work.

Capture's contract with the rest of the app is a flat list of image file
paths. Nothing downstream — the save form, AI analysis, storage — knows how
those paths were produced. Swapping to the ML Kit fallback later means
deleting the capture screens and rewiring one call, not touching the
detail form, save flow, AI service, or storage layer.

### Packages considered and excluded

- `simplest_document_scanner` — excluded: AGPL-3.0 license, unsuitable for
  Play Store distribution.
- `document_scanner_flutter` — excluded: this is the PDF-oriented package
  without the `flutter_` prefix (not to be confused with
  `flutter_document_scanner` above); superseded and less actively
  maintained.

## Consequences

The flat-file-path contract is what makes the fallback cheap if
`flutter_document_scanner`'s detection quality doesn't hold up — the cost
of being wrong about the primary package choice is bounded to the capture
screens themselves.
