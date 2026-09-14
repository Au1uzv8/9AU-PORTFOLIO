# 6 EA Combine Portfolio Update — Prompt สำหรับ Gemini (VS Code)

อ้างอิง: `9AU_COMBINE_PORTFOLIO_6EA_ContextSummary.md` (2026-07-27) + YAML 34 Fields Schema (ยืนยันแล้ว)

## ตารางค่าที่ต้องอัพเดต (ใช้ร่วมกันทั้ง 2 Prompt)

### Field ใหม่ 6 ตัวที่ต้องเพิ่มให้ครบ 34 Field (ทุก EA ทั้ง 6 ตัว)

| EA | port_group | combine_capital | port_members | combine_status | protocol_version |
|---|---|---|---|---|---|
| NDAQ100 | Port-01 | 600 | ["GBPJPY"] | true | "EA Validation Protocol v2.0 (Money & Risk Management layer)" |
| GBPJPY | Port-01 | 600 | ["NDAQ100"] | true | เหมือนกัน |
| OIL-WTI | Port-02 | 600 | ["USDJPY"] | true | เหมือนกัน |
| USDJPY | Port-02 | 600 | ["OIL-WTI"] | true | เหมือนกัน |
| 3PAIRS | Port-03 | 600 | ["AUDCAD"] | true | เหมือนกัน |
| AUDCAD | Port-03 | 600 | ["3PAIRS"] | true | เหมือนกัน |

### filename_production (Full Path — Base Folder: `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\`)

| EA | filename_production | version (อัพเดต) |
|---|---|---|
| NDAQ100 | `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\9AU_NDAQ100_COMBINE_M5_CAP300_v1.1.mq5` | V1.1 |
| GBPJPY | `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\9AU_GBPJPY_COMBINE_M5_CAP300_v1.3.mq5` | V1.3 |
| OIL-WTI | `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\9AU_OIL_WTI_COMBINE_M5_CAP300_v4.62.mq5` | V4.62 |
| USDJPY | `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\9AU_USDJPY_COMBINE_M5_CAP300_v1.3.mq5` | V1.3 |
| 3PAIRS | `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\9AU_3PAIRS_COMBINE_M15_CAP300_v2.7.mq5` | V2.7 |
| AUDCAD | `D:\#Projects\MQL5\ACTIVE_MQ5\COMBINE\9AU_AUDCAD_COMBINE_M15_CAP300_v6.12.mq5` | V6.12 |

### Metrics ที่ "เปลี่ยนจริง" — เฉพาะ USDJPY เท่านั้น (ตัวอื่นยืนยันแล้วว่า Compound ยัง Dormant ไม่เปลี่ยน)

| Field | ค่าเดิม | ค่าใหม่ |
|---|---|---|
| profit_factor | 1.79 | 1.541 |
| sharpe_ratio | 2.32 | 1.882 |
| recovery_factor | 3.00 | 2.109 |
| balance_dd_max_pct | (ค่าเดิมในไฟล์ .md) | 13.73 |
| net_profit_pct | 58.81 | 46.98 |

**หมายเหตุ**: `equity_dd_max_pct` ของ USDJPY ไม่มีค่าใหม่ที่ยืนยันจาก Context Summary (มีแค่ Balance DD) — ให้ Gemini คงค่าเดิมไว้ก่อน และแจ้งกลับมาว่ายังขาดค่านี้ ห้ามคำนวณเดาเอง

### 3PAIRS — Caveat พิเศษที่ต้องระบุในไฟล์

Version อัพเดตเป็น v2.7 (เปิด `Inp_Use_Compound=true` + เติม Telegram Token) แต่ **ยังไม่ได้ Backtest ยืนยัน** — Metrics ทั้งหมดในไฟล์ยังคงเป็นผลจาก v2.6 (Fixed Lot) ห้ามเปลี่ยนตัวเลข Backtest ใดๆ จนกว่าจะมีผล v2.7 ยืนยัน ให้เพิ่มบรรทัดเตือนใน Section "ข้อจำกัดที่ต้องระบุชัดเจน" ของไฟล์แทน

