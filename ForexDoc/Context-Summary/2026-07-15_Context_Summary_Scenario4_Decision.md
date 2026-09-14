---
concept_name: 9AU Portfolio Restructure — Scenario-4 (2 Meta-Pool) — Context Summary
protocol: Portfolio Management Layer (ต่อยอดจาก EA Validation Protocol v2.0)
status: ตัดสินใจแล้ว (Decision Made) — รอ Implementation
created: 2026-07-27
tags: [portfolio, scenario-4, meta-pool, dca, terminal-consolidation, virtual-balance]
---

## Section 1: Decision Summary

พี่อูตัดสินใจเลือก **Scenario-4** จากทั้งหมด 5 Scenario ที่จำลองไว้ (Excel: `9AU_Portfolio_Compound_Growth_Beta_Alpha.xlsx`) เหตุผล: ประสิทธิภาพเวลาถึงเป้าดีที่สุดในกลุ่มที่ไม่ต้อง Refactor EA ทั้งหมด (เท่ากับ Scenario-3 ที่ 40 เดือน) **บวกกับเหตุผลเพิ่มเติมด้าน VPS/การจัดการที่กระชับขึ้น**

## Section 2: โครงสร้าง Terminal/VPS — เดิม vs ใหม่

| | เดิม | ใหม่ (Scenario-4) |
|---|---|---|
| จำนวน Terminal | 4 | **2** |
| จำนวน Chart รวม | 7 | 7 (เท่าเดิม) |
| การจัดกลุ่มบัญชี | แยก 4 บัญชี: Port1($300) / Port2($300) / Port3($300) / Gold($450) | รวมเหลือ 2 บัญชี: **Beta-pool** / **Alpha-pool** |

### Terminal A — Beta-pool (ทุนรวม $600)
| EA | Magic | Chart |
|---|---|---|
| OIL-WTI | 919293 | OILCash# |
| USDJPY | 515253 | USDJPY# |
| 3PAIRS | 515252 | AUDCAD#/NZDCAD#/AUDNZD# |
| AUDCAD | 515251 | AUDCAD# |

### Terminal B — Alpha-pool (ทุนรวม $750)
| EA | Magic | Chart |
|---|---|---|
| NASDAQ100 | 919294 | US100Cash# |
| GBPJPY | 515254 | GBPJPY# |
| GOLD | 919291 | GOLD# |

**Magic Number Collision Check:** ทุกตัวไม่ซ้ำกันทั้งใน Terminal เดียวกันและข้าม Terminal — ผ่าน

## Section 3: DCA Allocation Structure

```
DCA รวม $100/เดือน แบ่ง 2 Pool ตามสัดส่วนทุน (Capital-Proportional):
  Beta-pool  ($600) -> $50/เดือน
  Alpha-pool ($750) -> $50/เดือน

ภายใน Beta-pool ($50): แบ่งตามสัดส่วนทุนของ Port2 vs Port3 (300:300 เท่ากัน) = $25 / $25
  -> ยังไม่ได้กำหนดว่า $25 ของ "Port2" จะแบ่งอย่างไรระหว่าง OIL-WTI กับ USDJPY (2 EA จริง)
  -> ยังไม่ได้กำหนดว่า $25 ของ "Port3" จะแบ่งอย่างไรระหว่าง 3PAIRS กับ AUDCAD (2 EA จริง)

ภายใน Alpha-pool ($50): แบ่งตามสัดส่วนทุน Port1(300/750=40%) vs Gold(450/750=60%) = $20 / $30
  -> Port1 ($20) ยังไม่ได้กำหนดว่าจะแบ่งอย่างไรระหว่าง NDAQ100 กับ GBPJPY (2 EA จริง)
```

**Open Decision:** โมเดล Excel คำนวณระดับ "Port" (2 EA รวมกัน) เป็นหน่วยเดียว ยังไม่ได้ลงรายละเอียดระดับ EA เดี่ยวภายใน Port — ต้องตัดสินใจต่อว่าจะแบ่ง DCA ภายใน Port อย่างไร (เท่ากัน 50/50 หรือ ตามสัดส่วน %กำไร/ปีของแต่ละ EA เหมือนที่ใช้จัดลำดับ Port)

## Section 4: Financial Projection (อ้างอิงจาก Excel Model)

