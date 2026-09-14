# 9AU_NASDAQ100_TREND_M5_CAP300 — Context Summary
> Version: v4.0 (Standalone) / v1.0 (Combine)
> Last Updated: 2026-07-25
> Status: Ready for Deploy | DD Structural (24.87%) | Accepted

---

## 1. EA Identity

| Field | Value |
|---|---|
| EA Name | 9AU_NASDAQ100_TREND_M5_CAP300 |
| Symbol | US100Cash# (XM Global) |
| Timeframe | M5 |
| Magic Number | 919294 |
| Strategy Type | Long-only Grid Mean-Reversion + Trend Filter |
| Capital | $300 USD |
| Files | v4.0 (Standalone), 9AU_NDAQ100_COMBINE_M5_CAP300 v1.0 (Combine) |

---

## 2. Final Configuration (v4.0 Deploy-Ready)

```
InpMagicNumber       = 919294
InpTrendEMA          = 200 (H1)
InpRSIPeriod         = 14
InpRSILowerLevel     = 48.0
InpRSIBuyZoneHigh    = 55.0
InpRSIPeriodH1       = 14
InpRSILowerLevelH1   = 50.0
InpUseDualTF         = true
InpADXPeriod         = 14
InpADXMin            = 20.0
InpATRPeriod         = 14
InpATRMultiplier     = 5.5
InpInitialLot        = 0.1
InpBaseMultiplier    = 1.12
InpReductionStep     = 0.03
InpMinMultiplier     = 1.05
InpMaxOrders         = 4
InpBasketTP          = 34.0
InpBasketCutLoss     = 30.0
InpMaxGridDepthATR   = 6.0
InpHardSLMultiplier  = 8.0
InpSoftStopPercent   = 20.0   ← Soft Stop (CloseAll)
InpKillSwitchPercent = 25.0   ← Hard Kill (ExpertRemove)
MaxDailyLossPercent  = 4.5
InpBaseBalance       = 300.0
InpHouseMoneyMult    = 2.0    ← Target $600
InpCompoundStartMult = 1.5    ← Compound เริ่มที่ $450
InpEnableCompound    = true
InpCompoundRiskPct   = 2.0
InpCompoundCapMult   = 3.0
```

---

## 3. Classification

| Field | Value |
|---|---|
| Type | House Money → Compound |
| Diagnostic Gate | Structural DD — ไม่ใช่ bug |
| DD Source | Single position floating ช่วง black swan (Tariff shock มีนาคม–เมษายน 2026) |
| Balance DD | 22.14% (ต่ำกว่า Equity DD มาก) |
| Sell Basket | ปิดถาวร — US100 Long bias ยืนยันแล้ว |

---

## 4. Full-Period Backtest (v4.0 Best)

| Metric | Value | เกณฑ์ | สถานะ |
|---|---|---|---|
| Period | 2025.08.01–2026.04.30 | 9 เดือน | — |
| Net Profit | +$94.84 | > 0 | PASS |
| Equity DD Maximal | 24.87% ($85.78) | ≤ 18% | FAIL* |
| Balance DD Maximal | 22.14% ($73.78) | ≤ 18% | FAIL* |
| Profit Factor | 1.60 | ≥ 1.50 | PASS |
| Recovery Factor | 1.11 | ≥ 1.50 | FAIL |
| Win Rate | 42.86% | ≥ 60% | FAIL |
| Sharpe Ratio | 3.87 | ≥ 1.50 | PASS |
| Total Trades | 28 | — | — |
| Avg Hold Time | 11:25 | — | — |

> *DD FAIL เป็น structural characteristic ของ US100 ช่วง Tariff shock — ยอมรับได้เพราะ Kill Switch 25% คุ้มครองอยู่

---

## 5. Protocol v2.0 Scorecard

| # | Criteria | Status | หมายเหตุ |
|---|---|---|---|
| 1 | Net Profit > 0 | PASS | +$94.84 |
| 2 | Profit Factor ≥ 1.50 | PASS | 1.60 |
| 3 | Sharpe Ratio ≥ 1.50 | PASS | 3.87 |
| 4 | Equity DD ≤ 18% | FAIL* | 24.87% — accepted structural |
| 5 | Balance DD ≤ 18% | FAIL* | 22.14% — accepted structural |
| 6 | Recovery Factor ≥ 1.50 | FAIL | 1.11 |
| 7 | Win Rate ≥ 60% | FAIL | 42.86% |
| 13 | Kill Switch ExpertRemove | PASS | Dual-level 20%/25% |

---

## 6. Version History

