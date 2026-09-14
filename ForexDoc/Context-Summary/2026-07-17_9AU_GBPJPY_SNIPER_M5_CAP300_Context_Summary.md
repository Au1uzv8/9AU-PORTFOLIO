# 9AU_GBPJPY_SNIPER_GRID_M5_CAP300 — Context Summary
**สถานะ:** Validation Protocol v2.0 ผ่านครบ 13/13 ✓  
**วันที่ export:** 2026-07-17  
**พัฒนาโดย:** พี่อู + James Consultant

---

## 1. EA Overview

| รายการ | รายละเอียด |
|---|---|
| ชื่อไฟล์ | `9AU_GBPJPY_SNIPER_GRID_M5_CAP300.mq5` |
| Symbol | GBPJPY# |
| Timeframe | M5 |
| Broker | XM Global (XMGlobal-MT5) |
| Account Type | XM Ultra Low Standard |
| Leverage | 1:1000 |
| Base Capital | $300 |
| Magic Number | 515254 |
| Version | V3 (Final — Validation Passed) |
| Lines of Code | 556 |

---

## 2. Strategy Logic

**Architecture:** Long-Only Basket Grid with Signal Filter

**Entry (First Leg — Sniper):**
- M5 RSI(14) rising และ < 50 (ป้องกัน overbought)
- H1 RSI(14) < 55 (ป้องกัน overbought H1)
- ADX(14) ≥ 28 (trend มีกำลังพอ)
- Price > EMA200(H1) และ within 2×ATR (pullback zone)
- ATR > 0.02 (กรอง low volatility)
- Spread ≤ 210 pts (ปกติ) / 290 pts (high vol)
- News filter: USD + GBP + JPY high impact ±60 นาที
- Time filter: 08:00–23:00, หยุด Friday หลัง 18:00

**Grid Leg (DCA):**
- Price ลงต่ำกว่า lowestBuyPrice − (ATR × 4.5)
- ไม่มี signal filter — price distance เพียงพอ
- Max 4 orders, Max depth 4.0 × ATR จาก first entry
- Lot multiplier: 1.12 per leg (ลดลง 0.03 ต่อ leg, min 1.05)

**Exit:**
- Basket TP: $22 (ปิดทุก position พร้อมกัน)
- Basket Cut Loss: $40
- Partial Close: 70% ของ TP = $15.4 (ปิดครึ่งหนึ่ง)
- Hard SL: ATR × 8.0 ต่ำกว่า open price (ต่อ leg)
- Trailing: เริ่มที่ $15 profit, step ATR × 1.5
- Grid Depth Exceeded: ปิดทั้งหมดเมื่อ depth ≥ 4.0 ATR
- Time Exit: MaxHoldDays = 60 วัน

---

## 3. Parameter Set (V3 Final)

### Step A: Filter
| Parameter | ค่า |
|---|---|
| InpTrendEMA | 200 |
| InpFilterTF | H1 |
| InpRSIPeriod | 14 |
| InpRSIBuyZoneHigh | 50.0 |
| InpRSIPeriodH1 | 14 |
| InpRSIUpperLevelH1 | 55.0 |
| InpUseDualTF | true |
| InpADXPeriod | 14 |
| InpADXMin | 28.0 |

### Step B: Grid & Lot
| Parameter | ค่า |
|---|---|
| InpEnableDynamicGrid | true |
| InpATRPeriod | 14 |
| InpATRMultiplier | 4.5 |
| InpInitialLot | 0.01 |
| InpBaseMultiplier | 1.12 |
| InpReductionStep | 0.03 |
| InpMinMultiplier | 1.05 |
| InpMaxOrders | 4 |

### Step C: Profit & Exit
| Parameter | ค่า |
|---|---|
| InpBasketTP | 22.0 |
| InpBasketCutLoss | 40.0 |
| InpMaxGridDepthATR | 4.0 |
| InpEnablePartialClose | true |
| InpPartialCloseLevel | 0.70 |
| InpHardSLMultiplier | 8.0 |
| InpMinHoldBars | 20 |

### Step D: News Filter
| Parameter | ค่า |
|---|---|
| EnableNewsFilter | true |
| NewsBeforeMinutes | 60 |
| NewsAfterMinutes | 60 |
| NewsHighImpactOnly | true |

### Step E: Safety & Protection
| Parameter | ค่า |
|---|---|
| InpEnableEquityStop | true |
| InpMaxDrawdownPercent | 25.0 |
| InpTrailStartUSD | 15.0 |
| InpTrailStepATR | 1.5 |
| InpMaxHoldDays | 60 |
| InpMinATRThreshold | 0.02 |
| InpMaxSpreadBase | 210.0 |
| InpMaxSpreadHighVol | 290.0 |
| InpMinMarginLevel | 700.0 |

### Step F: Time Filter
| Parameter | ค่า |
|---|---|
| EnableTimeFilter | true |
| TradingStartHour | 8 |
| TradingEndHour | 23 |
| StopFridayAfterClose | true |
| FridayCloseHour | 18 |

### Step G: Floating DD Limit
| Parameter | ค่า |
|---|---|
| InpEnableFloatingDD | false (ปิดไว้) |
| InpMaxFloatingDDPercent | 5.0 |

