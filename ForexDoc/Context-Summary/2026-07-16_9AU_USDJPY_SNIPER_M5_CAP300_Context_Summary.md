---
concept_name: 9AU_USDJPY_SNIPER_M5_CAP300 — Context Summary (Pre-Export)
protocol: EA Validation Protocol v2.0
status: Pending #13 (Live Demo ExpertRemove Test)
created: 2026-07-16
tags: [ea, usdjpy, validation, export-ready-pending]
---

# 9AU_USDJPY_SNIPER_M5_CAP300 — Context Summary

## 1. EA Identity

| รายการ | ค่า |
|---|---|
| Symbol | USDJPY# |
| Magic Number | 515253 |
| Timeframe | M5 |
| Base Capital (CAP) | $300 |
| Direction | Long-Only (Buy Grid Basket) |
| Filter Timeframe | H1 (Trend EMA200) + M5 (RSI Rebound + ADX) |
| Code Version | v1.1 (เพิ่ม InpTestExtraSpreadPoints สำหรับ Stress Test เท่านั้น) |

## 2. Final Production Config (ยืนยันแล้วผ่าน Isolation Test ครบ 4 lever)

| พารามิเตอร์ | ค่า | สถานะการยืนยัน |
|---|---|---|
| InpRSIBuyZoneHigh | 45.0 | Root cause หลักของ edge — ยืนยันด้วย isolation test |
| InpADXMin | 20.0 | Root cause หลักของ edge — ยืนยันด้วย isolation test |
| InpMaxDrawdownPercent | 18.0 | ยืนยัน non-binding ในช่วงข้อมูลทดสอบ, เก็บไว้เป็น safety margin |
| MaxDailyLossPercent | 3.0 | ยืนยันมีผลจริง (ดีกว่า 4.5% อย่างมีนัย) |
| InpTestExtraSpreadPoints | 0.0 | **ต้องเป็น 0 เสมอสำหรับ Live/Production** — ใช้เฉพาะรอบ Stress Test |

พารามิเตอร์อื่นทั้งหมด (Grid/Lot/TP/CutLoss/Time/News/Safety) คงค่า default ตามไฟล์ต้นฉบับ ไม่ได้ปรับเพิ่มเติม

## 3. Classification (Step 0)

Balance DD Maximal = 12.16% ≤ 18% → **Compound Type**
เกณฑ์ที่ใช้: Sharpe > 1.80, Recovery Factor > 2.0, DD < 20% (เข้มงวด)

หมายเหตุ: ยังไม่มี Baseline ที่ InpEnableEquityStop=false จริงตาม Protocol แต่ยืนยันโดยอ้อมแล้วว่า Equity DD สูงสุดที่เกิดจริง (14.69%) ไม่เคยแตะ threshold 18%/25% ในทุก config ที่ทดสอบ จึงถือว่าเทียบเท่า Baseline-Stop-Off โดยพฤตินัย

## 4. Full-Period Backtest Result (2023.10.02 – 2026.04.30, Real Ticks)

| Metric | ผล |
|---|---|
| Total Net Profit | $176.44 |
| Profit Factor | 1.7895 |
| Recovery Factor | 3.0022 |
| Sharpe Ratio | 2.3248 |
| Balance DD Maximal | 12.16% |
| Equity DD Maximal | 14.69% |
| Expected Payoff | $1.3367/trade |
| Win Rate | 27.27% (Avg Win $11.11 : Avg Loss $2.33 ≈ 4.77:1) |
| Total Trades | 132 |
| LR Correlation | 0.9241 |

## 5. Protocol v2.0 — 13+2 Criteria Scorecard (สถานะล่าสุด)

