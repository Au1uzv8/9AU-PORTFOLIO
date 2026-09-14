# Context Summary — Port-Combine (Virtual Balance per Magic) Session

อ้างอิงคู่กับ Context Summary เดิม (9AU FOREX EA Portfolio Project)

## หมวดหมู่การแก้ไข

**Money & Risk Management** (ไม่ใช่สถาปัตยกรรมใหม่)

สถาปัตยกรรมเดิมทุกส่วนไม่เปลี่ยน — Regime Detection, Entry Logic, Basket Isolation, Grid/Compound Lot Formula ยังทำงานเหมือนเดิมทุกจุด สิ่งที่เปลี่ยนคือ **แหล่งที่มาของตัวเลข Balance/Equity** ที่ป้อนเข้าสูตร Risk Control เท่านั้น จาก `AccountInfoDouble(ACCOUNT_BALANCE/EQUITY)` (อ่านทั้งบัญชี) เป็น **Virtual Balance/Equity per Magic Number** (คำนวณเฉพาะ Deal History ของ Magic ตัวเอง)

## สิ่งที่ทำเสร็จใน Session นี้

แก้ไฟล์ครบทั้ง 6 ไฟล์ ตาม Root Cause ที่ระบุไว้ใน Context เดิม พร้อมเปลี่ยนชื่อตาม Naming Convention `9AU_{SYMBOL}_COMBINE_M{TF}_CAP{amount}.mq5`

| Port | EA (ชื่อเดิม → ชื่อใหม่) | Version เดิม→ใหม่ | Magic | หมายเหตุโครงสร้าง |
|---|---|---|---|---|
| Port-01 | 9AU_GOLD_ADAPTIVE_REGIME_M5_CAP450 → 9AU_GOLD_COMBINE_M5_CAP450 | v19.3→v19.4 | 919291 | Dual-Basket + House Money + Compound (Pattern เต็มรูปแบบ) |
| Port-01 | 9AU_USDJPY_SNIPER_GRID_M5_CAP300 → 9AU_USDJPY_COMBINE_M5_CAP300 | v1.0→v1.1 | 515253 | Buy-only Basket Grid |
| Port-02 | 9AU_BTC_ADAPTIVE_REGIME_M5_CAP300 → 9AU_BTC_COMBINE_M5_CAP300 | v2.0(v2b)→v2.3(v2c) | 919295 | Dual-Basket + House Money + Compound (เหมือน Gold) |
| Port-02 | 9AU_AUDCAD_MEAN_BB_RSI_M15_CAP300 → 9AU_AUDCAD_COMBINE_M15_CAP300 | v6.3→v6.4 | (Inp_Magic เดิม) | โครงสร้างต่างจากไฟล์อื่น ไม่มี Base Balance เดิม ต้องเพิ่ม Input `Inp_Base_Balance=300` ใหม่ |
| Port-03 | 9AU_SILVER_TREND_RSI_GRID_M5_CAP300 → 9AU_SILVER_COMBINE_M5_CAP300 | v1.1→v1.2 | 919290 | Buy-only + 2x Withdraw Alert |
| Port-03 | 9AU_GBPJPY_SNIPER_GRID_M5_CAP300 → 9AU_GBPJPY_COMBINE_M5_CAP300 | v1.0→v1.1 | 515254 | Buy-only + Floating DD Limit (ไม่มี 2x Alert) |

**หมายเหตุสำคัญ**: ชื่อไฟล์ AUDCAD ใช้ `_M15_` ไม่ใช่ `_M5_` เพราะ Backtest ยืนยัน Timeframe จริงคือ M15 (ต่างจาก Pattern ที่ใช้ครั้งแรก)

## กลไกที่เพิ่มเข้าไปทุกไฟล์

```
Virtual Balance = InpBaseBalance (หรือ Inp_Base_Balance) + กำไร/ขาดทุนที่ปิดจริงสะสม เฉพาะ Magic ตัวเอง
Virtual Equity  = Virtual Balance + กำไรลอยของ Position เฉพาะ Magic ตัวเอง
```

- `ScanInitialRealizedProfit()` — สแกน Deal History ครั้งเดียวตอน OnInit (กู้คืนค่าหลัง Restart/Reset)
- `OnTradeTransaction()` — จับเฉพาะ Deal ใหม่ที่ปิด สะสมเข้าตัวแปร Global (ไม่ Scan History ทุก Tick เพื่อประสิทธิภาพ)
- แทนที่ `AccountInfoDouble` ในทุกจุดที่เกี่ยวกับ Risk ต่อ EA ตัวเอง: Kill Switch, Daily Loss Limit, Exposure Cap, House Money Target, Compound Lot Scaling, Telegram Alert
- คงไว้ตามเดิมเฉพาะ `ACCOUNT_MARGIN_LEVEL` (เป็นค่าระดับบัญชีจริง ไม่ใช่ต่อ Magic)

