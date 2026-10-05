from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, Iterable, List, Sequence, Tuple


FIELD_PATTERNS = {
    "egfr": [
        re.compile(r"egfr\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"gfr\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "cr": [
        re.compile(r"creatinine\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"cr\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "bun": [
        re.compile(r"bun\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"urea\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "acr": [
        re.compile(r"acr\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"a/c\s*ratio\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"microalbumin\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "a1c": [
        re.compile(r"hba1c\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"a1c\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "iop_od": [
        re.compile(r"iop\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"\b(?:od)\b.*?iop\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "iop_os": [
        re.compile(r"iop\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"\b(?:os)\b.*?iop\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "cdr_od": [
        re.compile(r"cdr\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"c/d\s*(?:od|right)\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "cdr_os": [
        re.compile(r"cdr\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
        re.compile(r"c/d\s*(?:os|left)\s*[:=]?\s*(\d+(?:\.\d+)?)", re.I),
    ],
    "vf_od": [
        re.compile(r"vf\s*(?:od|right).*?(?:md)?\s*[:=]?\s*(-?\d+(?:\.\d+)?)", re.I),
    ],
    "vf_os": [
        re.compile(r"vf\s*(?:os|left).*?(?:md)?\s*[:=]?\s*(-?\d+(?:\.\d+)?)", re.I),
    ],
}


MED_KEYWORDS = (
    "egfr",
    "gfr",
    "creatinine",
    "bun",
    "urea",
    "albumin",
    "microalbumin",
    "a/c ratio",
    "acr",
    "hba1c",
    "a1c",
    "ปัสสาวะ",
    "ไต",
    "kidney",
    "diabetes",
)

EYE_KEYWORDS = (
    "iop",
    "cdr",
    "optic",
    "retina",
    "visual field",
    "glaucoma",
    "eye",
    "oculus",
    "จักษุ",
    "ต้อหิน",
    "สายตา",
    "vision",
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

    patterns = [".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"]
    return sorted(
        [p for p in root.iterdir() if p.is_file() and p.suffix.lower() in patterns],
        key=lambda item: item.name.lower(),
    )


def dedupe_files(paths: Sequence[str | Path], fingerprints: Sequence[str] | None = None) -> List[Dict[str, Any]]:
    seen: Dict[str, Dict[str, Any]] = {}
    candidate_paths = [Path(p) for p in paths]

    for index, path in enumerate(candidate_paths):
        key = fingerprints[index] if fingerprints and index < len(fingerprints) else sha256_file(path)
        entry = seen.setdefault(
            key,
            {"key": key, "items": [], "representative": str(path)},
        )
        entry["items"].append(str(path))

    groups = []
    for item in seen.values():
        if len(item["items"]) > 1:
            item["duplicate_count"] = len(item["items"]) - 1
        else:
            item["duplicate_count"] = 0
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
        if candidate.count("-") > 1:
            continue
        numeric = float(candidate)
        if abs(numeric) >= 10000:
            continue
        if numeric == 0 and "0" not in candidate:
            continue
        values.append(numeric)
    return values


def group_related_files(files: Iterable[str | Path]) -> List[Tuple[str, str, List[str]]]:
    groups: Dict[Tuple[str, str], List[str]] = defaultdict(list)

    for raw_path in files:
        name = str(raw_path).lower()
        date_match = re.search(r"(\d{4}-\d{2}-\d{2})|((?:19|20)\d{2})", name)
        dept = classify_department(name)
        bucket = f"{dept}_{date_match.group(0)}" if date_match else dept
        groups[(bucket, dept)].append(str(raw_path))

    result = []
    for (bucket, dept), items in sorted(groups.items()):
        result.append((bucket, dept, sorted(items)))
    return result


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


def normalize_ocr_text(text: str, department_hint: str | None = None) -> Dict[str, Any]:
    normalized: Dict[str, Any] = {"department": department_hint or classify_department(text or ""), "fields": {}}
    if not text:
        return normalized

    cleaned = text.replace("—", "-").replace("–", "-").replace("/", " ")
    lines = [line.strip() for line in cleaned.splitlines() if line.strip()]
    for key, patterns in FIELD_PATTERNS.items():
        for pattern in patterns:
            match = pattern.search(cleaned)
            if match:
                normalized["fields"][key] = float(match.group(1))
                break

    date_match = re.search(r"(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{2}[-/]\d{2}[-/]\d{4})", cleaned)
    if date_match:
        normalized["date"] = date_match.group(1)

    if not normalized["fields"] and lines:
        combined = " ".join(lines)
        normalized["department"] = classify_department(combined)

    return normalized


def build_inventory(folder: str | Path, batch_size: int | None = None, progress: bool = False) -> Dict[str, Any]:
    images = file_list(folder)
    paths = [str(item) for item in images]
    duplicates = dedupe_files(paths)

    if batch_size and batch_size > 0:
        grouped_paths = [paths[i:i + batch_size] for i in range(0, len(paths), batch_size)]
    else:
        grouped_paths = [paths]

    records: List[Dict[str, Any]] = []
    for batch_index, batch_paths in enumerate(grouped_paths, start=1):
        if progress:
            print(f"[inventory] processing batch {batch_index}/{len(grouped_paths)} ({len(batch_paths)} files)")
        groups = group_related_files(batch_paths)
        for group_key, department, files_in_group in groups:
            text_chunks = []
            for image in files_in_group:
                text = _ocr_image(image)
                text_chunks.append({"file": image, "text": text.strip()})
            joined = "\n".join(chunk["text"] for chunk in text_chunks if chunk["text"])
            normalized = normalize_ocr_text(joined, department)
            resolved_department = normalized["department"]
            records.append(
                {
                    "group_key": group_key,
                    "department": resolved_department,
                    "files": files_in_group,
                    "values": extract_numeric_values(joined),
                    "ocr_text": joined,
                    "parsed_values": normalized["fields"],
                    "date": normalized.get("date"),
                }
            )

    summary = {
        "folder": str(Path(folder)),
        "total_files": len(images),
        "deduplicated_count": len(records),
        "duplicates": duplicates,
        "groups": records,
    }
    return summary


def map_ocr_to_app_record(fields: Dict[str, Any], department: str, date: str | None = None, note: str = "") -> Dict[str, Any]:
    field_map = {
        "egfr": "egfr",
        "gfr": "egfr",
        "cr": "cr",
        "creatinine": "cr",
        "bun": "bun",
        "urea": "bun",
        "acr": "acr",
        "microalbumin": "acr",
        "a1c": "a1c",
        "hba1c": "a1c",
        "iop_od": "iop_od",
        "iop_os": "iop_os",
        "iop right": "iop_od",
        "iop left": "iop_os",
        "cdr_od": "cdr_od",
        "cdr_os": "cdr_os",
        "cdr right": "cdr_od",
        "cdr left": "cdr_os",
        "vf_od": "vf_od",
        "vf_os": "vf_os",
    }

    items: Dict[str, float] = {}
    for key, value in fields.items():
        normalized_key = field_map.get(key, key)
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            items[normalized_key] = float(value)

    if department == "eye":
        eye_keys = ("iop_od", "iop_os", "cdr_od", "cdr_os", "vf_od", "vf_os")
        items = {k: v for k, v in items.items() if k in eye_keys}
    else:
        med_keys = ("egfr", "cr", "bun", "acr", "a1c")
        items = {k: v for k, v in items.items() if k in med_keys}

    return {
        "id": f"ocr_{department}_{date or 'unknown'}_{abs(hash(tuple(sorted(items.items()))))}",
        "date": date or "",
        "dept": department,
        "note": note,
        "items": items,
    }


def build_review_output(folder: str | Path, batch_size: int | None = None, progress: bool = False) -> Dict[str, Any]:
    inventory = build_inventory(folder, batch_size=batch_size, progress=progress)
    review: Dict[str, Any] = {
        "folder": inventory["folder"],
        "records": [],
        "summary": {
            "total_files": inventory["total_files"],
            "group_count": len(inventory["groups"]),
            "duplicate_groups": sum(1 for item in inventory["duplicates"] if item["duplicate_count"] > 0),
        },
    }

    for index, group in enumerate(inventory["groups"], start=1):
        if progress:
            print(f"[review] mapping group {index}/{len(inventory['groups'])} ({group.get('department')})")
        parsed = normalize_ocr_text(group.get("ocr_text", ""), group.get("department"))
        app_record = map_ocr_to_app_record(parsed.get("fields", {}), parsed.get("department", "med"), parsed.get("date"), "automated OCR import")
        review["records"].append(
            {
                "group_key": group.get("group_key"),
                "department": parsed.get("department"),
                "date": parsed.get("date"),
                "files": group.get("files", []),
                "parsed_values": parsed.get("fields", {}),
                "db_record": app_record,
                "review_status": "ready" if parsed.get("fields") else "needs_review",
                "ocr_text_preview": (group.get("ocr_text", "")[:400] or "")
            }
        )

    return review


def map_review_to_db_records(review_data: Dict[str, Any], include_unready: bool = False) -> List[Dict[str, Any]]:
    merged_records: List[Dict[str, Any]] = []
    for record in review_data.get("records", []):
        status = record.get("review_status", "ready")
        if status != "ready" and not include_unready:
            continue

        db_record = record.get("db_record") or {}
        parsed_values = record.get("parsed_values") or {}
        if db_record and db_record.get("items"):
            items = db_record.get("items") or {}
        else:
            items = map_ocr_to_app_record(parsed_values, record.get("department") or "med", record.get("date"), "automated OCR import")["items"]

        source_files = record.get("files", [])
        mapped = {
            "id": db_record.get("id") or f"ocr_{record.get('department', 'med')}_{record.get('date') or 'unknown'}_{abs(hash(tuple(source_files)))}",
            "date": record.get("date") or db_record.get("date") or "",
            "dept": record.get("department") or db_record.get("dept") or "med",
            "note": db_record.get("note") or "automated OCR import",
            "items": items,
            "source_files": source_files,
            "review_status": status,
            "group_key": record.get("group_key"),
        }
        merged_records.append(mapped)
    return merged_records


def build_app_db_payload(review_data: Dict[str, Any] | str | Path) -> Dict[str, Any]:
    if isinstance(review_data, (str, Path)):
        with Path(review_data).open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    else:
        data = review_data

    records = map_review_to_db_records(data)
    return {
        "DB": {"records": records},
        "LABS": records,
        "GROUPS": [
            {
                "group_key": record.get("group_key"),
                "dept": record.get("dept"),
                "date": record.get("date"),
                "records": [record.get("id")],
            }
            for record in records
        ],
        "meta": {
            "import_type": "ocr_screen_capture",
            "record_count": len(records),
        },
    }


def _write_json(path: str | Path, data: Dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Process OCR image folders for CKD/eye reports.")
    parser.add_argument("--folder", required=True, help="Folder containing screen-capture images")
    parser.add_argument("--output", default="ocr_inventory.json", help="JSON output path")
    parser.add_argument("--review-output", default="ocr_review.json", help="JSON output path for normalized review queue")
    parser.add_argument("--merge-output", default="db_merged_records.json", help="JSON output path for app-compatible DB merge records")
    parser.add_argument("--app-db-output", default="app_db_payload.json", help="JSON output path for the app DB structure")
    parser.add_argument("--batch-size", type=int, default=20, help="Process images in batches to avoid long single-run hangs")
    parser.add_argument("--progress", action="store_true", help="Emit per-batch progress while OCR is running")
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
        "folder": args.folder,
        "total_files": inventory["total_files"],
        "groups": len(inventory["groups"]),
        "duplicates": sum(1 for g in inventory["duplicates"] if g["duplicate_count"] > 0),
        "review_records": len(review["records"]),
        "db_merge_records": len(merged),
        "app_db_records": len(app_payload["DB"]["records"]),
        "batch_size": args.batch_size,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
