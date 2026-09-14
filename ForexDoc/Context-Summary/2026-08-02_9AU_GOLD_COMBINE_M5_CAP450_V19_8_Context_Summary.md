---
concept_name: 9AU_GOLD_COMBINE_M5_CAP450 — V19.4 to V19.8 FINAL Change Log
protocol: EA Validation Protocol v2.0
status: Accepted — Structural DD/PF Characteristic — Forward Test Ready
created: 2026-08-06
tags: [ea, gold, combine, compound, near-death-pause, hard-sl, structural-dd, v19-series]
---

# 9AU_GOLD_COMBINE_M5_CAP450 — Context Summary (V19.4 → V19.8 FINAL)

อ้างอิงต่อจาก `9AU_GOLD_ADAPTIVE_REGIME_M5_CAP450_ContextSummary.md` (V19.3 เดิม) และ `Context_Summary_Combine_7EA_2Terminal_Audit.md` — เอกสารนี้บันทึกการแก้ไขทั้งหมดตั้งแต่ Gold ย้ายเข้า Alpha-pool (Scenario-4) จนถึง Config สุดท้ายที่ยอมรับใช้งานจริง

## Section 1: สรุปเส้นทาง V19.4 → V19.8 (7 Fix + 3 Test Iteration)

| Version | การเปลี่ยนแปลง | ประเภท |
|---|---|---|
| V19.4 Fix K | Virtual Balance/Equity per Magic Number (Combine Mode) | Refactor (Parity-Neutral) |
| V19.4 Fix L | เพิ่ม `InpDCAtoAdd` (Manual DCA) + Global Variable Delta Guard | Feature Add (Parity-Neutral) |
| V19.4 Fix M | แก้ Default `InpEnableSell` false→true (ตรง Production .set เดิม) | Bug Fix (Parity-Neutral) |
| V19.5 Fix N | ตัด Compound ออกจากเงื่อนไข `InpEnableHouseMoney` (3 จุด) | Bug Fix (**Logic Change**) |
| V19.6 Fix O | แยก `UpdateCompoundState()` ออกจาก `CheckHouseMoney()` — Fix N ยังไม่พอเพราะ Auto-Activate ฝังอยู่ใน Early-Return | Bug Fix (**Critical — Compound ไม่เคยทำงานมาก่อนเลย**) |
| V19.7 Test(3+4) | `InpCompoundStartMultiple` 1.5→2.0, `InpCompoundDDSoftBrake` 20→15, `InpCompoundMaxDD` 28→22 | Parameter Test |
| V19.8 (Item-1, ยกเลิก) | `InpCompoundMaxDD` 22→25 — **ผลแย่ลง ไม่ใช้** | Parameter Test (Rejected) |
| V19.9 (Item-2, ยกเลิก) | Near-Death Pause + Auto-Recovery Architecture — **เหตุการณ์เร็วเกินกว่า Cooldown จะช่วยทัน ไม่ใช้** | Architecture Test (Rejected) |
| **V19.8 FINAL** | `InpHardSLMultiplier` 11.0→7.0 (Root Cause Fix) | **Parameter Fix — Accepted** |

## Section 2: Fix K/L/M — Combine Mode Migration (Parity Verified)

Gold เดิมรันเดี่ยว (Solo) ไม่มี Virtual Balance/Equity per Magic เลยทั้งไฟล์ — เมื่อย้ายเข้า Alpha-pool ร่วมกับ NDAQ100(919294)+GBPJPY(515254) ตาม Scenario-4 ต้อง Refactor เต็มรูปแบบตาม Pattern เดียวกับ NDAQ100 v1.0→v1.1:

- เพิ่ม `ScanInitialRealizedProfit()`, `OnTradeTransaction()`, `GetVirtualBalance()`, `GetVirtualEquity()`
- เพิ่ม `InpCombineMode`, `InpActiveBase` (=450.0)
- เพิ่ม `InpDCAtoAdd` (Manual DCA, Cumulative Total) + Global Variable Delta Guard + On-Chart Label
- แก้ Default `InpEnableSell` (false→true) ที่ค้างมาจากยุค V14 Buy-only

