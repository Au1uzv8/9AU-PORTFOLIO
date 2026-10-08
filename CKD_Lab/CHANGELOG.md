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
