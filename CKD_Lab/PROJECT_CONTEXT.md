# Health Tracker — Project Context

## Current objective
OCR-first medical record tracker for CKD/Diabetes/Ophthalmology. Primary UX goal: upload images, OCR, structure, validate, review only uncertain fields, then save.

## Non-negotiable UX
- Keep dashboard graphs.
- Improve graph readability/usefulness; do not remove graphs.
- Minimize manual data entry.
- Preserve original source image context for OCR-derived records.

## Current architecture
- `CKD_Lab_Tracker.html`: single-file browser app, LocalStorage, dashboard, graphs, browser OCR via Tesseract.js.
- `ocr_pipeline.py`: Python OCR/normalization pipeline.
- JSON files: OCR review, merged records, app payload.
- `tests/test_ocr_pipeline.py`: Python regression tests.

## P0 work completed in this revision
- OCR grouping no longer reads dates from parent folder names.
- OCR date is preferred; filename date is fallback; undated records require review.
- Batch size no longer splits medical groups.
- Added field plausibility validation and heuristic confidence metadata.
- Added core Potassium/Sodium/Phosphorus extraction.
- Replaced Python runtime-hash record IDs with stable SHA-1-derived IDs.
- Browser OCR no longer silently substitutes today's date when date OCR fails.
- Browser OCR review now exposes confidence and suspicious-value review state.
- Seed eGFR on 2026-08-25 aligned to the currently confirmed project value: 14.87.

## Important medical-model rule
Separate diabetic eye disease/retinopathy from glaucoma metrics. Co-occurring trends must not be presented as proven causation.

## Next P0/P1
1. Canonical field schema shared by browser and Python OCR.
2. Duplicate detection in browser OCR.
3. Original-image/source linkage in saved records.
4. Expand OCR field coverage to the existing `LABS` schema.
5. Source-specific reference ranges.
6. Medical timeline and change-detection layer.


## 2026-10-06 P0 continuation
- Duplicate detection now exists at image level (SHA-256) and OCR-content level (department + date + normalized fields).
- OCR records carry visit_key, source_images, field_sources, and content_fingerprint.
- Browser OCR flags exact duplicate OCR results within the current upload and does not commit duplicates.
- Original medical images remain the source-of-truth; OCR fields retain source-image references.


### Current checkpoint — 2026-10-06
- P0 date/grouping, confidence, plausibility validation, duplicate fingerprinting, and source-image linkage are implemented.
- P1-1 expanded OCR field coverage to match the current HTML LABS schema.
- Python OCR regression suite: 19/19 passed.
- Next priority: make Browser Tesseract OCR emit the same canonical field/meta/source model as Python OCR, then add visit-level duplicate detection and review gating.
- Graphs remain a mandatory UX requirement and must not be removed during refactoring.

## 2026-10-06 P1-2 checkpoint
- Shared OCR envelope implemented as `ocr-canonical-1` in Python and Browser OCR.
- Canonical field names now match the HTML `LABS` keys, including k/na/p/ca/hco3.
- Canonical field metadata: confidence, validation, needs_review, unit, source_files.
- Canonical record metadata: department, date, visit_key, content_fingerprint, source_images, raw_text.
- Browser OCR checks both current-upload duplicates and existing saved-record duplicates before commit.
- Saved OCR records retain original image references and canonical OCR metadata.
- Python regression suite: 21/21 passed.
- HTML embedded JavaScript syntax: passed.
- Next priority: P1-3 source-specific reference ranges + robust multi-page lab-visit grouping.

- P1-3/P1-4 completed: OCR can capture document reference ranges and split same-day multiple visits when distinct accession/report identifiers are present; pages without identifiers remain grouped conservatively.

### P1-5 completed (2026-10-06)
- Medical data model now distinguishes `glaucoma`, `vision`, and `diabetic_retina` domains inside ophthalmology.
- Existing record item keys remain backward compatible.
- Records can carry a `domains` array; diagnoses receive a normalized `domain` field.
- Cross-department HbA1c/eye messaging explicitly avoids causal inference and is framed as temporal association.

## P1-6 Status (2026-10-06)
Medical Timeline and Change Detection are implemented in the dashboard. The change detector compares the latest two records in the selected department/all view and flags notable changes using field-specific absolute/relative thresholds. The timeline combines lab records, visits, and diagnoses. Existing graphs remain intact.