| Metric | ค่า |
|---|---|
| ทุนรวมเริ่มต้น | $1,350 (Beta-pool $600 + Alpha-pool $750) |
| เป้าหมาย | $15,000 |
| DCA | $100/เดือน ($50 ต่อ Pool) |
| เดือนที่ถึงเป้า | **40 เดือน (~3.3 ปี)** |
| มูลค่า ณ เดือนที่ 40 | ~$15,116 |

**สมมติฐานสำคัญที่ต้องคงไว้:** แต่ละ EA ยังคงใช้ `InpActiveBase`/`InpBaseBalance`/`Inp_Virtual_Cap` เดิมของตัวเอง (300 หรือ 450) **ไม่เปลี่ยนเป็นค่าใหม่ตาม Pool** — การรวม Terminal เป็นแค่การจัดกลุ่มทางกายภาพ/บัญชี ไม่ใช่การรวมทุนให้ EA มองเห็นเป็นก้อนเดียว (ถ้าทำแบบนั้นจะกลายเป็น Scenario-5 ที่ผลลัพธ์แย่กว่า — ดู Context Summary การเงินเดิมประกอบ)

## Section 5: สิ่งที่ต้องปรับ (Technical + Operational)

### 5.1 Operational (ไม่ใช่ Code)
- รวมทุนจริงจาก 4 บัญชีเดิมเป็น 2 บัญชีใหม่ผ่าน Broker (Fund Transfer/Consolidation)
- ย้าย EA/Chart ไป Terminal ใหม่ตามผังใน Section 2

### 5.2 Code — ที่ต้องแก้แน่นอน
**GOLD ต้องอัปเกรดเป็น Virtual Balance per-Magic** — สาเหตุ: เดิม Gold รันเดี่ยว (Solo) ไม่เคยต้องกันการปนกับ EA อื่น จึงมีความเป็นไปได้สูงว่ายังใช้ `ACCOUNT_EQUITY`/`ACCOUNT_BALANCE` ตรงๆ (Pattern เดียวกับที่เจอเป็นบั๊กใน NDAQ100 v1.0) เมื่อย้ายเข้า Alpha-pool ร่วมกับ NDAQ100+GBPJPY จะเกิด Cross-Contamination ทันทีถ้าไม่แก้ก่อน — ต้อง Refactor ด้วย Pattern เดียวกับที่แก้ NDAQ100 v1.0→v1.1 (`ScanInitialRealizedProfit()` + `OnTradeTransaction()` กรอง Magic 919291 เท่านั้น)

### 5.3 Code — ที่ควรตรวจสอบซ้ำ (น่าจะไม่ต้องแก้ แต่ต้องยืนยัน)
- OIL-WTI/USDJPY/3PAIRS/AUDCAD (Beta-pool 4 EA ในบัญชีเดียว) — ระบบ Virtual Balance per-Magic ที่มีอยู่แล้ว **ออกแบบมาให้กรองด้วย Magic Number ของตัวเองเท่านั้น ไม่จำกัดจำนวน EA อื่นที่ร่วมบัญชี** ทางทฤษฎีควรรองรับ 4-EA-Combine ได้โดยไม่ต้องแก้โค้ดเพิ่ม — แต่ยังไม่เคย Backtest/Forward Test จริงในสภาพ 4 EA ร่วมบัญชีพร้อมกัน (ที่ผ่านมาเทียบแค่ 2 EA/บัญชี) ควรทดสอบยืนยันก่อน Deploy จริง
- NDAQ100/GBPJPY (Alpha-pool ร่วมกับ Gold) — เช่นเดียวกัน ระบบเดิมควรรองรับ 3-EA-Combine ได้ แต่ยังไม่เคยทดสอบจริง

### 5.4 Code — เรื่อง DCA เงินสด Auto-Recognition (มีข้อจำกัดเดิม + อัปเดตสำคัญ)

ข้อจำกัดเดิมที่เคยสรุปไว้:
> จุดที่ขาดจริง: การรับรู้ DCA เงินสด อัตโนมัติ — สาเหตุเชิงเทคนิค: การฝากเงินใน MT5 เป็น Deal ประเภท Balance ที่ไม่มี Magic Number ผูกอยู่ ระบบ Virtual Balance per-Magic ที่เพิ่งแก้ไปกัน Cross-Contamination (จำเป็นสำหรับ Combine 2 EA ในบัญชีเดียว) จะกรอง Deal นี้ทิ้งอัตโนมัติ ไม่นับเข้า EA ไหนเลย และไม่มีทางให้โค้ด Auto-Detect ได้เองว่าเงินที่ฝากมาควรแบ่งให้ EA ไหนเท่าไหร่ (ต้องมีคนตัดสินใจ)