## Backtest — ไม่ต้องทดสอบใหม่ (ยืนยันแล้ว)

MT5 Strategy Tester ไม่รองรับรัน 2 EA ร่วมบัญชีจริง ดังนั้น Virtual Balance = Real Balance เสมอตอน Backtest เดี่ยว ผลเดิมยังใช้ได้ทั้งหมด:

| EA | PF (>1.50) | Sharpe (>1.80) | Equity DD (<20%) | Recovery Factor (>2.0) |
|---|---|---|---|---|
| Gold | 1.31 ✗ | 2.09 ✓ | 34.19% ✗ | 2.93 ✓ |
| USDJPY | 1.79 ✓ | 2.31 ✓ | 15.00% ✓ | 2.86 ✓ |
| BTC | 2.49 ✓ | 0.82 ✗ | 39.83% ✗ | 1.82 ✗ |
| AUDCAD | 1.74 ✓ | 1.71 ✗ | 14.63% ✓ | 2.02 ✓ |
| Silver | 2.03 ✓ | 1.68 ✗ | 57.32% ✗ | 1.78 ✗ |
| GBPJPY | 1.57 ✓ | 2.40 ✓ | 11.84% ✓ | 3.62 ✓ |

## Data Schema — Badge ทั้งหมดที่ต้องเพิ่ม (Dashboard + Obsidian)

| Field | ประเภท | Cross-cutting? | คำอธิบาย |
|---|---|---|---|
| `own_capital` | Number | - | ทุนของ EA ตัวเอง เช่น 450 |
| `port_group` | String/null | ไม่ (Exclusive) | Port-01/02/03 หรือ null ถ้ายังไม่เข้ากลุ่ม |
| `combine_capital` | Number/null | - | ผลรวมทุนสมาชิกใน Port เดียวกัน |
| `port_members[]` | Array | - | รายชื่อ EA คู่หูใน Port เดียวกัน |
| `patterns[]` | Array | ใช่ (Many-to-Many) | เช่น `["Grid","Martingale"]` |
| `is_adaptive_regime` | Boolean | - | true = มี Uptrend+Downtrend Module ในตัวเดียวกัน |

**หลักการสำคัญ**: `port_group` เป็น Exclusive (1 EA อยู่ได้ Port เดียว) แต่ `patterns[]` เป็น Many-to-Many (1 EA มีได้หลาย Pattern พร้อมกัน) — ต้องแยก Logic การ Filter ให้ถูกต้อง (Dropdown เดี่ยวสำหรับ Port, Checkbox หลายตัวสำหรับ Pattern)

## Badge Layout บน Card (สรุปทั้งหมด)

```
┌─────────────────────────────────┐
│ GOLD              [HOUSE MONEY] │
│ 9AU_GOLD_COMBINE_M5_CAP450       │
│ [CAP 450] → [COMBINE 750]        │
│ [Grid] [Adaptive Regime]         │
│                                   │
│ PF 1.31   SHARPE 2.09   RF 2.93 │
└─────────────────────────────────┘
```

## Filter Bar ที่ต้องเพิ่ม

| Selector | ประเภท | ตัวอย่างผลลัพธ์ |
|---|---|---|
| Port | Dropdown เดี่ยว | เลือก Port-02 → Header: `Port-02 \| Combine 600 \| Members: BTCUSD, AUDCAD` |
| Pattern | Checkbox หลายตัว | เลือก Grid → Header: `Pattern: Grid \| Members: Gold, BTC, USDJPY, GBPJPY, Silver` |
| Regime | Dropdown เดี่ยว | เลือก Adaptive Regime → Header: `Members: Gold, BTC, ETH` |

## ตาราง Mapping ที่ใช้จริง (ยืนยันแล้วโดยพี่อู)

| EA | Own Capital | Port | Combine | Patterns | Adaptive Regime |
|---|---|---|---|---|---|
| Gold | 450 | Port-01 | 750 | Grid, Hedging | ใช่ |
| USDJPY | 300 | Port-01 | 750 | Grid | ไม่ใช่ |
| BTC | 300 | Port-02 | 600 | Grid, Hedging | ใช่ |
| AUDCAD | 300 | Port-02 | 600 | Mean Reversion | ไม่ใช่ |
| Silver | 300 | Port-03 | 600 | Grid, Martingale | ไม่ใช่ |
| GBPJPY | 300 | Port-03 | 600 | Grid, Martingale | ไม่ใช่ |

