# Requirements

## P0 — Reliability
- [x] Do not derive medical date from parent folder name.
- [x] OCR date preferred; filename date only as fallback.
- [x] No automatic "today" date when OCR date is missing.
- [x] Validate suspicious numeric values before automatic acceptance.
- [x] Expose OCR confidence/review state.
- [x] Stable record IDs.
- [x] Detect duplicate records at content/visit level.
- [x] Link each extracted field/record to original image.

## P1 — Intelligent record structure
- [x] Shared canonical schema for Python and browser OCR.
- [x] Expand OCR extraction to all important LABS fields.
- [x] Preserve source reference ranges.
- [x] Auto-group multi-page lab visits robustly.
- [x] Kidney / Diabetes / Diabetic Eye Disease / Glaucoma separation.
- [x] Medical timeline.
- [x] Significant-change detection.
- [x] Doctor report.

## Dashboard
- [x] Keep graphs.
- [x] Improve signal/readability without removing existing graph coverage.


### OCR P1-1 acceptance criteria
- Extract all currently defined numeric medical/eye fields where the source text contains a recognizable label.
- Preserve the existing App field keys.
- Attach validation metadata to every extracted field.
- Do not use parent-folder dates as medical dates.
- Keep original source-image linkage.
- Existing OCR tests must continue to pass.

- Reference ranges must preserve source-document values when OCR can identify them; default App ranges remain plausibility guards only.
- Same-day visits must not be merged when OCR provides distinct accession/report identifiers.

### P1-6 Medical Timeline / Change Detection
- Show what changed from the previous recorded visit.
- Distinguish notable vs minor changes using transparent field-specific thresholds.
- Show a chronological medical timeline for labs, visits, and diagnoses.
- Do not present change detection as diagnosis or causal inference.
- Preserve graph-first dashboard UX.


## P2 — Intelligent UX
- [x] Dashboard Attention Center for latest recorded out-of-range / OCR-review items.
- [x] High-confidence OCR confirmation workflow.
- [x] Block OCR commit while unresolved review items remain.
- [x] Preserve graph-first dashboard and existing graph coverage.


## P3 requirements — confirmed 2026-10-08
1. Appointment date must use the Internal Medicine visit date as the primary appointment date; lab date remains separate.
2. Appointment OCR must tolerate hospital app screenshots, Thai Buddhist dates, and rescheduled appointments.
3. Latest screenshot/source snapshot must have priority when appointment information changes.
4. Medical Events must support rare cross-department events without bloating the core lab model.
5. eGFR graph must keep Actual visually dominant and must not use arbitrary Best/Worst linear projections.
6. KFRE/Risk must be displayed separately from the main eGFR graph.
7. Original documents remain source-of-truth; OCR output is structured data, not the sole evidence.

## P4 recovery acceptance criteria — 2026-10-10
- [x] Use the old HTML as the recovery baseline when the newer HTML is missing core functions/state.
- [x] Keep existing data and localStorage key during schema migration.
- [x] Add appointment extraction with Internal Medicine as primary date and a separate blood-draw date.
- [x] Prioritize the screenshot snapshot date; parse Thai Buddhist dates in browser OCR.
- [x] Add Medical Events form/history and backward-compatible storage.
- [x] Keep KFRE separate from the eGFR graph and withhold numeric percentage until calibration is appropriate.
- [x] Replace arbitrary Best/Worst eGFR projections with Actual, stable reference, observed trend, and an illustrative range.
- [x] Preserve old dashboard charts and core database/OCR/import-export/print functions.
- [x] Maintain a rollback baseline and record this recovery in project documentation.
- [ ] Complete visual and interaction verification in a real browser on the user's machine.
