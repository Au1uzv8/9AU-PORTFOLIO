# Real Image Audit — 2026-10-07

## Dataset
- 195 JPG screenshots received and extracted successfully.
- All 195 images are 720×1640 RGB.
- SHA-256 uniqueness: 195/195 unique files; no byte-identical duplicates.
- ZIP contained 196 entries: 1 folder + 195 image files.

## Filename-date finding — IMPORTANT
Filename capture dates:
- 2026-10-05: 183 images
- 2026-08-25: 5 images
- 2026-05-20: 3 images
- 2026-04-16: 1 image
- 2026-05-14: 1 image
- 2026-05-21: 1 image
- 2026-09-17: 1 image

The 183 files captured on 2026-10-05 are screenshots of medical records from earlier dates. Therefore a `Screenshot_YYYY-MM-DD...` filename date MUST NOT be treated as the medical/report date.

### Visual verification
The 2026-08-25 screenshots visibly show the medical date `25 สิงหาคม 2569` and laboratory values including:
- Potassium 4.8 mmol/L
- Sodium 138 mmol/L
- Uric acid 2.3 mg/dL
- eGFR (EPI) 14.87 mL/min
- Creatinine 2.91 mg/dL

A 2026-05-20 screenshot visibly shows eye medications with a medication date of `20 พ.ค. 2569`.

## OCR spot-check finding
Independent Tesseract spot-checks on the supplied screenshots demonstrated decimal-separator loss on the same visually clear laboratory page:
- visual `Potassium 4.8` → OCR text `Potassium 48`
- visual `Creatinine 2.91` → OCR text `Creatinine 291`

This is not being treated as evidence that the production RapidOCR engine has the same error rate. It is a real-image robustness test showing that the canonical pipeline needs a conservative decimal-repair path.

## Changes applied
1. Added Thai Buddhist-calendar date parsing (`2569` → `2026`) and English month parsing.
2. `Screenshot_...` filename dates are no longer accepted as medical dates.
3. Added conservative decimal-repair for fields with known decimal precision when the raw OCR number is implausible but the repaired number is plausible.
4. Raw OCR value is preserved.
5. Decimal-repaired values are always marked `needs_review=true` and confidence is capped at 0.85; they are not silently trusted.
6. Reference-range extraction now prioritizes the range after the matched analyte/value, reducing accidental assignment of the previous analyte's range.

## Tests
- Existing OCR regression tests + real-image regression tests: **30/30 passed**.
- HTML embedded JavaScript syntax: **PASS**.

## Limitation
The execution environment used for this audit does not have `rapidocr_onnxruntime` and cannot download packages from the internet. Therefore this audit does not claim a full 195-image production-RapidOCR accuracy score. The supplied images were still used for file-integrity checks, visual verification, and independent OCR robustness checks.
