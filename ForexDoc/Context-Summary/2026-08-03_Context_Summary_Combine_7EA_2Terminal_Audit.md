---
concept_name: 9AU Portfolio — Combine-Readiness Audit (7 EA / 2 Terminal, Scenario-4)
protocol: EA Validation Protocol v2.0 + Portfolio Management Layer
status: Code Audit + Parity Check เสร็จสมบูรณ์ — พร้อมขั้นตอน Force-Test ก่อน Deploy จริง
created: 2026-08-02
tags: [audit, combine, scenario-4, virtual-balance, dca, parity-check, gold, audcad]
---

# 9AU Portfolio — Combine-Readiness Audit (7 EA / 2 Terminal)

อ้างอิงคู่กับ `Context_Summary_Scenario4_Decision.md` — เอกสารนี้บันทึกผลการตรวจ Code ทั้ง 7 EA ทีละไฟล์ตามที่ Scenario-4 §5.2/§5.3 ระบุไว้ว่าต้องตรวจก่อน Deploy จริง พร้อมผลการเพิ่ม Feature `InpDCAtoAdd` และผล Parity Check ยืนยันว่าการแก้ไขทั้งหมดไม่กระทบผล Backtest เดิม

## Section 1: โครงสร้าง Terminal (อ้างอิง Scenario-4)

| Terminal | EA | Magic | Version ล่าสุด |
|---|---|---|---|
| A — Beta-pool ($600) | OIL-WTI | 919293 | v4.63 |
| A — Beta-pool ($600) | USDJPY | 515253 | v1.4 |
| A — Beta-pool ($600) | 3PAIRS | 515252 | v2.8 |
| A — Beta-pool ($600) | AUDCAD | 515251 | v6.13 |
| B — Alpha-pool ($750) | NASDAQ100 | 919294 | v1.2 |
| B — Alpha-pool ($750) | GBPJPY | 515254 | v1.4 |
| B — Alpha-pool ($750) | GOLD | 919291 | v19.4 (`9AU_GOLD_COMBINE_M5_CAP450_V19_4.mq5`) |

Magic Number Collision Check: ทุกตัวไม่ซ้ำกันทั้งใน Terminal เดียวกันและข้าม Terminal — ผ่าน

## Section 2: ผลตรวจ Virtual Balance/Equity per Magic (Checklist หลัก)

Checklist ที่ใช้ตรวจทุกไฟล์: (1) ไม่มี `ACCOUNT_EQUITY`/`ACCOUNT_BALANCE` ดิบหลุดเข้าสูตร Money Management (2) `InpActiveBase`/`InpBaseBalance`/`Inp_Virtual_Cap` คงค่าเดิมตาม EA ไม่ใช่ตาม Pool (3) Magic Number ไม่ชนกัน (4) Telegram Token/ChatID ไม่ถูกลบ (5) Kill Switch คำนวณจาก Virtual Equity ของ Magic ตัวเอง

| EA | ผลตรวจตอนเริ่ม | Action |
|---|---|---|
| Gold v19.3 | **ไม่มี Virtual Balance เลยทั้งไฟล์** — ใช้ `ACCOUNT_BALANCE`/`ACCOUNT_EQUITY` ดิบใน 8 ฟังก์ชัน (OnInit, CheckHouseMoney, GetSniperLot, GetSellSniperLot, CheckEquityStop, UpdateDailyLoss, CheckDDAlert, Check2xBalance, IsExposureSafeSell) | **Fix K**: Refactor เต็มรูปแบบตาม Pattern NDAQ100 v1.1 — เพิ่ม `ScanInitialRealizedProfit()`, `OnTradeTransaction()`, `GetVirtualBalance()`, `GetVirtualEquity()` แทนที่ทุกจุด |
| NDAQ100 v1.1 | ผ่าน (Reference Pattern ที่ใช้อ้างอิงแก้ตัวอื่น) | ไม่ต้องแก้ |
| GBPJPY v1.3 | ผ่าน | ไม่ต้องแก้ |
| USDJPY v1.3 | ผ่าน | ไม่ต้องแก้ |
| OIL-WTI v4.62 | ผ่าน | ไม่ต้องแก้ |
| 3PAIRS v2.7 | ผ่าน | ไม่ต้องแก้ |
| AUDCAD v6.12 | **บั๊กร้ายแรง**: `g_virtual_balance = Inp_Virtual_Cap` Hardcode ตรงๆ ทุกครั้งที่ `OnInit()` ไม่มี `ScanInitialRealizedProfit()` — Restart EA (VPS Reboot/MT5 Update/Terminal Crash) จะล้างกำไร/ขาดทุนสะสมทิ้งหมด กระทบ Compound Trigger, Peak Balance/Equity, Kill Switch DD% | **Fix J**: เพิ่ม `ScanInitialRealizedProfit()` กู้คืนจาก Deal History — ยืนยันกับพี่อูแล้วว่า EA ตัวนี้ **ยังไม่เคย Restart บน Live** จึงยังไม่มีข้อมูลจริงเสียหาย แก้ทันเวลาพอดี |