5 EA ที่เหลือ (Platinum, NASDAQ100, WTI, ETH, 3PAIRS) — `port_group`/`combine_capital` เป็น null ทั้งหมด ส่วน `patterns[]`/`is_adaptive_regime` ให้ Gemini ดึงจาก Note `03_PATTERNS`/`04_ADAPTIVE_REGIME` เดิมของพี่อูโดยตรง ไม่ใช้ค่าจากเอกสารนี้ (ป้องกัน Hallucination เพราะ Session นี้ไม่ได้อ่าน Source Code 5 ตัวนั้น)

## ขั้นตอนถัดไป

Live Demo ทุนรวมตาม Port (750 / 600 / 600 USD) ระยะเวลา 1-2 เดือน แล้วนำ History กลับมาวิเคราะห์ — จุดที่ต้องเฝ้าดู: Telegram "Virtual Balance" ของแต่ละ EA ต้องขยับอิสระจากกัน ไม่ผูกกับยอดบัญชีรวม

---

# ออกแบบ Prompt สำหรับ Gemini (VS Code) — ส่วนที่ 1: อัพเดต .md ใน Obsidian

```
บทบาท: คุณคือผู้ช่วยจัดการ Obsidian Vault ที่ D:\#DEV_BOT\Obsidian_Vault\FOREX\EA_Trade\

งาน: อัพเดตเอกสารตามการเปลี่ยนแปลง "Virtual Balance/Equity per Magic Number (Port-Combine)"
ซึ่งจัดอยู่ในหมวด Money & Risk Management (ไม่ใช่สถาปัตยกรรมใหม่)

ทำตามลำดับนี้:

1. สร้างไฟล์ใหม่ที่ 01_CONCEPTS\Virtual_Balance_Per_Magic_Port_Combine.md
   เนื้อหา: อธิบาย Concept, สูตรคำนวณ Virtual Balance/Equity, เหตุผล (False Trigger
   ป้องกันเมื่อรัน 2 EA ร่วมบัญชี), ฟังก์ชันที่เกี่ยวข้อง (ScanInitialRealizedProfit,
   OnTradeTransaction, GetVirtualBalance, GetVirtualEquity)
   ระบุชัดว่า Port-Combine เป็น Cross-cutting Concept ไม่ใช่ Category แยกแบบ
   1.1_HOUSE_MONEY / 1.2_COMPOUND (EA ตัวเดียวเป็นได้ทั้ง House Money/Compound
   และ Combine พร้อมกัน)

2. อัพเดตไฟล์ EA Note ทั้ง 6 ตัวที่ 02_EA_PROJECTS\ (Gold, USDJPY, BTC, AUDCAD,
   Silver, GBPJPY) เพิ่ม Section "Changelog" ระบุ:
   - ชื่อไฟล์เดิม → ชื่อไฟล์ใหม่ (Pattern 9AU_{SYMBOL}_COMBINE_M{TF}_CAP{amount})
   - Version เดิม → Version ใหม่
   - วันที่แก้ไข: [ใส่วันที่วันนี้]
   - อ้างอิงกลับไปที่ 01_CONCEPTS\Virtual_Balance_Per_Magic_Port_Combine.md
   เพิ่ม Field ต่อท้าย Metadata เดิมของแต่ละ Note:
   - Own Capital / Port Group / Combine Capital / Port Members
     (ใช้ตาราง Mapping ที่แนบมาด้านล่าง Prompt นี้)
   - Patterns[] และ Adaptive Regime (true/false) — ดึงจาก Note 03_PATTERNS และ
     04_ADAPTIVE_REGIME เดิมที่มีอยู่แล้วในแต่ละ EA Note ห้ามเดาเอง ถ้า Note เดิม
     ไม่มีข้อมูลนี้ ให้ข้ามไปและแจ้งกลับมาว่าไม่พบ

3. อัพเดต 06_SOURCE CODE Metadata Note ให้ Path ชี้ไปยังชื่อไฟล์ใหม่ทั้ง 6 ไฟล์
   ที่ D:\#DEV_BOT\MQL5\ACTIVE MQ5\

4. อัพเดต 00_INDEX ให้แสดง Version ล่าสุด, สถานะ "Port-Combine Ready", และ
   Combine Capital สำหรับทั้ง 6 EA

ตาราง Mapping สำหรับใช้กรอก Field (Own Capital / Port / Combine Capital / Members):

| EA | Own Capital | Port | Combine Capital | Members |
|---|---|---|---|---|
| Gold | 450 | Port-01 | 750 | USDJPY |
| USDJPY | 300 | Port-01 | 750 | Gold |
| BTC | 300 | Port-02 | 600 | AUDCAD |
| AUDCAD | 300 | Port-02 | 600 | BTC |
| Silver | 300 | Port-03 | 600 | GBPJPY |
| GBPJPY | 300 | Port-03 | 600 | Silver |

ข้อกำหนด: ห้ามลบเนื้อหาเดิมที่ไม่เกี่ยวข้อง แก้เฉพาะจุดที่ระบุ รักษาโครงสร้าง
Markdown เดิมของแต่ละไฟล์ไว้ทุกประการ
```