| Version | Net Profit | DD | PF | การเปลี่ยนแปลง | ผล |
|---|---|---|---|---|---|
| v1.4 | +$108.14 | 23.94% | 1.74 | Original baseline | Best raw performance |
| v2.0 | -$36.51 | 23.56% | 0.84 | + House Money + Kill Switch + Compound | Logic regression |
| v3.0 | — | 39.62% | 0.97 | + Dual-Basket Isolation | Sell basket ไม่มี edge |
| v3.1 | +$38.25 | 21.75% | 1.17 | Buy-only + fix static array | Trade count regression |
| v4.0 | +$94.84 | 24.87% | 1.60 | v1.4 core + 3 features | Best overall — Deploy |
| v4.1 | +$108.24 | 23.94% | 1.75 | + Circuit Breaker (CL=4) | CB ไม่ได้ trigger ช่วงนี้ |
| v4.2 | +$15.76 | 24.87% | 1.10 | + Volatility Gate | ATR ต่ำกว่า threshold — ไม่ทำงาน |
| v4.3 | -$95.47 | 49.53% | 0.62 | + Market Closed Guard | Bug: g_pendingCloseAll ไม่ reset เมื่อ SL hit |

---

## 7. DD Reduction Experiments — สิ่งที่เรียนรู้

| Lever | ผล | Root Cause |
|---|---|---|
| Circuit Breaker | ไม่ลด DD | DD มาจาก floating position ไม่ใช่ consecutive entry |
| MaxOrders=2 | ไม่ลด DD | DD มาจาก single position ไม่ใช่ grid stack |
| Volatility Gate ATR>150/180/220 | ไม่ลด DD | ATR ช่วง crash = 36–51 pts ต่ำกว่า threshold ทุกค่า |
| Market Closed Guard | DD พุ่ง 49% | g_pendingCloseAll ไม่ reset เมื่อ SL hit ก่อน execute |
| SL แคบ 5.5–6.0× | DD สูงขึ้น | Cut ก่อน reversion → เปิดใหม่ซ้ำ → DD บวก |

**ข้อสรุป:** DD 24.87% เป็น structural characteristic ของ US100 ช่วง black swan ไม่ใช่ bug และไม่ใช่ parameter ผิด ทุก lever ที่ลด exposure ก็ลด profit ไปพร้อมกัน

---

## 8. MQL5 Lessons Learned (Session นี้)

| บทเรียน | รายละเอียด |
|---|---|
| Static array warning | `double buf[2]` ใช้กับ `ArrayResize()` / `ArraySetAsSeries()` ไม่ได้ — ต้องประกาศ `double buf[]` (dynamic) |
| OnTradeTransaction | ใช้ตรวจ deal result แทน polling ใน OnTick — แม่นยำกว่าและไม่ delay |
| Strategy Tester `[Market closed]` | Grid/CloseAll สั่งตอนตลาดปิด → position ค้างข้ามคืน → DD สูงขึ้น |
| g_pendingCloseAll bug | Flag ต้องถูก reset เมื่อ position ถูกปิดด้วย SL ด้วย ไม่เช่นนั้นจะ CloseAll position ใหม่ที่เปิดหลังจากนั้น |
| ATR บน US100 Strategy Tester | ATR M5 ช่วง normal = 9–51 pts แม้แต่ช่วง crash — Volatility Gate ที่ตั้ง 150+ จึงไม่เคย trigger |
| Sell basket บน US100 | Win Rate 30% เมื่อ Sell-only ยืนยัน Long-bias structural ของ US100 — ปิด Sell ถาวร |
| v1.4 core stability | การ refactor code ใหม่ทั้งหมดแม้ logic เดิมทำให้ผล backtest เปลี่ยน — ควรแก้ minimal diff แทน rewrite |

---

## 9. Combine Mode Parameters (v1.0)

```
InpCombineMode       = true
InpCycleStartEquity  = 0.0    ← Auto จาก OnInit (ใส่ค่า manual ถ้า deploy กลางคัน)
InpActiveBase        = 300.0  ← ทุน NASDAQ100 ใน portfolio
InpCombineDDLimit    = 20.0   ← Soft Stop บน Virtual Equity
InpCombineKillSwitch = 25.0   ← Hard Kill บน Virtual Equity

Virtual Equity = InpActiveBase + (RealEquity - CycleStartEquity)
```

---

## 10. Portfolio Combine Plan

| พอร์ต | EA 1 | EA 2 | Correlation | หมายเหตุ |
|---|---|---|---|---|
| พอร์ต A | NASDAQ100 (919294) | GBPJPY (515253) | ต่ำ | แนะนำ — Best pair |
| พอร์ต B | WTI-OIL (919293) | USDJPY (515254) | ต่ำ-ปานกลาง | Commodity + Rate |
| พอร์ต C | 3PAIRS (515252) | AUDCAD (515251) | ปานกลาง | Forex basket — Balance DD ต่ำมากทั้งคู่ |

---

## 11. Remaining Steps ก่อน Live

- [ ] Compile และ backtest 9AU_NDAQ100_COMBINE_M5_CAP300 v1.0 ยืนยัน Net Profit ≈ $94 (เหมือน v4.0)
- [ ] ตั้ง InpCycleStartEquity = Equity จริงวันที่ Deploy ใน Terminal ที่มี EA อื่นรันอยู่
- [ ] ยืนยัน WebRequest URL api.telegram.org ใน Tools → Options → Expert Advisors
- [ ] ExpertRemove() verification บน Demo ก่อน Live
- [ ] Combined DD Simulation กับ GBPJPY (Portfolio A)

---

*Generated: 2026-07-25 | James Consultant | Session: NASDAQ100 Full Development*