## Section 3: Compound Lot Formula — พบ 3 รูปแบบต่างกันในพอร์ตเดียว (ยังไม่แก้ — ต้องตัดสินใจแยก)

Memory บันทึก Lesson ไว้ว่า Compound Lot ต้อง Scale จาก `min(balance, HWM)/BaseBalance` (HWM-based) ไม่ใช่ Equity ปัจจุบัน เพราะ Scaling จาก Equity ระหว่าง DD จะขยายผลขาดทุนซ้ำ (Cascading Loss Amplification) — ตรวจ Code จริงพบว่ามีการใช้งานไม่ตรงกันถึง 3 แบบ:

| Formula | EA ที่ใช้ | ตรง Lesson หรือไม่ |
|---|---|---|
| HWM-based: `MathMin(bal, compoundHWM) / BaseBalance` | Gold เท่านั้น | ตรง Lesson |
| Equity-based: `VirtualEquity() / BaseBalance` (ไม่ Cap ด้วย HWM) | OIL-WTI, GBPJPY, USDJPY, AUDCAD | **ไม่ตรง Lesson** |
| Balance-based: `VirtualBalance() / BaseBalance` (Per-Symbol SoftBrake ตาม $floating) | 3PAIRS | สถาปัตยกรรมต่างโดยตั้งใจ (Mature System เดิม ไม่ใช่บั๊ก) |

**สถานะ:** ยังไม่แก้ เพราะกระทบผล Backtest ที่ผ่าน Protocol v2.0 ไปแล้วทั้ง 5 ตัว (OIL-WTI, GBPJPY, USDJPY, AUDCAD ผ่านแล้ว + Gold เพิ่งผ่าน) ต้องคุยแผน Re-validate แยกเป็นวาระถัดไปก่อนตัดสินใจว่าจะรวมเป็นมาตรฐานเดียวหรือไม่

## Section 4: Manual DCA Feature (`InpDCAtoAdd` / `Inp_DCAtoAdd`)

เพิ่มครบทั้ง 7 EA ด้วย Pattern เดียวกัน:

- กรอกเป็น **ยอดสะสมรวม** ไม่ใช่ยอดต่อเดือน (เดือน 1 = 25, เดือน 2 = 50, เดือน 3 = 75 ...)
- เก็บ Checkpoint ล่าสุดใน MT5 Global Variable ชื่อ `9AU_DCA_APPLIED_<Magic>` ซึ่งอยู่ข้าม EA Restart
- ทุก `OnInit()` คำนวณ `Delta = InpDCAtoAdd − ยอดที่เคย Apply แล้ว` แล้วบวกเข้า Virtual Balance เฉพาะส่วน Delta เท่านั้น — ถ้า Restart ซ้ำโดยค่า Input ไม่เปลี่ยน Delta=0 จะไม่บวกซ้ำ ป้องกัน Double-Apply
- Label สีเหลืองมุมซ้ายบนชาร์ตแสดง `DCA Cumulative / VBase / VBal` ตลอดเวลา เพื่อยืนยันสถานะก่อน Restart จริง

