import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import ocr_pipeline as p

def test_thai_buddhist_date():
    assert p.extract_date('ผลตรวจ วันที่ 25 ส.ค. 2569 เวลา 7:54 น.') == '2026-08-25'
    assert p.extract_date('25 สิงหาคม 2569') == '2026-08-25'

def test_english_buddhist_date():
    assert p.extract_date('25 Aug 2569') == '2026-08-25'

def test_decimal_repair_potassium():
    value, repair = p.repair_ocr_decimal('potassium', 48.0, {'type':'range','low':3.5,'high':5.1})
    assert value == 4.8 and repair and repair['needs_review'] is True

def test_decimal_repair_creatinine():
    value, repair = p.repair_ocr_decimal('cr', 291.0, {'type':'range','low':0.51,'high':0.95})
    assert value == 2.91 and repair and repair['raw_ocr_value'] == 291.0

def test_normalize_marks_repair_for_review():
    out = p.normalize_ocr_text('Potassium 48 mmol/L [3.5 - 5.1]')
    assert out['fields']['potassium'] == 4.8
    assert out['field_meta']['potassium']['needs_review'] is True


def test_screenshot_filename_date_is_not_medical_date():
    assert p.filename_date("Screenshot_2026-10-05-07-30-11-997_th.or.dga.bhr.jpg") is None