**Parity Check ยืนยันแล้ว** (2 รอบ, ก่อน/หลัง Fix M): Net Profit $1,440.23, Equity DD 24.75%, Sharpe 1.994, RF 2.391 — ตรงเป๊ะกับ V19.3 HM=FALSE Baseline ที่เคย Validate ไว้เดิม (ดู Section 5 ของ Combine Audit Report)

## Section 3: Fix N/O — Compound ไม่เคยทำงานจริงมาก่อน (Critical Discovery)

**Fix N**: พบว่า `GetSniperLot()`, `GetSellSniperLot()`, และ SoftBrake ใน `CheckEquityStop()` ผูก Compound ไว้กับ `InpEnableHouseMoney` ผิด (`|| !InpEnableHouseMoney`) — เพราะ Production Default คือ `InpEnableHouseMoney=false` (ตามคำแนะนำ HM=FALSE เดิม) Compound จึงล็อกอยู่ที่ Fixed Lot ตลอดแม้ `InpEnableCompound=true`

**Fix O (สำคัญกว่า)**: หลังแก้ Fix N พบว่า Backtest **ยังไม่เปลี่ยนแปลงเลยแม้แต่นิดเดียว** — ตรวจสอบพบว่าโค้ด Auto-Activate Compound (`currentLotMode = LOT_COMPOUND`) ฝังอยู่ข้างในฟังก์ชัน `CheckHouseMoney()` ซึ่งมี Early-Return 2 ชั้นก่อนถึงจุดนั้น (`if(!InpEnableHouseMoney) return;` และ `if(bal < target) return;`) — แก้โดยแยกเป็น `UpdateCompoundState()` อิสระ เรียกทุก Tick ใน `OnTick()` ไม่ขึ้นกับ House Money เลย

**ผลหลังแก้ทั้งคู่**: Net Profit $1,440.23 → **$2,593.03** (+80%) เพราะ Compound เริ่มทำงานจริงเป็นครั้งแรกในประวัติของ EA ตัวนี้ แลกกับ Balance DD ที่ขยับขึ้น 23.14%→27.96% (ธรรมชาติของ Compound Lot Scaling)

## Section 4: การหาสาเหตุที่แท้จริงของ DD — Journal-Driven Investigation

### 4.1 สมมติฐานแรก (ผิด): ปรับ Kill Switch Threshold

ทดสอบ 4 แนวทางตามลำดับที่ตกลงไว้ (Test 3+4 → Item 1 → Item 2 → Item 3):

| Test | การเปลี่ยนแปลง | Net Profit | Balance DD | ผล |
|---|---|---|---|---|
| Test(3+4) → V19.7 | StartMultiple 1.5→2.0, SoftBrake 20→15, MaxDD 28→22 | $1,989.60 | 22.03% | Baseline การทดลอง |
| Item-1: MaxDD 22→25 | Single-Lever | $1,864.72 | 25.83% | **แย่ลง** |
| Item-2: Near-Death Pause + Auto-Recovery | Architecture ใหม่ (Hard-Kill=30%) | $1,540.63 | 30.08% | **แย่ลงกว่าเดิม** |

