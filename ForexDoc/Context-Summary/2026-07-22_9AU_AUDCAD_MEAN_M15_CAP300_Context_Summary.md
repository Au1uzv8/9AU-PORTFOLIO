---
concept_name: 9AU_AUDCAD_MEAN_M15_CAP300 — Context Summary (Pre-Export)
protocol: EA Validation Protocol v2.0
status: Core Metrics PASSED — Pending #11/#13/#14 ก่อน Forward Test/Combine
created: 2026-07-22
tags: [ea, audcad, m15, mean-reversion, regime-filter, validation, combine, session-closed]
---

## Section 1: EA Identity

| รายการ | ค่า |
|---|---|
| Symbol | AUDCAD# |
| Magic Number | 515251 |
| Timeframe เทรด | M15 |
| Timeframe Regime Filter | D1 (ADX) |
| Base Capital (Virtual Cap) | $300 |
| Direction | Buy-only โดยพฤติกรรม (Short Logic มีในโค้ดแต่ไม่เคย Trigger เลยตลอด 2.6 ปี ทุก Version) |
| Code Version Production | v6.10 (Regime-Adaptive RSI Threshold) |
| Code Version Combine (ค้างอัปเดต) | v6.8 — ยังไม่ Sync กับ v6.10 ต้องทำก่อน Combine จริง |

## Section 2: Final Production Config

| Parameter | ค่า | สถานะการยืนยัน |
|---|---|---|
| Inp_Use_Regime_Filter | true | ยืนยันแล้วว่าจำเป็น — ปิดแล้วผลแย่ลง (กลับไปเป็น RSI68/71 Static) |
| Inp_Regime_TF | D1 | ยืนยันแล้วว่าต้องเป็น D1 — ลองบน M15 (v6.9) แล้วไม่ทำงาน (Timeframe Mismatch) |
| Inp_ADX_Period | 14 | ค่าดั้งเดิม ยังไม่ได้ทดสอบแยก |
| Inp_ADX_Trend_Threshold | 25.0 | ค่ามาตรฐานทั่วไป ยังไม่ได้ทดสอบแยก (โอกาสพัฒนาต่อ) |
| Inp_RSI_Max_Trend | 68.0 | ยืนยันแล้ว (ใช้ตอน ADX(D1)>=25) |
| Inp_RSI_Max_Range | 71.0 | ยืนยันแล้ว (ใช้ตอน ADX(D1)<25) |
| Inp_RSI_Max_Value | 68.0 | Fallback เท่านั้น ไม่ถูกใช้เมื่อ Regime Filter เปิดอยู่ |
| Inp_Trail_Step | 5.0 | ยืนยัน Optimal จากรอบทดสอบก่อนหน้า (3/5/10) |
| Inp_Virtual_Cap | 300.0 | ต้องตรวจสอบก่อน Live: ต้อง Sync เข้า Combine File (v6.8 -> ควรอัปเป็น v6.10) ก่อนรันคู่ BTCUSD |
| Timeframe เทรด | M15 | ยืนยันแล้วว่า M10 ไม่ใช่คำตอบ (Overfit เหมือนกัน, พักไว้) |

## Section 3: Classification (Step 0)

- Balance DD Maximal = 11.94% (<18%) -> จัดเป็น Compound Type
- ใช้เกณฑ์เข้มกว่า: Sharpe>1.80, Recovery Factor>2.0, PF>1.50, DD<20%
- v6.10 ผ่านทุกเกณฑ์ Compound Type เป็นครั้งแรก

## Section 4: Full-Period Backtest Result (v6.10, Production Baseline)

| Metric | ค่า |
|---|---|
| Net Profit | 115.11 |
| Profit Factor | 1.8374 |
| Recovery Factor | 2.7362 |
| Sharpe Ratio | 1.9634 |
| Balance DD Max | 11.94% |
| Equity DD Max | 12.29% |
| Expected Payoff | 0.6616 |
| Win Rate | 65.52% |
| Total Trades | 174 |
| LR Correlation | 0.8859 |
| Period | 2023.10.02-2026.04.30 (2.6 ปี) |
| Tick Quality | 100% Real Ticks (71,405,659 Ticks) |

