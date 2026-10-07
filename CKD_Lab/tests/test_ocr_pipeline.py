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
    canonicalize_ocr_result,
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


def test_extract_date_does_not_use_parent_folder():
    from ocr_pipeline import extract_date, filename_date
    assert extract_date("Collection date: 2026-08-25") == "2026-08-25"
    assert filename_date("2026-10-05_ผลเลือดแม่/Screenshot_123.jpg") is None


def test_group_related_files_uses_ocr_date_not_parent_folder():
    from ocr_pipeline import group_related_files
    files = [
        "/tmp/2026-10-05_ผลเลือดแม่/Screenshot_a.jpg",
        "/tmp/2026-10-05_ผลเลือดแม่/Screenshot_b.jpg",
        "/tmp/2026-10-05_ผลเลือดแม่/Screenshot_c.jpg",
    ]
    texts = {
        files[0]: "Date 2026-08-25 eGFR 14.87",
        files[1]: "Date 2026-08-25 Creatinine 2.91",
        files[2]: "Date 2026-05-12 eGFR 18.31",
    }
    groups = group_related_files(files, texts)
    assert len(groups) == 2
    assert any(g[0] == "med_2026-08-25" and len(g[2]) == 2 for g in groups)
    assert any(g[0] == "med_2026-05-12" and len(g[2]) == 1 for g in groups)


def test_validate_and_confidence_flag_suspicious_value():
    from ocr_pipeline import normalize_ocr_text
    result = normalize_ocr_text("Creatinine 99", "med")
    assert result["fields"]["cr"] == 99.0
    assert result["field_meta"]["cr"]["validation"]["status"] == "suspicious"
    assert result["field_meta"]["cr"]["needs_review"] is True


def test_normalize_additional_core_labs():
    from ocr_pipeline import normalize_ocr_text
    result = normalize_ocr_text("Potassium 4.80 Sodium 138 Phosphorus 4.30", "med")
    assert result["fields"] == {"potassium": 4.8, "sodium": 138.0, "phosphorus": 4.3}


def test_pipeline_id_is_stable():
    from ocr_pipeline import map_ocr_to_app_record
    a = map_ocr_to_app_record({"egfr": 14.87, "cr": 2.91}, "med", "2026-08-25")
    b = map_ocr_to_app_record({"cr": 2.91, "egfr": 14.87}, "med", "2026-08-25")
    assert a["id"] == b["id"]


def test_content_fingerprint_and_duplicate_groups():
    from ocr_pipeline import content_fingerprint, detect_duplicate_groups
    a = {"group_key":"med_2026-08-25_a","department":"med","date":"2026-08-25","parsed_values":{"cr":2.91,"egfr":14.87},"content_fingerprint":content_fingerprint("med","2026-08-25",{"cr":2.91,"egfr":14.87})}
    b = {"group_key":"med_2026-08-25_b","department":"med","date":"2026-08-25","parsed_values":{"egfr":14.87,"cr":2.91},"content_fingerprint":content_fingerprint("med","2026-08-25",{"egfr":14.87,"cr":2.91})}
    duplicates = detect_duplicate_groups([a,b])
    assert len(duplicates) == 1
    assert duplicates[0]["original_group"] == a["group_key"]


def test_field_sources_are_attached_to_group_meta():
    from ocr_pipeline import field_sources_from_chunks
    sources = field_sources_from_chunks([
        {"file":"a.jpg","parsed_values":{"cr":2.91,"egfr":14.87}},
        {"file":"b.jpg","parsed_values":{"cr":2.91}},
    ])
    assert sources["cr"] == ["a.jpg", "b.jpg"]
    assert sources["egfr"] == ["a.jpg"]


