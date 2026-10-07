# P0 OCR Audit — 2026-10-06

## Finding
The previous Python grouping logic searched `str(raw_path)` for a date. Because the project folder itself contains `2026-10-05`, that folder date could be incorrectly assigned to medical records.

## Fix
- Date extraction now uses OCR text first.
- Filename is only a fallback.
- Parent directories are never inspected for medical dates.
- Batch processing no longer creates separate medical groups; groups are formed after OCR.
- Missing date is retained as `unknown`/review-needed instead of silently becoming today's date.

## Validation layer
Each extracted field now carries:
- confidence (heuristic, not a medical certainty)
- plausibility status
- needs_review flag

## Browser OCR
- Removed silent current-date fallback.
- Added confidence/suspicious indicators in review UI.
- Records without a date are not committed automatically.

## Regression
- Python tests: 15/15 passed.
- Browser inline JavaScript: syntax check passed.
- Import JavaScript: syntax check passed.

## Scope note
The ZIP supplied for this audit did not contain the ~210 screenshots, so this revision does not regenerate the medical JSON from those images. The OCR engine changes are covered by synthetic/regression tests and are ready for the image set when it is supplied.