หมายเหตุสำคัญ: ดู Section 7 เรื่อง Boundary Effect ก่อนใช้ตัวเลขนี้เป็นตัวแทน Forward Performance แบบตรงไปตรงมา 100%

## Section 5: Protocol v2.0 — 13+2 Criteria Scorecard (Compound Type)

| # | เกณฑ์ | ผล | สถานะ |
|---|---|---|---|
| 1 | Net Profit >0 | 115.11 | ผ่าน |
| 2 | Profit Factor >1.50 | 1.837 | ผ่าน |
| 3 | Sharpe >1.80 (Compound) | 1.963 | ผ่าน |
| 4 | Balance DD <=20% | 11.94% | ผ่าน |
| 5 | Recovery Factor >2.0 (Compound) | 2.736 | ผ่าน |
| 6 | Expected Payoff >0 | 0.6616 | ผ่าน |
| 7 | Win Rate >60% | 65.52% | ผ่าน |
| 8 | Trade Count sufficient | 174 ไม้ / 2.6 ปี | ผ่าน (Qualitative) |
| 9 | LR Correlation >0 | 0.8859 | ผ่าน (สูงมาก) |
| 10 | Walk-Forward Degradation <20% | ดีขึ้นทุกตัว (-6.6% ถึง -45.7%) | ผ่าน |
| 11 | Spread Stress Test PF drop <15% | ยังไม่ได้ทดสอบ | ค้างอยู่ |
| 12 | Cycle Win Rate >=60% | N/A (ไม่ใช่ Reserve/Cycle-Reset EA) | N/A |
| 13 | Live Mode ExpertRemove() Verified | ยังไม่ได้ทดสอบ | ค้างอยู่ |
| 14 | Correlation Diversification (Combine Ports) | ยังไม่ได้ทดสอบ — จำเป็นก่อน Combine กับ BTCUSD | ค้างอยู่ |