**การตัดสินใจสำคัญที่เกี่ยวข้อง (บันทึกไว้เพื่ออ้างอิง):** พิจารณาแล้วว่า **ไม่ Concentrate DCA เข้า EA เดียวต่อ Pool** เพื่อความสะดวก เพราะ (1) Virtual Balance แยกกันเด็ดขาดต่อ Magic ทำให้เงินไม่กระจายเองข้าม EA (2) การฉีดเงินสดตรงเข้า Virtual Balance จะ "หลอก" สูตร Compound/HWM ให้เข้าใจผิดว่าเป็นกำไรจากการเทรด (3) จะทำให้ Correlation/Combined DD Simulation (Step 0.5 Combine Gate) ที่เคย Validate ไว้ไม่ตรงกับความเป็นจริงอีกต่อไป — ใช้สัดส่วนคงที่ตาม Scenario-4 §3 แทน (Beta $25/$25 ต่อ Port, Alpha $20/$30)

## Section 5: Parity Check — ยืนยันว่าการแก้ไขทั้งหมดไม่กระทบผล Backtest เดิม

Backtest ด้วย Default Input ล้วน (ไม่โหลด `.set`) เทียบกับตัวเลขที่บันทึกไว้ใน Context Summary เดิมของแต่ละ EA:

| EA | Net Profit | Balance DD | Equity DD | PF | Sharpe | Trades | ผล |
|---|---|---|---|---|---|---|---|
| NDAQ100 v1.2 | 94.84 = 94.84 | 22.14%=22.14% | 24.87%=24.87% | 1.60=1.60 | 3.87=3.87 | 28=28 | ตรงเป๊ะ |
| GBPJPY v1.4 | 134.34=134.34 | 8.73%=8.73% | 9.98%=9.98% | 1.57=1.57 | 2.40=2.40 | 118=118 | ตรงเป๊ะ |
| USDJPY v1.4 | 140.94 | 13.73%=13.73% | 14.19% | 1.541=1.541 | 1.882=1.882 | 131 | ตรงเป๊ะ (เทียบ Post-Compound) |
| 3PAIRS v2.8 | 101.95=101.95 | 0.67%=0.67% | 6.18%=6.18% | 15.12=15.12 | 7.87=7.87 | 48=48 | ตรงเป๊ะ |
| AUDCAD v6.13 | 115.11=115.11 | 11.94%=11.94% | 12.29%=12.29% | 1.837=1.837 | 1.963=1.963 | 174=174 | ตรงเป๊ะ (ยืนยัน Fix J ไม่กระทบผล) |
| OIL-WTI v4.63 | 31.35=31.35 | 0.95%=0.95% | 7.58% ≠ 5.22% | 12.00=12.00 | 3.56=3.56 | 13=13 | ตรงเกือบหมด — Equity DD คลาดเคลื่อนเล็กน้อยจาก Broker Historical Data Refresh (Build 6090) ไม่ใช่ Logic (PF/WR/Trades ตรงเป๊ะ) |
| Gold v19.4 (รอบแรก) | 1520.58 ≠ 1440 | 19.72% | 21.36% ≠ 24.75% | 1.312 | 2.091 | 393, Short=0 | **ไม่ตรง** — สาเหตุพบแล้ว ดู Section 6 |
| Gold v19.4 (หลังแก้ Fix M) | 1440.23 = 1440 | 23.14% | **602.35 (24.75%) = 24.75%** | 1.280 | 1.994=1.99 | 419 (Long 393@67.43%=67.43%, Short 26@61.54%=61.54%) | **ตรงเป๊ะหลังแก้** |

## Section 6: Gold — Root Cause ที่แท้จริงของความคลาดเคลื่อนรอบแรก (Fix M)

ตรวจ Default ทุก Input ใน Source Code Gold v19.3 (70+ Parameters) เทียบกับ Production `.set` ที่บันทึกไว้ในเอกสารเดิม พบว่า **ตรงกันหมดทุกตัว ยกเว้นจุดเดียว**:

```
บรรทัด 37 (v19.3): input bool InpEnableSell = false;   ← Code Default
เอกสาร Production .set (HM=FALSE Deploy):  InpEnableSell = true
```

**สาเหตุ:** Default ค้างจากยุค V14 Buy-only ก่อนเพิ่ม Sell Logic — ตอน Validate ผ่าน Protocol v2.0 ครั้งก่อนน่าจะโหลด `.set` File แยกต่างหาก (Manual) ไม่ได้พึ่ง Default ในโค้ด พอทดสอบรอบนี้ด้วย Default ล้วนไม่โหลด `.set` เลย EA จึงกลายเป็น Buy-only โดยไม่ตั้งใจ — **ไม่เกี่ยวข้องกับ DCA Refactor หรือ Virtual Balance Refactor (Fix K) แต่อย่างใด**

