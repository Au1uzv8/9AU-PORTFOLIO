# EXPORT-EA Instruction File 1 (V2.7 Update) — Obsidian Vault Operator Prompt
**Target working directory:** `D:\OneDrive\Obsidian_Vault`
**Target file:** `FOREX/EA_Trade/02_EA_PROJECTS/2.1_9AU_SILVER_RESERVE_M5_CAP450/9AU_SILVER_RESERVE_M5_CAP450.md`
**Role:** Copilot = Operator. อัปเดต Properties + เพิ่ม Changelog Entry ใหม่ (ไม่ต้อง Rename ไฟล์ครั้งนี้ — Version Bump ธรรมดา)

---

## STEP 1 — อัปเดต YAML Frontmatter (แทนที่ค่าเดิมด้วยค่าใหม่นี้)

```yaml
version: "V2.7"
near_death_dd_pct: 60
net_profit_pct: 522.44
cagr_pct: 208.0
profit_factor: 1.94
recovery_factor: 0.90
sharpe_ratio: 1.89
win_rate_pct: 67.79
equity_dd_max_pct: 48.16
balance_dd_max_pct: 20.19
expected_payoff: 23.667
cycle_win_rate_pct: 80.0
backtest_period_months: 19.5
last_validated: 2026-08-09
tags: [ea, silver, trend, grid, house-money, port-combine, reserve-capital, 2-wallet-system, walk-forward-continuation]
```

**หมายเหตุ:** `backtest_period_months` เปลี่ยนจาก 30 → 19.5 เพราะ Broker (XM) ตัด Tick History ก่อน 2024.12.01 ออก (บันทึกไว้ใน Memory แล้ว) — ไม่ใช่ความผิดพลาดของ EA

## STEP 2 — เพิ่ม Changelog Entry ใหม่ (ต่อท้าย Section Changelog เดิม ไม่ลบของเก่า)

```markdown
### v2.3 → v2.7 (2026-08-09)

**บริบท:** XM ตัด Tick History ก่อน 2024.12.01 ออก ทำให้ต้อง Re-validate ทั้งหมดบน Window ใหม่ (19.5 เดือน แทน 30 เดือนเดิม — ไม่มี Oct 2023 Crisis อยู่ในข้อมูลอีกต่อไป)

1. **Re-optimize InpNearDeathDDPercent**: 40.0 → **60.0** (ค่าเดิม Optimal เฉพาะ Window ที่มี Oct 2023 ร่วมด้วย เมื่อข้อมูลนั้นหายไป Local Optimum เปลี่ยนเป็น 60.0 — ยืนยันด้วยการ Sweep 30/35/40/45/50/60/65 และ Bracket ยืนยันด้วย 65 ที่แย่ลง)
2. **ค้นพบและแก้ Walk-Forward Boundary Effect Bug**: Fresh-Start OOS Testing ทำให้ EA แบบ Reserve Capital (Peak-based/Virtual-Rebase) รายงานผลลบเท็จ (False Hard-Kill ภายใน 8% ของ Test) เพราะเสียกันชนกำไรสะสมจาก IS Period — แก้โดยเพิ่ม `InpSeedCycleStartEquity` ให้ Test แบบ Continuation-Based ได้จริง รายละเอียดเต็มที่ [[01_CONCEPTS/Reserve_Capital_Near_Death_Cooldown]]
3. **Scorecard หลัง Re-Validate**: Balance DD 20.19% (จาก 22.32%), Recovery Factor 0.90 (จาก 0.77, กลับมา Pass), Walk-Forward Pass (Continuation-Based), Cycle Win Rate 80% — เหลือ Fail จริงแค่ 1 ข้อแบบเฉียดฉิว (Balance DD เกิน 0.19 จุด)
```

## STEP 3 — เพิ่มเนื้อหาใน Concept Page เดิม (Reserve_Capital_Near_Death_Cooldown.md)

เพิ่ม Section ใหม่ท้ายไฟล์:

```markdown
## Known Limitation: Walk-Forward Boundary Effect (พบ 2026-08-09)

EA แบบนี้ **ทดสอบ Walk-Forward แบบ Fresh-Start OOS มาตรฐานไม่ได้** เพราะกลไก Peak-based Kill Switch พึ่งพาทุนสะสมจากการรันต่อเนื่องเป็นกันชนหลัก — ต้องใช้ Continuation-Based Testing แทน (ดู EA Validation Protocol v2.0 Addendum ข้อ 10 ใน Memory Claude) วิธีสรุป:
1. รัน IS Period ปกติ เก็บค่า `FINAL RealBalance` จาก Log สรุป
2. รัน OOS Period โดยตั้ง Initial Deposit = ค่าจาก IS และตั้ง `InpSeedCycleStartEquity` = Deposit ตั้งต้นของเรื่องทั้งหมด (ไม่ใช่ Deposit ของรอบ OOS)
```

---
**หากขั้นตอนใดไม่ชัดเจนหรือ Path จริงต่างจากที่ระบุ ให้หยุดและถามพี่อูก่อนดำเนินการ**
