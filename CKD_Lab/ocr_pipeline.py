from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Sequence, Tuple


FIELD_PATTERNS = {
    "egfr": [r"\begfr\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\bgfr\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "cr": [r"\b(?:creatinine|serum\s+creatinine)\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\bcr\s*[:=]\s*(\d+(?:\.\d+)?)"],
    "bun": [r"\b(?:bun|blood\s+urea\s+nitrogen)\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\burea\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "acr": [r"\b(?:acr|a/c\s*ratio|albumin\s*/\s*creatinine\s*ratio)\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\bmicroalbumin\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "uric": [r"\b(?:uric\s*acid|urate)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "potassium": [r"\b(?:potassium|k)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "sodium": [r"\b(?:sodium|na)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "phosphorus": [r"\b(?:phosphorus|phosphate|po4)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "calcium": [r"\b(?:calcium|ca)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "bicarbonate": [r"\b(?:bicarbonate|hco3|total\s*co2)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "hb": [r"\b(?:hemoglobin|haemoglobin|hb)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "alb": [r"\b(?:serum\s+albumin|albumin)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "fbs": [r"\b(?:fasting\s+(?:blood\s+)?sugar|fasting\s+blood\s+glucose|fbs)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "a1c": [r"\b(?:hba1c|hb\s*a1c|a1c)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "chol": [r"\b(?:total\s+cholesterol|cholesterol|chol)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "tg": [r"\b(?:triglyceride|triglycerides|tg)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "hdl": [r"\bhdl(?:\s*-?c)?\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "ldl": [r"\bldl(?:\s*-?c)?\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "uph": [r"\burine\s+ph\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\bph\s*[:=]\s*(\d+(?:\.\d+)?)"],
    "usg": [r"\b(?:specific\s+gravity|urine\s+specific\s+gravity|usg)\s*[:=]?\s*(1\.\d{2,3})"],
    "upro": [r"\burine\s+protein\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "iop_od": [r"\biop\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\bod\b.*?\biop\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "iop_os": [r"\biop\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)", r"\bos\b.*?\biop\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "cdr_od": [r"\b(?:cdr|c/d)\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "cdr_os": [r"\b(?:cdr|c/d)\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "rnfl_od": [r"\b(?:rnfl|oct\s+rnfl)\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "rnfl_os": [r"\b(?:rnfl|oct\s+rnfl)\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "vf_od": [r"\b(?:vf|visual\s+field)(?:\s+md)?\s*(?:od|right).*?[:=]?\s*(-?\d+(?:\.\d+)?)"],
    "vf_os": [r"\b(?:vf|visual\s+field)(?:\s+md)?\s*(?:os|left).*?[:=]?\s*(-?\d+(?:\.\d+)?)"],
    "va_od": [r"\b(?:va|visual\s+acuity)\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "va_os": [r"\b(?:va|visual\s+acuity)\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)"],
    "dr": [r"\b(?:dr|diabetic\s+retinopathy)(?:\s+stage)?\s*[:=]?\s*(\d+)"],
}
FIELD_PATTERNS = {key: [re.compile(pattern, re.I) for pattern in patterns] for key, patterns in FIELD_PATTERNS.items()}

FIELD_RANGES = {
    "egfr": (0, 200), "cr": (0, 30), "bun": (0, 300), "acr": (0, 10000), "uric": (0, 20),
    "potassium": (1.5, 10), "sodium": (100, 180), "phosphorus": (1, 15), "calcium": (4, 15), "bicarbonate": (5, 50),
    "hb": (3, 20), "alb": (1.5, 7), "fbs": (20, 800), "a1c": (3, 20), "chol": (20, 1000), "tg": (10, 2000),
    "hdl": (5, 200), "ldl": (5, 500), "upro": (0, 100), "uph": (3, 10), "usg": (1.000, 1.060),
    "iop_od": (0, 80), "iop_os": (0, 80), "cdr_od": (0, 1), "cdr_os": (0, 1),
    "rnfl_od": (20, 300), "rnfl_os": (20, 300), "vf_od": (-50, 10), "vf_os": (-50, 10),
    "va_od": (0, 3), "va_os": (0, 3), "dr": (0, 4),
}


CANONICAL_FIELD_MAP = {
    "potassium": "k", "sodium": "na", "phosphorus": "p", "calcium": "ca",
    "bicarbonate": "hco3", "creatinine": "cr", "microalbumin": "acr",
}

CONDITION_DOMAIN_MAP = {
    "iop_od": "glaucoma", "iop_os": "glaucoma", "cdr_od": "glaucoma", "cdr_os": "glaucoma",
    "rnfl_od": "glaucoma", "rnfl_os": "glaucoma", "vf_od": "glaucoma", "vf_os": "glaucoma",
    "va_od": "vision", "va_os": "vision", "dr": "diabetic_retina",
}

def condition_domains(fields: Dict[str, Any]) -> List[str]:
    domains = []
    for key in fields or {}:
        domain = CONDITION_DOMAIN_MAP.get(key)
        if domain and domain not in domains:
            domains.append(domain)
    return sorted(domains)


FIELD_UNITS = {
    "egfr": "mL/min", "cr": "mg/dL", "bun": "mg/dL", "acr": "mgA/gC", "uric": "mg/dL",
    "potassium": "mmol/L", "sodium": "mmol/L", "phosphorus": "mg/dL", "calcium": "mg/dL",
    "bicarbonate": "mmol/L", "hb": "g/dL", "alb": "g/dL", "fbs": "mg/dL", "a1c": "%",
    "chol": "mg/dL", "tg": "mg/dL", "hdl": "mg/dL", "ldl": "mg/dL", "uph": "", "usg": "",
    "iop_od": "mmHg", "iop_os": "mmHg", "cdr_od": "", "cdr_os": "",
    "rnfl_od": "um", "rnfl_os": "um", "vf_od": "dB", "vf_os": "dB",
    "va_od": "", "va_os": "", "dr": "0-4",
}


MED_KEYWORDS = (
    "egfr", "gfr", "creatinine", "bun", "urea", "albumin", "microalbumin", "a/c ratio", "acr",
    "hba1c", "a1c", "potassium", "sodium", "phosphorus", "ปัสสาวะ", "ไต", "kidney", "diabetes",
)
EYE_KEYWORDS = (
    "iop", "cdr", "optic", "retina", "visual field", "glaucoma", "eye", "oculus", "จักษุ", "ต้อหิน",
    "สายตา", "vision",
)


def sha256_file(path: str | Path) -> str:
    hash_obj = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            hash_obj.update(chunk)
    return hash_obj.hexdigest()


def file_list(folder: str | Path) -> List[Path]:
    root = Path(folder)
    if not root.exists():
        raise FileNotFoundError(f"Folder not found: {root}")
    patterns = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
    return sorted([p for p in root.iterdir() if p.is_file() and p.suffix.lower() in patterns], key=lambda item: item.name.lower())


def dedupe_files(paths: Sequence[str | Path], fingerprints: Sequence[str] | None = None) -> List[Dict[str, Any]]:
    seen: Dict[str, Dict[str, Any]] = {}
    candidate_paths = [Path(p) for p in paths]
    for index, path in enumerate(candidate_paths):
        key = fingerprints[index] if fingerprints and index < len(fingerprints) else sha256_file(path)
        entry = seen.setdefault(key, {"key": key, "items": [], "representative": str(path)})
        entry["items"].append(str(path))
    groups = []
    for item in seen.values():
        item["duplicate_count"] = max(0, len(item["items"]) - 1)
        groups.append(item)
    return sorted(groups, key=lambda item: item["representative"].lower())


def classify_department(text: str) -> str:
    lowered = text.lower()
    med_score = sum(1 for keyword in MED_KEYWORDS if keyword.lower() in lowered)
    eye_score = sum(1 for keyword in EYE_KEYWORDS if keyword.lower() in lowered)
    return "med" if med_score >= eye_score else "eye"


def extract_numeric_values(text: str) -> List[float]:
    values: List[float] = []
    for match in re.finditer(r"[-+]?\d*\.\d+|[-+]?\d+", text):
        candidate = match.group(0)
        try:
            numeric = float(candidate)
        except ValueError:
            continue
        if abs(numeric) >= 10000:
            continue
        values.append(numeric)
    return values


THAI_MONTHS = {
    "ม.ค.": 1, "มค": 1, "มกราคม": 1, "ก.พ.": 2, "กพ": 2, "กุมภาพันธ์": 2,
    "มี.ค.": 3, "มีค": 3, "มีนาคม": 3, "เม.ย.": 4, "เมย": 4, "เมษายน": 4,
    "พ.ค.": 5, "พค": 5, "พฤษภาคม": 5, "มิ.ย.": 6, "มิย": 6, "มิถุนายน": 6,
    "ก.ค.": 7, "กค": 7, "กรกฎาคม": 7, "ส.ค.": 8, "สค": 8, "สิงหาคม": 8,
    "ก.ย.": 9, "กย": 9, "กันยายน": 9, "ต.ค.": 10, "ตค": 10, "ตุลาคม": 10,
    "พ.ย.": 11, "พย": 11, "พฤศจิกายน": 11, "ธ.ค.": 12, "ธค": 12, "ธันวาคม": 12,
}
EN_MONTHS = {"jan":1,"january":1,"feb":2,"february":2,"mar":3,"march":3,"apr":4,"april":4,"may":5,"jun":6,"june":6,"jul":7,"july":7,"aug":8,"august":8,"sep":9,"sept":9,"september":9,"oct":10,"october":10,"nov":11,"november":11,"dec":12,"december":12}

def _normalize_year(year: int) -> int | None:
    if 2400 <= year <= 2700:
        year -= 543
    return year if 1900 <= year <= 2100 else None

def extract_date(text: str) -> str | None:
    """Extract a medical/report date from OCR text, including Thai Buddhist-calendar dates."""
    if not text:
        return None
    normalized = text.replace(".", "/").replace("-", "/")
    match = re.search(r"\b(\d{4})/(\d{1,2})/(\d{1,2})\b", normalized)
    if match:
        year, month, day = map(int, match.groups()); year = _normalize_year(year)
        if year and 1 <= month <= 12 and 1 <= day <= 31: return f"{year:04d}-{month:02d}-{day:02d}"
    match = re.search(r"\b(\d{1,2})/(\d{1,2})/(\d{4})\b", normalized)
    if match:
        day, month, year = map(int, match.groups()); year = _normalize_year(year)
        if year and 1 <= month <= 12 and 1 <= day <= 31: return f"{year:04d}-{month:02d}-{day:02d}"
    thai = "|".join(sorted((re.escape(k) for k in THAI_MONTHS), key=len, reverse=True))
    match = re.search(rf"\b(\d{{1,2}})\s+({thai})\s+(\d{{4}})\b", text, re.I)
    if match:
        day, token, year = int(match.group(1)), match.group(2), _normalize_year(int(match.group(3)))
        month = THAI_MONTHS.get(token) or THAI_MONTHS.get(token.lower())
        if year and month and 1 <= day <= 31: return f"{year:04d}-{month:02d}-{day:02d}"
    english = "|".join(sorted(EN_MONTHS, key=len, reverse=True))
    match = re.search(rf"\b(\d{{1,2}})\s+({english})\s+(\d{{4}})\b", text, re.I)
    if match:
        day, token, year = int(match.group(1)), match.group(2).lower(), _normalize_year(int(match.group(3)))
        month = EN_MONTHS.get(token)
        if year and month and 1 <= day <= 31: return f"{year:04d}-{month:02d}-{day:02d}"
    return None

def filename_date(path: str | Path) -> str | None:
    """Use a filename date only when it is explicitly part of a medical filename.
    Smartphone screenshots are capture dates, not medical/report dates, so they are excluded.
    """
    name = Path(path).name
    if name.lower().startswith("screenshot_"):
        return None
    return extract_date(name)


def validate_field(key: str, value: float) -> Dict[str, Any]:
    bounds = FIELD_RANGES.get(key)
    if not bounds:
        return {"status": "unknown", "message": "No plausibility range configured"}
    low, high = bounds
    if low <= value <= high:
        return {"status": "plausible", "message": "Within configured plausibility range"}
    return {"status": "suspicious", "message": f"Outside configured plausibility range {low:g}–{high:g}"}


def extract_reference_range(key: str, text: str, match_start: int | None = None) -> Dict[str, Any] | None:
    """Extract source-document reference range near the matched analyte/value.
    Prefer the text after the match so a neighboring analyte's range is not misassigned.
    """
    if not text: return None
    pos = match_start or 0
    windows = [text[pos:pos + 180], text[max(0, pos - 60):pos + 20]]
    patterns = [
        r"(?:ref(?:erence)?(?:\s+range)?|normal\s+range)\s*[:=]?\s*(\d+(?:\.\d+)?)\s*(?:-|–|—|to)\s*(\d+(?:\.\d+)?)",
        r"(?:ref(?:erence)?(?:\s+range)?|normal\s+range)\s*[:=]?\s*(<|<=|>|>=)\s*(\d+(?:\.\d+)?)",
        r"\b(\d+(?:\.\d+)?)\s*(?:-|–|—|to)\s*(\d+(?:\.\d+)?)\b"
    ]
    for window in windows:
        for pattern in patterns:
            m = re.search(pattern, window, re.I)
            if not m: continue
            if len(m.groups()) == 2 and m.group(1) in ("<", "<=", ">", ">="):
                return {"type":"threshold","operator":m.group(1),"value":float(m.group(2)),"source":"ocr"}
            return {"type":"range","low":float(m.group(1)),"high":float(m.group(2)),"source":"ocr"}
    return None

def field_confidence(key: str, value: float, text: str) -> float:
    """Heuristic confidence: pattern match + plausibility, not a medical certainty."""
    validation = validate_field(key, value)
    score = 0.90 if key in text.lower() else 0.75
    if validation["status"] == "suspicious":
        score = 0.20
    return round(score, 2)


def extract_visit_identifier(text: str) -> str | None:
    """Extract a stable report/accession identifier when the document exposes one."""
    if not text:
        return None
    patterns = [
        r"\b(?:accession|accession\s*no|lab(?:oratory)?\s*(?:no|number)|specimen\s*(?:no|number)|order\s*(?:no|number)|request\s*(?:no|number)|report\s*(?:no|number))\s*[:#=]?\s*([A-Z0-9][A-Z0-9./_-]{3,})",
        r"\b(?:HN|MRN|visit)\s*[:#=]\s*([A-Z0-9][A-Z0-9./_-]{3,})"
    ]
    for pattern in patterns:
        m = re.search(pattern, text, re.I)
        if m:
            token = re.sub(r"[^A-Za-z0-9._/-]", "", m.group(1)).upper()
            if len(token) >= 4:
                return token
    return None


def group_related_files(files: Iterable[str | Path], ocr_text_by_file: Dict[str, str] | None = None) -> List[Tuple[str, str, List[str]]]:
    """Group multi-page reports by OCR date/department, splitting only when a document identifier proves separate visits."""
    chunks = []
    for raw_path in files:
        path = Path(raw_path)
        text = (ocr_text_by_file or {}).get(str(raw_path), "")
        date = extract_date(text) or filename_date(path) or "unknown"
        dept = classify_department(text or path.name)
        chunks.append({"file": str(raw_path), "text": text, "date": date, "dept": dept, "visit_id": extract_visit_identifier(text)})

    by_base: Dict[Tuple[str, str], List[Dict[str, Any]]] = defaultdict(list)
    for item in chunks:
        by_base[(item["dept"], item["date"])].append(item)

    output: List[Tuple[str, str, List[str]]] = []
    for (dept, date), items in sorted(by_base.items()):
        ids = sorted({i["visit_id"] for i in items if i["visit_id"]})
        if len(ids) <= 1:
            bucket = f"{dept}_{date}" + (f"_{ids[0]}" if ids else "")
            output.append((bucket, dept, sorted(i["file"] for i in items)))
            continue
        # Multiple identifiers on the same date: split by identifier; unlabelled pages remain in a shared bucket.
        for visit_id in ids:
            selected = [i["file"] for i in items if i["visit_id"] == visit_id]
            output.append((f"{dept}_{date}_{visit_id}", dept, sorted(selected)))
        unlabelled = [i["file"] for i in items if not i["visit_id"]]
        if unlabelled:
            output.append((f"{dept}_{date}_unidentified", dept, sorted(unlabelled)))
    return output


def _ocr_image(path: str | Path) -> str:
    try:
        from rapidocr_onnxruntime import RapidOCR
        if not hasattr(_ocr_image, "_detector"):
            _ocr_image._detector = RapidOCR()
        result, _ = _ocr_image._detector(str(path))
        if not result:
            return ""
        lines = []
        for row in result:
            if isinstance(row, (list, tuple)) and len(row) >= 2:
                text = str(row[1]).strip()
                if text:
                    lines.append(text)
        return "\n".join(lines)
    except Exception:
        return ""


FIELD_DECIMAL_PLACES = {"egfr":2,"cr":2,"uric":1,"potassium":1,"phosphorus":1,"calcium":1,"bicarbonate":0,"hb":1,"alb":1,"a1c":1,"iop_od":1,"iop_os":1,"cdr_od":2,"cdr_os":2,"vf_od":1,"vf_os":1}
DECIMAL_REPAIR_MIN_RAW = {"egfr":100,"cr":100,"uric":10,"potassium":10,"phosphorus":10,"calcium":10,"hb":30,"alb":10,"a1c":10,"iop_od":10,"iop_os":10,"cdr_od":10,"cdr_os":10}

def repair_ocr_decimal(key: str, value: float, source_range: Dict[str, Any] | None) -> tuple[float, Dict[str, Any] | None]:
    places = FIELD_DECIMAL_PLACES.get(key)
    if places is None or not float(value).is_integer(): return value, None
    raw = int(value)
    if raw == 0 or raw < DECIMAL_REPAIR_MIN_RAW.get(key, 10): return value, None
    candidate = raw / (10 ** places)
    bounds = FIELD_RANGES.get(key)
    if not bounds or not (bounds[0] <= candidate <= bounds[1]) or bounds[0] <= value <= bounds[1]: return value, None
    return candidate, {"type":"decimal_repair","raw_ocr_value":value,"normalized_value":candidate,"decimal_places":places,"reason":"Likely OCR dropped decimal separator","needs_review":True,"confidence_cap":0.85}


def normalize_ocr_text(text: str, department_hint: str | None = None) -> Dict[str, Any]:
    normalized: Dict[str, Any] = {
        "department": department_hint or classify_department(text or ""),
        "fields": {}, "field_meta": {}, "date": extract_date(text),
    }
    if not text:
        return normalized
    cleaned = text.replace("—", "-").replace("–", "-")
    for key, patterns in FIELD_PATTERNS.items():
        for pattern in patterns:
            match = pattern.search(cleaned)
            if match:
                raw_value = float(match.group(1))
                source_range = extract_reference_range(key, cleaned, match.start())
                value, repair = repair_ocr_decimal(key, raw_value, source_range)
                normalized["fields"][key] = value
                validation = validate_field(key, value)
                confidence = field_confidence(key, value, cleaned)
                if repair: confidence = min(confidence, float(repair.get("confidence_cap", 0.85)))
                normalized["field_meta"][key] = {
                    "confidence": confidence, "validation": validation, "reference_range": source_range,
                    "raw_ocr_value": raw_value, "repair": repair,
                    "needs_review": validation["status"] == "suspicious" or bool(repair),
                }
                break
    if not normalized["fields"]:
        normalized["department"] = classify_department(cleaned)
    return normalized


def _process_images(images: Sequence[Path], progress: bool = False) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    processed: List[Dict[str, Any]] = []
    for index, image in enumerate(images, start=1):
        if progress:
            print(f"[ocr] {index}/{len(images)} {image.name}")
        text = _ocr_image(image).strip()
        parsed = normalize_ocr_text(text)
        processed.append({
            "file": str(image),
            "text": text,
            "department": parsed.get("department"),
            "date": parsed.get("date") or filename_date(image),
            "parsed_values": parsed.get("fields", {}),
            "field_meta": parsed.get("field_meta", {}),
        })
    return processed, {}


def field_sources_from_chunks(chunks: Sequence[Dict[str, Any]]) -> Dict[str, List[str]]:
    sources: Dict[str, List[str]] = defaultdict(list)
    for item in chunks:
        source = item.get("file")
        for key in (item.get("parsed_values") or {}):
            if source and source not in sources[key]:
                sources[key].append(source)
    return {key: sorted(value) for key, value in sources.items()}


def content_fingerprint(department: str, date: str | None, fields: Dict[str, Any]) -> str:
    payload = json.dumps({"department": department, "date": date or "", "fields": fields}, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def detect_duplicate_groups(groups: Sequence[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen: Dict[str, Dict[str, Any]] = {}
    duplicates: List[Dict[str, Any]] = []
    for group in groups:
        fp = group.get("content_fingerprint")
        if not fp:
            continue
        if fp not in seen:
            seen[fp] = group
            continue
        duplicates.append({
            "fingerprint": fp,
            "original_group": seen[fp].get("group_key"),
            "duplicate_group": group.get("group_key"),
            "date": group.get("date"),
            "department": group.get("department"),
        })
    return duplicates


def build_inventory(folder: str | Path, batch_size: int | None = None, progress: bool = False) -> Dict[str, Any]:
    images = file_list(folder)
    paths = [str(item) for item in images]
    duplicates = dedupe_files(paths)

    # IMPORTANT: OCR all unique representatives first. Batching is only a progress/memory aid;
    # it must not create separate medical groups.
    unique_paths = [item["representative"] for item in duplicates]
    processed, _ = _process_images([Path(p) for p in unique_paths], progress=progress)
    ocr_text_by_file = {item["file"]: item["text"] for item in processed}
    groups = group_related_files(unique_paths, ocr_text_by_file)

    records: List[Dict[str, Any]] = []
    for group_key, department, files_in_group in groups:
        chunks = [item for item in processed if item["file"] in files_in_group]
        joined = "\n".join(item["text"] for item in chunks if item["text"])
        normalized = normalize_ocr_text(joined, department)
        date = normalized.get("date") or next((item.get("date") for item in chunks if item.get("date")), None)
        field_sources = field_sources_from_chunks(chunks)
        field_meta = normalized.get("field_meta", {})
        for key, meta in field_meta.items():
            meta["source_files"] = field_sources.get(key, [])
        fingerprint = content_fingerprint(normalized["department"], date, normalized["fields"]) if normalized["fields"] else None
        records.append({
            "group_key": group_key,
            "visit_key": f"{normalized['department']}_{date or 'unknown'}",
            "department": normalized["department"],
            "files": files_in_group,
            "values": extract_numeric_values(joined),
            "ocr_text": joined,
            "parsed_values": normalized["fields"],
            "field_meta": field_meta,
            "field_sources": field_sources,
            "date": date,
            "content_fingerprint": fingerprint,
            "needs_review": any(meta.get("needs_review") for meta in field_meta.values()) or not date or not normalized["fields"],
        })

    duplicate_visits = detect_duplicate_groups(records)
    return {
        "folder": str(Path(folder)),
        "total_files": len(images),
        "unique_files": len(unique_paths),
        "deduplicated_count": len(records),
        "duplicates": duplicates,
        "groups": records,
        "duplicate_visits": duplicate_visits,
    }



def canonicalize_ocr_result(
    fields: Dict[str, Any],
    field_meta: Dict[str, Any] | None = None,
    department: str = "med",
    date: str | None = None,
    source_images: Sequence[str] | None = None,
    raw_text: str = "",
) -> Dict[str, Any]:
    """Return the canonical OCR envelope shared by Python and browser OCR.

    Canonical field keys intentionally match the HTML App LABS keys.
    """
    canonical_fields: Dict[str, float] = {}
    canonical_meta: Dict[str, Any] = {}
    source_images = list(source_images or [])
    for key, value in (fields or {}).items():
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            continue
        canonical_key = CANONICAL_FIELD_MAP.get(key, key)
        canonical_fields[canonical_key] = float(value)
        meta = dict((field_meta or {}).get(key) or (field_meta or {}).get(canonical_key) or {})
        validation = meta.get("validation") or validate_field(key, float(value))
        canonical_meta[canonical_key] = {
            "confidence": float(meta.get("confidence", 0.0)),
            "validation": validation,
            "needs_review": bool(meta.get("needs_review", validation.get("status") == "suspicious")),
            "unit": FIELD_UNITS.get(key, FIELD_UNITS.get(canonical_key, "")),
            "reference_range": meta.get("reference_range"),
            "source_files": list(meta.get("source_files") or source_images),
        }
    visit_key = f"{department}_{date or 'unknown'}"
    fingerprint = content_fingerprint(department, date, canonical_fields) if canonical_fields else None
    return {
        "schema_version": "ocr-canonical-1",
        "department": department,
        "date": date,
        "fields": canonical_fields,
        "domains": condition_domains(canonical_fields),
        "field_meta": canonical_meta,
        "source_images": source_images,
        "raw_text": raw_text,
        "visit_key": visit_key,
        "content_fingerprint": fingerprint,
        "needs_review": (not date) or (not canonical_fields) or any(m.get("needs_review") for m in canonical_meta.values()),
    }


def map_ocr_to_app_record(fields: Dict[str, Any], department: str, date: str | None = None, note: str = "") -> Dict[str, Any]:
    field_map = {
        "egfr": "egfr", "gfr": "egfr", "cr": "cr", "creatinine": "cr", "bun": "bun", "urea": "bun",
        "acr": "acr", "microalbumin": "acr", "a1c": "a1c", "hba1c": "a1c", "iop_od": "iop_od", "iop_os": "iop_os",
        "iop right": "iop_od", "iop left": "iop_os", "cdr_od": "cdr_od", "cdr_os": "cdr_os", "cdr right": "cdr_od",
        "cdr left": "cdr_os", "vf_od": "vf_od", "vf_os": "vf_os", "potassium": "k", "sodium": "na",
        "phosphorus": "p", "uric": "uric", "calcium": "ca", "bicarbonate": "hco3",
        "hb": "hb", "alb": "alb", "fbs": "fbs", "chol": "chol", "tg": "tg", "hdl": "hdl", "ldl": "ldl",
        "uph": "uph", "usg": "usg", "upro": "upro", "rnfl_od": "rnfl_od", "rnfl_os": "rnfl_os",
        "va_od": "va_od", "va_os": "va_os", "dr": "dr",
    }
    items: Dict[str, float] = {}
    for key, value in fields.items():
        normalized_key = field_map.get(key, key)
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            items[normalized_key] = float(value)
    if department == "eye":
        allowed = {"iop_od", "iop_os", "cdr_od", "cdr_os", "vf_od", "vf_os"}
    else:
        allowed = {"egfr", "cr", "bun", "acr", "uric", "k", "na", "p", "ca", "hco3",
                   "hb", "alb", "fbs", "a1c", "chol", "tg", "hdl", "ldl", "upro", "uph", "usg"}
    items = {k: v for k, v in items.items() if k in allowed}
    stable = json.dumps(items, sort_keys=True, ensure_ascii=False)
    digest = hashlib.sha1(stable.encode("utf-8")).hexdigest()[:12]
    return {"id": f"ocr_{department}_{date or 'unknown'}_{digest}", "date": date or "", "dept": department, "note": note, "items": items}


def build_review_output(folder: str | Path, batch_size: int | None = None, progress: bool = False) -> Dict[str, Any]:
    inventory = build_inventory(folder, batch_size=batch_size, progress=progress)
    review: Dict[str, Any] = {
        "folder": inventory["folder"], "records": [],
        "summary": {
            "total_files": inventory["total_files"], "unique_files": inventory.get("unique_files", 0),
            "group_count": len(inventory["groups"]),
            "duplicate_groups": sum(1 for item in inventory["duplicates"] if item["duplicate_count"] > 0),
            "duplicate_visits": len(inventory.get("duplicate_visits", [])),
        },
    }
    for group in inventory["groups"]:
        parsed = normalize_ocr_text(group.get("ocr_text", ""), group.get("department"))
        app_record = map_ocr_to_app_record(parsed.get("fields", {}), parsed.get("department", "med"), group.get("date") or parsed.get("date"), "automated OCR import")
        has_fields = bool(parsed.get("fields"))
        needs_review = group.get("needs_review", False) or not has_fields
        canonical = canonicalize_ocr_result(
            parsed.get("fields", {}), group.get("field_meta", {}), parsed.get("department", "med"),
            group.get("date") or parsed.get("date"), group.get("files", []), group.get("ocr_text", "")
        )
        review["records"].append({
            "group_key": group.get("group_key"), "department": canonical.get("department"), "date": canonical.get("date"),
            "files": group.get("files", []), "parsed_values": parsed.get("fields", {}),
            "field_meta": group.get("field_meta", {}), "field_sources": group.get("field_sources", {}),
            "source_images": group.get("files", []),
            "visit_key": group.get("visit_key"),
            "content_fingerprint": group.get("content_fingerprint"),
            "duplicate_visit": any(d.get("duplicate_group") == group.get("group_key") for d in inventory.get("duplicate_visits", [])),
            "db_record": app_record,
            "review_status": "needs_review" if needs_review else "ready",
            "ocr_text_preview": group.get("ocr_text", "")[:400],
        })
    return review


def map_review_to_db_records(review_data: Dict[str, Any], include_unready: bool = False) -> List[Dict[str, Any]]:
    merged_records: List[Dict[str, Any]] = []
    for record in review_data.get("records", []):
        status = record.get("review_status", "ready")
        if status != "ready" and not include_unready:
            continue
        db_record = record.get("db_record") or {}
        parsed_values = record.get("parsed_values") or {}
        items = db_record.get("items") or map_ocr_to_app_record(parsed_values, record.get("department") or "med", record.get("date"), "automated OCR import")["items"]
        source_files = record.get("files", [])
        merged_records.append({
            "id": db_record.get("id") or map_ocr_to_app_record(items, record.get("department", "med"), record.get("date"))["id"],
            "date": record.get("date") or db_record.get("date") or "", "dept": record.get("department") or db_record.get("dept") or "med",
            "note": db_record.get("note") or "automated OCR import", "items": items, "source_files": source_files,
            "review_status": status, "group_key": record.get("group_key"), "visit_key": record.get("visit_key"),
            "field_meta": record.get("field_meta", {}), "field_sources": record.get("field_sources", {}),
            "source_images": record.get("source_images", source_files), "content_fingerprint": record.get("content_fingerprint"),
        })
    return merged_records


def build_app_db_payload(review_data: Dict[str, Any] | str | Path) -> Dict[str, Any]:
    if isinstance(review_data, (str, Path)):
        with Path(review_data).open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    else:
        data = review_data
    records = map_review_to_db_records(data)
    return {
        "DB": {"records": records}, "LABS": records,
        "GROUPS": [{"group_key": r.get("group_key"), "dept": r.get("dept"), "date": r.get("date"), "records": [r.get("id")]} for r in records],
        "meta": {"import_type": "ocr_screen_capture", "record_count": len(records), "pipeline_version": "2.3-p1-reference-grouping"},
    }


def _write_json(path: str | Path, data: Dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Process OCR image folders for CKD/eye reports.")
    parser.add_argument("--folder", required=True)
    parser.add_argument("--output", default="ocr_inventory.json")
    parser.add_argument("--review-output", default="ocr_review.json")
    parser.add_argument("--merge-output", default="db_merged_records.json")
    parser.add_argument("--app-db-output", default="app_db_payload.json")
    parser.add_argument("--batch-size", type=int, default=20, help="Progress chunk size; does not split medical groups")
    parser.add_argument("--progress", action="store_true")
    args = parser.parse_args()
    inventory = build_inventory(args.folder, batch_size=args.batch_size, progress=args.progress)
    review = build_review_output(args.folder, batch_size=args.batch_size, progress=args.progress)
    merged = map_review_to_db_records(review)
    app_payload = build_app_db_payload(review)
    _write_json(args.output, inventory)
    _write_json(args.review_output, review)
    _write_json(args.merge_output, {"records": merged, "summary": {"ready_records": len(merged), "source_review": args.review_output}})
    _write_json(args.app_db_output, app_payload)
    print(json.dumps({
        "folder": args.folder, "total_files": inventory["total_files"], "unique_files": inventory["unique_files"],
        "groups": len(inventory["groups"]), "duplicate_groups": sum(1 for g in inventory["duplicates"] if g["duplicate_count"] > 0),
        "review_records": len(review["records"]), "ready_records": len(merged), "app_db_records": len(app_payload["DB"]["records"]),
        "pipeline_version": "2.3-p1-reference-grouping",
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