**อัปเดตสำคัญภายใต้โครงสร้างใหม่:** ข้อยกเว้นเดิมที่ระบุว่า **"ยกเว้น Gold ที่รันเดี่ยวไม่แย่ง Magic กับใคร ทำ Auto ได้ง่ายกว่า" ใช้ไม่ได้อีกต่อไป** เพราะ Gold จะย้ายเข้าไปอยู่ใน Alpha-pool ร่วมกับ NDAQ100+GBPJPY (ไม่ใช่ Solo แล้ว) เพราะฉะนั้นทั้ง 7 EA ในโครงสร้างใหม่นี้**เจอปัญหา DCA Auto-Recognition เหมือนกันหมดทุกตัว ไม่มีข้อยกเว้นเหลืออยู่เลย**

**ทางเลือกที่ทำได้จริง (Manual แต่กึ่งอัตโนมัติ):** เพิ่ม Input เช่น `InpDCAtoAdd` ต่อ EA ให้พี่อูกรอกยอดที่จะแบ่งให้ EA ตัวนั้นเองด้วยมือ (ตาม Section 3 ที่ต้องตัดสินใจสัดส่วนอยู่แล้ว) แล้ว EA จะบวกเข้า Virtual Balance ของตัวเองทันทีที่ Restart/Set Input ใหม่ — อ้างอิงจากการวิเคราะห์ก่อนหน้า Manual Rebase แม้ทำทุก 3-6 เดือนก็แทบไม่ทำให้ผลตอบแทนช้าลง (ต่างจาก Full-Auto ไม่เกิน 1 เดือน) จึงไม่จำเป็นต้องรีบเร่งทำ Auto 100%

## Section 6: คำถามที่ต้องตัดสินใจก่อนเริ่ม Implementation

1. สัดส่วน DCA ภายใน Port2 (OIL-WTI vs USDJPY) และ Port3 (3PAIRS vs AUDCAD) และ Port1 (NDAQ100 vs GBPJPY) — แบ่งเท่ากัน หรือตามสัดส่วน %กำไร/ปีของแต่ละ EA
2. ลำดับการทำงาน: จะรวมทุนจริงในบัญชี (Broker) ก่อน แล้วค่อยแก้ Gold Code ทีหลัง หรือแก้ Gold Code ให้พร้อมก่อนแล้วค่อยย้ายเงิน
3. ต้องการ Force-Test Virtual Balance per-Magic แบบ 3-EA/4-EA-Combine (เหมือนที่เคย Force-Test SoftBrake ของ USDJPY) ก่อน Deploy จริงไหม
4. `InpDCAtoAdd` (Manual DCA Input) จะทำให้ครบทั้ง 7 EA เลย หรือทำเฉพาะบางตัวก่อน

## Section 7: Reference — ไฟล์ที่เกี่ยวข้อง

| ไฟล์ | เนื้อหา |
|---|---|
| `9AU_Portfolio_Compound_Growth_Beta_Alpha.xlsx` | Excel Model 5 Scenario (Summary/Scenario-1~5/VPS_and_AutoCompound) |
| `Context_Summary_Portfolio_Management_Beta_Alpha_v2.md` | ยกเลิก Copy Trade + โครงสร้างทุนล่าสุดก่อนตัดสินใจ Scenario-4 |
| `9AU_NDAQ100_COMBINE_M5_CAP300_v1.1.mq5` | Reference Pattern สำหรับแก้ Gold ให้เป็น Virtual Balance per-Magic |
| `9AU_GOLD_ADAPTIVE_REGIME_M5_CAP450_v19.3.mq5` | ไฟล์ Gold ปัจจุบัน (ยังไม่ยืนยันว่ามี/ไม่มี per-Magic Isolation) — ต้องตรวจสอบก่อนแก้ |

---

## Prompt สำหรับเริ่ม Session ใหม่

```
James — อ่าน Context Summary Scenario-4 นี้แล้วครับ วันนี้จะทำ: [ระบุงาน เช่น "ตรวจโค้ด Gold ว่ามี per-Magic Isolation หรือยัง" หรือ "เริ่มออกแบบ InpDCAtoAdd"]
```

*Generated: 2026-07-27 | James Consultant | Session: Portfolio Restructure Decision — Scenario-4*