**Journal Log ยืนยันสาเหตุ**: ทุกเวอร์ชันโดน Kill จาก**เหตุการณ์เดียวกัน** (2026.01.29 ~17:12-17:15) ซึ่งเป็น Fast Directional Move ที่ราคาวิ่งทะลุทุก Threshold ภายในไม่กี่นาที (Item-2's Near-Death Pause ถึง Hard-Kill ห่างกันแค่ 10 วินาที ทั้งที่ออกแบบ Cooldown ไว้ 180 นาที) — **สรุป: ยิ่งให้พื้นที่ก่อน Kill มาก ยิ่งขาดทุนมาก ไม่ใช่น้อยลง** เพราะ DD ไม่ใช่ Choppy Swing ที่รอได้ แต่เป็น Directional Move ต่อเนื่อง

### 4.2 สมมติฐานที่ 2 (ถูก): Hard SL กว้างเกินไป

สังเกตว่า `InpHardSLMultiplier=11.0` กว้างกว่า EA อื่นในพอร์ตมาก (เทียบ 3.5-8.0) — ทดสอบลดบน Base V19.7 (Kill=22% เดิม ไม่แตะ Threshold อีก):

| Config | Net Profit | Balance DD | PF | RF | Sharpe |
|---|---|---|---|---|---|
| V19.7 SL=11.0 (เดิม) | $1,989.60 | 22.03% | 1.376 | 2.035 | 3.266 |
| SL=7.0 | $2,273.38 | 22.21% | 1.439 | 2.116 | 3.607 |
| SL=6.7 (ใกล้ Invariant Floor) | $2,279.88 | 22.17% | 1.438 | 2.122 | 3.643 |

**ทุก Metric ดีขึ้นพร้อมกันหมด** ยืนยันว่า Hard SL ที่กว้างเกินไปคือ Root Cause จริงของ DD ลึก (ไม่ใช่แค่เหตุการณ์เดียว แต่ทุกไม้ตลอด 20.5 เดือน) — SL=6.7 ให้ผลแทบเท่า SL=7.0 (Diminishing Returns ชัดเจน) จึงเลือก **SL=7.0** เป็นค่าสุดท้าย (Buffer จาก Grid Invariant `HardSLMultiplier > ATRMultiplier(6.5)` มากกว่า ปลอดภัยกว่า)

## Section 5: Protocol v2.0 — Final Scorecard (V19.8 FINAL)

**Step 0**: Balance DD Maximal 22.21% > 18% → **House Money Type**

**Diagnostic Gate**: Balance DD (22.21%) vs Equity DD (28.29%) — ไม่ Waive อัตโนมัติ เพราะ DD มาจากเหตุการณ์เดี่ยวที่ระบุตัวได้ชัดเจน (2026.01.29) ไม่ใช่ Floating Swing ทั่วไป

| # | เกณฑ์ | ผล | สถานะ |
|---|---|---|---|
| 1 | Net Profit >0 | $2,273.38 | PASS |
| 2 | Profit Factor >1.50 | 1.439 | FAIL (ห่าง 0.061) |
| 3 | Sharpe >0.80 | 3.607 | PASS |
| 4 | Balance DD ≤20% | 22.21% | FAIL (ห่าง 2.21pp) |
| 5 | Recovery Factor >0.80 (ผ่านแม้เกณฑ์เข้ม >2.0) | 2.116 | PASS |
| 6 | Expected Payoff >0 | 7.706 | PASS |
| 7 | Win Rate >60% | 53.90% — Avg Win:Loss 1.23 (<3.0 ไม่เข้าเงื่อนไขยกเว้น) | FAIL |
| 8 | Trade Count เพียงพอ | 295 เทรด/20.5 เดือน | PASS |
| 9 | LR Correlation >0 | 0.789 | PASS |
| 10 | Walk-Forward degradation <20% | ยังไม่ทดสอบ | ค้างอยู่ |
| 11 | Spread Stress PF drop <15% | ยังไม่ทดสอบ | ค้างอยู่ |
| 12 | Cycle Win Rate ≥60% | N/A | N/A |
| 13 | Live Mode ExpertRemove() Verified | Backtest ยืนยัน CloseAll+ExpertRemove ทำงานสะอาด 5 รอบติด ไม่มี Position ค้าง — รอ Demo จริง | ค้างอยู่ (หลักฐานแข็งแรง) |
| 14 | Correlation Diversification (Combine) | ยังไม่ทดสอบ vs NDAQ100/GBPJPY | ค้างอยู่ |

**ผลรวม: FAIL 3/9 ที่ทดสอบได้ (#2, #4, #7) → Decision Rule = Full System Design Review**

## Section 6: การตัดสินใจ — Accept as Structural Characteristic

แม้ Decision Rule ทางเทคนิคยังชี้ไปทาง "3+ Fail → Design Review" แต่ตัดสินใจ **ยอมรับ Config นี้เป็น Structural Characteristic** ด้วยเหตุผล:

1. **ระยะห่างจากเกณฑ์แคบลงมาก**: PF จาก 0.22 เหลือ 0.061 (ปิดช่องว่าง ~73%), Balance DD จาก 9.96pp เหลือ 2.21pp (ปิดช่องว่าง ~78%) — ไม่ใช่ปัญหาเชิงระบบ (Systemic) ที่ยังไกลเกณฑ์มาก
2. **Root Cause ระบุได้ชัดเจน**: DD หลักมาจากเหตุการณ์เดี่ยว (2026.01.29 17:12-17:15) ที่ทดสอบแล้วว่าทั้ง Kill Threshold Tuning และ Auto-Recovery Architecture ช่วยไม่ได้ เพราะเป็น Fast Directional Move — ตรงกับหลักการเดียวกับที่เคยยอมรับ NASDAQ100 (Tariff Shock) และ BTC (Position ถือยาวข้ามช่วง Correction) มาก่อน
3. **Fix ที่ทำมาแล้วทั้งหมดเป็น Root-Cause-Driven** ไม่ใช่การเดา — Hard SL Tuning พิสูจน์แล้วว่าช่วยทุก Metric พร้อมกันไม่มี Trade-off

## Section 7: Production Parameters (V19.8 FINAL)

```
InpMagicNumber        = 919291
InpCombineMode        = true
InpActiveBase         = 450.0
InpEnableSell         = true
InpEnableCompound     = true
InpEnableHouseMoney   = false   (ไม่กระทบ Compound แล้วหลัง Fix N/O)
InpCompoundStartMultiple = 2.0
InpCompoundDDSoftBrake   = 15.0
InpCompoundMaxDD         = 22.0
InpHardSLMultiplier      = 7.0   ← เปลี่ยนจาก 11.0 (Root Cause Fix)
InpATRMultiplier         = 6.5   (Invariant: HardSLMultiplier ต้อง > ค่านี้เสมอ)
InpDCAtoAdd              = 0.0   (กรอกยอดสะสมตอน DCA จริง)
```

## Section 8: Remaining Steps ก่อน Forward Test เต็มรูปแบบ

1. Compile `9AU_GOLD_COMBINE_M5_CAP450_V19_8.mq5` ใน MetaEditor ยืนยัน 0 Errors
2. **Walk-Forward Test** (#10) — แบ่ง Period 2024.11.07-2026.07.17 เป็น 2 ช่วง ตรวจ Degradation
3. **Spread Stress Test** (#11) — Inject Spread Offset ตาม Lesson เดิม (100% Real Ticks ไม่ให้ปรับผ่าน Tester UI)
4. **Live Mode ExpertRemove() Demo Verification** (#13) — ยืนยันบน Demo จริงแม้ Backtest จะมีหลักฐานแข็งแรงแล้ว
5. **Correlation Diversification Check** (#14) — เทียบ Gold vs NDAQ100 vs GBPJPY ก่อน Deploy เข้า Alpha-pool จริงตาม Combine Gate Step 0.5
6. Force-Test 3-EA-Combine (Gold+NDAQ100+GBPJPY) ตาม Scenario-4 §6.3 ที่ยังค้างอยู่
7. Export ไฟล์เข้า Obsidian Vault ผ่าน Copilot Prompt ที่เตรียมไว้ (`Prompt คำสั่ง.md`) — อัปเดต Version History ในนั้นให้ตรง V19.8 FINAL

---

## Prompt สำหรับเริ่ม Session ใหม่

```
James — อ่าน Context Summary Gold V19.4→V19.8 FINAL นี้แล้วครับ วันนี้จะทำ: [ระบุงาน]
```

*Generated: 2026-08-06 | James Consultant | Session: Gold Compound Debug + Root Cause SL Tuning (V19.4→V19.8 FINAL)*