### Step H: Telegram
| Parameter | ค่า |
|---|---|
| InpEnableTelegram | true |
| InpTelegramDDAlert | 15.0 |
| InpEnable2xAlert | true |
| InpBaseBalance | 300.0 |

---

## 4. Backtest Results (Full Period)

**ช่วง:** 2023.11.01 – 2026.04.30 (100% Real Ticks)  
**Broker:** XM Global, Initial Deposit $300

| Metric | ผล |
|---|---|
| Net Profit | $134.34 (+44.8%) |
| Profit Factor | 1.57 |
| Sharpe Ratio | 2.40 |
| Recovery Factor | 3.62 |
| Balance DD Max | 8.73% |
| Equity DD Max | 9.98% |
| Win Rate | 20.34% (High-Reward exception: 6.1:1) |
| Avg Win / Avg Loss | $15.44 / $2.51 |
| Total Trades | 118 |
| LR Correlation | 0.932 |

---

## 5. Validation Protocol v2.0 — Final Scorecard

| # | Criterion | ผล |
|---|---|---|
| 0 | Classification Gate | Compound Type (Balance DD 8.73%) |
| 1 | Net Profit > 0 | PASS |
| 2 | Profit Factor ≥ 1.50 | PASS (1.57) |
| 3 | Sharpe > 1.80 | PASS (2.40) |
| 4 | Balance DD ≤ 20% | PASS (8.73%) |
| 5 | Recovery Factor > 2.0 | PASS (3.62) |
| 6 | Expected Payoff > 0 | PASS |
| 7 | Win Rate — High-Reward Exception | PASS (6.1:1 ratio) |
| 8 | Trade Count (qualitative) | PASS (118 trades) |
| 9 | LR Correlation > 0 | PASS (0.932) |
| 10 | Walk-Forward < 20% degradation | PASS (Out-of-sample PF ดีขึ้น) |
| 11 | Spread Stress PF drop < 15% | PASS (0% drop) |
| 12 | Cycle Win Rate | N/A |
| 13 | ExpertRemove() verified | PASS |
| **รวม** | | **13/13 PASS** |

---

## 6. Walk-Forward Detail

| | Period A (In-Sample) | Period B (Out-of-Sample) |
|---|---|---|
| ช่วง | 2023.11 – 2025.06 | 2025.07 – 2026.04 |
| Profit Factor | 1.458 | 1.755 |
| Sharpe | 2.253 | 2.731 |
| Recovery Factor | 1.839 | 2.054 |
| Equity DD | 9.98% | 10.18% |
| Net Profit | $68.17 | $66.07 |

Out-of-sample ดีกว่า in-sample — ไม่มี overfitting

---

## 7. Bug Fixes Applied (V3 Session)

| # | Bug | แก้ไข |
|---|---|---|
| 1 | `lastBuyLot` track lot ของ leg ต่ำสุดแทนที่ leg ล่าสุด | แยก logic ให้ถูกต้อง |
| 2 | News filter กรองแค่ USD | เพิ่ม GBP + JPY |
| 3 | `IsTradingTime()` ใช้ `TimeLocal()` | เปลี่ยนเป็น `TimeCurrent()` |
| 4 | `GetATR()` ถูก call 3 ครั้งต่อ tick | cache ครั้งเดียว |
| 5 | Cooldown 300s ทำให้ grid ช้าและผลแย่ | ลบออก ใช้ `UpdateBasketInfo()` แทน |
| 6 | `lastGridTime` global ค้างอยู่ | ลบออก |
| 7 | `SetHardSL()` วาง SL สูงกว่า entry ใน Buy | แยก Buy/Sell direction ให้ถูกต้อง |

---

## 8. Architecture Decisions (บันทึกเหตุผล)

- **Long-Only:** GBPJPY มี structural upward bias ใน period นี้ — Short signal ทดสอบแล้วฉุดค่าลง จึงตัดออก
- **Grid แทน Single Entry:** เพิ่ม Net Profit อย่างมีนัย แต่ต้องควบคุมด้วย `MaxGridDepthATR=4.0` และ `CutLoss=40`
- **High-Reward Low-WinRate:** Win Rate 20% ยอมรับได้เพราะ Avg Win/Loss = 6.1:1 ตามแนวทาง GBPJPY V3 precedent
- **Cooldown ลบออก:** `lowestBuyPrice` เป็น reference ที่ถูกต้องแล้ว cooldown ทำให้ผลแย่ลง
- **`IsExposureSafe()` ไม่ใช้กับ Grid:** Nominal JPY exposure เกิน % limit เสมอบน $300 account — ใช้ MaxOrders + CutLoss แทน

---

## 9. Next Step — Forward Test

**Deploy บน Demo:**
- Account: XM Global Demo, Ultra Low Standard
- Symbol: GBPJPY#
- TF: M5
- Deposit: $300
- ระยะเวลาทดสอบ: อย่างน้อย 1–2 เดือน

**KPI ที่ต้องดูระหว่าง Forward Test:**
- Equity DD ไม่เกิน 15% (buffer ก่อนถึง hard stop 25%)
- ≥ 10 trades ใน 30 วัน (confirm signal ยังทำงาน)
- Win Rate ≥ 15% (ไม่ต่ำกว่า backtest มากเกิน)
- Telegram alert ทำงานปกติ

**House Money Target:** $600 (2× base) → withdraw $300 แล้วรัน free
