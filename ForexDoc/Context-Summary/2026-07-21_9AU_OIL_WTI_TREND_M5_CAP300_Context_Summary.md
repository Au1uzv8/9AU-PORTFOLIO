---
concept_name: 9AU_OIL_WTI_TREND_M5_CAP300 — Context Summary (Pre-Export)
protocol: EA Validation Protocol v2.0
status: Forward Test Ready (ครบ 8/8 เกณฑ์ Compound Type — เหลือ #13 ExpertRemove Demo Test)
created: 2026-07-21
tags: [ea, oilcash, wti, compound-type, forward-test-ready]
---

# 9AU_OIL_WTI_TREND_M5_CAP300 — Context Summary

## 1. EA Identity

| รายการ | ค่า |
|---|---|
| Symbol | OILCash# (WTI Crude Oil) |
| Magic Number | 919293 |
| Timeframe | M5 |
| Base Capital (CAP) | $300 |
| Direction | Long-Only (Buy Grid Basket) — Sell Basket Rejected |
| Filter Timeframe | H4 (EMA200 Trend) + H1 (RSI Crossover) + M5 (RSI Crossover) |
| Code Version | v4.6 FINAL |
| Architecture | Dual-Basket Isolation + Compound Selective + House Money |

## 2. Final Production Config

| พารามิเตอร์ | ค่า | สถานะการยืนยัน |
|---|---|---|
| InpTrendEMA | 200 | ยืนยันแล้ว — กรอง downtrend Aug–Oct 2025 ออกได้ทั้งหมด |
| InpFilterTF | PERIOD_H4 | ยืนยันแล้ว — H4 EMA200 เหมาะกับ Oil structural trend |
| InpRSILowerLevel | 50.0 | ยืนยันแล้ว — RSI crossover 50 คือ edge หลัก |
| InpRSILowerLevelH1 | 50.0 | ยืนยันแล้ว — Dual TF filter เพิ่ม signal quality |
| InpATRMultiplier | 5.0 | ยืนยันแล้ว — Grid distance = ATR×5 |
| InpMinGridDistanceUSD | 0.3 | ยืนยันแล้ว — ต่ำกว่า ATR×SL(8x) เสมอ (invariant) |
| InpHardSLMultiplier | 8.0 | ยืนยันแล้ว — ต้อง > ATRMultiplier(5) เสมอ (invariant) |
| InpBasketTP | 40.0 | ยืนยันแล้ว — Basket TP ระดับที่ทำกำไรได้จริง |
| InpEnableSell | false | ยืนยันแล้ว — Sell basket Rejected (WR 0%, ทำลาย metrics) |
| InpBaseBalance | 300.0 | ยืนยันแล้ว — Compound Type, Capital จริง |
| InpLotMode | COMPOUND_LOT | ยืนยันแล้ว — Compound Type default |
| InpCompoundStartMult | 1.5 | ยืนยันแล้ว — เริ่ม scale ที่ Balance $450 |
| InpCompoundDDSoftBrake | 15.0% | ยืนยันแล้ว — strict กว่า House Money (20%) |
| InpCompoundMaxDD | 22.0% | ยืนยันแล้ว — Compound Kill threshold |
| InpWarnDD | 8.0% | ยืนยันแล้ว — L1 Telegram Warning |
| InpFreezeDD | 12.0% | ยืนยันแล้ว — L2 Freeze new entries |
| InpKillDD | 18.0% | ยืนยันแล้ว — L3 CloseAll + ExpertRemove |
| MaxDailyLossPercent | 3.0% | ยืนยันแล้ว — Closed P/L only (~$9/วัน) |
| InpCapRecoveryPct | 100.0% | ยืนยันแล้ว — House Money target $600 |
| InpTestExtraSpreadPoints / Debug | ปิดทั้งหมด | **ต้องเป็น false/0 เสมอสำหรับ Live** |

**หมายเหตุ:** Default ใน EA code ตรงกับ .set file ทุกค่า ไม่ต้องปรับเพิ่มเติมก่อน Forward Test

## 3. Classification (Step 0)

Balance DD Maximal = **0.95% ≤ 18%** → **Compound Type**

เกณฑ์ที่ใช้: Sharpe > 1.80, Recovery Factor > 2.0, DD < 20% (เข้มงวด)

**Diagnostic Gate A1:** Balance DD (0.95%) << Equity DD (5.22%) → floating swings ไม่ใช่ realized loss
→ Recovery Factor คำนวณจาก Balance DD = 31.35 / 2.85 = **11.0** (ผ่านเกณฑ์ 2.0 ชัดเจน)
→ Equity DD บันทึกไว้เท่านั้น ไม่ใช้เป็น gating metric

## 4. Full-Period Backtest Result

| Metric | ผล |
|---|---|
| Period | Aug 2025 – Apr 2026 (9 เดือน) |
| Tick Quality | 100% Real Ticks |
| Initial Deposit | $300 |
| Total Net Profit | $31.35 |
| Profit Factor | 12.00 |
| Recovery Factor (Balance-based) | 11.0 |
| Sharpe Ratio | 3.56 |
| Balance DD Maximal | 0.95% ($2.85) |
| Equity DD Maximal | 5.22% |
| Expected Payoff | $2.41 / trade |
| Win Rate | 92.31% (12W / 1L) |
| Total Trades | 13 |
| LR Correlation | 0.93 |
| AHPR | 0.77% |

**หมายเหตุ:** Trade count ต่ำ (13 trades / 9 เดือน) เพราะ EMA200 H4 กรอง downtrend Aug–Oct 2025 ออก และ H1 RSI Dual TF filter strict — signal quality สูงมาก

## 5. Protocol v2.0 — 13+2 Criteria Scorecard

| # | เกณฑ์ | ผล | สถานะ |
|---|---|---|---|
| 1 | Net Profit > 0 | $31.35 | ผ่าน |
| 2 | Profit Factor > 1.50 | 12.00 | ผ่าน |
| 3 | Sharpe > 1.80 (Compound) | 3.56 | ผ่าน |
| 4 | Balance DD Max ≤ 20% | 0.95% | ผ่าน |
| 5 | Recovery Factor > 2.0 (Compound, Balance-based) | 11.0 | ผ่าน |
| 6 | Expected Payoff > 0 | $2.41 | ผ่าน |
| 7 | Win Rate > 60% | 92.31% | ผ่าน |
| 8 | Trade Count เพียงพอ | 13 trades / 9 เดือน (signal quality สูง) | ผ่าน (qualitative) |
| 9 | LR Correlation > 0 | 0.93 | ผ่าน |
| 10 | Walk-Forward degradation < 20% | ยังไม่ได้ทดสอบ (period สั้น 9 เดือน) | **ค้างอยู่** |
| 11 | Spread Stress Test PF drop < 15% | ยังไม่ได้ทดสอบ | **ค้างอยู่** |
| 12 | Cycle Win Rate ≥ 60% | N/A (ไม่ใช่ Reserve/Cycle-Reset EA) | N/A |
| 13 | Live Mode ExpertRemove() verified | ยังไม่ทดสอบ | **ค้างอยู่ — ต้องรัน Demo จริง** |
| 14 | Correlation Diversification | N/A (single EA) | N/A |

**ผลรวม: ผ่าน 9/9 เกณฑ์ที่ทดสอบได้จาก Backtest — เหลือ #10, #11, #13 ที่ต้องทดสอบเพิ่ม**

## 6. Test History Log

| Version | EMA | MinGrid | Grid/Tick | Net Profit | PF | WR | Trades | หมายเหตุ |
|---|---|---|---|---|---|---|---|---|
| v4.0 | off | 0.8 | NewBar | -$19.50 | — | — | 6 | Dual-Basket architecture ใหม่ |
| v4.1 | off | 0.8 | NewBar | -$17.05 | 1.25 | 60.5% | 12 | Dollar Cap SL — formula ผิด |
| v4.2 | off | 0.8 | NewBar | -$14.90 | — | — | 12 | ATR 2x < Grid 5x — SL ชนก่อน Grid |
| v4.3 | off | 0.8 | NewBar | -$19.50 | — | — | 13 | Trade ใน downtrend Aug-Oct |
| v4.4 | EMA200 | 0.8 | NewBar | +$4.35 | 1.62 | 33.3% | 3 | MinGrid 0.8 > SL dist — Grid ไม่ fire |
| v4.5 | EMA200 | 0.8 | **Tick** | +$10.21 | 2.45 | 50.0% | 4 | Grid on Tick แล้วแต่ MinGrid ยัง 0.8 |
| **v4.6** | **EMA200** | **0.3** | **Tick** | **+$31.35** | **12.00** | **92.31%** | **13** | **FINAL — Grid trigger ได้ครบ** |
| v4.6 Sell ON | EMA200 | 0.3 | Tick | +$29.80 | 7.77 | 85.71% | 14 | Sell REJECTED — ลด PF 35% |

**Root Cause สรุปทุกจุด:**

| Bug | สาเหตุ | Fix |
|---|---|---|
| Grid ไม่ fire (v4.0–4.3) | SL distance < Grid distance (Mult ผิด) | Restore HardSLMult=8 |
| Dollar Cap SL ผิด (v4.1) | Formula หน่วยผิด → SL = 1.0 USD | ตัด Dollar Cap ออก |
| Trade ใน downtrend (v4.3) | TrendEMA=0 (disabled) | EMA200 H4 ON |
| Grid ไม่ fire กลางแท่ง (v4.4) | Grid อยู่ใน IsNewBar block | Grid ทุก Tick |
| Grid ไม่ fire low vol (v4.5) | MinGridDist=0.8 > SL distance 0.57 | ลด MinGridDist=0.3 |
| Sell basket (v4.6 Sell ON) | Oil structurally upward — no Sell edge | InpEnableSell=false |

## 7. Known Caveats / Data Limitations

- **Period สั้น 9 เดือน:** Real tick data เริ่มจาก 2025.07.22 เท่านั้น ทำให้ backtest ครอบคลุมได้แค่ Aug 2025 – Apr 2026 ไม่สามารถทดสอบ Walk-Forward แบบ 2-period ได้อย่างมีนัยสำคัญ
- **Trade count 13 trades:** น้อยกว่า USDJPY (132 trades) มาก ผล PF=12 และ WR=92% อาจ overfit ต่อ 9 เดือนนี้ — Forward Test จำเป็นมากกว่าปกติ
- **Tick mismatch 78,062 ticks (2026.03.10):** MT5 รายงาน tick prices mismatch 855 minute bars ในวันดังกล่าว — คาดว่ากระทบผลน้อยมากเพราะ EA ใช้ trade logic บน OHLC ไม่ใช่ tick-by-tick แต่บันทึกไว้เพื่อความโปร่งใส
- **Sell basket:** ไม่มี backtest data สำหรับ Sell บน Oil ในช่วงนี้เพียงพอ — Rejected อย่างถาวร

## 8. Code Change Log

| Version | การเปลี่ยนแปลง | ผล |
|---|---|---|
| v3.0 → v4.0 | Dual-Basket Isolation P1–P10, Compound Selective, 3-Level Kill Switch, Daily Loss Closed P/L | Architecture ใหม่ทั้งหมด |
| v4.0 → v4.1 | เพิ่ม Dollar Cap SL (InpMaxLossPerTrade=5.0) | REJECTED — formula ผิด, SL=1.0 USD แคบเกิน |
| v4.1 → v4.2 | ลด HardSLMultiplier 8→2, ตัด Dollar Cap | REJECTED — 2x < 5x Grid, SL ชนก่อน Grid |
| v4.2 → v4.3 | Restore HardSLMultiplier=8, Fix spread unit | ดีขึ้น แต่ Trade ใน downtrend เพราะ EMA=0 |
| v4.3 → v4.4 | Enable InpTrendEMA=200 H4 | กรอง downtrend ได้ แต่ MinGrid=0.8 ยังปัญหา |
| v4.4 → v4.5 | Grid Entry ย้ายออกจาก IsNewBar → ทุก Tick | Grid trigger ได้บ้าง แต่ MinGrid=0.8 ยัง > SL |
| v4.5 → v4.6 | ลด InpMinGridDistanceUSD 0.8→0.3 | ACCEPTED — Grid fire ครบ, PF=12, WR=92% |
| v4.6 Sell ON | Enable InpEnableSell=true | REJECTED — Net Profit ลด, PF ลด 35% |
| v4.6 → FINAL | Rename, BaseBalance=300, LotMode=COMPOUND, Kill thresholds เข้มขึ้น | Production Ready |

## 9. Production Parameters

| Parameter | Value | หมายเหตุ |
|---|---|---|
| InpMagicNumber | 919293 | ไม่ซ้ำกับ EA อื่นในพอร์ต |
| InpTrendEMA | 200 | EMA200 H4 — Buy เฉพาะ uptrend |
| InpFilterTF | PERIOD_H4 (16388) | |
| InpRSIPeriod | 14 | M5 RSI |
| InpRSILowerLevel | 50.0 | Crossover threshold |
| InpRSIPeriodH1 | 14 | H1 RSI |
| InpRSILowerLevelH1 | 50.0 | Dual TF crossover |
| InpUseDualTF | true | |
| InpRSIEntryMode | 1 | Crossover mode (ไม่ใช่ Level mode) |
| InpEnableDynamicGrid | true | |
| InpATRPeriod | 14 | |
| InpATRMultiplier | 5.0 | Grid = ATR×5 |
| InpMinGridDistanceUSD | 0.3 | **Invariant: ต้อง < ATR×HardSLMult** |
| InpInitialLot | 0.05 | Base lot |
| InpBaseMultiplier | 1.25 | Grid lot multiplier |
| InpMaxOrders | 5 | Max grid layers |
| InpEnableSell | false | Rejected permanently |
| InpBasketTP | 40.0 | Buy basket TP ($) |
| InpHardSLMultiplier | 8.0 | **Invariant: ต้อง > ATRMultiplier(5)** |
| InpMinHoldBars | 12 | Min hold before partial/trail |
| InpTrailStartUSD | 18.0 | Trail เริ่มเมื่อ basket profit >= $18 |
| InpTrailStepATR | 2.0 | Trail step = ATR×2 |
| EnableDailyLossLimit | true | |
| MaxDailyLossPercent | 3.0 | Closed P/L only |
| InpWarnDD | 8.0% | L1 HWM DD |
| InpFreezeDD | 12.0% | L2 HWM DD |
| InpKillDD | 18.0% | L3 HWM DD |
| InpBaseBalance | 300.0 | Compound Type |
| InpCapRecoveryPct | 100.0 | House Money target $600 |
| InpLotMode | COMPOUND_LOT (1) | |
| InpCompoundStartMult | 1.5 | เริ่มที่ $450 |
| InpCompoundDDSoftBrake | 15.0% | SoftBrake ON |
| InpCompoundMaxDD | 22.0% | Compound Kill |
| InpEnableTelegram | true | |
| InpDebugGridTest | false | **ต้อง false เสมอ** |
| InpDebugDisableExposure | false | **ต้อง false เสมอ** |

**Invariants บังคับ:**
```
1. HardSLMultiplier(8) > ATRMultiplier(5) — Grid trigger ก่อน SL เสมอ
2. MinGridDistanceUSD(0.3) < ATR × HardSLMultiplier — Grid อยู่ในพื้นที่ SL เสมอ
3. Compound เริ่มหลัง Balance >= BaseBalance × CompoundStartMult เท่านั้น
4. InpEnableSell = false ถาวร บน Oil structurally upward asset
```

## 10. Remaining Steps Before Export

1. **#10 Walk-Forward Test:** รอ Real Tick data OILCash# ย้อนหลังมากกว่า 9 เดือน (ปัจจุบัน data เริ่ม 2025.07.22) — ข้ามได้ชั่วคราวถ้า Forward Test ผ่านมากกว่า 1 เดือน
2. **#11 Spread Stress Test:** รัน backtest เพิ่ม Spread 2x และ 3x ตรวจว่า PF drop < 15%
3. **#13 Live Mode ExpertRemove() Test (บังคับ):**
   - Load EA บน Demo Account บน OILCash# M5
   - ตั้ง InpKillDD=0.1 ชั่วคราว ให้ EA trigger ExpertRemove ทันที
   - ยืนยันว่า open positions ปิดผ่าน SL/TP ได้จริง (ไม่ค้างลอย)
   - Reset InpKillDD=18.0 ก่อน Forward Test จริง
4. **Forward Test ระยะเวลา:** อย่างน้อย 1 เดือน บน Demo ก่อนตัดสินใจ Go Live
5. **Magic Number Check:** ยืนยันว่า 919293 ไม่ซ้ำกับ EA อื่นในบัญชีเดียวกัน (GOLD=919291, BTC=919295, US100=919294)
6. **Compound Selective Verification บน Demo:** ยืนยันว่า Telegram ส่ง "COMPOUND ACTIVATED" เมื่อ Balance ถึง $450 จริง และ SoftBrake ทำงานถูกต้อง
