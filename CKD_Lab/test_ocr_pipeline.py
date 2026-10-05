import json
from pathlib import Path

from ocr_pipeline import (
    build_app_db_payload,
    classify_department,
    dedupe_files,
    extract_numeric_values,
    group_related_files,
    map_ocr_to_app_record,
    map_review_to_db_records,
    normalize_ocr_text,
)


def test_classify_department_med():
    text = "eGFR 18.31 Creatinine 2.45 BUN 55"
    assert classify_department(text) == "med"


def test_classify_department_eye():
    text = "IOP OD 22.0 IOP OS 20.0 CDR OD 0.65"
    assert classify_department(text) == "eye"


def test_dedupe_files_reuses_unique_entries():
    files = [
        Path("a.jpg"),
        Path("b.jpg"),
        Path("a_copy.jpg"),
    ]
    groups = dedupe_files(files, ["a", "b", "a"])  # string payload intentionally simple
    assert len(groups) == 2
    assert any(len(g["items"]) >= 1 for g in groups)


def test_extract_numeric_values():
    text = "eGFR=18.31, Creatinine=2.45, IOP OD=22.0"
    values = extract_numeric_values(text)
    assert 18.31 in values
    assert 2.45 in values
    assert 22.0 in values


def test_group_related_files():
    files = [
        "2026-05-12_med_lab_1.jpg",
        "2026-05-12_med_lab_2.jpg",
        "2026-01-28_eye_1.jpg",
        "2026-01-28_eye_2.jpg",
    ]
    groups = group_related_files(files)
    assert len(groups) >= 2
    assert any("med" in str(g[0]).lower() for g in groups)


def test_normalize_ocr_text_med_and_eye():
    med_text = "eGFR 18.31 Creatinine 2.45 ACR 443"
    med_result = normalize_ocr_text(med_text, "med")
    assert med_result["fields"].get("egfr") == 18.31
    assert med_result["fields"].get("cr") == 2.45
    assert med_result["fields"].get("acr") == 443

    eye_text = "IOP OD 22.0 IOP OS 20.0 CDR OD 0.65"
    eye_result = normalize_ocr_text(eye_text, "eye")
    assert eye_result["department"] == "eye"
    assert eye_result["fields"].get("iop_od") == 22.0
    assert eye_result["fields"].get("cdr_od") == 0.65


def test_map_ocr_to_app_record():
    med_fields = {"egfr": 18.31, "cr": 2.45, "acr": 443}
    record = map_ocr_to_app_record(med_fields, "med", "2026-05-12", "ocr import")
    assert record["date"] == "2026-05-12"
    assert record["dept"] == "med"
    assert record["items"]["egfr"] == 18.31
    assert record["items"]["cr"] == 2.45
    assert record["items"]["acr"] == 443

    eye_fields = {"iop_od": 22.0, "iop_os": 20.0, "cdr_od": 0.65}
    eye_record = map_ocr_to_app_record(eye_fields, "eye", "2026-01-28", "ocr import")
    assert eye_record["dept"] == "eye"
    assert eye_record["items"]["iop_od"] == 22.0
    assert eye_record["items"]["cdr_od"] == 0.65


def test_map_review_to_db_records():
    review = {
        "records": [
            {
                "group_key": "med_2026-05-12",
                "department": "med",
                "date": "2026-05-12",
                "files": ["a.jpg", "b.jpg"],
                "review_status": "ready",
                "parsed_values": {"egfr": 18.31, "cr": 2.45},
                "db_record": {
                    "id": "ocr_med_2026-05-12_1",
                    "date": "2026-05-12",
                    "dept": "med",
                    "note": "automated OCR import",
                    "items": {"egfr": 18.31, "cr": 2.45},
                },
            }
        ]
    }
    merged = map_review_to_db_records(review)
    assert len(merged) == 1
    assert merged[0]["date"] == "2026-05-12"
    assert merged[0]["dept"] == "med"
    assert merged[0]["items"]["egfr"] == 18.31
    assert merged[0]["source_files"] == ["a.jpg", "b.jpg"]


def test_map_review_to_db_records_from_parsed_values():
    review = {
        "records": [
            {
                "group_key": "med_2026-05-12",
                "department": "med",
                "date": "2026-05-12",
                "files": ["a.jpg"],
                "review_status": "ready",
                "parsed_values": {"egfr": 18.31, "cr": 2.45},
            }
        ]
    }
    merged = map_review_to_db_records(review)
    assert len(merged) == 1
    assert merged[0]["items"]["egfr"] == 18.31
    assert merged[0]["items"]["cr"] == 2.45


def test_build_app_db_payload():
    review = {
        "records": [
            {
                "group_key": "med_2026-05-12",
                "department": "med",
                "date": "2026-05-12",
                "files": ["a.jpg"],
                "review_status": "ready",
                "parsed_values": {"egfr": 18.31, "cr": 2.45},
            }
        ]
    }
    payload = build_app_db_payload(review)
    assert payload["DB"]["records"][0]["dept"] == "med"
    assert payload["LABS"][0]["items"]["egfr"] == 18.31
    assert payload["GROUPS"][0]["group_key"] == "med_2026-05-12"
