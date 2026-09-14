---
ea_name: "9AU_GOLD_ADAPTIVE_REGIME_M5_CAP450"
version: "v19.3"
instrument: "GOLD#"
timeframe: "M5"
capital: 450
magic_number: 919291
broker: "XMGlobal-MT5 7 (Build 5836)"
leverage: "1:1000"
base_code: "9AU_GOLD_TREND_ATR_FILTER_M5_CAP450 (V14 Buy-only baseline)"
backtest_period: "2023.10.02 - 2026.04.30"
history_quality: "100% real ticks"
session_date: "2026-06"
status: "Completed — Ready for Forward Test (HM=FALSE)"
tags: [GOLD, MQL5, DualBasket, RegimeFilter, CompoundLot, HouseMoney]
---

# EA Context Summary — 9AU GOLD ADAPTIVE REGIME v19.3

## สถานะปัจจุบัน

EA ต่อยอดจาก V14 Buy-only โดยเพิ่ม Dual-Basket Sell + Regime Classification
+ House Money Compound System ครบ architecture ตาม SKILL.md #5 ใน memory

## Instrument

GOLD# (XMGlobal) | digits=2 | contract size=100 | min_vol=0.01 | leverage 1:1000

## Architecture Overview

**Buy Entry (ไม่เปลี่ยนจาก V14):**
RSI < 42 + Close > EMA200 H4 → Sniper Buy 0.01 lot
Grid Buy ทุก ATR×6.5 จาก last entry | MaxOrders=5 | BasketTP=$18 | SL=11×ATR

**Sell Entry (เพิ่มใหม่ — Regime-gated):**
IsTrendDown(): ADX>28 + Slope<-(ATR×0.08) + Close<EMA200 + RSI 43–57
+ Layer 3: ATR >= AvgATR(50)×1.2 + Layer 4: price < Resistance(96bars)×0.997
Grid Sell ทุก ATR×9.75 | MaxOrders=5 | BasketTP=$16 | SL=3.5×ATR (แคบ)
EMA50<EMA200 เป็น optional bonus ไม่ใช่ hard requirement (Gold uptrend ยาวปี)

**Basket Isolation:**
buyBasketProfit / sellBasketProfit แยก tracking
basket.buyCount>0 → skip Sell block และ vice versa
CloseAllBuy() + return → Sell basket ทำงานต่อได้

**House Money & Compound:**
- FIXED mode: balance < BaseBalance×1.5 ($675)
- COMPOUND active: balance >= $675 → lot = 0.01×min(balance,HWM)/450
- SoftBrake ON: DD>=20% → lot กลับ Fixed ชั่วคราว
- SoftBrake OFF: DD<15% → lot กลับ Compound
- Kill Switch COMPOUND: DD>=28% → ExpertRemove()
- Kill Switch FIXED: DD>=25% → ExpertRemove()
- House Money Alert: balance>=$900 → Label blink + Telegram ทุก 1 ชม.

## Backtest Results

| Config | Net Profit | Equity DD | Sharpe | RF | WR Long | WR Short |
|---|---|---|---|---|---|---|
| V14 Buy-only | $1,627 | 25.15% | 1.57 | 2.33 | 65.48% | — |
| V19.3 HM=FALSE | $1,440 | **24.75%** | **1.99** | **2.39** | **67.43%** | 61.54% |
| V19.3 HM=TRUE | $2,291 | 33.89% | 2.20 | 1.63 | 53.17% | 40.00% |

**Recommended Deploy: HM=FALSE** — DD ผ่าน threshold, RF ผ่าน, full 2.6 ปีไม่โดน Kill Switch

## Concept การถอน/Compound

```
Max DD < 18%  → กลุ่ม Compound (รัน HM=TRUE ต่อเนื่อง)
Max DD 18-25% → กลุ่ม House Money (รัน HM=FALSE แล้ว Withdraw manual ที่ 2x)
Max DD > 25%  → Kill Switch → ExpertRemove() → ถอน EA ออก
```

ปัจจุบัน V19.3 อยู่กลุ่ม House Money (DD=24.75%) — รัน HM=FALSE จนถึง $900 แล้ว
Withdraw $450 กลับมา restart EA หรือ switch HM=TRUE ด้วย CompoundMaxDD=28%