---

# Prompt ส่วนที่ 1 — อัพเดต Obsidian Vault (YAML 34 Fields)

```
บทบาท: คุณคือผู้ช่วยจัดการ Obsidian Vault ที่ D:\#DEV_BOT\Obsidian_Vault\FOREX\EA_Trade\

งาน: อัพเดตไฟล์ EA Note 6 ตัว (NDAQ100, GBPJPY, OIL-WTI, USDJPY, 3PAIRS, AUDCAD)
ใน 02_EA_PROJECTS\ ให้ใช้ YAML Properties Schema ใหม่ 34 Field (จาก 28 Field เดิม
เพิ่ม 6 Field: port_group, combine_capital, port_members, filename_production,
combine_status, protocol_version)

กฎสำคัญ: ห้ามลบหรือแก้ Field ใดๆ ที่ไม่ได้ระบุไว้ในคำสั่งนี้ (เช่น pattern, regime,
tags, source_code, backtest_archive, history_quality, avg_holding_time,
max_consecutive_loss_usd, cagr_pct — คงค่าเดิมทั้งหมด) เพิ่มเฉพาะ 6 Field ใหม่
และแก้เฉพาะ Field ที่ระบุค่าใหม่ไว้ชัดเจนเท่านั้น

ทำตามลำดับนี้:

1. สำหรับทั้ง 6 ไฟล์ เพิ่ม 6 Field ใหม่ต่อท้าย Frontmatter (ก่อน tags:) ตามตาราง
   "Field ใหม่ 6 ตัว" และ "filename_production" ด้านบน — ใส่ port_group,
   combine_capital, port_members, filename_production, combine_status,
   protocol_version ให้ตรงกับ EA ของไฟล์นั้นๆ

2. อัพเดต Field `version` ของทั้ง 6 ไฟล์ตามตาราง (เช่น NDAQ100 เป็น "V1.1")
   อัพเดต `last_validated` เป็น 2026-07-27 สำหรับทั้ง 6 ไฟล์

3. เฉพาะไฟล์ USDJPY: อัพเดต profit_factor, sharpe_ratio, recovery_factor,
   balance_dd_max_pct, net_profit_pct ตามตาราง "Metrics ที่เปลี่ยนจริง" ด้านบน
   ห้ามแตะ equity_dd_max_pct (ยังไม่มีค่าใหม่ยืนยัน) — เพิ่ม Section "Changelog"
   ในเนื้อหาไฟล์ (นอก Frontmatter) อธิบายว่า Compound Activate จริงระหว่าง
   Backtest ทำให้ Balance ข้าม Threshold 1.5x ก่อนเจอ Losing Streak 5 ไม้รวด
   (ม.ค. 2026) Net Profit จึงลดจาก Fixed Lot Baseline

4. เฉพาะไฟล์ 3PAIRS: อัพเดต version เป็น "V2.7" เท่านั้น ห้ามแตะ Metrics ใดๆ
   ในไฟล์ (ยังเป็นผล v2.6) เพิ่มประโยคเตือนใน Section "ข้อจำกัดที่ต้องระบุชัดเจน":
   "Version 2.7 เปิด Compound Selective แล้ว แต่ยังไม่ได้ Backtest ยืนยัน
   Metrics ด้านบนทั้งหมดยังเป็นผลจาก v2.6 (Fixed Lot)"

5. ไฟล์อีก 4 ตัว (NDAQ100, GBPJPY, OIL-WTI, AUDCAD): เพิ่ม 6 Field ใหม่และ
   อัพเดต version ตามข้อ 2 เท่านั้น ไม่ต้องแตะ Metrics ใดๆ (ยืนยันแล้วว่าไม่เปลี่ยน)

6. อัพเดต 06_SOURCE CODE\*_SRC.md ทั้ง 6 ไฟล์ให้ Path ชี้ไปยัง filename_production
   เต็มตามตารางด้านบน

7. อัพเดต 00_INDEX.md ให้ Version ของทั้ง 6 EA ตรงกับตารางล่าสุด

ยืนยันกลับมาหลังทำเสร็จว่าไฟล์ไหนถูกแก้กี่บรรทัด และมี Field ใดที่ขาดข้อมูล
(เช่น equity_dd_max_pct ของ USDJPY) แจ้งไว้ชัดเจน ไม่ต้องเดาเติมเอง
```