---

# ออกแบบ Prompt สำหรับ Gemini (VS Code) — ส่วนที่ 2: อัพเดต .html บน GitHub Pages

```
บทบาท: คุณคือผู้ช่วยแก้ไข Dashboard ที่ Repo https://github.com/Au1uzv8/9AU-FOREX-EA
(branch main, root)

งาน: อัพเดต Card แสดงผล EA ทั้ง 6 ตัว ให้สะท้อนการเปลี่ยนแปลง Port-Combine

ทำตามลำดับนี้:

1. หาไฟล์ index.html (หรือไฟล์ที่ render Card ทั้ง 11 EA) และหา Component/Object
   ของ 6 EA นี้: Gold (Magic 919291), USDJPY (515253), BTC (919295),
   AUDCAD (Magic เดิม), Silver (919290), GBPJPY (515254)

2. สำหรับแต่ละ EA ทั้ง 6 ตัว อัพเดต Field ต่อไปนี้:
   - "filename"/"source" → ชื่อไฟล์ใหม่ (Pattern COMBINE)
   - "version" → เวอร์ชันใหม่ตามตาราง Version เดิม→ใหม่ (แนบด้านล่าง)
   - "own_capital" → ทุนของ EA ตัวเอง
   - "port_group" → Port-01/02/03
   - "combine_capital" → ผลรวมทุนของ Port
   - "port_members" → รายชื่อ EA คู่หู
   Badge บน Card: เพิ่ม 2 Badge ใหม่ต่อจาก Badge เดิม (House Money/Compound)
   - Badge คู่ Capital: `[CAP {own_capital}] → [COMBINE {combine_capital}]`
     แสดงเฉพาะเมื่อ port_group ไม่เป็น null
   - Badge Pattern/Regime: แสดงจาก patterns[] และ is_adaptive_regime ที่มีอยู่ใน
     Data เดิมของ Dashboard (ถ้ายังไม่มี Field นี้ใน Data ปัจจุบัน ให้ข้ามส่วนนี้
     และแจ้งกลับมาว่าต้องเพิ่ม Field ก่อน ห้ามเดาค่า Pattern เอง)

3. เพิ่ม Filter Bar ใหม่ 2 ตัว ข้าง Sort Dropdown เดิม:
   - Dropdown เดี่ยว "Port": All / Port-01 / Port-02 / Port-03
     เลือกแล้ว Filter Card เหลือเฉพาะสมาชิก + แสดง Header สรุป
     "{Port} | Combine Capital {combine_capital} | Members: {port_members}"
   - Dropdown เดี่ยว "Regime": All / Adaptive Regime / Static
     เลือกแล้ว Filter ตาม is_adaptive_regime + แสดง Header "Members: ..."
   (Pattern Filter แบบ Checkbox หลายตัว ให้เพิ่มเป็นขั้นต่อไปหลัง Field patterns[]
    พร้อมใช้งานจริงแล้ว เพราะเป็น Many-to-Many ต้องออกแบบ UI แยกจาก Dropdown เดี่ยว)

4. ห้ามเปลี่ยน Layout, Filter/Sort Logic เดิม, หรือ CSS เดิมของ Tab
   All/House Money/Compound/Combine แก้เฉพาะ Data และเพิ่ม Filter Bar/Badge
   ใหม่ตามที่ระบุเท่านั้น ส่วน EA อีก 5 ตัว (Platinum, NASDAQ100, WTI-Oil,
   Ethereum, 3PAIRS) ที่ยังไม่ได้แก้ Virtual Balance ห้ามแตะต้อง Field ใดๆ เลย

ตาราง Version เดิม→ใหม่ และ Capital Mapping:

| EA | Version เดิม→ใหม่ | Own Capital | Port | Combine Capital | Members |
|---|---|---|---|---|---|
| Gold | v19.3→v19.4 | 450 | Port-01 | 750 | USDJPY |
| USDJPY | v1.0→v1.1 | 300 | Port-01 | 750 | Gold |
| BTC | v2.0→v2.3 | 300 | Port-02 | 600 | AUDCAD |
| AUDCAD | v6.3→v6.4 | 300 | Port-02 | 600 | BTC |
| Silver | v1.1→v1.2 | 300 | Port-03 | 600 | GBPJPY |
| GBPJPY | v1.0→v1.1 | 300 | Port-03 | 600 | Silver |

5. Commit message แนะนำ: "Update 6 EA to Port-Combine + Capital/Pattern/Regime
   Badge (Virtual Balance per Magic) v[ระบุช่วง version]"
```