def test_normalize_extended_lab_panel():
    from ocr_pipeline import normalize_ocr_text
    text = ("Uric acid 6.2 Calcium 9.1 Bicarbonate 24 Hemoglobin 11.8 "
            "Albumin 3.9 FBS 126 Cholesterol 188 Triglyceride 142 HDL 48 LDL 92 "
            "Urine pH 6.0 Specific Gravity 1.015")
    result = normalize_ocr_text(text, "med")
    assert result["fields"]["uric"] == 6.2
    assert result["fields"]["calcium"] == 9.1
    assert result["fields"]["bicarbonate"] == 24.0
    assert result["fields"]["hb"] == 11.8
    assert result["fields"]["alb"] == 3.9
    assert result["fields"]["fbs"] == 126.0
    assert result["fields"]["chol"] == 188.0
    assert result["fields"]["tg"] == 142.0
    assert result["fields"]["hdl"] == 48.0
    assert result["fields"]["ldl"] == 92.0
    assert result["fields"]["uph"] == 6.0
    assert result["fields"]["usg"] == 1.015


def test_normalize_extended_eye_panel():
    from ocr_pipeline import normalize_ocr_text
    result = normalize_ocr_text("RNFL OD 82 RNFL OS 79 VA OD 0.8 VA OS 0.7 DR Stage 1", "eye")
    assert result["fields"]["rnfl_od"] == 82.0
    assert result["fields"]["rnfl_os"] == 79.0
    assert result["fields"]["va_od"] == 0.8
    assert result["fields"]["va_os"] == 0.7
    assert result["fields"]["dr"] == 1.0


def test_canonical_ocr_schema_uses_app_field_keys():
    from ocr_pipeline import canonicalize_ocr_result
    result = canonicalize_ocr_result(
        {"potassium": 4.8, "sodium": 138, "phosphorus": 4.3},
        {"potassium": {"confidence": 0.9, "validation": {"status": "plausible"}, "source_files": ["a.jpg"]}},
        "med", "2026-08-25", ["a.jpg"], "Potassium 4.8 Sodium 138 Phosphorus 4.3"
    )
    assert result["schema_version"] == "ocr-canonical-1"
    assert result["fields"] == {"k": 4.8, "na": 138.0, "p": 4.3}
    assert result["field_meta"]["k"]["unit"] == "mmol/L"
    assert result["field_meta"]["k"]["source_files"] == ["a.jpg"]
    assert result["visit_key"] == "med_2026-08-25"


def test_app_record_preserves_html_lab_keys():
    from ocr_pipeline import map_ocr_to_app_record
    record = map_ocr_to_app_record({"potassium": 4.8, "sodium": 138, "phosphorus": 4.3}, "med", "2026-08-25")
    assert record["items"] == {"k": 4.8, "na": 138.0, "p": 4.3}



def test_extract_source_reference_range():
    from ocr_pipeline import normalize_ocr_text
    result = normalize_ocr_text("Potassium 4.80 mmol/L Reference range 3.5-5.1", "med")
    assert result["field_meta"]["potassium"]["reference_range"] == {"type": "range", "low": 3.5, "high": 5.1, "source": "ocr"}


def test_group_same_date_splits_multiple_visit_identifiers():
    from ocr_pipeline import group_related_files
    files = ["a.jpg", "b.jpg", "c.jpg"]
    texts = {
        "a.jpg": "Date 2026-08-25 Accession No ABC123 eGFR 14.87",
        "b.jpg": "Date 2026-08-25 Accession No ABC123 Creatinine 2.91",
        "c.jpg": "Date 2026-08-25 Accession No XYZ789 Creatinine 2.50",
    }
    groups = group_related_files(files, texts)
    assert len(groups) == 2
    assert any(g[0] == "med_2026-08-25_ABC123" and len(g[2]) == 2 for g in groups)
    assert any(g[0] == "med_2026-08-25_XYZ789" and len(g[2]) == 1 for g in groups)


def test_canonical_eye_domains():
    result = canonicalize_ocr_result(
        {"iop_od": 17.0, "va_od": 0.5, "dr": 0},
        department="eye", date="2026-01-28"
    )
    assert result["domains"] == ["diabetic_retina", "glaucoma", "vision"]
