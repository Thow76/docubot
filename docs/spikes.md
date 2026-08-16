# DocuBot — Spikes

Spikes are bounded investigations with a written finding as output, not code to merge. Run them to answer uncertain questions before building features on top of them.

## S-001 — Edge detection quality validation

**Question:** Is `flutter_document_scanner`'s detection good enough to build FR-02's manual-adjust screen on, or should we take the ML Kit fallback recorded in ADR-0006?

**Scope:**
- Throwaway Flutter project (not in `docubot` repo)
- `flutter_document_scanner` integration test
- Real-world conditions on Pixel 7: good light, shadows, patterned background, creased paper, low contrast, slight angle
- Record what the package returns (corner coordinates, pre-cropped image, both) and detection latency

**Acceptance:**
- Short written finding: pass/fail per condition, API output format, whether FR-02's screens are buildable on it
- Recommendation: proceed with `flutter_document_scanner`, or take the ML Kit fallback

**Blocks:** FR-02 capture package decision. Does not block foundation phase.

**Notes:** Cheapest moment to change course. If detection is materially worse than ML Kit, update ADR-0006 to record the reversal before any capture screens are written.