---

# Prompt ส่วนที่ 2 — อัพเดต GitHub Pages (Theme เดิม, ข้อมูลใหม่)

```
บทบาท: คุณคือผู้ช่วยแก้ไข Dashboard ที่ Repo 9AU-FOREX-EA (branch main, root)
ไฟล์ index.html และ data.json ที่แนบมาคือเวอร์ชันปัจจุบันจริง

งาน: อัพเดต data.json และ Inline Data ใน index.html สำหรับ 6 EA เดียวกัน
โดยคง Theme/CSS/Layout เดิมทั้งหมดไว้ 100% ไม่แตะ Design ใดๆ

ทำตามลำดับนี้:

1. อัพเดต Field "filename" ของทั้ง 6 Entry เป็นชื่อไฟล์ (ไม่ต้องมี Path D:\)
   ตามนี้:
   - NDAQ100 → "9AU_NDAQ100_COMBINE_M5_CAP300_v1.1.mq5"
   - GBPJPY  → "9AU_GBPJPY_COMBINE_M5_CAP300_v1.3.mq5"
   - OIL-WTI → "9AU_OIL_WTI_COMBINE_M5_CAP300_v4.62.mq5"
   - USDJPY  → "9AU_USDJPY_COMBINE_M5_CAP300_v1.3.mq5"
   - 3PAIRS  → "9AU_3PAIRS_COMBINE_M15_CAP300_v2.7.mq5"
   - AUDCAD  → "9AU_AUDCAD_COMBINE_M15_CAP300_v6.12.mq5"

2. เพิ่ม Field "version" ใหม่ให้ทั้ง 6 Entry นี้เท่านั้น (Entry อื่นที่เหลือ
   5 ตัวไม่ต้องเพิ่ม Field นี้ ปล่อยตามเดิม): "V1.1", "V1.3", "V4.62", "V1.3",
   "V2.7", "V6.12" ตามลำดับ EA ด้านบน

3. เฉพาะ Entry USDJPY: อัพเดต pf→1.541, sharpe→1.882, rf→2.109,
   net_profit→46.98 (dd คงค่าเดิม 14.69 ไว้ก่อนเพราะไม่มีค่า Balance DD ใหม่
   ที่จะแปลงมาใช้แทนได้อย่างสมเหตุสมผลกับ Field เดิม)

4. Entry อื่นอีก 5 ตัว (NDAQ100, GBPJPY, OIL-WTI, 3PAIRS, AUDCAD): ห้ามแตะ
   Metrics ใดๆ (pf, sharpe, dd, rf, winrate, payoff, net_profit) — เปลี่ยน
   แค่ filename กับเพิ่ม version ตามข้อ 1-2

5. อัพเดต "generated" ที่หัว Dashboard เป็นวันที่วันนี้

6. ห้ามแตะ Entry ของอีก 5 EA ที่เหลือ (Gold, Platinum, Silver, ETH, BTC) เลย
   แม้แต่ Field เดียว

7. ทดสอบ Local ด้วย python -m http.server 8000 ก่อน แล้วเปิด Browser เช็ค:
   - Console (F12) ไม่มี Error สีแดง
   - Card ทั้ง 6 ตัวแสดง Version Badge ใหม่ (ถ้า Theme มี Field แสดง Version
     อยู่แล้ว) และ Metrics ของ USDJPY อัพเดตถูกต้อง
   - Card อีก 5 ตัวที่ไม่เกี่ยวข้องไม่เปลี่ยนแปลงเลย

8. Commit message แนะนำ: "Update 6 EA Combine Portfolio — Compound Selective +
   SoftBrake versions (NDAQ100 v1.1, GBPJPY v1.3, OIL-WTI v4.62, USDJPY v1.3,
   3PAIRS v2.7, AUDCAD v6.12)"
```
