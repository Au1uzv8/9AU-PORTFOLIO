# Next Session Handoff — 2026-10-10

## Current candidate
- `CKD_Lab_Tracker.html` — P4 merged candidate, based on the older working HTML.
- `CKD_Lab_Tracker_BASELINE_OLD.html` — rollback copy of the supplied older HTML.

## Why the merge was necessary
The supplied newer HTML removed core state/functions (`I18N`, `ADV`, `LANG`, `DEPT`, `KEY`, `DB`, `seed`, `migrate`, `save`, `recs`, `avg`) but retained downstream calls to them. It should not be used as the base.

## Verified in this environment
- Embedded JS syntax: pass.
- Duplicate HTML IDs: none found.
- Fake-DOM startup smoke test: pass.
- Save a Medical Event and persist it: pass.
- Existing-record migration preserves prior record: pass.
- Thai OCR date `25 ส.ค. 2569` normalizes to `2026-08-25`: pass.
- Appointment sample selects 27 Oct 2026 Internal Medicine, separates 26 Oct 2026 blood draw, and extracts 09:00 and the room: pass.
- Scenario builder: 5 actual data points + 6 illustrative projections for the sample dataset.
- Python OCR regression tests: 30/30 pass using `python -m pytest -q tests/test_ocr_pipeline.py test_real_image_regressions.py --import-mode=importlib`.

## Not yet verified
Headless Chromium timed out in this environment. Open the candidate in a real browser and verify dashboard, department switching, manual lab save, daily save, OCR upload/review/commit, event save, JSON export/import, print report, and language toggle before publishing it.

## Next work
1. Browser acceptance test and fix any runtime/UI issues.
2. Do not replace the baseline until acceptance tests pass.
3. Keep KFRE numeric risk withheld until an appropriate Thailand calibration/validation choice is justified.