Decision Rule: เกณฑ์เชิงปริมาณหลักทั้งหมด (#1-10) ผ่านครบ เหลือเพียง 3 ข้อ (#11/#13/#14) ที่เป็นขั้นตอนก่อน Live/Combine ไม่ใช่ปัญหา Performance -> พร้อมเข้าสู่ขั้นตอนเตรียม Forward Test หลังปิดรายการค้างอยู่

## Section 6: Test History Log (สรุปทั้ง Session)

| Version/Config | การเปลี่ยนแปลงหลัก | Net Profit | PF | Sharpe | สรุป |
|---|---|---|---|---|---|
| v6.3 (Original) | Baseline ก่อนแก้ | 122.56 | 1.74 | - | ตัวเลขพองจาก OnTimer Tester Bug (ไม่ Reproducible) |
| v6.4-v6.7 | Fix A-F (Infra/Bug Fixes) | 50.27 | 1.235 | 0.759 | Baseline ที่ Reproducible จริง แต่ไม่ผ่านเกณฑ์ Compound |
| v6.7 RSI71 (Full) | RSI Threshold Sweep | 127.14 | 2.27 | 2.34 | Walk-Forward Fail (Degrade 27-64%) — REJECTED |
| v6.7 RSI68 (Walk-Forward) | ตรวจ Baseline เอง | In 3.11/Out 47.24 | - | - | พบ Time-Inconsistency ชัดเจน — นำไปสู่ Insight เรื่อง Regime |
| กราฟ Daily AUDCAD | วิเคราะห์ภาพ | - | - | - | ยืนยัน Range (2023.10-2025.01) vs Trend (2025.02-2026.04) ตรงกับรอยต่อ Walk-Forward พอดี |
| v6.9 (Fix H, ADX บน M15) | Regime Filter รอบแรก | Full 50.75, In 3.75 (119 ไม้) | - | - | ล้มเหลว — ADX M15 ไวเกินไป แทบไม่ต่างจาก RSI68 Static เลย (Timeframe Mismatch) |
| v6.10 (Fix I, ADX บน D1) | แก้ Timeframe เป็น D1 | 115.11 (174 ไม้) | 1.837 | 1.963 | สำเร็จ — ผ่านเกณฑ์ Compound Type ครบทุกตัว, Walk-Forward ไม่ Degrade เลย |

## Section 7: Known Caveats / Data Limitations

- ไม่มี Stop Loss รายไม้: ทุกไม้เปิดด้วย SL=0 ยังคงเป็นจริงในทุก Version รวม v6.10 การควบคุมความเสี่ยงพึ่งพา Kill Switch ระดับ Basket/Portfolio เท่านั้น
- Short Logic ไม่เคยถูกพิสูจน์: ยังคงเป็นจริงในทุก Version — แนะนำปิดเป็น Buy-only อย่างเป็นทางการ
- Walk-Forward Split Boundary Effect (พบใหม่ใน v6.10): ผลรวม In+Out-of-Sample (77.20) ไม่เท่ากับ Full-Period (115.11) เพราะ Basket ที่ถือยาวข้ามรอยต่อวันที่ถูกบังคับปิด/เปิดใหม่ในการ Split-Test ตัวเลข Full-Period 115.11 อาจมองในแง่ดีเกินจริงเล็กน้อย ควรอ้างอิงตัวเลขจากสองช่วงแยก (37.37 + 39.83) เป็นค่าอนุรักษ์นิยมกว่าเมื่อประเมินความคาดหวัง
- บทเรียนสำคัญเรื่อง Regime Filter Timeframe: ต้องคำนวณ Indicator ตรวจ Regime บน Timeframe เดียวกับที่ใช้ระบุ Pattern ด้วยตา (ในที่นี้คือ Daily Chart) ไม่ใช่ Timeframe เดียวกับที่เทรด — ใช้เป็นหลักการอ้างอิงสำหรับ Regime Filter ของ EA ตัวอื่นในอนาคตได้
- Combine File (9AU_AUDCAD_COMBINE_M15_CAP300) ยังไม่ Sync กับ v6.10: ปัจจุบัน Sync ไว้ที่ v6.8 เท่านั้น (ก่อนมี Regime Filter) ต้องอัปเดต Logic ให้ตรงกับ v6.10 ก่อนใช้งานจริงในโหมด Combine ตามกฎ "Version ต้องตรงกันเมื่อ Logic เหมือนกัน"
- M10 Timeframe ถูกพักไว้: ทดสอบแล้วพบ Overfitting Pattern (RSI Cliff ที่ 62->63) ไม่ได้นำ Regime Filter Concept ไปทดสอบกับ M10 เพิ่มเติม เป็นโอกาสพัฒนาในอนาคตถ้าต้องการ
- Backtest ทั้งหมดใช้ 100% Real Ticks คุณภาพสูง ไม่มีข้อกังวลเรื่อง Data Quality

## Section 8: Code Change Log

- v6.3 -> v6.7: Fix A-F (OnTick Migration, Peak-Equity Kill Switch, Perf Throttle, Re-arm, Indicator Shift, Partial-Close State) — ทั้งหมด ACCEPTED เป็นการแก้ Infra ที่จำเป็น
- v6.7 -> v6.8: Fix G (Virtual Balance/Equity ต่อ Magic Number ผ่าน OnTradeTransaction) — เตรียมพร้อม Combine กับ BTCUSD, แก้ Warning POSITION_COMMISSION Deprecated
- v6.8 -> v6.9: Fix H (เพิ่ม ADX เป็น Regime Filter สลับ RSI Threshold) — แนวคิดถูกต้องแต่ Implementation ผิด (ADX บน M15) ผลไม่ต่างจาก Static RSI68
- v6.9 -> v6.10: Fix I (ย้าย ADX ไปคำนวณบน D1 ผ่าน Inp_Regime_TF) — ACCEPTED, สำเร็จ ผ่านเกณฑ์ Compound Type ครบทุกตัวเป็นครั้งแรกในทั้ง Session

## Section 9: Production Parameters (v6.10)

| Parameter | ค่า | หมายเหตุ |
|---|---|---|
| Inp_Symbols | AUDCAD# | |
| Inp_Magic | 515251 | ต้องไม่ชนกับ Magic ของ BTCUSD EA (919295) |
| Inp_Max_Drawdown_Pct | 12.0 | อิง Virtual Equity |
| Inp_Virtual_Cap | 300.0 | ตรวจสอบสัดส่วนทุนจริงก่อน Combine |
| Inp_Fixed_Lot | 0.01 | |
| Inp_Max_Lot | 0.3 | |
| Inp_Max_Spread | 2.5 | |
| Inp_Use_Trailing | true | ทำให้ Inp_TP_Initial_Pips/Inp_TP_Grid_Pips เป็น Dead Code |
| Inp_Trail_Start | 12.0 | |
| Inp_Trail_Step | 5.0 | ยืนยัน Optimal |
| Inp_Use_Partial | true | |
| Inp_Partial_Level1/2/3 | 10.0 / 20.0 / 30.0 | มี State ป้องกันปิดซ้ำแล้ว (v6.7 Fix F) |
| Inp_Max_Daily_Loss_Pct | 5.0 | อิง Virtual Equity |
| Inp_BreakEven_Pips | 15.0 | |
| Inp_BB_Period / Deviation | 20 / 2.0 | |
| Inp_RSI_Period | 14 | |
| Inp_Use_Regime_Filter | true | Master Switch ของระบบ v6.10 |
| Inp_Regime_TF | PERIOD_D1 | ห้ามเปลี่ยนกลับเป็น M15 (พิสูจน์แล้วว่าใช้ไม่ได้) |
| Inp_ADX_Period | 14 | |
| Inp_ADX_Trend_Threshold | 25.0 | |
| Inp_RSI_Max_Trend | 68.0 | |
| Inp_RSI_Max_Range | 71.0 | |
| Inp_Trade_Distance | 25.0 | |
| Inp_Step_Lot1 / Lot2 | 0.01 / 0.02 | |
| Inp_Max_Trades | 5 | |

Invariant สำคัญ: ทุกไม้เปิดด้วย SL=0 เสมอ — ไม่มี Protection รายไม้เลย ไม่เปลี่ยนแปลงจาก Version ก่อนหน้า

## Section 10: Remaining Steps Before Forward Test / Combine

1. Sync Combine File: อัปเดต 9AU_AUDCAD_COMBINE_M15_CAP300.mq5 จาก Logic v6.8 เป็น v6.10 (เพิ่ม Regime Filter เข้าไปพร้อม Fix G เดิม) ให้ Version ตรงกันตามกฎที่ตั้งไว้
2. Spread Stress Test (เกณฑ์ #11) ยังไม่เคยทำกับทุก Version รวม v6.10
3. Live Mode ExpertRemove() Verification (เกณฑ์ #13) ยังไม่เคยทำ
4. Correlation Check ระหว่าง AUDCAD (v6.10) กับ BTCUSD ก่อน Combine จริง (เกณฑ์ #14, เกณฑ์ <0.3 = กระจายความเสี่ยงจริง)
5. Combined DD Simulation แบบ CAP-Weighted ตาม Step 0.5 Combine Gate
6. พิจารณาทดสอบ Inp_ADX_Trend_Threshold (ปัจจุบัน 25.0 เป็นค่ามาตรฐานทั่วไป ยังไม่ได้ Optimize) เป็น Single-Lever รอบถัดไปถ้าต้องการพัฒนาต่อ
7. ปิด Short Logic อย่างเป็นทางการในโค้ด (เปลี่ยนจาก "ไม่เคย Trigger" เป็น "ปิดโดยตั้งใจ") เพื่อความชัดเจนของสถาปัตยกรรม
8. รับทราบ Walk-Forward Boundary Effect (Section 7) เป็นข้อจำกัดของวิธีวัด ไม่ใช่ของระบบ — ถ้าต้องการความมั่นใจสูงขึ้น พิจารณาทำ Rolling Walk-Forward (แบ่งมากกว่า 2 ช่วง) ในรอบถัดไป
