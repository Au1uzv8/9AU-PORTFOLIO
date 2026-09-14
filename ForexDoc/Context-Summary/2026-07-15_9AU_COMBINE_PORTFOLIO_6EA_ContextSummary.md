---
concept_name: 9AU Combine Portfolio (6 EA) — Virtual Equity Fix + Compound Selective + SoftBrake — Context Summary
protocol: EA Validation Protocol v2.0 (Money & Risk Management layer)
status: Code พร้อม Deploy ครบ 6 EA — รอ Backtest 3PAIRS v2.7 + Forward Test Demo
created: 2026-07-27
tags: [combine, portfolio, virtual-equity, compound, softbrake, kill-switch, money-management]
---

## Section 1: Project Identity

| Attribute | Value |
|---|---|
| ขอบเขตงาน | Combine Portfolio 3 พอร์ต รวม 6 EA รันร่วมบัญชีเดียวกัน |
| เป้าหมาย | (1) ตรวจ/แก้ Money & Risk Management conflict ระหว่าง EA ในพอร์ตเดียวกัน (2) เพิ่ม Auto Dynamic Lot (Compound) 1.5x ให้ครบทุกตัวตามแผนใหม่ |
| Broker | XM Global (# suffix) |
| Consultant | James |

### พอร์ตและ Magic Number (ยืนยันแล้ว — แก้จุดที่เคยบันทึกผิดในความจำ)

| พอร์ต | EA 1 | Magic | EA 2 | Magic |
|---|---|---|---|---|
| Port 1 | NASDAQ100 (US100Cash#, M5) | 919294 | GBPJPY (M5) | **515254** |
| Port 2 | OIL-WTI (OILCash#, M5) | 919293 | USDJPY (M5) | **515253** |
| Port 3 | 3PAIRS (AUDCAD#/NZDCAD#/AUDNZD#, M15) | 515252 | AUDCAD (M15) | 515251 |

หมายเหตุ: ก่อนหน้านี้บันทึกผิดว่า GBPJPY=515253 (implied) — ที่ถูกต้องคือ USDJPY=515253, GBPJPY=515254 (แก้ไขในความจำแล้ว)

---

## Section 2: ปัญหาที่พบและแก้ไข — Virtual Equity Cross-Contamination (Port 1)

### อาการ
NASDAQ100 Combine v1.0 คำนวณ Virtual Equity/Balance จาก `ACCOUNT_EQUITY`/`ACCOUNT_BALANCE` ทั้งบัญชี (diff จาก Cycle Start) ไม่ได้กรองด้วย Magic Number ของตัวเอง ต่างจาก GBPJPY/OIL/USDJPY/3PAIRS/AUDCAD ที่ใช้ Pattern per-Magic ที่ถูกต้อง (`ScanInitialRealizedProfit()` + `OnTradeTransaction()` กรอง `DEAL_MAGIC`/`POSITION_MAGIC` เฉพาะตัวเอง)

### ผลกระทบ
เมื่อรันคู่กับ GBPJPY จริง floating P/L ของ GBPJPY จะไหลปนเข้าสูตร DD ของ NASDAQ100 โดยตรง ทำให้ Soft Stop/Kill Switch/Daily Loss/House Money ของ NASDAQ100 ทำงานผิดจังหวะ และผล Backtest เดี่ยวจะไม่ตรงกับพฤติกรรมจริงเมื่อ Combine

### การแก้ไข
Refactor `GetVirtualEquity()`/`GetVirtualBalance()` ของ NASDAQ100 ให้ใช้ Pattern เดียวกับอีก 5 ตัว → **v1.1**

---

## Section 3: Feature ที่เพิ่ม — Compound Selective (Auto Dynamic Lot 1.5x) + SoftBrake

### เหตุผล
ก่อนหน้านี้มีแค่ 3 ใน 6 EA ที่มี Logic Compound (NDAQ100, OIL-WTI มี Compound เดิมอยู่แล้ว, 3PAIRS มีโครงสร้างพร้อมแต่ปิดไว้) ส่วน GBPJPY/USDJPY/AUDCAD เป็น Fixed Lot ถาวรไม่ว่า Balance จะโตแค่ไหน — ไม่ตรงกับแผนระยะยาวที่ต้องการให้ทุก EA Auto Dynamic Lot เมื่อ Balance ถึง 1.5x

### Concept (sync กับ OIL-WTI/GOLD ทุกจุด)

```
Activate:     Virtual Balance >= BaseBalance x 1.5   (ครั้งเดียว ถาวร ไม่ Deactivate กลับ)
Lot Formula:  lot = BaseLot x (Virtual Equity / BaseBalance)  — ปัดตาม Volume Step ของ Broker
SoftBrake ON: cDD (จาก Compound High Water Mark) >= 15%  -> Lot กลับ Fixed ชั่วคราว
SoftBrake OFF: cDD < 11.25% (75% ของ 15%)                -> Lot กลับ Compound
Kill Switch:  cDD >= 22%  -> CloseAll("COMPOUND KILL SWITCH") + ExpertRemove()
```

cDD = (Compound HWM − Virtual Equity ปัจจุบัน) / Compound HWM × 100 — HWM เริ่มจับตั้งแต่วินาทีที่ Compound Activate และอัปเดตทุก Tick ไม่ Reset แม้ cDD จะกลับมาต่ำ

### EA ที่เพิ่ม Feature นี้ใหม่
GBPJPY (v1.2→v1.3), USDJPY (v1.2→v1.3), AUDCAD (v6.11→v6.12)

### EA ที่ไม่แตะ (มี Logic เดิมอยู่แล้ว/ตัดสินใจแยก)
- **NDAQ100**: Compound เดิมเป็นแบบ Risk-% ผูกกับ House Money 2x (ไม่ใช่ Ratio-based 1.5x ตรงๆ) — ยังไม่ได้ Normalize ให้ตรงกับ 5 ตัวที่เหลือ (ค้างเป็น Open Item)
- **OIL-WTI**: มี Compound+SoftBrake Ratio-based 1.5x อยู่แล้วตั้งแต่ต้น ตรง Concept เดียวกัน ไม่ต้องแก้
- **3PAIRS**: มีโครงสร้าง Compound Selective + SoftBrake แยกรายคู่เงิน (`g_compound_brake[idx]`) อยู่แล้ว ครบเครื่องกว่าตัวอื่น (Threshold 1.5x เหมือนกัน) — แค่ปิดไว้ที่ `Inp_Use_Compound=false` (Stage 1) จนถึงรอบนี้

---

## Section 4: Update ล่าสุด — 3PAIRS v2.6 → v2.7

| การเปลี่ยนแปลง | ก่อนหน้า | ตอนนี้ |
|---|---|---|
| `Inp_Use_Compound` | `false` (Stage 1 Fixed Lot) | `true` (Stage 2 — Compound Active) |
| `InpToken` | `""` (ว่างเปล่า — Telegram เงียบมาตลอดโดยไม่ Error) | ใส่ Token จริงแล้ว |
| `InpChatID` | `""` | ใส่ ChatID จริงแล้ว |

**สถานะ:** ยังไม่ได้ Backtest ยืนยันหลังแก้ — เป็น Remaining Step

---

## Section 5: ผล Backtest หลังเพิ่ม Compound (Full Period 2023.10.02/11.01–2026.04.30)

| EA | Balance สูงสุดที่ทำได้ | Ratio vs 1.5x | Compound Activate ใน Backtest นี้? | Net Profit เดิม (Fixed) | Net Profit ใหม่ (Compound) | เปลี่ยนแปลง |
|---|---|---|---|---|---|---|
| **USDJPY** | $476.44 | 1.587x | **ใช่** | $176.44 | $140.94 | PF 1.79→1.541, Sharpe 2.32→1.882, RF 3.00→2.109, Balance DD 12.16%→13.73% — แย่ลงทุกตัว (ยกเว้น DD) แต่ยังผ่าน Protocol v2.0 (Margin บางลงมาก) |
| GBPJPY | $436.70 | 1.456x | ไม่ | $134.34 | $134.34 (เหมือนเดิม 100%) | ไม่มีผลกระทบ — Compound ยัง Dormant |
| AUDCAD | $425.74 | 1.419x | ไม่ | $115.11 | $115.11 (เหมือนเดิม 100%) | ไม่มีผลกระทบ — Compound ยัง Dormant |

**สาเหตุที่ USDJPY แย่ลง:** Balance ข้าม Threshold 450 พอดีก่อนเจอ Losing Streak 5 ไม้รวด (ม.ค. 2026) — Lot ที่เพิ่งขยายเป็น 0.02 โดน Streak นี้เต็มๆ ทำให้ขาดทุนส่วนเกิน ~$28 เทียบกับถ้ายังเป็น Fixed Lot — เป็น Risk ที่มากับ Concept การ Compound แบบ Binary Threshold ไม่ใช่ Bug

---

## Section 6: การยืนยัน SoftBrake/Kill Switch (Force-Test บน USDJPY)

เนื่องจาก DD จริงในประวัติศาสตร์ (13.73%) ไม่เคยแตะ SoftBrake Threshold ปกติ (15%) จึงลดค่าชั่วคราวเพื่อบังคับ Trigger และพิสูจน์กลไก:

**Test Config ชั่วคราว:** `InpCompoundDDSoftBrake=5.0`, `InpCompoundMaxDD=14.0` (Full Period เดิม 2023.10.02–2026.04.30)

| เวลา | Balance | cDD (จาก Compound HWM) | เหตุการณ์ |
|---|---|---|---|
| 2026.01.13 | 453.79 | 0% | Compound ACTIVATE |
| 2026.01.23 | 470.34 | 0% | HWM Peak ใหม่ |
| 2026.01.23 (หลัง Deal 252) | 442.77 | 5.86% | cDD ทะลุ 5% → SoftBrake ON (ไม้เปิดใหม่ตั้งแต่นี้กลับ Lot 0.01) |
| 2026.02.23 17:53:34 | 405.23 | ~14% | **Kill Switch: CloseAll("COMPOUND KILL SWITCH") + ExpertRemove()** — EA หยุดทำงานจริง (Bars ลดจาก 191,504 เหลือ 177,895) |

**ผลสรุป:** ยืนยันครบทั้ง 3 ชั้น (Compound Activate → SoftBrake ควบคุม Lot ไม้ใหม่ → Kill Switch หยุด EA) ทำงานถูกต้องตาม Design 100% หลังยืนยันแล้ว Reset กลับค่า Production (15%/22%) และ Backtest ซ้ำได้ผลเท่าค่าก่อน Force-Test (ยืนยันว่าไม่กระทบผลลัพธ์จริงเพราะ Threshold Production ไม่เคยถูกแตะ)

---

## Section 7: Version History ทั้ง 6 ไฟล์

| EA | Version เดิม | Version ล่าสุด | การเปลี่ยนแปลงหลัก |
|---|---|---|---|
| NDAQ100 | v1.0 | **v1.1** | Fix G: Virtual Equity/Balance per-Magic (แก้ Cross-Contamination) |
| GBPJPY | v1.1 | **v1.3** | v1.2 เพิ่ม Compound Ratio-based, v1.3 เพิ่ม SoftBrake+Kill |
| OIL-WTI | v4.62 | v4.62 (ไม่แตะ) | มี Compound+SoftBrake อยู่แล้วตั้งแต่ต้น |
| USDJPY | v1.1 | **v1.3** | v1.2 เพิ่ม Compound, v1.3 เพิ่ม SoftBrake+Kill — **Backtest ยืนยันครบแล้ว** |
| 3PAIRS | v2.6 | **v2.7** | เปิด `Inp_Use_Compound=true` (Stage 2) + เติม Telegram Token/ChatID |
| AUDCAD | v6.10 | **v6.12** | v6.11 เพิ่ม Compound Ratio-based, v6.12 เพิ่ม SoftBrake+Kill |

---

## Section 8: Known Caveats

1. **NDAQ100 Compound Formula ไม่ตรงกับ 5 ตัวที่เหลือ** — ใช้ Risk-% ผูกกับ House Money 2x Gate ไม่ใช่ Ratio-based 1.5x Threshold เฉยๆ ยังไม่ได้ตัดสินใจว่าจะ Normalize ให้เหมือนกันหรือปล่อยไว้ตามเดิม
2. **3PAIRS v2.7 ยังไม่ได้ Backtest ยืนยัน** หลังเปิด Compound + เติม Telegram — เป็น Priority ถัดไป
3. **GBPJPY/AUDCAD ยังไม่เคย Force-Test SoftBrake โดยตรง** — ใช้ Code Pattern เดียวกับ USDJPY เป๊ะทุกตัวอักษร (ต่างแค่ชื่อตัวแปรตาม Naming Convention ไฟล์) จึงเชื่อได้ในระดับหนึ่งว่าใช้งานได้ แต่ยังไม่มีหลักฐาน Backtest ตรงเหมือน USDJPY
4. **Combined DD Simulation ระดับพอร์ต (Step 0.5 Combine Gate)** ยังไม่ได้ทำสำหรับทั้ง 3 พอร์ต — ยังทดสอบแค่ระดับ EA เดี่ยวรันคู่กัน (Virtual Equity Isolation) ไม่ใช่ DD รวมของทั้งพอร์ตพร้อมกัน
5. **Correlation Check (#14)** ระหว่าง EA ในพอร์ตเดียวกันยังค้างอยู่ทุกพอร์ต (มาจาก Context Summary เดิมของแต่ละ EA ก่อนหน้า Session นี้)

---

## Section 9: Production File Reference

| ไฟล์ | Magic | Version |
|---|---|---|
| 9AU_NDAQ100_COMBINE_M5_CAP300_v1.1.mq5 | 919294 | 1.1 |
| 9AU_GBPJPY_COMBINE_M5_CAP300_v1.3.mq5 | 515254 | 1.3 |
| 9AU_OIL_WTI_COMBINE_M5_CAP300_v4.62.mq5 | 919293 | 4.62 |
| 9AU_USDJPY_COMBINE_M5_CAP300_v1.3.mq5 | 515253 | 1.3 |
| 9AU_3PAIRS_COMBINE_M15_CAP300_v2.7.mq5 | 515252 | 2.7 |
| 9AU_AUDCAD_COMBINE_M15_CAP300_v6.12.mq5 | 515251 | 6.12 |

**Invariant ร่วมทุกไฟล์:** Compound Threshold = BaseBalance × 1.5, SoftBrake ON/OFF = 15%/11.25% (ยกเว้น 3PAIRS ใช้ 15%/10.0% ที่มีอยู่เดิม), Kill Switch = 22% (3PAIRS ใช้ 20% ที่มีอยู่เดิม), ทุกไฟล์ผ่านการตรวจ Brace Balance และ Cross-Contamination แล้ว

---

## Section 10: Remaining Steps

1. **Backtest 3PAIRS v2.7** (Full Period 2023.10.02–2026.04.30) ยืนยันว่า Compound Stage 2 + Telegram ทำงานถูกต้อง — ยังไม่ได้ทำ
2. **ตัดสินใจเรื่อง NDAQ100 Compound Formula** — Normalize ให้ตรงกับ 5 ตัวที่เหลือ หรือปล่อยแบบ Risk-% เดิม
3. **Combined DD Simulation ระดับพอร์ต** ทั้ง 3 พอร์ต (Step 0.5 Combine Gate) ก่อน Forward Test จริง
4. **Correlation Check (#14)** ระหว่าง EA คู่ในแต่ละพอร์ต
5. **Forward Test Demo** ทั้ง 6 EA พร้อมกัน (Combine จริง) อย่างน้อย 1-2 เดือน ก่อนพิจารณา Live
6. (Optional) Force-Test SoftBrake ของ GBPJPY/AUDCAD โดยตรง เพื่อความมั่นใจเพิ่มเติมก่อน Deploy จริง

---

*Generated: 2026-07-27 | James Consultant | Session: 6 EA Combine — Virtual Equity Fix + Compound Selective + SoftBrake*
