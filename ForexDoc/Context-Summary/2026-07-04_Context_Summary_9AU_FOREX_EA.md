# Context Summary — 9AU FOREX EA Portfolio Project

อ้างอิงบริบทนี้เมื่อเปิดเธรดใหม่ เพื่อให้เจมส์เข้าใจสถานะงานทันทีโดยไม่ต้องอธิบายซ้ำ

## สถานะปัจจุบัน (สิ่งที่ทำเสร็จแล้ว)

1. Obsidian Vault Knowledge Base ที่ `D:\#DEV_BOT\Obsidian_Vault\FOREX\EA_Trade\` ครบ 11 EA
   - โครงสร้าง: 00_INDEX, 01_CONCEPTS (House Money/Compound), 02_EA_PROJECTS (11 EA), 03_PATTERNS, 04_ADAPTIVE_REGIME, 05_BACKTEST_ARCHIVE, 06_SOURCE CODE (Metadata Note ชี้ไป Path จริงใน `D:\#DEV_BOT\MQL5\ACTIVE MQ5\`)
   - เกณฑ์จัดกลุ่ม: Max Equity DD ≥18% = House Money (ถอนกำไรหรือ Compound ต่อเมื่อถึงเป้า), <18% = Compound (รันยาว)
2. GitHub Pages Dashboard ที่ Repo `https://github.com/Au1uzv8/9AU-FOREX-EA` (branch main, root) แสดง Card ทั้ง 11 EA พร้อม Filter/Sort

## รายชื่อ EA ทั้ง 11 ตัว พร้อมกลุ่ม

| EA | Magic | กลุ่ม | PF | Sharpe | DD |
|---|---|---|---|---|---|
| GOLD (ทดสอบที่ 450 USD) | 919291 | House Money | 1.28 | 1.99 | 24.75% |
| SILVER | 919290 | House Money | 2.03 | 1.68 | 35.84% |
| BITCOIN | 919295 | House Money | 2.46 | 0.81 | 37.03% |
| NASDAQ100 (ทดสอบ 9 เดือนเท่านั้น) | 919294 | House Money | 1.74 | 4.71 | 23.94% |
| PLATINUM (ทดสอบ ~10-11 เดือนเท่านั้น) | 919292 | House Money | 2.23 | 3.13 | 29.83% |
| USDJPY | 515253 | Compound | 1.79 | 2.31 | 15.00% |
| GBPJPY | 515254 | Compound | 1.57 | 2.40 | 9.98% |
| AUDCAD | 515251 | Compound | 1.74 | 1.71 | 14.63% |
| 3PAIRS (Oceanic) | 515252 | Compound | 15.12 | 7.87 | 6.18% |
| WTI-Oil (**ทดสอบจริงแค่ 9 เดือน ไม่ใช่ 30 — พบ Bug เอกสารเดิม ยังไม่ได้แก้ไฟล์**) | 919293 | Compound | 4.48 | 4.48 | 8.22% |
| ETHEREUM (Win Rate ต่ำสุด 9.80% ยังเป็นจุดอ่อน) | 919296 | Compound | 1.69 | 1.28 | 8.50% |

## แผนพอร์ตที่ตัดสินใจแล้ว (Trend Following + Mean Reversion ต่อพอร์ต)

เหตุผล: ตลาด Sideway ~70% ของปี Trend Following ทำงานสั้น เพิ่ม Mean Reversion เพื่อลด Action Bias (พฤติกรรมเข้าเทรดมือเองตอนระบบเงียบ) และเพิ่ม Diversification ตาม Modern Portfolio Theory

| Port | House Money (Trend) | Compound (Mean Reversion) |
|---|---|---|
| Port-01 | GOLD | USDJPY |
| Port-02 | BTC | AUDCAD |
| Port-03 | SILVER | GBPJPY |

## แผนทุน

- Backtest ใช้ 300 USD (ยกเว้น Gold ใช้ 450 USD ตั้งแต่ต้น)
- เป้า Live: 450 USD ต่อ EA (Gold ไม่ต้องเพิ่ม เพราะ Backtest ที่ 450 อยู่แล้ว)
- มีแผนทำ XM Copy Trade (เป็นทั้ง Leader และ Follower ตัวเอง) — ทำให้ต้องลดจำนวนบัญชีจริงจาก 6 บัญชี (1 EA/บัญชี) เหลือ 3 บัญชี (2 EA/บัญชี ต่อ Port)

## ปัญหา Code ที่พบและยังไม่ได้แก้ (งานหลักของเธรดใหม่)

**Root Cause**: ทุก EA คำนวณ Kill Switch (`GetPeakEquityDD`), 2x House Money Target (`CheckHouseMoney`), และ Compound Lot Scaling จาก `AccountInfoDouble(ACCOUNT_BALANCE/EQUITY)` ซึ่งอ่านค่า**ทั้งบัญชี** ไม่แยกตาม Magic Number

**ผลกระทบ**: ถ้ารัน 2 EA ร่วมบัญชีเดียวกันตามแผน Port ด้านบน ผลขาดทุน/กำไรของ EA ตัวหนึ่งจะไปกระตุ้น Kill Switch หรือ 2x Target ของอีกตัวผิดพลาด (False Trigger)

**แนวทางแก้ที่ตกลงไว้**: เปลี่ยนให้ทุก Watcher Function คำนวณ "Virtual Balance/Equity" เฉพาะ Magic Number ของตัวเอง จาก Deal History (`HistorySelect` + กรอง `POSITION_MAGIC`) แทนการใช้ `AccountInfoDouble` ตรงๆ ต้องแก้ทั้ง 3 ฟังก์ชันในทุก EA ที่จับคู่กัน (6 ไฟล์ทั้งหมด: Gold, USDJPY, BTC, AUDCAD, Silver, GBPJPY)

## กติกาการ Withdraw + Reset (ที่ตกลงไว้ก่อนหน้า ต้องทำคู่กันเสมอ)

เมื่อ Balance แตะ 2x Target: (1) ถอนกำไรออก (2) ลบ EA ออกจากกราฟแล้วแนบใหม่ทันที (บังคับ `OnInit()` รีเซ็ต Peak Equity) — ถ้าข้ามขั้นตอน 2 จะโดน Kill Switch หลอกทำงานทันทีหลังถอนเงิน เพราะ Peak Equity เก่ายังค้างอยู่

## งานที่ต้องทำต่อในเธรดใหม่

1. แก้ Source Code ทั้ง 6 ไฟล์ ให้ใช้ Virtual Balance/Equity ต่อ Magic Number
2. แก้ไฟล์ WTI ใน Obsidian (EA Note + Backtest Archive + Index) จาก 30 เดือน เป็น 9 เดือน ตามข้อเท็จจริง
3. ทดสอบ Backtest ใหม่แบบ 2 EA ร่วมบัญชี (Port-01/02/03) เพื่อยืนยันว่า Virtual Balance ทำงานถูกต้องก่อน Live จริง
---
