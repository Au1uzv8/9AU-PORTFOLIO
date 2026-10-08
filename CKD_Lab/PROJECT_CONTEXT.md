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
