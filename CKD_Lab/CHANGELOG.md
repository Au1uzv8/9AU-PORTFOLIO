
## 2026-10-08 — P3 Appointment / Medical Events / eGFR Scenario UX
- Added dashboard latest appointment card. Primary appointment date is the Internal Medicine visit date; lab/venipuncture date is stored separately.
- Added Thai Buddhist date parsing and appointment extraction from OCR text, including snapshot-date priority and source ordering.
- Added extensible Medical Events storage/UI for occasional events (fall, head injury, accident, emergency, surgery, orthopedics, neurology, other).
- Reworked eGFR scenario chart to use Actual + Stable + Observed Trend + statistical projection range instead of fixed Best/Worst linear values. The projection is explicitly informational, not a dialysis decision rule.
- Added a separate Kidney Risk / KFRE information panel; it is intentionally not drawn inside the main eGFR chart. The current build withholds a numeric KFRE percentage until region/calibration is explicitly specified.
- Stored patient birth date/sex fields needed for future validated risk calculation.
- Added migration support for `appointments` and `events` without changing the existing localStorage key.
- Regression tests: 30/30 passed; embedded JavaScript syntax check passed; appointment OCR parser spot test passed.

# CHANGELOG

## 2026-10-06 — P0 OCR reliability pass
- Added deterministic OCR content fingerprints for duplicate visit detection.
- Added visit keys and original source-image linkage to OCR review/DB payloads.
- Added field-level source image lists so each extracted value can be traced back to its image.
- Browser OCR now flags exact OCR-content duplicates within the same upload and skips them on commit.
- Fixed parent-folder date contamination in Python grouping.
- Grouped OCR results after OCR instead of per batch.
- Added OCR date normalization for ISO and DD/MM/YYYY.
- Added plausibility validation and confidence metadata.
- Added Potassium, Sodium, Phosphorus extraction.
- Made OCR record IDs deterministic/stable.
- Browser OCR now leaves date blank when OCR cannot find one instead of using the current date.
- Browser OCR review displays confidence and suspicious-value state.
- Corrected project seed eGFR 2026-08-25 from 14.67 to 14.87.
- Python regression suite: 15/15 passing.


## 2026-10-06 — P1-1 OCR field coverage
- Expanded Python OCR extraction to the lab schema used by the HTML app: uric acid, calcium, bicarbonate, hemoglobin, albumin, FBS, cholesterol, triglyceride, HDL, LDL, urine pH, specific gravity, plus RNFL, visual acuity and diabetic retinopathy fields.
- Added plausibility ranges for the new OCR fields. These are screening ranges only, not diagnostic reference ranges.
- Extended the canonical Python-to-App field mapping so extracted values can enter the existing DB schema without creating parallel keys.
- Added regression tests for extended medical and ophthalmology panels.
- Test result: 19/19 passed.

## 2026-10-06 — P1-2 Canonical OCR Model
- Added shared `ocr-canonical-1` envelope for Python and Browser OCR.
- Canonical fields use the existing HTML App `LABS` keys (`k`, `na`, `p`, `ca`, `hco3`, etc.) to avoid duplicate schemas.
- Canonical field metadata now carries confidence, validation, needs_review, unit, and source_files.
- Canonical records carry department, date, visit_key, content_fingerprint, source_images, and raw_text.
- Browser OCR now creates the same canonical envelope before review/commit.
- Browser OCR now checks uploaded OCR results against existing saved records for visit-level duplicates.
- OCR-derived saved records retain `source_images` and `ocr_canonical` metadata.
- Regression tests increased from 19 to 21; all pass.

- 2026-10-06 P1-3/P1-4: source-derived reference range extraction; same-day visit splitting by OCR accession/report identifiers; canonical field metadata now preserves reference_range. Pipeline 2.3-p1-reference-grouping.

## 2026-10-06 — P1-5 Medical Data Model
- Separated ophthalmology measurement domains: glaucoma, vision, and diabetic retinopathy.
- Added record-level `domains` metadata while preserving existing LABS keys and historical records.
- Added diagnosis-domain mapping for CKD, diabetes, hypertension, glaucoma, vision, and diabetes screening.
- Updated cross-department dashboard wording to describe temporal association rather than direct causation.
- Kept all existing graphs; no dashboard chart was removed.
- Regression tests: 24 passed.

## 2026-10-06 — P1-6 Medical Timeline + Change Detection
- Added dashboard card: What changed since previous visit.
- Added generic field-level change detection with per-field absolute/relative thresholds.
- Added Medical Timeline combining lab records, clinic visits, and diagnoses.
- Change detection is explicitly framed as recorded-data change detection, not diagnosis or causation.
- Preserved existing graphs and dashboard structure.
- Bilingual labels added for new dashboard sections.

## 2026-10-06 — P1-7 Doctor Report
- Expanded the print report to include a concise change summary, department-level change tables, medical timeline, current vitals, and recorded advice.
- Added rendered dashboard chart snapshots to the printable report so visual trends remain available for clinician discussion.
- Preserved source reference ranges where present and kept the report tied to recorded data only.
- Added a clear non-diagnostic disclaimer to the report.
- Regression: 24/24 Python OCR tests passed; embedded HTML JavaScript syntax passed.


## 2026-10-06 — P2 Intelligent Layer / UX pass
- Added dashboard Attention Center for latest out-of-range and OCR-review items.
- Added high-confidence OCR confirmation action so users can mark only sufficiently confident fields without manually retyping them.
- Preserved graph-first dashboard and existing chart coverage.
- Updated requirements to mark canonical OCR and graph readability work complete.

## 2026-10-10 — P4 HTML recovery and safe merge
- Compared the supplied old/new HTML files directly. The newer file had dropped the original database bootstrap, schema migration, persistence, record selection/aggregation helpers, and language/advice dictionaries while retaining references to those dependencies.
- Rebuilt from the older baseline instead of patching the broken file, then merged appointment, KFRE panel, Medical Events, and revised eGFR graph features.
- Added Thai Buddhist-date support to browser OCR date extraction and tightened appointment parsing so a nearby later ophthalmology appointment cannot be mistaken for the Internal Medicine appointment. The primary appointment, lab date, time, and location passed a regression test.
- Added backward-compatible schema defaults for appointments/events/risk and retained the existing localStorage key `ckd_db_v6`.
- Fixed payload bootstrap to write the payload to `ckd_db_v6`, preserving the legacy `DB` key too.
- Preserved the original HTML as `CKD_Lab_Tracker_BASELINE_OLD.html` for rollback.
- Tests: JS syntax pass; HTML ID uniqueness pass; fake-DOM startup pass; event save pass; existing-record migration pass; appointment/date parser pass; 30/30 Python OCR tests pass.
- Not verified: full real-browser visual and interaction test. Headless Chromium timed out in the current environment.