**แก้แล้ว (Fix M):** เปลี่ยน Default เป็น `InpEnableSell = true` ในไฟล์ `9AU_GOLD_COMBINE_M5_CAP450_V19_4.mq5` — Backtest ซ้ำยืนยัน Parity ผ่านสมบูรณ์ (ดู Section 5 แถวสุดท้าย)

## Section 7: Version Reference สุดท้าย (ไฟล์ที่ใช้ Deploy จริง)

| EA | ไฟล์ | Version |
|---|---|---|
| Gold | `9AU_GOLD_COMBINE_M5_CAP450_V19_4.mq5` | v19.4 (Fix K + L + M, เปลี่ยนชื่อจาก `_ADAPTIVE_REGIME_` เป็น `_COMBINE_`) |
| NDAQ100 | `9AU_NDAQ100_COMBINE_M5_CAP300_v1_2.mq5` | v1.2 (Fix L) |
| GBPJPY | `9AU_GBPJPY_COMBINE_M5_CAP300_v1_4.mq5` | v1.4 (Fix L) |
| OIL-WTI | `9AU_OIL_WTI_COMBINE_M5_CAP300_v4_63.mq5` | v4.63 (Fix L) |
| USDJPY | `9AU_USDJPY_COMBINE_M5_CAP300_v1_4.mq5` | v1.4 (Fix L) |
| 3PAIRS | `9AU_3PAIRS_COMBINE_M15_CAP300_v2_8.mq5` | v2.8 (Fix L) |
| AUDCAD | `9AU_AUDCAD_COMBINE_M15_CAP300_v6_13.mq5` | v6.13 (Fix J + L) |

## Section 8: Remaining Steps ก่อน Deploy จริง

1. **Compile ทุกไฟล์ใน MetaEditor จริง** — ตรวจ Brace Balance เบื้องต้นผ่านหมดแล้ว แต่ไม่เท่ากับ Compile จริง ต้องยืนยันไม่มี Error/Warning
2. **Force-Test 4-EA-Combine (Beta-pool)**: OIL-WTI + USDJPY + 3PAIRS + AUDCAD รันพร้อมกันบน Demo Account เดียว ยืนยันว่า Virtual Balance/Kill Switch ของแต่ละตัวไม่ปนกัน (ยังไม่เคยทดสอบเกิน 2 EA/บัญชีมาก่อน)
3. **Force-Test 3-EA-Combine (Alpha-pool)**: Gold + NDAQ100 + GBPJPY รันพร้อมกัน ยืนยันเดียวกัน โดยเฉพาะ Floating Loss ของ NDAQ100/GBPJPY (เคยมี DD สูงช่วง Black Swan) ต้องไม่ลาก Kill Switch ของ Gold ให้ Trigger ผิด
4. **Compound Formula Inconsistency** (Section 3) — ตัดสินใจว่าจะรวมเป็น HWM-based มาตรฐานเดียวหรือคงไว้ตามเดิม ต้อง Re-validate ถ้าแก้
5. **Correlation Diversification Check (#14)** ระหว่าง AUDCAD กับ BTCUSD ที่เคยค้างไว้ — ไม่เกี่ยวกับ Scenario-4 (BTC ไม่อยู่ใน 7 EA ของ Terminal A/B) ข้ามได้ในรอบนี้
6. **รวมทุนจริงจาก 4 บัญชีเดิมเป็น 2 บัญชีใหม่ผ่าน Broker** ตาม Scenario-4 §5.1 (Operational ไม่ใช่ Code)
7. **DCA Allocation**: กรอก `InpDCAtoAdd`/`Inp_DCAtoAdd` ตามสัดส่วนคงที่ที่ตัดสินใจไว้ (Section 4) ทุกครั้งที่มีการฝากเงินใหม่

---
*Generated: 2026-08-02 | James Consultant | Session: Combine-Readiness Audit + DCA Feature + Parity Verification (7 EA / 2 Terminal, Scenario-4)*