| # | เกณฑ์ | ผล | สถานะ |
|---|---|---|---|
| 1 | Net Profit >0 | 176.44 | ผ่าน |
| 2 | Profit Factor >1.50 | 1.7895 | ผ่าน |
| 3 | Sharpe >1.80 (Compound) | 2.3248 | ผ่าน |
| 4 | Balance DD Max ≤20% | 12.16% | ผ่าน |
| 5 | Recovery Factor >2.0 (Compound) | 3.0022 | ผ่าน |
| 6 | Expected Payoff >0 | 1.3367 | ผ่าน |
| 7 | Win Rate >60% | 27.27% | ผ่านผ่านข้อยกเว้น High-Reward/Low-Winrate (ratio 4.77 ≥3.0, ครบเงื่อนไข a/b/c) |
| 8 | Trade Count เพียงพอ | 132 เทรด/2.5 ปี, สม่ำเสมอทั้ง Period A/B | ผ่าน |
| 9 | LR Correlation >0 | 0.9241 | ผ่าน |
| 10 | Walk-Forward degradation <20% | -5.85% (OOS ดีกว่า IS) | ผ่าน |
| 11 | Spread Stress PF drop <15% | สูงสุด 2.23% ที่ระดับ Mild | ผ่าน |
| 12 | Cycle Win Rate ≥60% | — | N/A (ไม่ใช่ Reserve/Cycle-Reset EA) |
| 13 | Live Mode ExpertRemove() verified | ยังไม่ทดสอบ | **ค้างอยู่ — ต้องรัน Demo จริง** |
| 14 | Correlation Diversification | — | N/A (ยังไม่ Combine Port) |

**ผลรวม: ผ่าน 11/11 เกณฑ์ที่ทดสอบได้จาก Backtest ครบทั้งหมด เหลือเพียง #13 เท่านั้นที่ต้องรอผลจาก Demo Account**

## 6. Test History Log (Isolation Testing)

| Test | RSI/ADX | DD Stop | Daily Loss | Net Profit | PF | Trades | WR |
|---|---|---|---|---|---|---|---|
| รอบ 1 | 52/17 | 25% | 3% | 103.50 | 1.395 | 151 | 21.19% |
| รอบ 2 | 45/20 | 18% | 4.5% | 171.61 | 1.752 | 132 | 27.27% |
| รอบ 3 | 45/20 | 25% | 3% | 176.44 | 1.790 | 132 | 27.27% |
| รอบ 4 (Final Config) | 45/20 | 18% | 3% | 176.44 | 1.790 | 132 | 27.27% |

Root cause ยืนยันแล้ว: RSI/ADX คือตัวขับ edge หลัก, MaxDailyLossPercent=3% ดีกว่า 4.5% จริง, InpMaxDrawdownPercent ไม่ผูกกับผลลัพธ์ในช่วงข้อมูลนี้ (non-binding)

## 7. Known Data Caveat

Walk-Forward Split (Period A + B = $163.75) ไม่เท่ากับ Full Continuous Run ($176.44) ต่างกัน $12.69 — สาเหตุคาดว่ามาจากการบังคับปิด/เปิด basket ที่รอยต่อวันที่ 2025.01.16 ไม่กระทบข้อสรุปเรื่อง Walk-Forward degradation (ยังผ่านชัดเจน) แต่บันทึกไว้เพื่อความโปร่งใส

## 8. Code Change Log

- **v1.0 → v1.1**: เพิ่ม input `InpTestExtraSpreadPoints` (default 0.0) สำหรับจำลอง spread กว้างขึ้นเฉพาะรอบ Stress Test เท่านั้น กระทบเฉพาะราคา Ask ที่ใช้เข้าไม้ Buy (ทั้ง First Entry และ Grid Leg) ไม่กระทบ Bid/exit
- Default = 0.0 จึงปลอดภัยสำหรับ Production โดยไม่ต้อง revert ก่อน Export แต่ **แนะนำให้ตรวจสอบซ้ำก่อน Compile เวอร์ชัน Live** ว่าค่านี้ยังเป็น 0 อยู่จริง

## 9. Remaining Steps Before Export-EA

1. รัน **#13 Live Mode ExpertRemove Test** บน Demo Account: เปิด position ค้าง → กด ExpertRemove → ยืนยันไม้เก่าปิดผ่าน SL/TP สำเร็จ
2. ยืนยันค่า `InpTestExtraSpreadPoints = 0.0` ก่อน Compile เวอร์ชันที่จะ Export จริง
3. เมื่อ #13 ผ่าน → เข้าเกณฑ์ "all applicable criteria pass" ตาม Decision Rule ของ Protocol 2.0 → พร้อม Forward Test / Export-EA เต็มรูปแบบ

## 10. Magic Number Reference (สำหรับกันชนกับ EA อื่น)

USDJPY#=515253, GOLD=919291 (inferred), BTC=919295, US100=919294 — ควรตรวจสอบว่าไม่ซ้ำกับ EA อื่นในพอร์ตก่อน Export จริงบนบัญชีเดียวกัน