## Default .set Parameters (HM=FALSE Deploy)

```
InpMagicNumber=919291
InpTrendEMA=200
InpFilterTF=16388
InpRSIPeriod=14
InpRSILowerLevel=42.0
InpRSIUpperLevel=68.0
InpEnableDynamicGrid=true
InpATRPeriod=14
InpATRMultiplier=6.5
InpInitialLot=0.01
InpBaseMultiplier=1.15
InpReductionStep=0.05
InpMinMultiplier=1.05
InpMaxOrders=5
InpEnableSell=true
InpSellInitialLot=0.01
InpSellATRMultiplier=9.75
InpSellBaseMultiplier=1.05
InpSellReductionStep=0.02
InpSellMinMultiplier=1.02
InpSellMaxOrders=5
InpSellBasketTP=16.0
InpSellHardSLMultiplier=3.5
InpSellTrailStartUSD=8.0
InpSellTrailStepATR=1.5
InpADXPeriod=14
InpADXTrendHigh=28.0
InpEMA50Period=50
InpEMASlopeATRMult=0.08
InpEMASlopeLookback=20
InpRSITrendLow=43.0
InpRSITrendHigh=57.0
InpSellMinATRMult=1.2
InpAvgATRPeriod=50
InpResistLookback=96
InpResistBuffer=0.003
InpBasketTP=18.0
InpEnablePartialClose=true
InpPartialCloseLevel=0.70
InpHardSLMultiplier=11.0
InpMinHoldBars=12
EnableNewsFilter=true
NewsBeforeMinutes=60
NewsAfterMinutes=60
NewsHighImpactOnly=true
InpEnableEquityStop=true
InpMaxDrawdownPercent=25.0
InpTrailStartUSD=12.0
InpTrailStepATR=2.5
InpMaxHoldDays=60
InpMinATRThreshold=3.5
InpMaxSpreadBase=35.0
InpMaxSpreadHighVol=40.0
InpMaxExposurePercent=12.5
InpMinMarginLevel=700.0
EnableTimeFilter=true
TradingStartHour=6
TradingEndHour=2
StopFridayAfterClose=true
FridayCloseHour=18
EnableDailyLossLimit=true
MaxDailyLossPercent=2.25
InpDailyLossCloseAllPercent=5.0
InpEnableTelegram=true
InpToken=8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE
InpChatID=8053031320
InpTelegramDDAlert=15.0
InpEnable2xAlert=true
InpBaseBalance=450.0
InpEnableHouseMoney=false
InpHouseMoneyTarget=2.0
InpEnableCompound=true
InpCompoundStartMultiple=1.5
InpCompoundMaxLot=0.10
InpCompoundDailyLossClose=3.0
InpCompoundDDSoftBrake=20.0
InpCompoundMaxDD=28.0
InpDiagnosticLog=true
```

## Open Issues / Next Session

- [ ] PF ≥1.50 ยังไม่ผ่าน (structural — Grid system บน Gold)
- [ ] Sell Win Rate ใน HM=TRUE ต่ำ (40%) — Compound amplify Sell loss
- [ ] Forward Test ยังไม่ได้รัน — ทดสอบบน Live Demo ก่อน deploy จริง
- [ ] USDTRY# V1.0 รอดำเนินการต่อ (ATR mismatch, negative swap, RSI filter, News TRY)

## Reference Files

| ไฟล์ | รายละเอียด |
|---|---|
| 9AU_GOLD_ADAPTIVE_REGIME_M5_CAP450_v19.3.mq5 | Source code ล่าสุด |
| 9AU_GOLD_ADAPTIVE_REGIME_SKILL.md | Architecture reference สำหรับ EA อื่น |
| V19_3_EnableHouseMoney_FALSE.xlsx | Backtest report (recommended config) |
| V19_3_EnableHouseMoney_TRUE.xlsx | Backtest report (compound config) |

## Prompt สำหรับเริ่ม Session ใหม่

วาง context นี้ทั้งหมด แล้วต่อด้วย:

```
James — อ่าน context ด้านบนแล้วครับ วันนี้จะทำ: [ระบุงาน]
```

Claude จะเข้าใจ architecture ทั้งหมดทันทีโดยไม่ต้อง re-explain