### P1-7 status (2026-10-06)
Doctor Report now combines latest department data, diagnosis/visit context, previous-vs-current lab changes, medical timeline, current vitals, advice, and dashboard chart snapshots. Report is explicitly a recorded-data summary and not a diagnosis.


### P3 baseline (2026-10-08)
- Appointment: use the Internal Medicine visit date as the primary appointment date; keep lab date separately; latest clear screenshot/source snapshot has highest priority.
- Future paper records: screenshots and A5/A4 scans are treated as the same document-source concept.
- Medical events: extensible generic event record supports occasional cross-department events without creating a new schema for every specialty.
- eGFR graph: Actual remains visually dominant. The main chart now separates Stable, Observed Trend, and a statistical projection range; no fixed Best/Worst linear scenario is used.
- KFRE: risk information is a separate data panel, not overlaid on the main graph, to preserve readability. Numeric risk is intentionally withheld until appropriate calibration/region handling is implemented.
- Patient risk inputs: birthDate and sex are stored in the patient profile for future validated risk calculation.

## P4 recovery checkpoint — 2026-10-10
- The user supplied two HTML snapshots: `CKD_Lab_Tracker.txt` (older baseline) and `CKD_Lab_Tracker_(ใหม่).txt` (newer but incomplete).
- Direct comparison showed the newer file had removed core functions and state: `seed`, `migrate`, `save`, `recs`, `avg`, `I18N`, `ADV`, `LANG`, `DEPT`, `KEY`, and `DB`, while other code still depended on them. Do not use that newer file as the base.
- Recovery strategy: restore the older HTML as the application baseline and transplant only the newer feature surfaces and functions. The package's `CKD_Lab_Tracker.html` is the merged candidate; `CKD_Lab_Tracker_BASELINE_OLD.html` is the rollback baseline.
- Restored/preserved core state and functions, existing dashboard charts, lab history, daily entries, manual entry, OCR review/commit, JSON import/export, print report, and language handling.
- Added the latest appointment card and OCR extraction. Internal Medicine date is primary; blood-draw date is separate; Thai Buddhist dates are parsed; the most recent screenshot snapshot date takes priority. The OCR parser regression sample correctly selected 27 Oct 2026 Internal Medicine, 26 Oct 2026 blood draw, 09:00, and room `ห้องตรวจอายุรกรรม (คุ้มเกศ) ชั้น 1` from a sample OCR text containing a later ophthalmology appointment.
- Added extensible Medical Events UI and backward-compatible `DB.events` migration.
- Added separate KFRE information panel and migration-safe `DB.risk` defaults; numeric risk percentage remains withheld until appropriate calibration is specified.
- Replaced fixed Best/Worst eGFR scenario series with observed Actual data, stable line, observed trend, and a statistical projection band. The projection is illustrative only, not a clinical prediction.
- Added Thai Buddhist date parsing to browser OCR's lab-date detection.
- Fixed payload bootstrap to save imported `payload.DB` to the app's actual localStorage key (`ckd_db_v6`) as well as the legacy `DB` key, preventing payload data from being ignored on first load.
- Added bilingual labels for new features without replacing the original translation dictionaries.
- Validation: embedded JavaScript `node --check` passed; no duplicate HTML IDs; fake-DOM initialization smoke test passed; Medical Event save flow passed; existing-record migration test confirmed prior records are preserved; appointment OCR/date regression test passed; scenario builder returned 5 actual points + 6 projections for the current sample dataset; Python OCR tests passed 30/30 using `pytest --import-mode=importlib`.
- Limitation: real browser visual verification was not completed because headless Chromium hung in this execution environment. Treat this as a candidate for local browser verification, not as a claim that every UI interaction has been fully tested in a real browser.

## Mandatory development protocol
Before every code change, write a concise plan covering: baseline/version, objective, exact scope, protected behavior/data, acceptance tests, and rollback. Never patch the only known-good file in place. Update `PROJECT_CONTEXT.md`, `REQUIREMENTS.md`, and `CHANGELOG.md` at each meaningful milestone. Prefer existing project files and context over asking the user to upload files again. If context is at risk of being lost, checkpoint the current state before proceeding.
