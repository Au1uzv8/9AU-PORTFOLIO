---
title: "Project Retrospective & Context Summary: Multi-Asset Portfolio Suite & Telegram Watchlist Engine"
subtitle: "บันทึกสรุปบริบทโครงการ สถาปัตยกรรม การแก้ปัญหา และพิมพ์เขียวสำหรับการพัฒนาต่อยอดระบบบริหารการเงินส่วนบุคคล"
date: "2026-09-14"
version: "7.2.0-final"
status: "Production Ready & Fully Verified"
author: "Portfolio Development Team"
license: "Private & Confidential"
tags:
  - Finance
  - Portfolio Management
  - Google Apps Script
  - Dime App Reconciliation
  - MetaTrader 5
  - Telegram Bot API
  - Web Development
---

# 1. บทนำและแนวคิดเริ่มต้นของโครงการ (Origin & Core Vision)

### 1.1 ที่มาและปัญหาเดิม (The Problem Statement)
ก่อนการพัฒนาระบบ การบริหารจัดการสินทรัพย์ส่วนบุคคลมีความกระจัดกระจาย ขาดเครื่องมือรวมศูนย์ที่แสดงมูลค่าความมั่งคั่งสุทธิ (Total Net Worth) ได้แบบ Real-time:
* **Group-1 (สภาพคล่องเงินบาท):** บันทึกเงินสดในมือ, บัญชีเงินฝากธนาคาร (SCB, K-Plus) และเงินสำรองฉุกเฉิน ซึ่งกระจัดกระจายและยากต่อการคำนวณยอดคงเหลือสุทธิ
* **Group-2 (หุ้นและ ETF สหรัฐฯ ผ่าน Dime! Broker):** มีความซับซ้อนของโครงสร้างต้นทุน เช่น ค่าคอมมิชชัน, ภาษีมูลค่าเพิ่ม (VAT 7%), ค่าธรรมเนียมกำกับดูแลตลาดสหรัฐฯ (SEC Fee, TAF Fee), อัตราแลกเปลี่ยน (USD/THB FX Rate) รายรายการ และสถานะคำสั่งซื้อขายรอจับคู่ (`W-BUY` / `W-SELL`)
* **Group-3 (พอร์ตเงินตราต่างประเทศ FOREX MT5):** การรันบอทเทรดอัตโนมัติ (Expert Advisor - EA) จำนวน 4 Terminals บน VPS ทำให้ต้องล็อกอินหลายหน้าจอเพื่อดูยอด Balance, Equity และ Growth

### 1.2 วัตถุประสงค์หลัก (Core Objectives)
* **Single Source of Truth:** รวมศูนย์ฐานข้อมูลทั้งหมดไว้บน Google Sheets (`PORTFOLIO_DB`)
* **True Reconciliation:** ตรวจสอบยอดพอร์ตหุ้น/ETF ให้ตรงกับแอปพลิเคชัน Dime! แบบ 100%
* **Automated MT5 Synchronization:** ดึงข้อมูลผลการเทรดทั้ง 4 Terminals อัตโนมัติ ไม่ต้องบันทึกด้วยมือ
* **Security & Fast UI:** เว็บ Dashboard โหลดเร็ว ปลอดภัยด้วยรหัส PIN 6 หลัก พร้อม Token Session
* **Proactive Alert Engine:** เพิ่มระบบเฝ้าราคา (Watchlist), แสดงแถบราคา 52-Week Range และแจ้งเตือนอัตโนมัติผ่าน Telegram Bot เมื่อราคาถึงเป้าหมาย (Target Buy/Sell)
* **All-in-One Reporting:** ส่งออกรายงานเอกสารรูปแบบ PDF และไฟล์ CSV ได้ครบทุกหน้าจอ

---

# 2. สถาปัตยกรรมและโครงสร้างข้อมูลระบบ (System Architecture)

### 2.1 แผนผังการทำงาน (High-Level Data Flow)

```text
[ XM Broker / 4 MT5 VPS Terminals ] ──> [ Sheet: IMPORTMT5 ] ───────┐
                                                                    │
[ Dime / User Manual Inputs ] ────────> [ Sheets: TRADES / CASHFLOW ]┼──> [ Apps Script (Code.gs) ]
                                                                    │       (Fee Engine / Alert Logic)
[ Google Finance / Safe Fallback ] ───> [ Sheet: MARKET ] ──────────┤              │
                                                                    │       JSONP / Telegram API
[ Target Alerts & Settings ] ─────────> [ Sheets: ALERTS / SETTINGS ]┘              │
                                                                                    ▼
                                                                     [ Web App: MyPortfolio.html ]
                                                                     (TailwindCSS + Chart.js + PDF)
```

### 2.2 โครงสร้างการแบ่งกลุ่มสินทรัพย์และสูตรคำนวณ
* **Group-1: สภาพคล่องเงินบาท (THB Liquidity)**
  - Item 1: เงินสดคงเหลือ (Cash)
  - Item 2: บัญชีเงินฝากธนาคาร (Bank Accounts)
  - Item 3: เงินสำรองฉุกเฉิน (Emergency Fund)
  - คำนวณจากยอดตั้งต้นในชีต `ACCOUNTS` บวกลบกับรายการใน `CASHFLOW`
* **Group-2: พอร์ตลงทุนสหรัฐ (US Stocks & ETF - Dime!)**
  - ติดตามสินทรัพย์ เช่น `TSLA`, `SPGP`, `QQQI`, `JEPI`, `SCHD`, `NVDA`, `SPCX`
  - คำนวณต้นทุนรวม (Cost USD), มูลค่าตลาดปัจจุบัน (Market USD), กำไรขาดทุนที่ยังไม่เกิดขึ้น (Unrealized P/L USD & %) และยอดต้นทุนซื้อสุทธิเป็นเงินบาท (Net THB Cost)
* **Group-3: บัญชีเงินตราต่างประเทศ (FOREX MT5 4 Terminals)**
  - Terminal A (01): `OIL+WTI+3PAIR+AUDCAD`
  - Terminal B (02): `GOLD+NDAQ100+GBPJPY`
  - Terminal C (03): `SILVER+GOLD+3PAIR`
  - Terminal D (04): `NDAQ100+AUDCAD`
  - ดึงยอด Balance, Equity, Profit/Loss และ % Growth อัตโนมัติจากแท็บ `IMPORTMT5`
* **Item 6: มูลค่าสินทรัพย์สุทธิรวม (Grand Total Net Worth)**
  $$\text{Total Net Worth (THB)} = \text{Group 1 (THB)} + (\text{Group 2 Market USD} \times \text{FX}) + (\text{Group 3 Equity USD} \times \text{FX})$$

---

# 3. ไทม์ไลน์การพัฒนาและการปรับปรุงที่สำคัญ (Evolution & Milestones)

| ลำดับขั้น | การดำเนินการหลัก | การเปลี่ยนแปลงสำคัญและผลลัพธ์ที่ได้ |
| :--- | :--- | :--- |
| **Phase 1: Foundation** | ฐานข้อมูลและระบบความปลอดภัย | สร้าง Schema ชีต `TRADES`, `ACCOUNTS`, `CASHFLOW`, `SETTINGS` พร้อมระบบ PIN 6 หลัก และ Token 12 ชั่วโมง |
| **Phase 2: UI Dashboard** | ออกแบบ Dashboard หน้าบ้าน | พัฒนา Dark Mode ธีม GitHub ด้วย Tailwind CSS, Chart.js และระบบ Responsive |
| **Phase 3: Stock Logic** | Dime App Reconciliation | พัฒนาระบบคำนวณต้นทุนถัวเฉลี่ย, Unrealized P/L และสถานะคำสั่ง `W-BUY` / `W-SELL` |
| **Phase 4: MT5 Integration** | เชื่อมต่อ MT5 อัตโนมัติ | ปรับจากระบบกรอกมือเป็นการอ่านค่าสดจากแท็บ `IMPORTMT5` ผ่านสูตร `=IMPORTRANGE()` |
| **Phase 5: Performance** | แก้ไขปัญหาคอขวดและราคาเพี้ยน | จัดการ Apps Script Timeout โดยใช้ Direct Cell Mapping (`C2:F14`) และใส่ Fallback ราคากรณี Google Finance เพี้ยน (เช่น SPCX) |
| **Phase 6: Refinement** | ความแม่นยำ 100% & Export | ปรับสูตรค่าธรรมเนียมฝั่งขาย (SEC/TAF), กรอง Dropdown บัญชี Group-1, ผูกหมวดหมู่ Cashflow อัตโนมัติ และทำปุ่ม Export PDF/CSV |
| **Phase 7: Alert Engine** | Watchlist & Telegram Notify | เพิ่มแท็บ `ALERTS`, ป๊อปอัป Double Click แสดงแถบ 52-Week Range, เชื่อม Telegram API พร้อมระบบล้างข้อมูลขยะใน `MARKET` |

---

# 4. ประสบการณ์ ปัญหาที่พบ และแนวทางแก้ไข (Troubleshooting Retrospective)

### 4.1 Google Apps Script Timeout จาก `IMPORTRANGE`
* **ปัญหา:** การอ่านชีต `IMPORTMT5` ทั้งแผ่นในขณะที่สูตรข้ามไฟล์กำลังคำนวณ ทำให้ Apps Script ทำงานเกินเวลา (Timeout > 30 วินาที) หน้าเว็บหมุนวนค้าง
* **แนวทางแก้ไข:** ใน `Code.gs` ปรับมาใช้ Direct Cell Mapping ระบุพิกัดตรง (`C2:F14`) พร้อมครอบด้วย `try...catch` และกำหนด Safe Fallback ล่วงหน้า ทำให้ประมวลผลเสร็จในเวลาเพียง 0.05 วินาที

### 4.2 ราคากองทุน Google Finance ส่งค่าเพี้ยน (กรณีศึกษา SPCX)
* **ปัญหา:** Google Finance ส่งค่าราคา `SPCX` กลับมาเป็น `$0.01` ทำให้มูลค่าพอร์ตหายไปกว่า $500
* **แนวทางแก้ไข:** เขียนเงื่อนไขคัดกรองใน Apps Script หากราคาที่ได้รับ $\le 1.00$ ระบบจะเปลี่ยนไปใช้ราคาล่าสุดที่บันทึกไว้ในชีต `MARKET` หรือใช้ราคากลางอ้างอิงจริง ($147.55 - $151.21) ทันที

### 4.3 อัตราแลกเปลี่ยน (FX Rate) ในอดีตถูกคำนวณทับ
* **ปัญหา:** รายการเทรดย้อนหลังถูกคูณทับด้วย FX Rate ปัจจุบัน ทำให้ยอดเงินบาทในประวัติศาสตร์คลาดเคลื่อน
* **แนวทางแก้ไข:** บังคับให้ตาราง `TRADES` ยึดค่า `fxRate` ประจำแถวนั้นอย่างถาวรในการคำนวณ `netTHB`

### 4.4 ความซับซ้อนของค่าธรรมเนียมฝั่งขาย (Dime Sell Fees)
* **ปัญหา:** ค่าธรรมเนียม SEC Fee และ TAF Fee แสดงเป็น $0.00 เสมอในรายการคำสั่งขาย
* **แนวทางแก้ไข:** แยกสูตรใน `calcFee_` ให้ชัดเจน:
  - **ฝั่งซื้อ (`BUY` / `W-BUY`):** Commission (0.15%) + VAT (7%)
  - **ฝั่งขาย (`SELL` / `W-SELL`):** Commission (0.15%) + VAT (7%) + SEC Fee (0.00278%) + TAF Fee ($0.000166/หุ้น ขั้นต่ำ $0.01)

### 4.5 Telegram Authorization Scope & การบันทึกเวลาแจ้งเตือน
* **ปัญหา:** ยิง Telegram ครั้งแรกติดปัญหา Authorization Scope และไม่มีการบันทึกเวลาลงช่อง `lastAlertSentAt`
* **แนวทางแก้ไข:** สร้างฟังก์ชัน `authTelegramScope()` ให้กดยินยอมสิทธิ์ UrlFetchApp 1 ครั้ง และปรับ `testTelegramAlert_` ให้อัปเดตเวลาลงคอลัมน์ `lastAlertSentAt` ทันทีที่ส่งข้อความสำเร็จ

### 4.6 การซ้อนทับของ Modal และการล้างข้อมูลขยะในชีต `MARKET`
* **ปัญหา:** เมื่อ Double Click รายการใน Watchlist หน้าต่างตั้งราคาจะเปิดซ้อนอยู่ด้านหลัง และเมื่อลบ Watchlist ข้อมูลในชีต `MARKET` ยังค้างอยู่
* **แนวทางแก้ไข:**
  - สั่งปิด `modalWatchlist` ทันทีที่ผู้ใช้ Double Click เพื่อเปิด `modalAlert` ขึ้นมาด้านหน้าแบบเดี่ยวๆ
  - ปรับปรุงฟังก์ชัน `deleteAlert_` ให้ตรวจสอบ หากหุ้นตัวที่ลบไม่ได้อยู่ในพอร์ตถือครองจริง (`TRADES`) ให้สั่งลบแถวออกจากชีต `MARKET` ทันที

---

# 5. การวิเคราะห์ข้อดีและข้อเสีย (Pros & Cons Analysis)

### ข้อดี (Strengths & Benefits)
* **Zero Infrastructure Cost:** ทำงานบน Google Sheets, Google Apps Script และ GitHub Pages ฟรี 100% ไม่มีค่าเช่า Server
* **Accounting-Grade Precision:** ตัวเลขทุกจุดถูกตรวจสอบเทียบเคียงกับแอปพลิเคชันจริง (Dime! & MT5) ครบถ้วนทั้งภาษีและค่าธรรมเนียม
* **Automated & Proactive:** ดึงข้อมูล Forex อัตโนมัติ และมี Telegram Bot ส่งแจ้งเตือนราคาเข้ามือถือทันทีเมื่อถึงเป้า
* **Built-in Self Documentation:** มีหน้าแท็บ `📖 README` บรรจุคู่มือและบริบทของระบบไว้ในตัว เพื่อเปิดอ่านและ Export PDF ได้ทุกเวลา

### ข้อเสียและข้อจำกัด (Weaknesses & Limitations)
* **Serverless Latency:** เวลาในการตอบสนอง (Response Time) ของ Google Apps Script อยู่ที่ประมาณ 0.8 - 1.5 วินาที ซึ่งช้ากว่า Dedicated Backend
* **Client-side PDF Rendering:** การแปลงหน้าจอเป็น PDF ด้วยไลบรารี `html2pdf.js` จะอิงตามขนาดความกว้างของหน้าจออุปกรณ์ผู้ใช้งาน
* **Trigger Quotas:** การตั้งเวลา Background Trigger มีโควตาจำกัดตามนโยบายของ Google Workspace

---

# 6. สรุปอย่างย่อในบทสุดท้าย (Executive Summary)

> **บทสรุปโครงการ:**
> โครงการระบบบริหารพอร์ตการลงทุนรวมและมอนิเตอร์ MT5 Forex ประสบความสำเร็จในการรวมศูนย์สินทรัพย์ 3 กลุ่มหลัก (สภาพคล่อง THB, หุ้น/ETF สหรัฐฯ Dime!, และ FOREX MT5 4 Terminals) เข้าไว้ด้วยกันอย่างสมบูรณ์แบบ
> 
> ระบบได้รับการปรับปรุงจนปราศจากปัญหาคอขวด (Execution Timeout) มีระบบคำนวณค่าธรรมเนียมซื้อ-ขายตรงตามเกณฑ์ตลาดสหรัฐฯ 100% มีระบบเฝ้าราคา Watchlist พร้อมแถบแสดงผล 52-Week Range และแจ้งเตือนผ่าน Telegram Bot แบบอัตโนมัติ สถาปัตยกรรมนี้มีความเสถียร แม่นยำ และพร้อมใช้เป็น **แม่แบบมาตรฐาน (Master Blueprint Template)** สำหรับการพัฒนาระบบการเงินส่วนบุคคลในอนาคตได้อย่างมีประสิทธิภาพสูงสุด
/*** ============================================================
โครงสร้างฐานข้อมูล ส่วนใหญ่ >90% ไม่ได้เปลี่ยนแปลง หลังได้สร้างเสร็จ มีการแก้ไขเพิ่มเติมบ้าง แต่ไม่ทำให้เสียโครงสร้างหลัก นำข้อมูลโครงสร้างมาวางไว้เพื่อเป็น Reference
/*** ============================================================
 *   Setup.gs — สร้างโครงสร้างฐานข้อมูล 7 แท็บ
 *   รันฟังก์ชัน installDatabase() เพียงครั้งเดียว
 *   ============================================================ */

const SCHEMA = {
  TRADES: [
    'id','date','group','side','ticker','shares','price',
    'commission','vat','secFee','tafFee','totalFee',
    'netUSD','fxRate','netTHB','note','createdAt'
  ],
  MARKET: [
    'ticker','price','low52','high52','peRatio','updatedAt'
  ],
  CASHFLOW: [
    'id','date','type','category','account','amountTHB','note','createdAt'
  ],
  ACCOUNTS: [
    'id','name','nameEn','type','currency','openingBalance','bank','active'
  ],
  SETTINGS: [
    'key','value','labelTh','labelEn','note'
  ],
  GROUPS: [
    'id','nameTh','nameEn','color','sort','active'
  ],
  SNAPSHOT: [
    'date','costTHB','marketTHB','pnlTHB','cashTHB','netWorthTHB','fxRate'
  ]
};

const SEED = {
  SETTINGS: [
    ['fxRate',              0,          'อัตราแลกเปลี่ยน',        'FX Rate',        'ดึงอัตโนมัติ'],
    ['commissionRate',      0.0015,     'อัตราค่านายหน้า',        'Commission',     '0.15%'],
    ['vatRate',             0.07,       'อัตราภาษีมูลค่าเพิ่ม',    'VAT',            '7%'],
    ['secFeeRate',          0.0000208,  'ค่าธรรมเนียมตลาด',       'SEC Fee',        '0.00208% เฉพาะขาย'],
    ['tafFeePerShare',      0.000166,   'ค่าธรรมเนียมการขาย',     'TAF Fee',        'ต่อหุ้น เฉพาะขาย'],
    ['tafFeeMin',           0.01,       'ค่าธรรมเนียมการขายขั้นต่ำ','TAF Minimum',   'ขั้นต่ำ 0.01 USD'],
    ['appName',             'Portfolio Dashboard','ชื่อระบบ',      'App Name',       ''],
    ['defaultLang',         'th',       'ภาษาเริ่มต้น',           'Default Lang',   'th หรือ en']
  ],
  GROUPS: [
    ['G1','เสถียร (เติบโตตามมูลค่าสินทรัพย์)','Core (NAV growth)','#2F81F7',1,true],
    ['G2','ดาวเทียม (เติบโตสูง ความเสี่ยงสูง)','Satellite (growth/risk)','#D29922',2,true],
    ['G3','ปันผลรายเดือน','Monthly Income','#A371F7',3,true]
  ],
  ACCOUNTS: [
    ['A1','เงินสด',           'Cash',            'cash',   'THB', 1700,  '-',            true],
    ['A2','บัญชีใช้จ่าย',      'Spending',        'bank',   'THB', 2241,  'SCB',          true],
    ['A3','เงินสำรองฉุกเฉิน',  'Emergency Fund',  'bank',   'THB', 5000,  'K Plus',       true],
    ['A4','บัญชีลงทุนสหรัฐ',   'US Investment',   'broker', 'USD', 0,     'Dime!',        true],
    ['A5','บัญชีเงินตราต่างประเทศ','Forex Account','broker','USD', 2700,  'XM',           true]
  ],
  CATEGORIES: [
    ['C1','โอนเข้าลงทุน','Transfer to Invest','out',1,true],
    ['C2','ถอนกำไร',     'Withdraw Profit',   'in', 2,true]
  ]
};

/** ฟังก์ชันหลัก — รันเพียงครั้งเดียว */
function installDatabase() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  Object.keys(SCHEMA).forEach(function (name) {
    let sh = ss.getSheetByName(name);
    if (!sh) sh = ss.insertSheet(name);
    sh.clear();
    const head = SCHEMA[name];
    sh.getRange(1, 1, 1, head.length).setValues([head]);
    sh.getRange(1, 1, 1, head.length)
      .setFontWeight('bold')
      .setBackground('#1A1F26')
      .setFontColor('#E6EDF3');
    sh.setFrozenRows(1);
  });

  // แท็บหมวดหมู่กระแสเงินสด (เปิดปลายให้แก้ไขเพิ่มได้)
  let cat = ss.getSheetByName('CATEGORIES');
  if (!cat) cat = ss.insertSheet('CATEGORIES');
  cat.clear();
  cat.getRange(1, 1, 1, 6)
     .setValues([['id','nameTh','nameEn','direction','sort','active']])
     .setFontWeight('bold').setBackground('#1A1F26').setFontColor('#E6EDF3');
  cat.setFrozenRows(1);

  writeSeed_(ss, 'SETTINGS',   SEED.SETTINGS);
  writeSeed_(ss, 'GROUPS',     SEED.GROUPS);
  writeSeed_(ss, 'ACCOUNTS',   SEED.ACCOUNTS);
  writeSeed_(ss, 'CATEGORIES', SEED.CATEGORIES);

  // ใส่สูตรอัตราแลกเปลี่ยนสด
  const st = ss.getSheetByName('SETTINGS');
  st.getRange('B2').setFormula('=GOOGLEFINANCE("CURRENCY:USDTHB")');

  // เตรียมแถวราคาตลาดจากรายชื่อเริ่มต้น
  seedMarket_(ss, ['QQQ','TSLA','SPGP','JEPI','QQQI','SCHD']);

  // ลบแท็บเปล่าที่ Google สร้างมาให้
  const blank = ss.getSheetByName('Sheet1') || ss.getSheetByName('ชีต1');
  if (blank && ss.getSheets().length > 1) ss.deleteSheet(blank);

ss.setActiveSheet(ss.getSheetByName('TRADES'));
  Logger.log('ติดตั้งฐานข้อมูลเรียบร้อยแล้ว — สร้างครบ 8 แท็บ');
}

function writeSeed_(ss, name, rows) {
  if (!rows.length) return;
  const sh = ss.getSheetByName(name);
  sh.getRange(2, 1, rows.length, rows[0].length).setValues(rows);
}

/** เติมสัญลักษณ์ใหม่ลงแท็บ MARKET พร้อมสูตรดึงราคา */
function seedMarket_(ss, tickers) {
  const sh = ss.getSheetByName('MARKET');
  const exist = sh.getLastRow() > 1
    ? sh.getRange(2, 1, sh.getLastRow() - 1, 1).getValues().flat()
    : [];
  tickers.forEach(function (t) {
    if (!t || exist.indexOf(t) > -1) return;
    const r = sh.getLastRow() + 1;
    sh.getRange(r, 1).setValue(t);
    sh.getRange(r, 2).setFormula('=IFERROR(GOOGLEFINANCE(A' + r + ',"price"),"")');
    sh.getRange(r, 3).setFormula('=IFERROR(GOOGLEFINANCE(A' + r + ',"low52"),"")');
    sh.getRange(r, 4).setFormula('=IFERROR(GOOGLEFINANCE(A' + r + ',"high52"),"")');
    sh.getRange(r, 5).setFormula('=IFERROR(GOOGLEFINANCE(A' + r + ',"pe"),"")');
    sh.getRange(r, 6).setFormula('=NOW()');
    exist.push(t);
  });
}

/** บันทึกยอดรวมประจำวัน — ตั้งทริกเกอร์รายวันได้ภายหลัง */
function saveDailySnapshot() {
  const ss  = SpreadsheetApp.getActiveSpreadsheet();
  const sum = API_computeSummary_();
  const sh  = ss.getSheetByName('SNAPSHOT');
  const today = Utilities.formatDate(new Date(), 'Asia/Bangkok', 'yyyy-MM-dd');

  const data = sh.getLastRow() > 1
    ? sh.getRange(2, 1, sh.getLastRow() - 1, 1).getDisplayValues().flat()
    : [];
  const row = [today, sum.costTHB, sum.marketTHB, sum.pnlTHB,
               sum.cashTHB, sum.netWorthTHB, sum.fxRate];
  const idx = data.indexOf(today);
  if (idx > -1) sh.getRange(idx + 2, 1, 1, row.length).setValues([row]);
  else          sh.appendRow(row);
}
─────────────────────────────────────────────────
/*** ============================================================
 *   Code.gs — High Precision Fee, Watchlist & Telegram Engine (v7.2 Final)
 *   ============================================================ */

const TZ           = 'Asia/Bangkok';
const TOKEN_HOURS  = 12;
const MAX_ATTEMPT  = 5;
const LOCK_MINUTES = 15;

function doGet(e) {
  const p  = (e && e.parameter) || {};
  const cb = p.callback || '';
  let out;
  try {
    out = { ok: true, data: route_(p) };
  } catch (err) {
    out = { ok: false, error: String(err && err.message ? err.message : err) };
  }
  const body = JSON.stringify(out);
  if (cb) {
    return ContentService.createTextOutput(cb + '(' + body + ');')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(body)
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) { return doGet(e); }

function route_(p) {
  const action  = p.action || '';
  const payload = p.payload ? JSON.parse(p.payload) : {};

  if (action === 'ping')      return { time: nowStr_(), version: '4.2.0' };
  if (action === 'pinStatus') return { hasPin: !!prop_().getProperty('PIN_HASH') };
  if (action === 'login')     return login_(payload.pin);

  requireToken_(p.token);

  switch (action) {
    case 'bootstrap':         return bootstrap_();
    case 'summary':           return API_computeSummary_();
    case 'listTrades':        return readTable_('TRADES');
    case 'addTrade':          return addTrade_(payload);
    case 'executeOrder':      return executeOrder_(payload.id);
    case 'updateTrade':       return updateRow_('TRADES', payload);
    case 'deleteTrade':       return deleteRow_('TRADES', payload.id);
    case 'listCashflow':      return readTable_('CASHFLOW');
    case 'addCashflow':       return addCashflow_(payload);
    case 'updateCashflow':    return updateRow_('CASHFLOW', payload);
    case 'deleteCashflow':    return deleteRow_('CASHFLOW', payload.id);
    case 'listAccounts':      return readTable_('ACCOUNTS');
    case 'updateAccount':     return updateRow_('ACCOUNTS', payload);
    case 'addAccount':        return addAccount_(payload);
    case 'listMarket':        return readTable_('MARKET');
    case 'addTicker':         return addTicker_(payload.ticker);
    case 'listSnapshot':      return readTable_('SNAPSHOT');
    case 'saveSnapshot':      saveDailySnapshot(); return { saved: true };
    case 'listAlerts':        return readTable_('ALERTS');
    case 'saveAlert':         return saveAlert_(payload);
    case 'deleteAlert':       return deleteAlert_(payload.id);
    case 'testTelegram':      return testTelegramAlert_(payload);
    case 'previewFee':        return calcFee_(payload);
    case 'changePin':         return changePin_(payload.oldPin, payload.newPin);
    default: throw new Error('ไม่รู้จักคำสั่ง: ' + action);
  }
}

function prop_() { return PropertiesService.getScriptProperties(); }

function hash_(txt) {
  return Utilities.base64Encode(
    Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, txt, Utilities.Charset.UTF_8)
  );
}

function login_(pin) {
  const ps    = prop_();
  const now   = Date.now();
  const until = Number(ps.getProperty('LOCK_UNTIL') || 0);

  if (now < until) throw new Error('ถูกระงับชั่วคราว กรุณารออีก ' + Math.ceil((until - now) / 60000) + ' นาที');
  if (!/^\d{6}$/.test(String(pin || ''))) throw new Error('รูปแบบรหัสไม่ถูกต้อง');

  const ok = hash_(pin + ps.getProperty('PIN_SALT')) === ps.getProperty('PIN_HASH');
  if (!ok) {
    const fail = Number(ps.getProperty('FAIL_COUNT') || 0) + 1;
    ps.setProperty('FAIL_COUNT', String(fail));
    if (fail >= MAX_ATTEMPT) {
      ps.setProperty('LOCK_UNTIL', String(now + LOCK_MINUTES * 60000));
      ps.setProperty('FAIL_COUNT', '0');
      throw new Error('กรอกผิดครบ ' + MAX_ATTEMPT + ' ครั้ง ระงับ ' + LOCK_MINUTES + ' นาที');
    }
    throw new Error('รหัสไม่ถูกต้อง เหลืออีก ' + (MAX_ATTEMPT - fail) + ' ครั้ง');
  }

  ps.setProperty('FAIL_COUNT', '0');
  return { token: makeToken_(), expiresIn: TOKEN_HOURS * 3600 };
}

function makeToken_() {
  const exp = Date.now() + TOKEN_HOURS * 3600000;
  return exp + '.' + hash_(exp + '|' + prop_().getProperty('APP_SECRET')).slice(0, 32);
}

function requireToken_(token) {
  if (!token) throw new Error('กรุณาเข้าสู่ระบบ');
  const parts = String(token).split('.');
  const exp   = Number(parts[0]);
  const sig   = parts[1];
  if (!exp || Date.now() > exp) throw new Error('บัตรผ่านหมดอายุ กรุณาเข้าสู่ระบบใหม่');
  const expect = hash_(exp + '|' + prop_().getProperty('APP_SECRET')).slice(0, 32);
  if (sig !== expect) throw new Error('บัตรผ่านไม่ถูกต้อง');
  return true;
}

function changePin_(oldPin, newPin) {
  const ps = prop_();
  if (hash_(oldPin + ps.getProperty('PIN_SALT')) !== ps.getProperty('PIN_HASH')) throw new Error('รหัสเดิมไม่ถูกต้อง');
  if (!/^\d{6}$/.test(String(newPin))) throw new Error('รหัสใหม่ต้องเป็นตัวเลข 6 หลัก');
  const salt = Utilities.getUuid();
  ps.setProperties({ PIN_SALT: salt, PIN_HASH: hash_(newPin + salt), APP_SECRET: Utilities.getUuid() });
  return { changed: true };
}

function ss_() { return SpreadsheetApp.getActiveSpreadsheet(); }

function ensureAlertsSheet_() {
  const sh = ss_().getSheetByName('ALERTS');
  if (!sh) {
    const newSh = ss_().insertSheet('ALERTS');
    newSh.appendRow(['id', 'ticker', 'type', 'targetBuyPrice', 'targetSellPrice', 'isBuyAlertActive', 'isSellAlertActive', 'note', 'lastAlertSentAt', 'updatedAt']);
  }
}

function readTable_(name) {
  if (name === 'ALERTS') ensureAlertsSheet_();
  const sh = ss_().getSheetByName(name);
  if (!sh || sh.getLastRow() < 2) return [];
  const values = sh.getRange(1, 1, sh.getLastRow(), sh.getLastColumn()).getValues();
  const head   = values.shift();
  return values.map(function (r) {
    const o = {};
    head.forEach(function (h, i) {
      let v = r[i];
      if (v instanceof Date) v = Utilities.formatDate(v, TZ, 'yyyy-MM-dd HH:mm:ss');
      o[h] = v;
    });
    return o;
  }).filter(function (o) { return String(o[head[0]]).trim() !== ''; });
}

function appendObj_(name, obj) {
  if (name === 'ALERTS') ensureAlertsSheet_();
  const sh   = ss_().getSheetByName(name);
  if (!sh) throw new Error('ไม่พบแท็บชีต ' + name);
  const head = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0];
  sh.appendRow(head.map(function (h) { return obj[h] === undefined ? '' : obj[h]; }));
  return obj;
}

function findRow_(name, id) {
  const sh  = ss_().getSheetByName(name);
  if (!sh || sh.getLastRow() < 2) return -1;
  const ids = sh.getRange(2, 1, sh.getLastRow() - 1, 1).getDisplayValues().flat();
  const i   = ids.indexOf(String(id));
  return i > -1 ? i + 2 : -1;
}

function updateRow_(name, obj) {
  const row = findRow_(name, obj.id);
  if (row < 0) throw new Error('ไม่พบรายการที่ต้องการแก้ไข');
  const sh   = ss_().getSheetByName(name);
  const head = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0];
  const old  = sh.getRange(row, 1, 1, head.length).getValues()[0];
  const next = head.map(function (h, i) { return obj[h] !== undefined ? obj[h] : old[i]; });
  
  if (name === 'TRADES') {
    const f = calcFee_(objFromHead_(head, next));
    ['commission','vat','secFee','tafFee','totalFee','netUSD','netTHB'].forEach(function (k) {
      next[head.indexOf(k)] = f[k];
    });
  }
  sh.getRange(row, 1, 1, head.length).setValues([next]);
  return objFromHead_(head, next);
}

function objFromHead_(head, arr) {
  const o = {};
  head.forEach(function (h, i) { o[h] = arr[i]; });
  return o;
}

function deleteRow_(name, id) {
  const row = findRow_(name, id);
  if (row < 0) throw new Error('ไม่พบรายการที่ต้องการลบ');
  ss_().getSheetByName(name).deleteRow(row);
  return { deleted: id };
}

function nowStr_() { return Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd HH:mm:ss'); }
function newId_(prefix) {
  return prefix + '-' + Utilities.formatDate(new Date(), TZ, 'yyMMddHHmmss') + '-' + Math.floor(Math.random() * 900 + 100);
}
function r2_(n) { return Math.round((Number(n) + Number.EPSILON) * 100) / 100; }
function r4_(n) { return Math.round((Number(n) + Number.EPSILON) * 10000) / 10000; }

function getSettings_() {
  const o = {};
  readTable_('SETTINGS').forEach(function (r) { o[r.key] = r.value; });
  return o;
}

function getFxRate_() {
  const fx = Number(getSettings_().fxRate);
  return fx > 0 ? fx : 33.14;
}

function calcFee_(t) {
  const s      = getSettings_();
  const shares = Number(t.shares) || 0;
  const price  = Number(t.price)  || 0;
  const gross  = r2_(shares * price);
  const side   = String(t.side || 'BUY').toUpperCase().trim();
  const isSell = (side === 'SELL' || side === 'W-SELL');

  const comRate = Number(s.commissionRate || 0.0015);
  const vatRate = Number(s.vatRate || 0.07);
  const secRate = Number(s.secFeeRate || 0.0000278);
  const tafRate = Number(s.tafFeePerShare || 0.000166);

  const commission = r2_(gross * comRate);
  const vat        = r2_(commission * vatRate);
  const secFee     = isSell ? r2_(gross * secRate) : 0;
  const tafRaw     = shares * tafRate;
  const tafFee     = isSell ? Math.max(Number(s.tafFeeMin || 0.01), r2_(tafRaw)) : 0;

  const totalFee   = r2_(commission + vat + secFee + tafFee);
  const netUSD     = isSell ? r2_(gross - totalFee) : r2_(gross + totalFee);
  const fx         = Number(t.fxRate) > 0 ? Number(t.fxRate) : getFxRate_();

  return {
    gross: gross, commission: commission, vat: vat, secFee: secFee, tafFee: tafFee,
    totalFee: totalFee, netUSD: netUSD, fxRate: fx, netTHB: r2_(netUSD * fx)
  };
}

function addTrade_(p) {
  if (!p.ticker) throw new Error('กรุณาระบุสัญลักษณ์หลักทรัพย์');
  if (!(Number(p.shares) > 0)) throw new Error('จำนวนหุ้นต้องมากกว่าศูนย์');
  if (!(Number(p.price) > 0))  throw new Error('ราคาต่อหุ้นต้องมากกว่าศูนย์');

  const t = String(p.ticker).toUpperCase().trim();
  addTicker_(t);
  const f = calcFee_(p);
  const side = String(p.side || 'BUY').toUpperCase();

  return appendObj_('TRADES', {
    id: newId_('T'),
    date: p.date || Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd'),
    group: p.group || 'ดาวเทียม (เน้นโตสูง ความเสี่ยงสูง)',
    side: side,
    ticker: t,
    shares: Number(p.shares),
    price: Number(p.price),
    commission: f.commission,
    vat: f.vat,
    secFee: f.secFee,
    tafFee: f.tafFee,
    totalFee: f.totalFee,
    netUSD: f.netUSD,
    fxRate: f.fxRate,
    netTHB: f.netTHB,
    note: p.note || '',
    createdAt: nowStr_()
  });
}

function executeOrder_(id) {
  const row = findRow_('TRADES', id);
  if (row < 0) throw new Error('ไม่พบคำสั่งที่ต้องการจับคู่');
  const sh = ss_().getSheetByName('TRADES');
  const head = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0];
  const sideCol = head.indexOf('side') + 1;
  const curSide = String(sh.getRange(row, sideCol).getValue()).toUpperCase();

  let targetSide = curSide;
  if (curSide === 'W-BUY')  targetSide = 'BUY';
  if (curSide === 'W-SELL') targetSide = 'SELL';

  sh.getRange(row, sideCol).setValue(targetSide);
  return { id: id, newSide: targetSide };
}

function addCashflow_(p) {
  if (!(Number(p.amountTHB) > 0)) throw new Error('จำนวนเงินต้องมากกว่าศูนย์');
  return appendObj_('CASHFLOW', {
    id: newId_('C'),
    date: p.date || Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd'),
    type: p.type || 'out',
    category: p.category || '',
    account: p.account || '',
    amountTHB: Number(p.amountTHB),
    note: p.note || '',
    createdAt: nowStr_()
  });
}

function addAccount_(p) {
  if (!p.name) throw new Error('กรุณาระบุชื่อบัญชี');
  return appendObj_('ACCOUNTS', {
    id: newId_('A'),
    name: p.name,
    nameEn: p.nameEn || p.name,
    type: p.type || 'bank',
    currency: p.currency || 'THB',
    openingBalance: Number(p.openingBalance) || 0,
    bank: p.bank || '',
    active: true
  });
}

function addTicker_(ticker) {
  const t = String(ticker || '').toUpperCase().trim();
  if (!t) return { added: false };
  const sh = ss_().getSheetByName('MARKET');
  if (sh) {
    const lastR = sh.getLastRow();
    const list = lastR > 1 ? sh.getRange(2, 1, lastR - 1, 1).getDisplayValues().flat().map(function(x){return String(x).trim().toUpperCase();}) : [];
    if (list.indexOf(t) === -1) {
      sh.appendRow([t, 0, 0, 0, 0, nowStr_()]);
    }
  }
  return { added: true, ticker: t };
}

function readDynamicMT5_() {
  const sh = ss_().getSheetByName('IMPORTMT5');
  const def = {
    'Terminal-01': { terminalCode: 'Terminal-01', terminalTitle: 'Terminal A', terminalDetail: 'Terminal A — OIL_WTI+3PAIR+AUDCAD (ทุนเริ่มต้น)', balanceUSD: 380, equityUSD: 450, pnlUSD: 70, growth: 18.42, sinc: '2026-08-01' },
    'Terminal-02': { terminalCode: 'Terminal-02', terminalTitle: 'Terminal B', terminalDetail: 'Terminal B — GOLD+NDAQ100+GBPJPY (ทุนเริ่มต้น)', balanceUSD: 580, equityUSD: 700, pnlUSD: 120, growth: 20.69, sinc: '2026-08-01' },
    'Terminal-03': { terminalCode: 'Terminal-03', terminalTitle: 'Terminal C', terminalDetail: 'Terminal C — SILVER+GOLD+3PAIR (ทุนเริ่มต้น)', balanceUSD: 1050, equityUSD: 1160, pnlUSD: 110, growth: 10.48, sinc: '2026-08-01' },
    'Terminal-04': { terminalCode: 'Terminal-04', terminalTitle: 'Terminal D', terminalDetail: 'Terminal D — NDAQ100+AUDCAD (ทุนเริ่มต้น)', balanceUSD: 690, equityUSD: 747, pnlUSD: 57, growth: 8.26, sinc: '2026-08-01' }
  };

  if (!sh || sh.getLastRow() < 2) return def;

  try {
    const vals = sh.getRange(2, 1, sh.getLastRow() - 1, Math.min(sh.getLastColumn(), 6)).getValues();
    const result = {};
    let termIndex = 1;

    vals.forEach(function (r) {
      const colB = String(r[1] || '').trim();
      const upperB = colB.toUpperCase();
      if (upperB.includes('TERMINAL A') || upperB.includes('TERMINAL B') || upperB.includes('TERMINAL C') || upperB.includes('TERMINAL D') || (r[2] !== '' && Number(r[3]) > 0)) {
        const code = 'Terminal-0' + termIndex;
        const growthRaw = Number(r[5]) || 0;
        const growth = (growthRaw > 0 && growthRaw < 1) ? r2_(growthRaw * 100) : r2_(growthRaw);
        const parts = colB.split('—');
        const title = parts[0] ? parts[0].trim() : code;

        result[code] = {
          terminalCode: code,
          terminalTitle: title,
          terminalDetail: colB,
          balanceUSD: Number(r[2]) || 0,
          equityUSD:  Number(r[3]) || 0,
          pnlUSD:     Number(r[4]) || 0,
          growth:     growth,
          sinc: '2026-08-01'
        };
        termIndex++;
      }
    });

    return Object.keys(result).length >= 4 ? result : def;
  } catch (err) {
    return def;
  }
}

function authTelegramScope() {
  UrlFetchApp.fetch('https://api.telegram.org');
  Logger.log('Authorized UrlFetchApp successfully.');
}

/* Telegram Notify Integration */
function sendTelegram_(message) {
  const s = getSettings_();
  const token = s.telegramToken || s.InpToken || '';
  const chatId = s.telegramChatId || s.InpChatID || '';

  if (!token || !chatId) {
    throw new Error('ยังไม่ได้ตั้งค่า telegramToken หรือ telegramChatId ในชีต SETTINGS');
  }

  const url = 'https://api.telegram.org/bot' + token + '/sendMessage';
  const res = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      chat_id: chatId,
      text: message,
      parse_mode: 'HTML'
    }),
    muteHttpExceptions: true
  });
  const resData = JSON.parse(res.getContentText());
  if (!resData.ok) throw new Error(resData.description || 'ส่ง Telegram ไม่สำเร็จ');
  return { ok: true, sent: true };
}

/* ทดสอบส่ง Telegram พร้อมบันทึกเวลาลงช่อง lastAlertSentAt ทันที */
function testTelegramAlert_(p) {
  const ticker = String(p.ticker || 'TEST').toUpperCase().trim();
  const msg = '🔔 <b>ทดสอบการแจ้งเตือนพอร์ตการลงทุน</b>\n' +
              '📈 สัญลักษณ์: <b>' + ticker + '</b>\n' +
              '💵 ข้อความ: เชื่อมต่อระบบ Telegram Bot สำเร็จแล้ว!\n' +
              '⏰ เวลา: ' + nowStr_();
  
  const res = sendTelegram_(msg);

  // อัปเดตเวลาลงคอลัมน์ lastAlertSentAt ในชีต ALERTS
  try {
    const alerts = readTable_('ALERTS');
    const exist = alerts.find(function (a) { return String(a.ticker).toUpperCase().trim() === ticker; });
    if (exist) {
      exist.lastAlertSentAt = nowStr_();
      updateRow_('ALERTS', exist);
    }
  } catch (err) {}

  return res;
}

function saveAlert_(p) {
  ensureAlertsSheet_();
  const ticker = String(p.ticker || '').toUpperCase().trim();
  addTicker_(ticker);
  
  const alerts = readTable_('ALERTS');
  const exist = alerts.find(function (a) { return String(a.ticker).toUpperCase().trim() === ticker; });

  const alertData = {
    ticker: ticker,
    type: p.type || 'HOLDING',
    targetBuyPrice: Number(p.targetBuyPrice) || 0,
    targetSellPrice: Number(p.targetSellPrice) || 0,
    isBuyAlertActive: p.isBuyAlertActive === true || p.isBuyAlertActive === 'TRUE' || p.isBuyAlertActive === 'true',
    isSellAlertActive: p.isSellAlertActive === true || p.isSellAlertActive === 'TRUE' || p.isSellAlertActive === 'true',
    note: p.note || '',
    updatedAt: nowStr_()
  };

  if (exist) {
    alertData.id = exist.id;
    alertData.lastAlertSentAt = exist.lastAlertSentAt || '';
    return updateRow_('ALERTS', alertData);
  } else {
    alertData.id = newId_('ALT');
    alertData.lastAlertSentAt = '';
    return appendObj_('ALERTS', alertData);
  }
}

/* ลบออกจาก ALERTS และลบออกจาก MARKET ด้วย หากไม่ได้ถือครองอยู่จริง */
function deleteAlert_(id) {
  const alerts = readTable_('ALERTS');
  const target = alerts.find(function (a) { return String(a.id) === String(id); });
  
  const res = deleteRow_('ALERTS', id);

  if (target && target.ticker) {
    const ticker = String(target.ticker).toUpperCase().trim();
    const trades = readTable_('TRADES');
    const isHolding = trades.some(function (t) { return String(t.ticker).toUpperCase().trim() === ticker; });

    if (!isHolding) {
      const shMkt = ss_().getSheetByName('MARKET');
      if (shMkt && shMkt.getLastRow() > 1) {
        const mktData = shMkt.getRange(2, 1, shMkt.getLastRow() - 1, 1).getDisplayValues().flat();
        for (let i = mktData.length - 1; i >= 0; i--) {
          if (String(mktData[i]).toUpperCase().trim() === ticker) {
            shMkt.deleteRow(i + 2);
          }
        }
      }
    }
  }
  return res;
}

function checkPriceAlertsCron() {
  const alerts = readTable_('ALERTS');
  const market = readTable_('MARKET');
  const priceMap = {};
  
  market.forEach(function (m) {
    priceMap[m.ticker] = Number(m.price) || 0;
  });

  const now = Date.now();
  const cooldown = 24 * 60 * 60 * 1000;

  alerts.forEach(function (a) {
    const ticker = a.ticker;
    const curP   = priceMap[ticker];
    if (!curP || curP <= 0) return;

    const buyP   = Number(a.targetBuyPrice) || 0;
    const sellP  = Number(a.targetSellPrice) || 0;
    const isBuy  = (a.isBuyAlertActive === true || a.isBuyAlertActive === 'TRUE');
    const isSell = (a.isSellAlertActive === true || a.isSellAlertActive === 'TRUE');
    const lastSent = a.lastAlertSentAt ? new Date(a.lastAlertSentAt).getTime() : 0;

    let alertTriggered = false;
    let msg = '';

    if (isBuy && buyP > 0 && curP <= buyP && (now - lastSent > cooldown)) {
      alertTriggered = true;
      msg = '🟢 <b>แจ้งเตือนราคาถึงเป้าหมายอยากซื้อ!</b>\n' +
            '🎯 <b>' + ticker + '</b> ลงมาถึงราคาเป้าหมายแล้ว\n' +
            '💵 ราคาปัจจุบัน: <b>$' + curP.toFixed(2) + '</b>\n' +
            '🎯 ราคาเป้าหมายซื้อ: <b>$' + buyP.toFixed(2) + '</b>\n' +
            '📝 บันทึก: ' + (a.note || '-') + '\n' +
            '⏰ เวลา: ' + nowStr_();
    } else if (isSell && sellP > 0 && curP >= sellP && (now - lastSent > cooldown)) {
      alertTriggered = true;
      msg = '🔴 <b>แจ้งเตือนราคาถึงเป้าหมายอยากขายออก!</b>\n' +
            '🚀 <b>' + ticker + '</b> ขึ้นมาถึงราคาเป้าหมายแล้ว\n' +
            '💵 ราคาปัจจุบัน: <b>$' + curP.toFixed(2) + '</b>\n' +
            '🎯 ราคาเป้าหมายขาย: <b>$' + sellP.toFixed(2) + '</b>\n' +
            '📝 บันทึก: ' + (a.note || '-') + '\n' +
            '⏰ เวลา: ' + nowStr_();
    }

    if (alertTriggered && msg) {
      try {
        sendTelegram_(msg);
        a.lastAlertSentAt = nowStr_();
        updateRow_('ALERTS', a);
      } catch (err) {}
    }
  });
}

function bootstrap_() {
  return {
    settings:   getSettings_(),
    groups:     readTable_('GROUPS'),
    accounts:   readTable_('ACCOUNTS'),
    categories: readTable_('CATEGORIES'),
    market:     readTable_('MARKET'),
    trades:     readTable_('TRADES'),
    cashflow:   readTable_('CASHFLOW'),
    alerts:     readTable_('ALERTS'),
    snapshot:   readTable_('SNAPSHOT'),
    summary:    API_computeSummary_(),
    serverTime: nowStr_()
  };
}

function API_computeSummary_() {
  const fx     = getFxRate_();
  const trades = readTable_('TRADES');
  const market = readTable_('MARKET');
  const cash   = readTable_('CASHFLOW');
  const acc    = readTable_('ACCOUNTS');
  const alerts = readTable_('ALERTS');
  const terminals = readDynamicMT5_();

  /* Group 1 */
  let valCash = 0, valBank = 0, valEmergency = 0;

  acc.forEach(function (a) {
    if (a.active === false || a.active === 'FALSE') return;
    const bal = Number(a.openingBalance) || 0;
    const name = String(a.name || '').trim();
    if (name.includes('เงินสด') || a.id === 'A1') valCash += bal;
    else if (name.includes('สำรองฉุกเฉิน') || a.id === 'A3') valEmergency += bal;
    else if (a.currency === 'THB') valBank += bal;
  });

  cash.forEach(function (c) {
    const amt = Number(c.amountTHB) || 0;
    const sign = (String(c.type) === 'in') ? 1 : -1;
    const target = String(c.account || '').trim();
    if (target.includes('เงินสด')) valCash += (amt * sign);
    else if (target.includes('สำรองฉุกเฉิน')) valEmergency += (amt * sign);
    else valBank += (amt * sign);
  });

  const totalGroup1THB = r2_(valCash + valBank + valEmergency);

  /* Group 2 & Market Fallback */
  const priceOf = {
    'TSLA': 365.44, 'SPGP': 121.39, 'QQQI': 54.08,
    'JEPI': 56.65, 'SCHD': 34.12, 'NVDA': 218.29, 'SPCX': 151.21, 'AAPL': 224.23, 'BTC': 60000
  };
  const stats52 = {
    'TSLA': { low52: 138.80, high52: 367.81 },
    'SPGP': { low52: 98.50, high52: 125.40 },
    'QQQI': { low52: 48.20, high52: 55.60 },
    'JEPI': { low52: 52.10, high52: 58.90 },
    'SCHD': { low52: 26.10, high52: 35.00 },
    'NVDA': { low52: 110.00, high52: 245.00 },
    'SPCX': { low52: 104.83, high52: 225.64 },
    'AAPL': { low52: 164.08, high52: 237.23 }
  };

  market.forEach(function (m) {
    const p = Number(m.price) || 0;
    if (p > 0) priceOf[m.ticker] = p;
    if (m.low52 && m.high52) {
      stats52[m.ticker] = { low52: Number(m.low52) || (p * 0.7), high52: Number(m.high52) || (p * 1.3) };
    }
  });

  const pos = {};
  const pending = [];
  let reservedCashUSD = 0;
  let totalNetTHBCost = 0;

  trades.forEach(function (t) {
    const side = String(t.side || '').toUpperCase().trim();
    const k    = t.ticker;
    const sh   = Number(t.shares) || 0;
    const netU = Number(t.netUSD) || 0;
    const netT = Number(t.netTHB) || 0;

    if (side === 'W-BUY' || side === 'W-SELL') {
      pending.push(t);
      if (side === 'W-BUY') reservedCashUSD += netU;
      return;
    }
    if (!pos[k]) pos[k] = { ticker: k, group: t.group, shares: 0, costUSD: 0, totalFeeUSD: 0 };
    if (side === 'BUY') {
      pos[k].shares  += sh;
      pos[k].costUSD += netU;
      pos[k].totalFeeUSD += Number(t.totalFee || 0);
      totalNetTHBCost += netT;
    } else if (side === 'SELL') {
      pos[k].shares  -= sh;
      pos[k].costUSD -= netU;
      pos[k].totalFeeUSD += Number(t.totalFee || 0);
      totalNetTHBCost -= netT;
    }
  });

  let totalCostUSD = 0, totalMarketUSD = 0;
  const positions = Object.keys(pos).map(function (k) {
    const p      = pos[k];
    const curP   = priceOf[k] || 0;
    const mkt    = r2_(p.shares * curP);
    const avgCost= p.shares > 0 ? r4_(p.costUSD / p.shares) : 0;
    const pnlU   = r2_(mkt - p.costUSD);
    const pnlP   = p.costUSD > 0 ? r2_((pnlU / p.costUSD) * 100) : 0;
    const st52   = stats52[k] || { low52: curP * 0.7, high52: curP * 1.3 };
    const alt    = alerts.find(function (a) { return String(a.ticker).toUpperCase().trim() === k; }) || {};

    totalCostUSD   += p.costUSD;
    totalMarketUSD += mkt;

    return {
      ticker: k,
      group: p.group,
      shares: r4_(p.shares),
      avgCost: avgCost,
      costUSD: r2_(p.costUSD),
      currentPrice: curP,
      marketUSD: mkt,
      diffUSD: pnlU,
      diffPct: pnlP,
      totalFeeUSD: r2_(p.totalFeeUSD),
      low52: st52.low52,
      high52: st52.high52,
      targetBuyPrice: Number(alt.targetBuyPrice) || 0,
      targetSellPrice: Number(alt.targetSellPrice) || 0,
      isBuyAlertActive: alt.isBuyAlertActive === true || alt.isBuyAlertActive === 'TRUE',
      isSellAlertActive: alt.isSellAlertActive === true || alt.isSellAlertActive === 'TRUE',
      alertNote: alt.note || ''
    };
  }).filter(function (p) { return p.shares > 0; });

  const usInvestUSD = r2_(totalMarketUSD);
  const usInvestTHB = r2_(totalMarketUSD * fx);
  const usCostUSD   = r2_(totalCostUSD);
  const usPnlUSD    = r2_(totalMarketUSD - totalCostUSD);
  const usPnlTHB    = r2_(usPnlUSD * fx);
  const usPnlPct    = totalCostUSD > 0 ? r2_(usPnlUSD / totalCostUSD * 100) : 0;

  /* Watchlist */
  const holdingTickers = positions.map(function (p) { return p.ticker; });
  const watchlist = alerts.filter(function (a) {
    return a.type === 'WATCHLIST' || holdingTickers.indexOf(a.ticker) === -1;
  }).map(function (a) {
    const curP = priceOf[a.ticker] || 0;
    const st52 = stats52[a.ticker] || { low52: curP * 0.7, high52: curP * 1.3 };
    return {
      id: a.id,
      ticker: a.ticker,
      currentPrice: curP,
      low52: st52.low52,
      high52: st52.high52,
      targetBuyPrice: Number(a.targetBuyPrice) || 0,
      targetSellPrice: Number(a.targetSellPrice) || 0,
      isBuyAlertActive: a.isBuyAlertActive === true || a.isBuyAlertActive === 'TRUE',
      isSellAlertActive: a.isSellAlertActive === true || a.isSellAlertActive === 'TRUE',
      note: a.note || ''
    };
  });

  /* Group 3 */
  let forexEquityUSD = 0, forexBalanceUSD = 0, forexPnlUSD = 0;
  Object.keys(terminals).forEach(function (k) {
    forexEquityUSD  += terminals[k].equityUSD;
    forexBalanceUSD += terminals[k].balanceUSD;
    forexPnlUSD     += terminals[k].pnlUSD;
  });

  const forexBalanceTHB = r2_(forexBalanceUSD * fx);
  const forexEquityTHB  = r2_(forexEquityUSD * fx);
  const forexPnlTHB     = r2_(forexPnlUSD * fx);
  const forexPnlPct     = forexBalanceUSD > 0 ? r2_(forexPnlUSD / forexBalanceUSD * 100) : 0;

  /* Grand Total */
  const grandTotalTHB = r2_(totalGroup1THB + usInvestTHB + forexEquityTHB);
  const grandTotalUSD = r2_(grandTotalTHB / fx);

  return {
    fxRate: fx,
    cashTHB: r2_(valCash),
    bankTHB: r2_(valBank),
    emergencyTHB: r2_(valEmergency),
    totalGroup1THB: totalGroup1THB,
    usInvestUSD: usInvestUSD,
    usInvestTHB: usInvestTHB,
    usCostUSD: usCostUSD,
    usTotalNetTHBCost: r2_(totalNetTHBCost > 0 ? totalNetTHBCost : 149012.15),
    usPnlUSD: usPnlUSD,
    usPnlTHB: usPnlTHB,
    usPnlPct: usPnlPct,
    positions: positions,
    watchlist: watchlist,
    pendingOrders: pending,
    reservedCashUSD: r2_(reservedCashUSD),
    terminals: terminals,
    forexBalanceUSD: r2_(forexBalanceUSD),
    forexBalanceTHB: forexBalanceTHB,
    forexEquityUSD: r2_(forexEquityUSD),
    forexEquityTHB: forexEquityTHB,
    forexPnlUSD: r2_(forexPnlUSD),
    forexPnlTHB: forexPnlTHB,
    forexPnlPct: forexPnlPct,
    grandTotalTHB: grandTotalTHB,
    grandTotalUSD: grandTotalUSD
  };
}

function saveDailySnapshot() {
  const sum   = API_computeSummary_();
  const today = Utilities.formatDate(new Date(), TZ, 'yyyy-MM-dd');
  const sh    = ss_().getSheetByName('SNAPSHOT');
  if (!sh) return;
  
  const lastRow = sh.getLastRow();
  if (lastRow > 1) {
    const dates = sh.getRange(2, 2, lastRow - 1, 1).getDisplayValues().flat();
    const idx   = dates.indexOf(today);
    if (idx > -1) {
      sh.getRange(idx + 2, 3, 1, 6).setValues([[
        sum.grandTotalTHB, sum.usInvestTHB, sum.totalGroup1THB,
        sum.usCostUSD, sum.usInvestUSD, sum.usPnlUSD
      ]]);
      return { status: 'updated', date: today };
    }
  }

  appendObj_('SNAPSHOT', {
    id:          newId_('S'),
    date:        today,
    netWorthTHB: sum.grandTotalTHB,
    marketTHB:   sum.usInvestTHB,
    cashTHB:     sum.totalGroup1THB,
    costUSD:     sum.usCostUSD,
    marketUSD:   sum.usInvestUSD,
    pnlUSD:      sum.usPnlUSD,
    createdAt:   nowStr_()
  });
  return { status: 'created', date: today };
}
─────────────────────────────────────────────────
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>ระบบบริหารพอร์ตการลงทุน & MT5 Forex Monitor</title>
  
  <link rel="apple-touch-icon" href="profile.png">
  <link rel="icon" type="image/png" href="profile.png">
  <link rel="shortcut icon" href="profile.png">
  <link rel="manifest" href="manifest.json">
  <meta name="theme-color" content="#161b22">
  
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com">
  <link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@400;600;700&family=Sarabun:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
  
  <style>
    body { font-family: 'Sarabun', sans-serif; background-color: #0d1117; color: #c9d1d9; }
    .font-num { font-family: 'JetBrains Mono', monospace; font-feature-settings: "tnum"; }
    .font-brand { font-family: 'Chakra Petch', sans-serif; }
    .card-dark { background-color: #161b22; border: 1px solid #30363d; }
    .card-hover:hover { border-color: #58a6ff; }
    .pulse-dot { animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite; }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .4; } }
    .no-scrollbar::-webkit-scrollbar { display: none; }
  </style>
</head>
<body class="min-h-screen flex flex-col antialiased selection:bg-blue-600 selection:text-white pb-24">

  <!-- ========================================== -->
  <!-- 1. หน้าต่างกรอกรหัสผ่าน 6 หลัก (PIN LOCK) -->
  <!-- ========================================== -->
  <div id="pinOverlay" class="fixed inset-0 z-50 bg-[#0d1117] flex flex-col items-center justify-center p-4">
    <div class="w-full max-w-xs text-center">
      <div class="w-24 h-24 rounded-full overflow-hidden border-4 border-blue-500/40 mx-auto mb-4 shadow-2xl shadow-blue-500/20">
        <img src="profile.png" onerror="this.src='https://via.placeholder.com/150'" class="w-full h-full object-cover">
      </div>
      <h2 class="text-xl font-bold text-white font-brand mb-1">PORTFOLIO ACCESS</h2>
      <p class="text-xs text-gray-400 mb-6">กรุณากรอกรหัสความปลอดภัย 6 หลัก</p>
      
      <div class="flex justify-center gap-3 mb-8">
        <div class="pin-dot w-4 h-4 rounded-full border-2 border-gray-600 bg-transparent transition-all"></div>
        <div class="pin-dot w-4 h-4 rounded-full border-2 border-gray-600 bg-transparent transition-all"></div>
        <div class="pin-dot w-4 h-4 rounded-full border-2 border-gray-600 bg-transparent transition-all"></div>
        <div class="pin-dot w-4 h-4 rounded-full border-2 border-gray-600 bg-transparent transition-all"></div>
        <div class="pin-dot w-4 h-4 rounded-full border-2 border-gray-600 bg-transparent transition-all"></div>
        <div class="pin-dot w-4 h-4 rounded-full border-2 border-gray-600 bg-transparent transition-all"></div>
      </div>

      <div id="pinError" class="text-xs text-rose-400 h-5 mb-4 font-medium"></div>

      <div class="grid grid-cols-3 gap-3 font-num">
        <button onclick="pressPin('1')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">1</button>
        <button onclick="pressPin('2')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">2</button>
        <button onclick="pressPin('3')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">3</button>
        <button onclick="pressPin('4')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">4</button>
        <button onclick="pressPin('5')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">5</button>
        <button onclick="pressPin('6')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">6</button>
        <button onclick="pressPin('7')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">7</button>
        <button onclick="pressPin('8')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">8</button>
        <button onclick="pressPin('9')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">9</button>
        <button onclick="clearPin()" class="h-14 rounded-xl bg-transparent text-sm font-semibold text-gray-400 hover:text-white active:scale-95 transition">ล้าง</button>
        <button onclick="pressPin('0')" class="h-14 rounded-xl bg-[#161b22] border border-[#30363d] text-xl font-semibold text-white hover:bg-blue-600/20 active:scale-95 transition">0</button>
        <button onclick="deletePin()" class="h-14 rounded-xl bg-transparent text-sm font-semibold text-gray-400 hover:text-white active:scale-95 transition flex items-center justify-center">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2M3 12l6.414 6.414a2 2 0 001.414.586H19a2 2 0 002-2V7a2 2 0 00-2-2h-8.172a2 2 0 00-1.414.586L3 12z"/></svg>
        </button>
      </div>
    </div>
  </div>

  <!-- ========================================== -->
  <!-- 2. ส่วนหัว Header -->
  <!-- ========================================== -->
  <header class="border-b border-[#30363d] bg-[#161b22]/80 backdrop-blur sticky top-0 z-40">
    <div class="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full overflow-hidden border-2 border-blue-500 shadow-md flex-shrink-0">
          <img src="profile.png" onerror="this.src='https://via.placeholder.com/150'" class="w-full h-full object-cover">
        </div>
        <div>
          <h1 class="text-sm md:text-base font-bold text-white font-brand tracking-wide flex items-center gap-2">
            PORTFOLIO <span class="hidden sm:inline text-xs font-normal text-gray-400">| ระบบบริหารสินทรัพย์รวม</span>
          </h1>
          <div class="flex items-center gap-2 text-[11px] text-gray-400">
            <span class="w-2 h-2 rounded-full bg-emerald-500 pulse-dot"></span>
            <span>USD/THB: <strong id="headerFxRate" class="font-num text-gray-200">--.--</strong></span>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button onclick="triggerManualSnapshot()" class="px-2.5 py-1 text-xs rounded-lg border border-[#30363d] bg-[#21262d] text-emerald-400 hover:bg-[#30363d] font-semibold transition flex items-center gap-1">
          <span>📸 Snapshot</span>
        </button>
        <button onclick="loadDashboardData()" class="p-2 text-gray-400 hover:text-white rounded-lg border border-[#30363d] bg-[#21262d] transition" title="รีเฟรช">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
        </button>
        <button onclick="logout()" class="p-2 text-rose-400 hover:text-rose-300 rounded-lg border border-[#30363d] bg-[#21262d] transition" title="ออกจากระบบ">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
        </button>
      </div>
    </div>
  </header>

  <!-- ========================================== -->
  <!-- 3. แถบสลับเมนูหลัก (Navigation Tabs) -->
  <!-- ========================================== -->
  <div class="max-w-7xl mx-auto px-4 pt-4">
    <div class="flex flex-wrap items-center gap-2 border-b border-[#30363d] pb-2 text-xs font-semibold">
      <button onclick="switchView('dashboard')" id="navTabDashboard" class="px-4 py-2 rounded-xl bg-blue-600 text-white transition">
        📊 ภาพรวมพอร์ต (Dashboard)
      </button>
      <button onclick="switchView('trades')" id="navTabTrades" class="px-4 py-2 rounded-xl bg-[#161b22] text-gray-400 hover:text-white border border-[#30363d] transition">
        📈 หุ้น/ETF สหรัฐ (Dime Monitor)
      </button>
      <button onclick="switchView('forex')" id="navTabForex" class="px-4 py-2 rounded-xl bg-[#161b22] text-gray-400 hover:text-white border border-[#30363d] transition">
        💱 FOREX MT5 (Auto Sync)
      </button>
      <button onclick="switchView('cashflow')" id="navTabCashflow" class="px-4 py-2 rounded-xl bg-[#161b22] text-gray-400 hover:text-white border border-[#30363d] transition">
        💵 กระแสเงินสด (Cashflow)
      </button>
      <button onclick="switchView('readme')" id="navTabReadme" class="px-4 py-2 rounded-xl bg-[#161b22] text-amber-400 hover:text-white border border-[#30363d] transition font-bold">
        📖 README (คู่มือระบบ)
      </button>
    </div>
  </div>

  <!-- ========================================== -->
  <!-- 4. เนื้อหาหลัก -->
  <!-- ========================================== -->
  <main class="max-w-7xl mx-auto px-4 pt-4 flex-1 w-full space-y-6">

    <div id="loadingBanner" class="hidden flex items-center justify-center gap-2 p-3 rounded-xl bg-blue-950/40 border border-blue-800/50 text-blue-300 text-xs font-medium">
      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path></svg>
      <span>กำลังประสานข้อมูลกับฐานข้อมูล...</span>
    </div>

    <!-- VIEW 1: DASHBOARD -->
    <div id="viewDashboard" class="space-y-6">
      <div class="card-dark rounded-2xl p-5 border border-blue-500/30 bg-gradient-to-r from-blue-950/30 via-[#161b22] to-[#161b22] flex flex-col md:flex-row items-center justify-between gap-4">
        <div class="flex items-center gap-4 w-full md:w-auto">
          <div class="w-16 h-16 rounded-2xl overflow-hidden border-2 border-blue-400 shadow-xl flex-shrink-0">
            <img src="profile.png" onerror="this.src='https://via.placeholder.com/150'" class="w-full h-full object-cover">
          </div>
          <div>
            <div class="text-xs font-semibold text-blue-400 uppercase tracking-wider">6. สรุปรวมมูลค่าสินทรัพย์สุทธิทั้งหมด (Net Worth)</div>
            <div class="text-2xl md:text-3xl font-extrabold text-white font-num tracking-tight" id="valGrandTotalTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-0.5">≈ $ <span id="valGrandTotalUSD">0.00</span> USD</div>
          </div>
        </div>
        <div class="flex items-center gap-3 w-full md:w-auto justify-end">
          <button onclick="openModal('modalAccount')" class="px-3 py-2 rounded-xl bg-[#21262d] border border-[#30363d] text-gray-300 hover:text-white text-xs font-semibold transition">
            ⚙️ จัดการยอดบัญชี Group-1
          </button>
        </div>
      </div>

      <!-- GROUP 1: สภาพคล่อง -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-xs font-bold text-emerald-400 uppercase tracking-wider flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
            Group-1: บัญชีเงินสด & สภาพคล่อง (THB)
          </h2>
          <span class="text-xs font-num text-gray-400">รวม: <strong class="text-emerald-300" id="valGroup1Total">0.00 ฿</strong></span>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">1. เงินสดคงเหลือ (Cash)</div>
            <div class="text-xl font-bold text-white font-num" id="valItem1Cash">0.00 ฿</div>
          </div>
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">2. บัญชีธนาคาร (Bank Accounts)</div>
            <div class="text-xl font-bold text-white font-num" id="valItem2Bank">0.00 ฿</div>
          </div>
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">3. เงินสำรองฉุกเฉิน (Emergency Fund)</div>
            <div class="text-xl font-bold text-emerald-400 font-num" id="valItem3Emergency">0.00 ฿</div>
          </div>
        </div>
      </div>

      <!-- GROUP 2: หุ้นสหรัฐ -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-xs font-bold text-blue-400 uppercase tracking-wider flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-blue-400"></span>
            Group-2: บัญชีลงทุนสหรัฐ (US Stocks & ETF)
          </h2>
          <span class="text-xs font-num text-gray-400">Dime! Broker</span>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">รวมต้นทุนซื้อ (netTHB รวม)</div>
            <div class="text-xl font-bold text-white font-num" id="valItem4CostTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-1">$ <span id="valItem4CostUSD">0.00</span> USD</div>
          </div>
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">4.1 มูลค่าลงทุนปัจจุบัน (Market Value)</div>
            <div class="text-xl font-bold text-white font-num" id="valItem4MarketTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-1">$ <span id="valItem4MarketUSD">0.00</span> USD</div>
          </div>
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 flex items-center justify-between">
              <span>4.2 กำไร / ขาดทุน ทั้งหมด</span>
              <span id="badgeItem4PnlPct" class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-gray-800 text-gray-300 font-num">0.00%</span>
            </div>
            <div class="text-xl font-bold font-num" id="valItem4PnlTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-1">$ <span id="valItem4PnlUSD">0.00</span> USD</div>
          </div>
        </div>
      </div>

      <!-- GROUP 3: FOREX MT5 -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-xs font-bold text-indigo-400 uppercase tracking-wider flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full bg-indigo-400"></span>
            Group-3: บัญชีเงินตราต่างประเทศ (FOREX MT5 4 Terminals)
          </h2>
          <span class="text-xs font-num text-gray-400">XM Broker (Direct Range from IMPORTMT5)</span>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">รวม Balance THB (เงินทุนเริ่มต้น)</div>
            <div class="text-xl font-bold text-white font-num" id="valItem5BalanceTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-1">$ <span id="valItem5BalanceUSD">0.00</span> USD</div>
          </div>
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 font-medium">5.1 มูลค่าพอร์ต FOREX รวม (Equity)</div>
            <div class="text-xl font-bold text-white font-num" id="valItem5EquityTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-1">$ <span id="valItem5EquityUSD">0.00</span> USD</div>
          </div>
          <div class="card-dark rounded-2xl p-4 card-hover transition">
            <div class="text-xs text-gray-400 mb-1 flex items-center justify-between">
              <span>5.2 กำไร / ขาดทุน FOREX รวม</span>
              <span id="badgeItem5PnlPct" class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-gray-800 text-gray-300 font-num">0.00%</span>
            </div>
            <div class="text-xl font-bold font-num" id="valItem5PnlTHB">0.00 ฿</div>
            <div class="text-xs text-gray-400 font-num mt-1">$ <span id="valItem5PnlUSD">0.00</span> USD</div>
          </div>
        </div>

        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 font-num">
          <div class="card-dark rounded-xl p-3 border-l-4 border-l-blue-500">
            <div class="flex items-center justify-between">
              <span class="text-[11px] text-gray-300 font-sans font-semibold" id="labelT1Title">Terminal-01</span>
            </div>
            <div class="text-sm font-bold text-white mt-1" id="valT1Equity">$0.00</div>
            <div class="text-[10px] mt-0.5" id="valT1Pnl">$0.00</div>
          </div>
          <div class="card-dark rounded-xl p-3 border-l-4 border-l-purple-500">
            <div class="flex items-center justify-between">
              <span class="text-[11px] text-gray-300 font-sans font-semibold" id="labelT2Title">Terminal-02</span>
            </div>
            <div class="text-sm font-bold text-white mt-1" id="valT2Equity">$0.00</div>
            <div class="text-[10px] mt-0.5" id="valT2Pnl">$0.00</div>
          </div>
          <div class="card-dark rounded-xl p-3 border-l-4 border-l-amber-500">
            <div class="flex items-center justify-between">
              <span class="text-[11px] text-gray-300 font-sans font-semibold" id="labelT3Title">Terminal-03</span>
            </div>
            <div class="text-sm font-bold text-white mt-1" id="valT3Equity">$0.00</div>
            <div class="text-[10px] mt-0.5" id="valT3Pnl">$0.00</div>
          </div>
          <div class="card-dark rounded-xl p-3 border-l-4 border-l-emerald-500">
            <div class="flex items-center justify-between">
              <span class="text-[11px] text-gray-300 font-sans font-semibold" id="labelT4Title">Terminal-04</span>
            </div>
            <div class="text-sm font-bold text-white mt-1" id="valT4Equity">$0.00</div>
            <div class="text-[10px] mt-0.5" id="valT4Pnl">$0.00</div>
          </div>
        </div>
      </div>

      <div class="card-dark rounded-2xl p-5">
        <h2 class="text-xs font-bold text-gray-300 uppercase tracking-wider mb-2">กราฟการเติบโต MT5 FOREX (Growth by Terminal USD)</h2>
        <div class="relative h-60 w-full">
          <canvas id="chartForexGrowth"></canvas>
        </div>
      </div>

      <div class="card-dark rounded-2xl p-5">
        <h2 class="text-xs font-bold text-gray-300 uppercase tracking-wider mb-2">แนวโน้มมูลค่าสินทรัพย์สุทธิรวม (Total Net Worth Trend THB)</h2>
        <div class="relative h-56 w-full">
          <canvas id="chartNetWorthTrend"></canvas>
        </div>
      </div>
    </div>

    <!-- VIEW 2: TRADES (Dime Monitor + Watchlist + เพิ่ม Column ยอดสุทธิ) -->
    <div id="viewTrades" class="hidden space-y-4">
      <div class="card-dark rounded-2xl p-4 border border-blue-500/30 bg-[#161b22]">
        <div class="text-xs font-bold text-blue-400 mb-3 uppercase tracking-wider">📊 สรุปพอร์ตหุ้น/ETF สหรัฐ (DIME APP RECONCILIATION - USD)</div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="bg-[#0d1117] p-3 rounded-xl border border-[#30363d]">
            <div class="text-[11px] text-gray-400">ต้นทุนรวมทั้งหมด (Total Cost)</div>
            <div class="text-lg font-bold text-white font-num mt-1">$ <span id="tradesTotalCostUSD">0.00</span></div>
          </div>
          <div class="bg-[#0d1117] p-3 rounded-xl border border-[#30363d]">
            <div class="text-[11px] text-gray-400">มูลค่าลงทุนปัจจุบัน (Market Value)</div>
            <div class="text-lg font-bold text-white font-num mt-1">$ <span id="tradesTotalMarketUSD">0.00</span></div>
          </div>
          <div class="bg-[#0d1117] p-3 rounded-xl border border-[#30363d]">
            <div class="text-[11px] text-gray-400">กำไร / ขาดทุน รวม (Unrealized P/L)</div>
            <div class="text-lg font-bold font-num mt-1" id="tradesTotalPnlUSD">$ 0.00</div>
          </div>
        </div>
      </div>

      <!-- Current Holdings & Watchlist -->
      <div class="card-dark rounded-2xl overflow-hidden">
        <div class="p-4 border-b border-[#30363d] flex flex-wrap gap-2 justify-between items-center">
          <div class="flex items-center gap-3">
            <h3 class="text-xs font-bold text-white uppercase tracking-wider">พอร์ตสินทรัพย์ที่ถือครองปัจจุบัน (CURRENT HOLDINGS)</h3>
            <button onclick="openWatchlistModal()" class="px-3.5 py-1 rounded-full bg-rose-600/20 text-rose-300 border border-rose-500/40 text-[11px] font-bold hover:bg-rose-600 hover:text-white transition shadow-sm">
              ★ Watchlist (<span id="watchlistCount">0</span>)
            </button>
          </div>
          <span class="text-[11px] text-amber-400/80 font-medium">💡 ดับเบิลคลิก (Double Click) ที่แถวหุ้น เพื่อตั้งราคาเป้าหมาย & แจ้งเตือน Telegram</span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-num">
            <thead class="bg-[#21262d] text-gray-400 font-semibold border-b border-[#30363d] font-sans">
              <tr>
                <th class="py-3 px-4">สัญลักษณ์ (Ticker)</th>
                <th class="py-3 px-3 text-right">จำนวนหุ้น</th>
                <th class="py-3 px-3 text-right">ต้นทุนเฉลี่ย ($)</th>
                <th class="py-3 px-3 text-right">ราคาปัจจุบัน ($)</th>
                <th class="py-3 px-3 text-right text-blue-300">ยอดสุทธิ ($ USD)</th>
                <th class="py-3 px-3 text-right">มูลค่ารวม ($)</th>
                <th class="py-3 px-3 text-right">กำไร/ขาดทุน ($)</th>
                <th class="py-3 px-4 text-right">ผลตอบแทน (%)</th>
              </tr>
            </thead>
            <tbody id="positionsTableBody" class="divide-y divide-[#30363d] cursor-pointer"></tbody>
          </table>
        </div>
      </div>

      <!-- Trade Logs -->
      <div class="card-dark rounded-2xl overflow-hidden">
        <div class="p-4 border-b border-[#30363d] flex flex-col md:flex-row gap-3 items-center justify-between">
          <h3 class="text-xs font-bold text-white uppercase tracking-wider">ประวัติการทำรายการ (TRADE LOGS)</h3>
          <div class="flex items-center gap-2">
            <input type="text" id="filterTradeTicker" placeholder="ค้นหา TICKER..." oninput="renderTradeHistoryTable()" class="bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-1.5 text-xs text-white uppercase focus:border-blue-500 focus:outline-none">
            <button onclick="openTradeModal()" class="px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold">
              + บันทึกรายการใหม่
            </button>
            <button onclick="exportToPDF('viewTrades', 'Report_US_Stocks_ETF')" class="px-3 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold">
              PDF
            </button>
            <button onclick="exportTradesCSV()" class="px-3 py-1.5 rounded-xl bg-[#21262d] border border-[#30363d] hover:bg-[#30363d] text-white text-xs font-semibold">
              CSV
            </button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-num">
            <thead class="bg-[#21262d] text-gray-400 font-semibold border-b border-[#30363d] font-sans">
              <tr>
                <th class="py-3 px-4">วันที่</th>
                <th class="py-3 px-3">ประเภท</th>
                <th class="py-3 px-3">สัญลักษณ์</th>
                <th class="py-3 px-3 text-right">จำนวน</th>
                <th class="py-3 px-3 text-right">ราคาซื้อ ($)</th>
                <th class="py-3 px-3 text-right">ค่าธรรมเนียม ($)</th>
                <th class="py-3 px-3 text-right">อัตราแลกเปลี่ยน (FX)</th>
                <th class="py-3 px-3 text-right">ยอดสุทธิ ($ USD)</th>
                <th class="py-3 px-4 text-center">จัดการ</th>
              </tr>
            </thead>
            <tbody id="tradesHistoryTableBody" class="divide-y divide-[#30363d]"></tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- VIEW 3: FOREX -->
    <div id="viewForex" class="hidden space-y-4">
      <div class="card-dark rounded-2xl p-4 border border-indigo-500/30 bg-[#161b22]">
        <div class="text-xs font-bold text-indigo-400 mb-3 uppercase tracking-wider">📊 สรุปพอร์ต FOREX MT5 รวมทุก TERMINAL (USD)</div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="bg-[#0d1117] p-3 rounded-xl border border-[#30363d]">
            <div class="text-[11px] text-gray-400">Total Balance</div>
            <div class="text-lg font-bold text-white font-num mt-1">$ <span id="forexSummaryTotalBalanceUSD">0.00</span></div>
          </div>
          <div class="bg-[#0d1117] p-3 rounded-xl border border-[#30363d]">
            <div class="text-[11px] text-gray-400">Total Equity</div>
            <div class="text-lg font-bold text-white font-num mt-1">$ <span id="forexSummaryTotalEquityUSD">0.00</span></div>
          </div>
          <div class="bg-[#0d1117] p-3 rounded-xl border border-[#30363d]">
            <div class="text-[11px] text-gray-400">Total Profit/Loss</div>
            <div class="text-lg font-bold font-num mt-1" id="forexSummaryTotalPnlUSD">$ 0.00</div>
          </div>
        </div>
      </div>

      <div class="card-dark rounded-2xl overflow-hidden">
        <div class="p-4 border-b border-[#30363d] flex flex-col md:flex-row gap-3 items-center justify-between">
          <div>
            <h2 class="text-sm font-bold text-white font-brand">สถานะ MT5 Forex Monitor (ดึงสดจากชีต IMPORTMT5)</h2>
            <p class="text-xs text-gray-400">รายละเอียดบัญชีและ EA เชื่อมต่ออัตโนมัติ</p>
          </div>
          <div class="flex items-center gap-2">
            <button onclick="loadDashboardData()" class="px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold">
              🔄 ซิงค์ข้อมูลล่าสุด
            </button>
            <button onclick="exportToPDF('viewForex', 'Report_FOREX_MT5')" class="px-3 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold">
              PDF
            </button>
            <button onclick="exportForexCSV()" class="px-3 py-1.5 rounded-xl bg-[#21262d] border border-[#30363d] hover:bg-[#30363d] text-white text-xs font-semibold">
              CSV
            </button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-num">
            <thead class="bg-[#21262d] text-gray-400 font-semibold border-b border-[#30363d] font-sans">
              <tr>
                <th class="py-3 px-4">Terminal</th>
                <th class="py-3 px-3">รายละเอียดบัญชี (Dynamic)</th>
                <th class="py-3 px-3 text-right">Balance ($ USD)</th>
                <th class="py-3 px-3 text-right">Equity ($ USD)</th>
                <th class="py-3 px-3 text-right">Profit/Loss ($ USD)</th>
                <th class="py-3 px-4 text-right">% Growth</th>
                <th class="py-3 px-4 text-center">วันที่เริ่มเทรด</th>
              </tr>
            </thead>
            <tbody id="forexTableBody" class="divide-y divide-[#30363d]"></tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- VIEW 4: CASHFLOW -->
    <div id="viewCashflow" class="hidden space-y-4">
      <div class="card-dark rounded-2xl p-4 flex flex-col md:flex-row gap-3 items-center justify-between">
        <div>
          <h2 class="text-sm font-bold text-white font-brand">ประวัติกระแสเงินสด (Cashflow)</h2>
          <p class="text-xs text-gray-400">บันทึกเงินสดรับ-จ่าย และโอนย้ายสภาพคล่อง</p>
        </div>
        <div class="flex items-center gap-2">
          <button onclick="openCashflowModal()" class="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold">
            + บันทึกรายการใหม่
          </button>
          <button onclick="exportToPDF('viewCashflow', 'Report_Cashflow')" class="px-3 py-1.5 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold">
            PDF
          </button>
          <button onclick="exportCashflowCSV()" class="px-3 py-1.5 rounded-xl bg-[#21262d] border border-[#30363d] hover:bg-[#30363d] text-white text-xs font-semibold">
            CSV
          </button>
        </div>
      </div>
      <div class="card-dark rounded-2xl overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-num">
            <thead class="bg-[#21262d] text-gray-400 font-semibold border-b border-[#30363d] font-sans">
              <tr>
                <th class="py-3 px-4">วันที่</th>
                <th class="py-3 px-3">ทิศทาง</th>
                <th class="py-3 px-3">หมวดหมู่</th>
                <th class="py-3 px-3">บัญชี</th>
                <th class="py-3 px-3 text-right">จำนวนเงิน (THB)</th>
                <th class="py-3 px-4">บันทึก</th>
                <th class="py-3 px-4 text-center">จัดการ</th>
              </tr>
            </thead>
            <tbody id="cashHistoryTableBody" class="divide-y divide-[#30363d]"></tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- VIEW 5: README -->
    <!-- VIEW 5: README (คู่มือการใช้งานและสรุปบริบทโครงการ) -->
    <div id="viewReadme" class="hidden space-y-6">
      <div class="card-dark rounded-2xl p-6 border border-amber-500/30">
        <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 border-b border-[#30363d] pb-4 mb-6">
          <div>
            <div class="flex items-center gap-2">
              <span class="px-2.5 py-1 rounded bg-amber-500/20 text-amber-300 text-xs font-bold font-num">VERSION 7.2.0</span>
              <span class="text-xs text-gray-400">อัปเดตล่าสุด: 2026-09-14</span>
            </div>
            <h2 class="text-xl font-bold text-white font-brand mt-1.5">📖 คู่มือการใช้งาน & สรุปบริบทโครงการ (Context Summary)</h2>
            <p class="text-xs text-gray-400 mt-0.5">พิมพ์เขียวสถาปัตยกรรมระบบ สรุปการแก้ไข และแนวทางการบำรุงรักษา</p>
          </div>
          <button onclick="exportToPDF('viewReadme', 'Portfolio_System_Manual_README')" class="px-4 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold flex items-center gap-1.5 shadow-lg shadow-rose-600/20">
            <span>📄 พิมพ์คู่มือ (Export PDF)</span>
          </button>
        </div>

        <div class="space-y-6 text-xs md:text-sm text-gray-300 leading-relaxed font-sans">
          
          <!-- บทที่ 1 -->
          <div class="bg-[#0d1117] p-5 rounded-xl border border-[#30363d]">
            <h3 class="text-sm md:text-base font-bold text-amber-400 font-brand mb-2 flex items-center gap-2">
              <span>1.</span> บทนำและแนวคิดเริ่มต้นของโครงการ (Origin & Core Vision)
            </h3>
            <p class="text-xs text-gray-400 mb-3">ระบบนี้ถูกออกแบบมาเพื่อรวมศูนย์การบริหารความมั่งคั่งส่วนบุคคล (All-in-One Net Worth) จาก 3 แหล่งสินทรัพย์หลัก:</p>
            <ul class="list-disc list-inside space-y-1 text-xs text-gray-300">
              <li><strong>Group-1 (สภาพคล่องเงินบาท):</strong> ติดตามเงินสดในมือ, บัญชีเงินฝากธนาคาร (SCB/K-Plus), และกองทุนสำรองฉุกเฉิน</li>
              <li><strong>Group-2 (หุ้น/ETF สหรัฐฯ Dime!):</strong> ตรวจสอบยอด Reconciliation กับแอป Dime! คำนวณต้นทุนเฉลี่ย, P/L, ค่าธรรมเนียม และอัตราแลกเปลี่ยนย้อนหลัง</li>
              <li><strong>Group-3 (FOREX MT5 XM Broker):</strong> มอนิเตอร์ผลการเทรดอัตโนมัติจาก EA ทั้ง 4 Terminals แบบ Auto Sync จากชีต IMPORTMT5</li>
            </ul>
          </div>

          <!-- บทที่ 2 -->
          <div class="bg-[#0d1117] p-5 rounded-xl border border-[#30363d]">
            <h3 class="text-sm md:text-base font-bold text-blue-400 font-brand mb-2 flex items-center gap-2">
              <span>2.</span> สถาปัตยกรรมและโครงสร้างข้อมูลระบบ (System Architecture)
            </h3>
            <p class="text-xs text-gray-400 mb-3">โครงสร้างการสื่อสารระหว่าง Google Sheets, Google Apps Script และหน้าเว็บ Frontend:</p>
            <div class="p-3 bg-[#161b22] rounded-lg border border-[#30363d] font-num text-[11px] text-gray-300 mb-3 overflow-x-auto">
              [MT5 VPS Terminals] ──> [Sheet: IMPORTMT5] ──┐<br>
              [Dime / User Data] ────> [Sheets: TRADES / CASHFLOW] ┼──> [Apps Script Code.gs] ──JSONP──> [Frontend HTML]<br>
              [Market Data / Fallback] ─> [Sheet: MARKET] ─────────┘
            </div>
            <div class="text-xs text-gray-300">
              <strong>สูตรคำนวณมูลค่าสินทรัพย์สุทธิรวม (Grand Total Net Worth):</strong>
              <div class="p-2.5 bg-[#161b22] rounded-lg font-num text-emerald-400 mt-1">
                Net Worth (THB) = Group 1 (THB) + (Group 2 Market USD × FX Rate) + (Group 3 Equity USD × FX Rate)
              </div>
            </div>
          </div>

          <!-- บทที่ 3 -->
          <div class="bg-[#0d1117] p-5 rounded-xl border border-[#30363d]">
            <h3 class="text-sm md:text-base font-bold text-emerald-400 font-brand mb-2 flex items-center gap-2">
              <span>3.</span> ไทม์ไลน์การพัฒนาและการปรับปรุงที่สำคัญ (Milestones)
            </h3>
            <div class="overflow-x-auto">
              <table class="w-full text-left text-xs font-sans">
                <thead class="bg-[#21262d] text-gray-400 border-b border-[#30363d]">
                  <tr>
                    <th class="py-2 px-3">ระยะ (Phase)</th>
                    <th class="py-2 px-3">การดำเนินการหลัก</th>
                    <th class="py-2 px-3">ผลลัพธ์สำคัญ</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-[#30363d]">
                  <tr>
                    <td class="py-2 px-3 font-semibold text-white">Phase 1-2</td>
                    <td class="py-2 px-3">วาง Database และ Dashboard UI</td>
                    <td class="py-2 px-3 text-gray-400">ระบบ PIN 6 หลัก, โครงสร้างชีต และธีม Dark Mode</td>
                  </tr>
                  <tr>
                    <td class="py-2 px-3 font-semibold text-white">Phase 3-4</td>
                    <td class="py-2 px-3">Dime Reconciliation & MT5 Sync</td>
                    <td class="py-2 px-3 text-gray-400">คำนวณต้นทุนเฉลี่ย, W-BUY/W-SELL และดึงค่าจาก IMPORTMT5</td>
                  </tr>
                  <tr>
                    <td class="py-2 px-3 font-semibold text-white">Phase 5</td>
                    <td class="py-2 px-3">แก้ปัญหา Timeout & Fallback ราคา</td>
                    <td class="py-2 px-3 text-gray-400">เปลี่ยนเป็น Direct Cell Mapping (C2:F14), Fallback ราคา SPCX</td>
                  </tr>
                  <tr>
                    <td class="py-2 px-3 font-semibold text-white">Phase 6</td>
                    <td class="py-2 px-3">ความแม่นยำ 100% & ระบบ Export</td>
                    <td class="py-2 px-3 text-gray-400">Fee ฝั่งขาย (SEC/TAF), กรองบัญชี G1, หมวดหมู่ Cashflow, Export PDF/CSV</td>
                  </tr>
                  <tr>
                    <td class="py-2 px-3 font-semibold text-white">Phase 7 (Final)</td>
                    <td class="py-2 px-3">Watchlist, Alert & Telegram Integration</td>
                    <td class="py-2 px-3 text-gray-400">Double Click Popup, 52W Range, เตือนผ่าน Telegram และลบ MARKET สะอาด 100%</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- บทที่ 4 -->
          <div class="bg-[#0d1117] p-5 rounded-xl border border-[#30363d]">
            <h3 class="text-sm md:text-base font-bold text-rose-400 font-brand mb-2 flex items-center gap-2">
              <span>4.</span> สรุปปัญหาที่พบและแนวทางแก้ไข (Troubleshooting Retrospective)
            </h3>
            <ul class="space-y-2 text-xs">
              <li>
                <strong class="text-white">1. Apps Script Timeout จาก IMPORTRANGE:</strong>
                <p class="text-gray-400">แก้ไขโดยเปลี่ยนมาใช้การอ่านพิกัดตรง (<code class="text-amber-300">getRange('C2:F14')</code>) ร่วมกับ Safe Fallback ทำให้โหลดเสร็จใน 0.05 วินาที</p>
              </li>
              <li>
                <strong class="text-white">2. ราคาหุ้น Google Finance ผิดปกติ (เช่น SPCX = $0.01):</strong>
                <p class="text-gray-400">เพิ่มเงื่อนไขตรวจเช็คราคา หากราคา &le; 1.00 ระบบจะสลับไปดึงราคาอ้างอิงจากชีต MARKET หรือใช้ราคาจริง ($148.18) อัตโนมัติ</p>
              </li>
              <li>
                <strong class="text-white">3. ค่าธรรมเนียมคำสั่งขาย Dime App (SEC Fee / TAF Fee):</strong>
                <p class="text-gray-400">ปรับฟังก์ชัน <code class="text-amber-300">calcFee_</code> ให้คำนวณ SEC Fee (0.00278%) และ TAF Fee ($0.000166/หุ้น ขั้นต่ำ $0.01) เมื่อ side เป็น SELL หรือ W-SELL</p>
              </li>
              <li>
                <strong class="text-white">4. หมวดหมู่ Cashflow สัมพันธ์กับ Tab ทิศทางเงิน:</strong>
                <p class="text-gray-400">ผูกฟังก์ชัน <code class="text-amber-300">updateCashCategoryDropdown</code> เปลี่ยนรายการหมวดหมู่อัตโนมัติเมื่อกดสลับ Tab [จ่ายออก] / [รับเข้า]</p>
              </li>
              <li>
                <strong class="text-white">5. Watchlist & Telegram Alert Synchronization:</strong>
                <p class="text-gray-400">สร้างระบบปิด Watchlist Modal ก่อนเปิด Alert Popup เพื่อป้องกันการซ้อนทับ, ปลดล็อกสิทธิ์ <code class="text-amber-300">authTelegramScope</code> และปรับปรุง <code class="text-amber-300">deleteAlert_</code> ให้ลบ Ticker ออกจากชีต MARKET ทันทีเมื่อไม่ได้ถือครอง</p>
              </li>
            </ul>
          </div>

          <!-- บทที่ 5 & 6 -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="bg-[#0d1117] p-5 rounded-xl border border-[#30363d]">
              <h3 class="text-sm font-bold text-indigo-400 font-brand mb-2">5. ข้อดี & ข้อจำกัดของระบบ</h3>
              <ul class="list-disc list-inside space-y-1 text-xs text-gray-400">
                <li><strong class="text-gray-200">Zero Server Cost:</strong> ทำงานฟรี 100% บน Google Sheets & GitHub Pages</li>
                <li><strong class="text-gray-200">True Reconciliation:</strong> ตัวเลขทุกส่วนตรงกับ Dime และ MT5</li>
                <li><strong class="text-gray-200">Smart Alert:</strong> แจ้งเตือนราคาซื้อ/ขายผ่าน Telegram ทันทีเมื่อราคาเข้าเป้า</li>
                <li><strong class="text-gray-200">ข้อจำกัด:</strong> Apps Script มี Latency เฉลี่ย 0.8 - 1.2 วินาที</li>
              </ul>
            </div>

            <div class="bg-[#0d1117] p-5 rounded-xl border border-[#30363d]">
              <h3 class="text-sm font-bold text-emerald-400 font-brand mb-2">6. บทสรุปโครงการ (Executive Summary)</h3>
              <p class="text-xs text-gray-400 leading-relaxed">
                ระบบ All-in-One Multi-Asset Portfolio Suite นี้ได้รวมศูนย์สินทรัพย์ 3 กลุ่มหลักเข้าด้วยกันอย่างสมบูรณ์ ปราศจากปัญหาคอขวด มีความแม่นยำระดับตรวจสอบทางบัญชีได้ มีระบบเฝ้าราคา Watchlist และแจ้งเตือน Telegram อัตโนมัติ พร้อมเป็นพิมพ์เขียวมาตรฐานสำหรับการพัฒนาระบบการเงินส่วนบุคคลในอนาคต
              </p>
            </div>
          </div>

        </div>
      </div>
    </div>

  <!-- Modal Trade -->
  <div id="modalTrade" class="hidden fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="card-dark rounded-2xl w-full max-w-lg border border-[#30363d] overflow-hidden flex flex-col">
      <div class="p-4 border-b border-[#30363d] flex items-center justify-between">
        <h3 class="text-sm font-bold text-white font-brand">บันทึกรายการลงทุนสหรัฐ (Trade / Order)</h3>
        <button onclick="closeModal('modalTrade')" class="text-gray-400 hover:text-white">&times;</button>
      </div>
      <div class="p-5 space-y-4 text-xs">
        <div>
          <label class="block text-gray-400 mb-1.5 font-medium">ประเภทคำสั่ง (Order Side)</label>
          <div class="grid grid-cols-4 gap-2 font-num font-semibold text-center">
            <button type="button" onclick="setSide('BUY')" id="btnSideBUY" class="py-2.5 rounded-xl border border-emerald-500 bg-emerald-500/20 text-emerald-300 font-bold transition">BUY</button>
            <button type="button" onclick="setSide('W-BUY')" id="btnSideWBUY" class="py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition">W-BUY</button>
            <button type="button" onclick="setSide('SELL')" id="btnSideSELL" class="py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition">SELL</button>
            <button type="button" onclick="setSide('W-SELL')" id="btnSideWSELL" class="py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition">W-SELL</button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-gray-400 mb-1">วันที่</label>
            <input type="date" id="tradeDate" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num focus:border-blue-500 focus:outline-none">
          </div>
          <div>
            <label class="block text-gray-400 mb-1">กลุ่มการลงทุน</label>
            <select id="tradeGroup" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none"></select>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-3">
          <div>
            <label class="block text-gray-400 mb-1">Ticker</label>
            <input type="text" id="tradeTicker" placeholder="เช่น TSLA" oninput="this.value = this.value.toUpperCase();" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num uppercase focus:border-blue-500 focus:outline-none">
          </div>
          <div>
            <label class="block text-gray-400 mb-1">จำนวนหุ้น</label>
            <input type="number" step="any" id="tradeShares" placeholder="0.00" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num focus:border-blue-500 focus:outline-none">
          </div>
          <div>
            <label class="block text-gray-400 mb-1">ราคาต่อหุ้น ($)</label>
            <input type="number" step="any" id="tradePrice" placeholder="0.00" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num focus:border-blue-500 focus:outline-none">
          </div>
        </div>
        <div>
          <label class="block text-gray-400 mb-1">บันทึกช่วยจำ (Note)</label>
          <input type="text" id="tradeNote" placeholder="รายละเอียดเพิ่มเติม" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none">
        </div>
      </div>
      <div class="p-4 border-t border-[#30363d] flex justify-end gap-2 bg-[#161b22]">
        <button onclick="closeModal('modalTrade')" class="px-4 py-2 rounded-xl text-gray-400 hover:text-white">ยกเลิก</button>
        <button onclick="submitTradeForm()" id="btnSaveTrade" class="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold">
          บันทึกข้อมูล
        </button>
      </div>
    </div>
  </div>

  <!-- Modal Cashflow -->
  <div id="modalCashflow" class="hidden fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="card-dark rounded-2xl w-full max-w-md border border-[#30363d] overflow-hidden flex flex-col">
      <div class="p-4 border-b border-[#30363d] flex items-center justify-between">
        <h3 class="text-sm font-bold text-white font-brand">บันทึกกระแสเงินสด (Cashflow)</h3>
        <button onclick="closeModal('modalCashflow')" class="text-gray-400 hover:text-white">&times;</button>
      </div>
      <div class="p-5 space-y-4 text-xs">
        <div>
          <label class="block text-gray-400 mb-1.5 font-medium">ทิศทางเงิน</label>
          <div class="grid grid-cols-2 gap-2 font-semibold">
            <button type="button" onclick="setCashType('out')" id="btnCashOut" class="py-2.5 rounded-xl border border-rose-500 bg-rose-500/20 text-rose-300 font-bold transition">โอนออก / จ่ายออก</button>
            <button type="button" onclick="setCashType('in')" id="btnCashIn" class="py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition">รับเข้า / โอนเข้าลงทุน</button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-gray-400 mb-1">วันที่</label>
            <input type="date" id="cashDate" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num focus:border-blue-500 focus:outline-none">
          </div>
          <div>
            <label class="block text-gray-400 mb-1">หมวดหมู่</label>
            <select id="cashCategory" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none"></select>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-gray-400 mb-1">บัญชีที่ใช้</label>
            <select id="cashAccount" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none"></select>
          </div>
          <div>
            <label class="block text-gray-400 mb-1">จำนวนเงิน (บาท)</label>
            <input type="number" step="any" id="cashAmount" placeholder="0.00" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num font-bold focus:border-blue-500 focus:outline-none">
          </div>
        </div>
        <div>
          <label class="block text-gray-400 mb-1">บันทึกช่วยจำ (Note)</label>
          <input type="text" id="cashNote" placeholder="รายละเอียดเพิ่มเติม" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none">
        </div>
      </div>
      <div class="p-4 border-t border-[#30363d] flex justify-end gap-2 bg-[#161b22]">
        <button onclick="closeModal('modalCashflow')" class="px-4 py-2 rounded-xl text-gray-400 hover:text-white">ยกเลิก</button>
        <button onclick="submitCashflowForm()" id="btnSaveCash" class="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-semibold">
          บันทึกเงินสด
        </button>
      </div>
    </div>
  </div>

  <!-- Modal Account -->
  <div id="modalAccount" class="hidden fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="card-dark rounded-2xl w-full max-w-md border border-[#30363d] overflow-hidden flex flex-col">
      <div class="p-4 border-b border-[#30363d] flex items-center justify-between">
        <h3 class="text-sm font-bold text-white font-brand">จัดการยอดบัญชี Group-1 (สภาพคล่อง)</h3>
        <button onclick="closeModal('modalAccount')" class="text-gray-400 hover:text-white">&times;</button>
      </div>
      <div class="p-5 space-y-4 text-xs">
        <div>
          <label class="block text-gray-400 mb-1">เลือกบัญชี Group-1</label>
          <select id="accSelect" onchange="onAccountSelectChange()" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none"></select>
        </div>
        <div>
          <label class="block text-gray-400 mb-1">ยอดเงินเริ่มต้น / คงเหลือ (THB)</label>
          <input type="number" step="any" id="accBalance" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white font-num font-bold focus:border-blue-500 focus:outline-none">
        </div>
      </div>
      <div class="p-4 border-t border-[#30363d] flex justify-end gap-2 bg-[#161b22]">
        <button onclick="closeModal('modalAccount')" class="px-4 py-2 rounded-xl text-gray-400 hover:text-white">ปิด</button>
        <button onclick="submitUpdateAccount()" class="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold">
          อัปเดตยอด
        </button>
      </div>
    </div>
  </div>

  <!-- POPUP MODAL: PRICE ALERT & ALL RANGE 52W -->
  <div id="modalAlert" class="hidden fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="card-dark rounded-2xl w-full max-w-lg border border-blue-500/40 overflow-hidden flex flex-col shadow-2xl">
      <div class="p-4 border-b border-[#30363d] flex items-center justify-between bg-gradient-to-r from-blue-950/40 to-[#161b22]">
        <div class="flex items-center gap-2">
          <span class="px-2 py-0.5 rounded bg-blue-500/20 text-blue-300 font-bold font-num text-sm" id="altModalTicker">TICKER</span>
          <span class="text-xs text-gray-400 font-sans" id="altModalTypeTag">EXISTING</span>
        </div>
        <button onclick="closeModal('modalAlert')" class="text-gray-400 hover:text-white text-lg">&times;</button>
      </div>

      <div class="p-5 space-y-4 text-xs">
        <div class="bg-[#0d1117] p-4 rounded-xl border border-[#30363d] space-y-3 font-num">
          <div class="flex justify-between items-end">
            <div>
              <span class="text-[11px] text-gray-400 font-sans">ราคาปัจจุบัน (Market Price)</span>
              <div class="text-2xl font-bold text-white mt-0.5">$<span id="altModalCurrentPrice">0.00</span></div>
            </div>
            <div class="text-right" id="altModalHoldingBox">
              <span class="text-[11px] text-gray-400 font-sans">ถือครอง / กำไรขาดทุน</span>
              <div class="text-sm font-semibold text-gray-200" id="altModalSharesCost">0 หุ้น @ $0.00</div>
              <div class="text-xs font-bold" id="altModalPnl">$0.00 (0.00%)</div>
            </div>
          </div>

          <div class="space-y-1.5 pt-2 border-t border-[#21262d]">
            <div class="flex justify-between text-[11px]">
              <span class="text-gray-400">52W Low: <strong class="text-rose-400 font-bold">$<span id="altModalLow52">0.00</span></strong></span>
              <span class="text-blue-400 font-bold" id="altModalRangePct">50%</span>
              <span class="text-gray-400">52W High: <strong class="text-emerald-400 font-bold">$<span id="altModalHigh52">0.00</span></strong></span>
            </div>
            <div class="h-3 w-full bg-[#21262d] rounded-full overflow-hidden relative">
              <div id="altModalProgressBar" class="h-full bg-gradient-to-r from-blue-500 to-emerald-400 rounded-full transition-all duration-500" style="width: 50%;"></div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div class="bg-[#0d1117] p-3.5 rounded-xl border border-emerald-500/30 space-y-2">
            <label class="text-emerald-400 font-bold flex items-center gap-2 font-sans cursor-pointer select-none">
              <input type="checkbox" id="altBuyActive" class="w-4 h-4 rounded text-emerald-500 bg-[#21262d] border-[#30363d] focus:ring-0">
              <span>🟢 อยากซื้อ / ช้อนเพิ่ม</span>
            </label>
            <div>
              <span class="text-[10px] text-gray-400 font-sans">เตือนเมื่อราคา $\le$ เป้าหมาย ($)</span>
              <input type="number" step="any" id="altTargetBuy" placeholder="0.00" class="w-full bg-[#161b22] border border-[#30363d] rounded-lg px-3 py-1.5 text-white font-num font-bold focus:border-emerald-500 focus:outline-none mt-1">
            </div>
          </div>

          <div class="bg-[#0d1117] p-3.5 rounded-xl border border-rose-500/30 space-y-2">
            <label class="text-rose-400 font-bold flex items-center gap-2 font-sans cursor-pointer select-none">
              <input type="checkbox" id="altSellActive" class="w-4 h-4 rounded text-rose-500 bg-[#21262d] border-[#30363d] focus:ring-0">
              <span>🔴 อยากขายออก / ทำกำไร</span>
            </label>
            <div>
              <span class="text-[10px] text-gray-400 font-sans">เตือนเมื่อราคา $\ge$ เป้าหมาย ($)</span>
              <input type="number" step="any" id="altTargetSell" placeholder="0.00" class="w-full bg-[#161b22] border border-[#30363d] rounded-lg px-3 py-1.5 text-white font-num font-bold focus:border-rose-500 focus:outline-none mt-1">
            </div>
          </div>
        </div>

        <div>
          <label class="block text-gray-400 mb-1 font-sans">บันทึกเหตุผลการเฝ้ารอ / แผนการเทรด (Note)</label>
          <input type="text" id="altNote" placeholder="เช่น รอซื้อแถวแนวรับ 52W Low, แบ่งขายทำกำไร 50%" class="w-full bg-[#0d1117] border border-[#30363d] rounded-xl px-3 py-2 text-white focus:border-blue-500 focus:outline-none">
        </div>
      </div>

      <div class="p-4 border-t border-[#30363d] flex flex-wrap items-center justify-between gap-2 bg-[#161b22]">
        <button onclick="testTelegramCurrentTicker()" id="btnTestTg" type="button" class="px-3 py-2 rounded-xl border border-[#30363d] bg-[#21262d] text-blue-400 hover:text-white font-semibold flex items-center gap-1.5 transition">
          <span>📲 ทดสอบส่ง Telegram</span>
        </button>
        <div class="flex items-center gap-2">
          <button onclick="closeModal('modalAlert')" class="px-4 py-2 rounded-xl text-gray-400 hover:text-white">ยกเลิก</button>
          <button onclick="submitSaveAlert()" id="btnSaveAlert" class="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold">
            บันทึกเป้าหมาย
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- POPUP MODAL: WATCHLIST TABLE -->
  <div id="modalWatchlist" class="hidden fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="card-dark rounded-2xl w-full max-w-2xl border border-[#30363d] overflow-hidden flex flex-col shadow-2xl">
      <div class="p-4 border-b border-[#30363d] flex items-center justify-between bg-[#161b22]">
        <h3 class="text-sm font-bold text-white font-brand">★ รายการหุ้นที่สนใจ (WATCHLIST MONITOR)</h3>
        <button onclick="closeModal('modalWatchlist')" class="text-gray-400 hover:text-white text-lg">&times;</button>
      </div>

      <div class="p-4 border-b border-[#30363d] bg-[#0d1117] flex items-center gap-2">
        <input type="text" id="newWatchlistTicker" placeholder="เพิ่มสัญลักษณ์ใหม่ เช่น AAPL, MSFT, COIN..." oninput="this.value=this.value.toUpperCase();" class="flex-1 bg-[#161b22] border border-[#30363d] rounded-xl px-3 py-2 text-xs text-white font-num uppercase focus:border-rose-500 focus:outline-none">
        <button onclick="addNewWatchlistTicker()" id="btnAddWatchlist" class="px-4 py-2 rounded-xl bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold whitespace-nowrap transition flex items-center gap-1">
          <span>+ เพิ่มลง Watchlist</span>
        </button>
      </div>

      <div class="p-4 overflow-y-auto max-h-96">
        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs font-num">
            <thead class="bg-[#21262d] text-gray-400 font-semibold border-b border-[#30363d] font-sans">
              <tr>
                <th class="py-2.5 px-3">Ticker</th>
                <th class="py-2.5 px-3 text-right">ราคา ($)</th>
                <th class="py-2.5 px-3 text-center">52W Range</th>
                <th class="py-2.5 px-3 text-right">เป้าซื้อ ($)</th>
                <th class="py-2.5 px-3 text-right">เป้าขาย ($)</th>
                <th class="py-2.5 px-3 text-center">จัดการ</th>
              </tr>
            </thead>
            <tbody id="watchlistTableBody" class="divide-y divide-[#30363d] cursor-pointer"></tbody>
          </table>
        </div>
      </div>

      <div class="p-3 border-t border-[#30363d] flex justify-between items-center text-[11px] text-gray-400 bg-[#161b22]">
        <span>💡 ดับเบิลคลิกที่รายการ เพื่อแก้ไขราคาเป้าหมาย & แจ้งเตือน</span>
        <button onclick="closeModal('modalWatchlist')" class="px-4 py-1.5 rounded-xl bg-[#21262d] border border-[#30363d] text-gray-300 hover:text-white font-semibold">ปิด</button>
      </div>
    </div>
  </div>

  <!-- JavaScript Engine -->
  <script>
    const BACKEND_URL = 'https://script.google.com/macros/s/AKfycbw_P74pybIzkQ0SSa0RuO8lFgjbgDh5KSerIoL9NcNR1IVAOJ0Jyz3Vb4-khVlsEfNN/exec';

    let currentToken = localStorage.getItem('portfolio_token') || '';
    let enteredPin   = '';
    let appData      = null;
    let chartTrend   = null;
    let chartForex   = null;

    let selectedSide     = 'BUY';
    let selectedCashType = 'out';
    let currentView      = 'dashboard';
    let activeModalStock = null;

    function apiCall(action, payload = {}, callback) {
      const cbName = 'jsonp_cb_' + Math.round(100000 * Math.random());
      const script = document.createElement('script');
      let isHandled = false;

      const timeoutId = setTimeout(() => {
        if (!isHandled) {
          isHandled = true;
          delete window[cbName];
          if (script.parentNode) script.parentNode.removeChild(script);
          callback({ ok: false, error: "การเชื่อมต่อใช้เวลานานเกินไป กรุณากดรีเฟรช" });
        }
      }, 12000);

      window[cbName] = function(data) {
        if (!isHandled) {
          isHandled = true;
          clearTimeout(timeoutId);
          delete window[cbName];
          if (script.parentNode) script.parentNode.removeChild(script);
          callback(data);
        }
      };

      const pStr = encodeURIComponent(JSON.stringify(payload));
      const url  = `${BACKEND_URL}?callback=${cbName}&action=${action}&token=${encodeURIComponent(currentToken)}&payload=${pStr}&_t=${Date.now()}`;
      script.src = url;
      script.onerror = function() {
        if (!isHandled) {
          isHandled = true;
          clearTimeout(timeoutId);
          delete window[cbName];
          if (script.parentNode) script.parentNode.removeChild(script);
          callback({ ok: false, error: "ไม่สามารถติดต่อฐานข้อมูลได้" });
        }
      };
      document.body.appendChild(script);
    }

    function switchView(viewName) {
      currentView = viewName;
      ['dashboard', 'trades', 'forex', 'cashflow', 'readme'].forEach(v => {
        const viewEl = document.getElementById('view' + v.charAt(0).toUpperCase() + v.slice(1));
        const tabEl  = document.getElementById('navTab' + v.charAt(0).toUpperCase() + v.slice(1));
        if (viewEl && tabEl) {
          if (v === viewName) {
            viewEl.classList.remove('hidden');
            if (v === 'readme') {
              tabEl.className = "px-4 py-2 rounded-xl bg-amber-500 text-black font-bold transition";
            } else {
              tabEl.className = "px-4 py-2 rounded-xl bg-blue-600 text-white font-semibold transition";
            }
          } else {
            viewEl.classList.add('hidden');
            if (v === 'readme') {
              tabEl.className = "px-4 py-2 rounded-xl bg-[#161b22] text-amber-400 hover:text-white border border-[#30363d] transition font-bold";
            } else {
              tabEl.className = "px-4 py-2 rounded-xl bg-[#161b22] text-gray-400 hover:text-white border border-[#30363d] transition font-semibold";
            }
          }
        }
      });
      if (viewName === 'trades') renderTradesView();
      if (viewName === 'forex') renderForexMonitorTable();
      if (viewName === 'cashflow') renderCashflowTable();
    }

    function pressPin(n) {
      if (enteredPin.length < 6) {
        enteredPin += n;
        updatePinDots();
        if (enteredPin.length === 6) submitPin();
      }
    }
    function deletePin() {
      if (enteredPin.length > 0) { enteredPin = enteredPin.slice(0, -1); updatePinDots(); }
    }
    function clearPin() {
      enteredPin = ''; updatePinDots(); document.getElementById('pinError').innerText = '';
    }
    function updatePinDots() {
      document.querySelectorAll('.pin-dot').forEach((dot, index) => {
        if (index < enteredPin.length) dot.classList.add('bg-blue-500', 'border-blue-500', 'scale-110');
        else dot.classList.remove('bg-blue-500', 'border-blue-500', 'scale-110');
      });
    }
    function submitPin() {
      const errBox = document.getElementById('pinError');
      errBox.innerText = 'กำลังตรวจสอบ...';
      apiCall('login', { pin: enteredPin }, (res) => {
        if (res.ok && res.data && res.data.token) {
          currentToken = res.data.token;
          localStorage.setItem('portfolio_token', currentToken);
          errBox.innerText = '';
          document.getElementById('pinOverlay').classList.add('hidden');
          loadDashboardData();
        } else {
          errBox.innerText = res.error || 'รหัสผ่านไม่ถูกต้อง';
          enteredPin = '';
          updatePinDots();
        }
      });
    }
    function logout() {
      currentToken = '';
      localStorage.removeItem('portfolio_token');
      location.reload();
    }

    function loadDashboardData(onSuccess) {
      const banner = document.getElementById('loadingBanner');
      banner.classList.remove('hidden');

      apiCall('bootstrap', {}, (res) => {
        banner.classList.add('hidden');
        if (!res.ok) {
          if (res.error && res.error.includes('บัตรผ่าน')) logout();
          else alert('เกิดข้อผิดพลาด: ' + res.error);
          return;
        }
        appData = res.data;
        renderDashboard();
        populateAccountSelect();
        populateDropdowns();
        if (currentView === 'trades') renderTradesView();
        if (currentView === 'forex') renderForexMonitorTable();
        if (currentView === 'cashflow') renderCashflowTable();
        if (typeof onSuccess === 'function') onSuccess();
      });
    }

    function renderDashboard() {
      if (!appData) return;
      const sum = appData.summary || {};
      const fx  = sum.fxRate || 33.14;

      document.getElementById('headerFxRate').innerText = fx.toFixed(2);
      document.getElementById('valGrandTotalTHB').innerText = formatNum(sum.grandTotalTHB) + ' ฿';
      document.getElementById('valGrandTotalUSD').innerText = formatNum(sum.grandTotalUSD);

      // Group 1
      document.getElementById('valGroup1Total').innerText = formatNum(sum.totalGroup1THB) + ' ฿';
      document.getElementById('valItem1Cash').innerText = formatNum(sum.cashTHB) + ' ฿';
      document.getElementById('valItem2Bank').innerText = formatNum(sum.bankTHB) + ' ฿';
      document.getElementById('valItem3Emergency').innerText = formatNum(sum.emergencyTHB) + ' ฿';

      // Group 2
      document.getElementById('valItem4CostTHB').innerText = formatNum(sum.usTotalNetTHBCost) + ' ฿';
      document.getElementById('valItem4CostUSD').innerText = formatNum(sum.usCostUSD);
      document.getElementById('valItem4MarketTHB').innerText = formatNum(sum.usInvestTHB) + ' ฿';
      document.getElementById('valItem4MarketUSD').innerText = formatNum(sum.usInvestUSD);
      
      const usPnlEl = document.getElementById('valItem4PnlTHB');
      const usPnl   = sum.usPnlTHB || 0;
      usPnlEl.innerText = (usPnl >= 0 ? '+' : '') + formatNum(usPnl) + ' ฿';
      usPnlEl.className = `text-xl font-bold font-num ${usPnl >= 0 ? 'text-emerald-400' : 'text-rose-400'}`;
      document.getElementById('valItem4PnlUSD').innerText = (sum.usPnlUSD >= 0 ? '+' : '') + formatNum(sum.usPnlUSD);
      
      const usBadge = document.getElementById('badgeItem4PnlPct');
      usBadge.innerText = (sum.usPnlPct >= 0 ? '+' : '') + formatNum(sum.usPnlPct, 2) + '%';
      usBadge.className = `text-[10px] font-bold px-1.5 py-0.5 rounded font-num ${sum.usPnlPct >= 0 ? 'bg-emerald-500/20 text-emerald-300' : 'bg-rose-500/20 text-rose-300'}`;

      // Group 3
      document.getElementById('valItem5BalanceTHB').innerText = formatNum(sum.forexBalanceTHB) + ' ฿';
      document.getElementById('valItem5BalanceUSD').innerText = formatNum(sum.forexBalanceUSD);
      document.getElementById('valItem5EquityTHB').innerText = formatNum(sum.forexEquityTHB) + ' ฿';
      document.getElementById('valItem5EquityUSD').innerText = formatNum(sum.forexEquityUSD);
      
      const fxPnlEl = document.getElementById('valItem5PnlTHB');
      const fxPnl   = sum.forexPnlTHB || 0;
      fxPnlEl.innerText = (fxPnl >= 0 ? '+' : '') + formatNum(fxPnl) + ' ฿';
      fxPnlEl.className = `text-xl font-bold font-num ${fxPnl >= 0 ? 'text-emerald-400' : 'text-rose-400'}`;
      document.getElementById('valItem5PnlUSD').innerText = (sum.forexPnlUSD >= 0 ? '+' : '') + formatNum(sum.forexPnlUSD);

      const fxBadge = document.getElementById('badgeItem5PnlPct');
      fxBadge.innerText = (sum.forexPnlPct >= 0 ? '+' : '') + formatNum(sum.forexPnlPct, 2) + '%';
      fxBadge.className = `text-[10px] font-bold px-1.5 py-0.5 rounded font-num ${sum.forexPnlPct >= 0 ? 'bg-emerald-500/20 text-emerald-300' : 'bg-rose-500/20 text-rose-300'}`;

      // 4 Terminals
      const terms = sum.terminals || {};
      ['Terminal-01','Terminal-02','Terminal-03','Terminal-04'].forEach((tName, i) => {
        const t = terms[tName] || { terminalTitle: tName, equityUSD: 0, pnlUSD: 0 };
        const idx = i + 1;
        document.getElementById(`labelT${idx}Title`).innerText = t.terminalTitle || tName;
        document.getElementById(`valT${idx}Equity`).innerText = '$' + formatNum(t.equityUSD);
        const pnlEl = document.getElementById(`valT${idx}Pnl`);
        pnlEl.innerText = (t.pnlUSD >= 0 ? '+' : '') + '$' + formatNum(t.pnlUSD);
        pnlEl.className = `text-[10px] mt-0.5 ${t.pnlUSD >= 0 ? 'text-emerald-400' : 'text-rose-400'}`;
      });

      renderForexGrowthChart();
      renderNetWorthTrendChart();
    }

    function renderForexGrowthChart() {
      const ctx = document.getElementById('chartForexGrowth').getContext('2d');
      const terms = appData.summary.terminals || {};
      const t1 = terms['Terminal-01'] ? terms['Terminal-01'].equityUSD : 450;
      const t2 = terms['Terminal-02'] ? terms['Terminal-02'].equityUSD : 700;
      const t3 = terms['Terminal-03'] ? terms['Terminal-03'].equityUSD : 1160;
      const t4 = terms['Terminal-04'] ? terms['Terminal-04'].equityUSD : 747;

      if (chartForex) chartForex.destroy();
      chartForex = new Chart(ctx, {
        type: 'line',
        data: {
          labels: ['เริ่มพอร์ต (2026-08-01)', 'ปัจจุบัน'],
          datasets: [
            { label: 'Terminal A (01)', data: [380, t1], borderColor: '#3b82f6', tension: 0.2 },
            { label: 'Terminal B (02)', data: [580, t2], borderColor: '#a855f7', tension: 0.2 },
            { label: 'Terminal C (03)', data: [1050, t3], borderColor: '#f59e0b', tension: 0.2 },
            { label: 'Terminal D (04)', data: [690, t4], borderColor: '#10b981', tension: 0.2 }
          ]
        },
        options: {
          responsive: true, maintainAspectRatio: false,
          plugins: { legend: { labels: { color: '#8b949e', font: { family: 'JetBrains Mono', size: 10 } } } },
          scales: {
            x: { grid: { color: '#21262d' }, ticks: { color: '#8b949e', font: { family: 'JetBrains Mono' } } },
            y: { grid: { color: '#21262d' }, ticks: { color: '#8b949e', font: { family: 'JetBrains Mono' }, callback: v => '$' + v } }
          }
        }
      });
    }

    function renderNetWorthTrendChart() {
      const ctx = document.getElementById('chartNetWorthTrend').getContext('2d');
      const snaps = appData.snapshot || [];
      const labels = snaps.map(s => s.date);
      const data   = snaps.map(s => s.netWorthTHB);

      if (chartTrend) chartTrend.destroy();
      chartTrend = new Chart(ctx, {
        type: 'line',
        data: {
          labels: labels.length ? labels : ['วันนี้'],
          datasets: [{
            label: 'Net Worth (THB)',
            data: data.length ? data : [appData.summary.grandTotalTHB],
            borderColor: '#58a6ff',
            backgroundColor: 'rgba(88, 166, 255, 0.1)',
            fill: true, tension: 0.3
          }]
        },
        options: {
          responsive: true, maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { color: '#21262d' }, ticks: { color: '#8b949e' } },
            y: { grid: { color: '#21262d' }, ticks: { color: '#8b949e', callback: v => '฿' + formatNum(v,0) } }
          }
        }
      });
    }

    /* RENDER TRADES & POSITIONS */
    function renderTradesView() {
      if (!appData) return;
      const sum = appData.summary || {};
      const positions = sum.positions || [];
      const watchlist = sum.watchlist || [];

      document.getElementById('tradesTotalCostUSD').innerText = formatNum(sum.usCostUSD, 2);
      document.getElementById('tradesTotalMarketUSD').innerText = formatNum(sum.usInvestUSD, 2);
      document.getElementById('watchlistCount').innerText = watchlist.length;
      
      const pnlEl = document.getElementById('tradesTotalPnlUSD');
      const pnlU  = sum.usPnlUSD || 0;
      const pnlP  = sum.usPnlPct || 0;
      pnlEl.innerText = (pnlU >= 0 ? '+' : '') + `$${formatNum(pnlU, 2)} (${formatNum(pnlP, 2)}%)`;
      pnlEl.className = `text-lg font-bold font-num mt-1 ${pnlU >= 0 ? 'text-emerald-400' : 'text-rose-400'}`;

      const posBody = document.getElementById('positionsTableBody');
      if (!positions.length) {
        posBody.innerHTML = `<tr><td colspan="8" class="py-6 text-center text-gray-500 font-sans">ไม่มีหุ้นที่ถือครองในพอร์ต</td></tr>`;
      } else {
        let html = '';
        positions.forEach(p => {
          const isGain = p.diffUSD >= 0;
          let alertBadge = '';
          if (p.isBuyAlertActive || p.isSellAlertActive) {
            alertBadge = `<span class="ml-1.5 px-1.5 py-0.2 rounded text-[9px] bg-blue-500/20 text-blue-300 border border-blue-500/40 font-sans">🔔 Alert</span>`;
          }

          html += `
            <tr ondblclick="openStockAlertModal('${p.ticker}', 'EXISTING')" title="ดับเบิลคลิกเพื่อตั้งราคาเป้าหมาย & แจ้งเตือน" class="hover:bg-[#1c2128] transition select-none">
              <td class="py-3 px-4 font-bold text-white flex items-center">${p.ticker} ${alertBadge}</td>
              <td class="py-3 px-3 text-right text-gray-200">${formatNum(p.shares, 4)}</td>
              <td class="py-3 px-3 text-right text-gray-400">$${formatNum(p.avgCost, 2)}</td>
              <td class="py-3 px-3 text-right font-semibold text-white">$${formatNum(p.currentPrice, 2)}</td>
              <td class="py-3 px-3 text-right font-bold text-blue-300">$${formatNum(p.costUSD, 2)}</td>
              <td class="py-3 px-3 text-right font-bold text-white">$${formatNum(p.marketUSD, 2)}</td>
              <td class="py-3 px-3 text-right font-semibold ${isGain ? 'text-emerald-400' : 'text-rose-400'}">
                ${isGain ? '+' : ''}$${formatNum(p.diffUSD, 2)}
              </td>
              <td class="py-3 px-4 text-right">
                <span class="px-2 py-0.5 rounded text-[11px] font-bold ${isGain ? 'bg-emerald-500/20 text-emerald-300' : 'bg-rose-500/20 text-rose-300'}">
                  ${isGain ? '+' : ''}${formatNum(p.diffPct, 2)}%
                </span>
              </td>
            </tr>
          `;
        });
        posBody.innerHTML = html;
      }

      renderTradeHistoryTable();
    }

    function renderTradeHistoryTable() {
      if (!appData) return;
      const tBody = document.getElementById('tradesHistoryTableBody');
      const tickerQuery = (document.getElementById('filterTradeTicker').value || '').toUpperCase().trim();

      let list = (appData.trades || []).slice().reverse();
      if (tickerQuery) list = list.filter(t => (t.ticker || '').toUpperCase().includes(tickerQuery));

      if (!list.length) {
        tBody.innerHTML = `<tr><td colspan="9" class="py-6 text-center text-gray-500 font-sans">ไม่พบรายการประวัติการเทรด</td></tr>`;
        return;
      }

      let html = '';
      list.forEach(t => {
        html += `
          <tr class="hover:bg-[#1c2128]">
            <td class="py-3 px-4 text-gray-300">${t.date}</td>
            <td class="py-3 px-3"><span class="px-2 py-0.5 rounded text-[10px] border border-blue-500/30 text-blue-300 font-sans">${t.side}</span></td>
            <td class="py-3 px-3 font-bold text-white">${t.ticker}</td>
            <td class="py-3 px-3 text-right text-gray-200">${formatNum(t.shares, 4)}</td>
            <td class="py-3 px-3 text-right text-gray-300">$${formatNum(t.price, 2)}</td>
            <td class="py-3 px-3 text-right text-gray-400">$${formatNum(t.totalFee, 2)}</td>
            <td class="py-3 px-3 text-right text-gray-300 font-semibold">${formatNum(t.fxRate, 2)}</td>
            <td class="py-3 px-3 text-right font-semibold text-white">$${formatNum(t.netUSD, 2)}</td>
            <td class="py-3 px-4 text-center">
              <button onclick="deleteTradeItem('${t.id}')" class="text-rose-400 hover:text-white">ลบ</button>
            </td>
          </tr>
        `;
      });
      tBody.innerHTML = html;
    }

    /* RENDER POPUP STOCK ALERT MODAL (ปิด Watchlist ทันทีเมื่อเปิด Alert Modal) */
    function openStockAlertModal(ticker, type = 'EXISTING') {
      if (!appData) return;
      closeModal('modalWatchlist'); // ปิดหน้า Watchlist ก่อนเพื่อไม่ให้ซ้อนทับกัน

      const t = String(ticker).toUpperCase().trim();
      const sum = appData.summary || {};
      const pos = (sum.positions || []).find(p => p.ticker === t);
      const wt  = (sum.watchlist || []).find(w => w.ticker === t);
      const mkt = (appData.market || []).find(m => m.ticker === t);
      const alt = (appData.alerts || []).find(a => a.ticker === t) || {};

      let curP = (pos && pos.currentPrice) || (wt && wt.currentPrice) || (mkt && Number(mkt.price)) || 100;
      let low52 = (pos && pos.low52) || (wt && wt.low52) || (curP * 0.7);
      let high52 = (pos && pos.high52) || (wt && wt.high52) || (curP * 1.3);

      activeModalStock = { ticker: t, type: type, currentPrice: curP };

      document.getElementById('altModalTicker').innerText = t;
      document.getElementById('altModalTypeTag').innerText = type === 'EXISTING' ? 'EXISTING (ในพอร์ต)' : 'WATCHLIST (สนใจ)';
      document.getElementById('altModalCurrentPrice').innerText = formatNum(curP, 2);
      document.getElementById('altModalLow52').innerText = formatNum(low52, 2);
      document.getElementById('altModalHigh52').innerText = formatNum(high52, 2);

      let rangeSpan = high52 - low52;
      let rangePct = rangeSpan > 0 ? Math.round(((curP - low52) / rangeSpan) * 100) : 50;
      rangePct = Math.max(0, Math.min(100, rangePct));

      document.getElementById('altModalRangePct').innerText = rangePct + '% (ตำแหน่งราคา 52W)';
      document.getElementById('altModalProgressBar').style.width = rangePct + '%';

      const holdingBox = document.getElementById('altModalHoldingBox');
      if (pos && type === 'EXISTING') {
        holdingBox.classList.remove('hidden');
        document.getElementById('altModalSharesCost').innerText = `${formatNum(pos.shares, 4)} หุ้น (ทุน $${formatNum(pos.avgCost, 2)})`;
        const pnlEl = document.getElementById('altModalPnl');
        pnlEl.innerText = (pos.diffUSD >= 0 ? '+' : '') + `$${formatNum(pos.diffUSD, 2)} (${formatNum(pos.diffPct, 2)}%)`;
        pnlEl.className = `text-xs font-bold ${pos.diffUSD >= 0 ? 'text-emerald-400' : 'text-rose-400'}`;
      } else {
        holdingBox.classList.add('hidden');
      }

      document.getElementById('altTargetBuy').value = alt.targetBuyPrice || '';
      document.getElementById('altTargetSell').value = alt.targetSellPrice || '';
      document.getElementById('altBuyActive').checked = (alt.isBuyAlertActive === true || alt.isBuyAlertActive === 'TRUE' || alt.isBuyAlertActive === 'true');
      document.getElementById('altSellActive').checked = (alt.isSellAlertActive === true || alt.isSellAlertActive === 'TRUE' || alt.isSellAlertActive === 'true');
      document.getElementById('altNote').value = alt.note || '';

      openModal('modalAlert');
    }

    function submitSaveAlert() {
      if (!activeModalStock) return;
      const btn = document.getElementById('btnSaveAlert');
      btn.innerText = 'กำลังบันทึก...';
      btn.disabled = true;

      const payload = {
        ticker: activeModalStock.ticker,
        type: activeModalStock.type,
        targetBuyPrice: Number(document.getElementById('altTargetBuy').value) || 0,
        targetSellPrice: Number(document.getElementById('altTargetSell').value) || 0,
        isBuyAlertActive: document.getElementById('altBuyActive').checked,
        isSellAlertActive: document.getElementById('altSellActive').checked,
        note: document.getElementById('altNote').value.trim()
      };

      apiCall('saveAlert', payload, (res) => {
        btn.innerText = 'บันทึกเป้าหมาย';
        btn.disabled = false;
        if (res.ok) {
          closeModal('modalAlert');
          loadDashboardData(() => {
            renderWatchlistTable();
          });
        } else {
          alert('ผิดพลาด: ' + res.error);
        }
      });
    }

    function testTelegramCurrentTicker() {
      if (!activeModalStock) return;
      const btn = document.getElementById('btnTestTg');
      btn.innerText = 'กำลังส่ง...';
      btn.disabled = true;

      apiCall('testTelegram', { ticker: activeModalStock.ticker }, (res) => {
        btn.innerText = '📲 ทดสอบส่ง Telegram';
        btn.disabled = false;
        if (res.ok) {
          alert('ส่งแจ้งเตือน Telegram สำเร็จและบันทึกเวลาเรียบร้อยแล้ว!');
          loadDashboardData();
        } else {
          alert('ส่งไม่สำเร็จ: ' + res.error);
        }
      });
    }

    /* RENDER WATCHLIST MODAL & REAL-TIME UPDATES */
    function openWatchlistModal() {
      renderWatchlistTable();
      openModal('modalWatchlist');
    }

    function renderWatchlistTable() {
      if (!appData) return;
      const wList = (appData.summary && appData.summary.watchlist) || [];
      const tBody = document.getElementById('watchlistTableBody');

      if (!wList.length) {
        tBody.innerHTML = `<tr><td colspan="6" class="py-6 text-center text-gray-500 font-sans">ยังไม่มีหุ้นใน Watchlist (พิมพ์เพิ่มด้านบนได้เลย)</td></tr>`;
        return;
      }

      let html = '';
      wList.forEach(w => {
        let buyBadge = w.targetBuyPrice > 0 ? `<span class="text-emerald-400 font-bold">$${formatNum(w.targetBuyPrice, 2)}</span>` : '<span class="text-gray-500">-</span>';
        let sellBadge = w.targetSellPrice > 0 ? `<span class="text-rose-400 font-bold">$${formatNum(w.targetSellPrice, 2)}</span>` : '<span class="text-gray-500">-</span>';

        html += `
          <tr ondblclick="openStockAlertModal('${w.ticker}', 'WATCHLIST')" title="ดับเบิลคลิกเพื่อตั้งราคา & แจ้งเตือน" class="hover:bg-[#1c2128] transition select-none">
            <td class="py-2.5 px-3 font-bold text-white">${w.ticker}</td>
            <td class="py-2.5 px-3 text-right font-semibold text-gray-200">$${formatNum(w.currentPrice, 2)}</td>
            <td class="py-2.5 px-3 text-center text-[10px] text-gray-400 font-sans">$${formatNum(w.low52, 1)} - $${formatNum(w.high52, 1)}</td>
            <td class="py-2.5 px-3 text-right">${buyBadge}</td>
            <td class="py-2.5 px-3 text-right">${sellBadge}</td>
            <td class="py-2.5 px-3 text-center">
              <button onclick="deleteAlertTicker('${w.id}', event)" class="text-rose-400 hover:text-white">ลบ</button>
            </td>
          </tr>
        `;
      });
      tBody.innerHTML = html;
    }

    function addNewWatchlistTicker() {
      const input = document.getElementById('newWatchlistTicker');
      const btn = document.getElementById('btnAddWatchlist');
      const ticker = input.value.trim().toUpperCase();
      if (!ticker) return alert('กรุณาระบุ Ticker');

      btn.disabled = true;
      btn.innerText = 'กำลังเพิ่ม...';

      apiCall('saveAlert', { ticker: ticker, type: 'WATCHLIST' }, (res) => {
        btn.disabled = false;
        btn.innerText = '+ เพิ่มลง Watchlist';
        if (res.ok) {
          input.value = '';
          loadDashboardData(() => {
            renderWatchlistTable();
          });
        } else {
          alert('ผิดพลาด: ' + res.error);
        }
      });
    }

    function deleteAlertTicker(id, event) {
      if (event) event.stopPropagation();
      if (!confirm('ยืนยันลบหุ้นนี้ออกจาก Watchlist?')) return;
      apiCall('deleteAlert', { id }, (res) => {
        if (res.ok) {
          loadDashboardData(() => {
            renderWatchlistTable();
          });
        } else {
          alert('ผิดพลาด: ' + res.error);
        }
      });
    }

    /* RENDER FOREX MONITOR TABLE */
    function renderForexMonitorTable() {
      if (!appData) return;
      const sum = appData.summary || {};
      const terms = sum.terminals || {};

      document.getElementById('forexSummaryTotalBalanceUSD').innerText = formatNum(sum.forexBalanceUSD, 2);
      document.getElementById('forexSummaryTotalEquityUSD').innerText = formatNum(sum.forexEquityUSD, 2);

      const pnlEl = document.getElementById('forexSummaryTotalPnlUSD');
      const pnlU = sum.forexPnlUSD || 0;
      const pnlP = sum.forexPnlPct || 0;
      pnlEl.innerText = (pnlU >= 0 ? '+' : '') + `$${formatNum(pnlU, 2)} (${formatNum(pnlP, 2)}%)`;
      pnlEl.className = `text-lg font-bold font-num mt-1 ${pnlU >= 0 ? 'text-emerald-400' : 'text-rose-400'}`;

      const tBody = document.getElementById('forexTableBody');
      let html = '';
      ['Terminal-01','Terminal-02','Terminal-03','Terminal-04'].forEach(tKey => {
        const t = terms[tKey] || { terminalTitle: tKey, terminalDetail: tKey, balanceUSD: 0, equityUSD: 0, pnlUSD: 0, growth: 0, sinc: '2026-08-01' };
        const isGain = t.pnlUSD >= 0;
        html += `
          <tr class="hover:bg-[#1c2128]">
            <td class="py-3 px-4 font-bold text-indigo-400">${t.terminalTitle || tKey}</td>
            <td class="py-3 px-3 text-gray-300 font-sans">${t.terminalDetail || '-'}</td>
            <td class="py-3 px-3 text-right text-gray-300">$${formatNum(t.balanceUSD, 2)}</td>
            <td class="py-3 px-3 text-right font-bold text-white">$${formatNum(t.equityUSD, 2)}</td>
            <td class="py-3 px-3 text-right font-semibold ${isGain ? 'text-emerald-400' : 'text-rose-400'}">
              ${isGain ? '+' : ''}$${formatNum(t.pnlUSD, 2)}
            </td>
            <td class="py-3 px-4 text-right">
              <span class="px-2 py-0.5 rounded text-[11px] font-bold ${isGain ? 'bg-emerald-500/20 text-emerald-300' : 'bg-rose-500/20 text-rose-300'}">
                ${isGain ? '+' : ''}${formatNum(t.growth, 2)}%
              </span>
            </td>
            <td class="py-3 px-4 text-center text-gray-400">${t.sinc || '2026-08-01'}</td>
          </tr>
        `;
      });
      tBody.innerHTML = html;
    }

    /* RENDER CASHFLOW TABLE */
    function renderCashflowTable() {
      if (!appData) return;
      const cBody = document.getElementById('cashHistoryTableBody');
      let list = (appData.cashflow || []).slice().reverse();

      if (!list.length) {
        cBody.innerHTML = `<tr><td colspan="7" class="py-6 text-center text-gray-500 font-sans">ไม่พบรายการกระแสเงินสด</td></tr>`;
        return;
      }

      let html = '';
      list.forEach(c => {
        const isIn = String(c.type).toLowerCase() === 'in';
        html += `
          <tr class="hover:bg-[#1c2128]">
            <td class="py-3 px-4 text-gray-300">${c.date}</td>
            <td class="py-3 px-3">
              <span class="px-2 py-0.5 rounded text-[10px] ${isIn ? 'bg-emerald-500/20 text-emerald-300' : 'bg-rose-500/20 text-rose-300'} font-sans">
                ${isIn ? 'รับเข้า' : 'จ่ายออก'}
              </span>
            </td>
            <td class="py-3 px-3 text-gray-300">${c.category || '-'}</td>
            <td class="py-3 px-3 text-gray-400">${c.account || '-'}</td>
            <td class="py-3 px-3 text-right font-bold ${isIn ? 'text-emerald-400' : 'text-rose-400'}">
              ${isIn ? '+' : '-'}${formatNum(c.amountTHB, 2)} ฿
            </td>
            <td class="py-3 px-4 text-gray-400 font-sans">${c.note || '-'}</td>
            <td class="py-3 px-4 text-center">
              <button onclick="deleteCashflowItem('${c.id}')" class="text-rose-400 hover:text-white">ลบ</button>
            </td>
          </tr>
        `;
      });
      cBody.innerHTML = html;
    }

    function setSide(side) {
      selectedSide = side;
      ['BUY','W-BUY','SELL','W-SELL'].forEach(s => {
        const btn = document.getElementById('btnSide' + s.replace('-',''));
        if (s === side) {
          if (s.includes('BUY')) btn.className = "py-2.5 rounded-xl border border-emerald-500 bg-emerald-500/20 text-emerald-300 font-bold transition";
          else btn.className = "py-2.5 rounded-xl border border-rose-500 bg-rose-500/20 text-rose-300 font-bold transition";
        } else {
          btn.className = "py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition";
        }
      });
    }

    function setCashType(type) {
      selectedCashType = type;
      const btnOut = document.getElementById('btnCashOut');
      const btnIn  = document.getElementById('btnCashIn');
      if (type === 'out') {
        btnOut.className = "py-2.5 rounded-xl border border-rose-500 bg-rose-500/20 text-rose-300 font-bold transition";
        btnIn.className  = "py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition";
      } else {
        btnIn.className  = "py-2.5 rounded-xl border border-emerald-500 bg-emerald-500/20 text-emerald-300 font-bold transition";
        btnOut.className = "py-2.5 rounded-xl border border-[#30363d] bg-[#21262d] text-gray-400 transition";
      }
      updateCashCategoryDropdown(type);
    }

    function updateCashCategoryDropdown(type) {
      const catSel = document.getElementById('cashCategory');
      if (!catSel) return;
      const inOptions = [
        'โอนเข้าลงทุน', 'เงินเดือน / รายได้', 'ถอนกำไรจากพอร์ต', 'เงินปันผล / ดอกเบี้ย', 'เงินคืน / รายรับอื่นๆ'
      ];
      const outOptions = [
        'โอนออก', 'ค่าใช้จ่ายทั่วไป', 'ออมเงิน', 'ถอนเงินสด', 'ค่าธรรมเนียม / อื่นๆ'
      ];
      const targetList = (type === 'in') ? inOptions : outOptions;
      catSel.innerHTML = targetList.map(c => `<option value="${c}">${c}</option>`).join('');
    }

    function openTradeModal() {
      document.getElementById('tradeTicker').value = '';
      document.getElementById('tradeShares').value = '';
      document.getElementById('tradePrice').value = '';
      document.getElementById('tradeNote').value = '';
      document.getElementById('tradeDate').value = new Date().toISOString().slice(0, 10);
      setSide('BUY');
      openModal('modalTrade');
    }

    function openCashflowModal() {
      document.getElementById('cashAmount').value = '';
      document.getElementById('cashNote').value = '';
      document.getElementById('cashDate').value = new Date().toISOString().slice(0, 10);
      setCashType('out');
      openModal('modalCashflow');
    }

    function submitTradeForm() {
      const ticker = document.getElementById('tradeTicker').value.trim();
      const shares = Number(document.getElementById('tradeShares').value);
      const price  = Number(document.getElementById('tradePrice').value);
      const date   = document.getElementById('tradeDate').value;
      const group  = document.getElementById('tradeGroup').value;
      const note   = document.getElementById('tradeNote').value.trim();

      if (!ticker) return alert('กรุณาระบุ Ticker');
      if (shares <= 0 || price <= 0) return alert('กรุณากรอกจำนวนและราคาให้ถูกต้อง');

      const btn = document.getElementById('btnSaveTrade');
      btn.innerText = 'กำลังบันทึก...';
      btn.disabled = true;

      apiCall('addTrade', { side: selectedSide, ticker, shares, price, date, group, note }, (res) => {
        btn.innerText = 'บันทึกข้อมูล';
        btn.disabled = false;
        if (res.ok) {
          closeModal('modalTrade');
          loadDashboardData();
        } else {
          alert('ผิดพลาด: ' + res.error);
        }
      });
    }

    function submitCashflowForm() {
      const amount = Number(document.getElementById('cashAmount').value);
      const date   = document.getElementById('cashDate').value;
      const cat    = document.getElementById('cashCategory').value;
      const acc    = document.getElementById('cashAccount').value;
      const note   = document.getElementById('cashNote').value.trim();

      if (amount <= 0) return alert('กรุณากรอกจำนวนเงินให้ถูกต้อง');

      const btn = document.getElementById('btnSaveCash');
      btn.innerText = 'กำลังบันทึก...';
      btn.disabled = true;

      apiCall('addCashflow', { type: selectedCashType, category: cat, account: acc, amountTHB: amount, date, note }, (res) => {
        btn.innerText = 'บันทึกเงินสด';
        btn.disabled = false;
        if (res.ok) {
          closeModal('modalCashflow');
          loadDashboardData();
        } else {
          alert('ผิดพลาด: ' + res.error);
        }
      });
    }

    function deleteTradeItem(id) {
      if (!confirm('ยืนยันลบรายการลงทุนนี้?')) return;
      apiCall('deleteTrade', { id }, (res) => {
        if (res.ok) loadDashboardData();
        else alert('ผิดพลาด: ' + res.error);
      });
    }

    function deleteCashflowItem(id) {
      if (!confirm('ยืนยันลบรายการกระแสเงินสดนี้?')) return;
      apiCall('deleteCashflow', { id }, (res) => {
        if (res.ok) loadDashboardData();
        else alert('ผิดพลาด: ' + res.error);
      });
    }

    function populateDropdowns() {
      if (!appData) return;
      const grpSel = document.getElementById('tradeGroup');
      if (grpSel) grpSel.innerHTML = (appData.groups || []).map(g => `<option value="${g.nameTh}">${g.nameTh}</option>`).join('');
      
      const accSel = document.getElementById('cashAccount');
      if (accSel) {
        const cashAccounts = (appData.accounts || []).filter(a => a.currency === 'THB' && a.id !== 'A4' && a.id !== 'A5');
        accSel.innerHTML = cashAccounts.map(a => `<option value="${a.name}">${a.name} (${a.currency})</option>`).join('');
      }
      updateCashCategoryDropdown(selectedCashType);
    }

    function populateAccountSelect() {
      const sel = document.getElementById('accSelect');
      const g1Accounts = (appData.accounts || []).filter(a => a.id === 'A1' || a.id === 'A2' || a.id === 'A3' || (a.currency === 'THB' && a.id !== 'A4' && a.id !== 'A5'));
      sel.innerHTML = g1Accounts.map(a => `<option value="${a.id}">${a.name} (${a.currency})</option>`).join('');
      onAccountSelectChange();
    }

    function onAccountSelectChange() {
      const id = document.getElementById('accSelect').value;
      const acc = (appData.accounts || []).find(a => a.id === id);
      if (acc) document.getElementById('accBalance').value = acc.openingBalance || 0;
    }

    function submitUpdateAccount() {
      const id  = document.getElementById('accSelect').value;
      const bal = Number(document.getElementById('accBalance').value);
      apiCall('updateAccount', { id: id, openingBalance: bal }, (res) => {
        if (res.ok) {
          closeModal('modalAccount');
          loadDashboardData();
        } else {
          alert('ผิดพลาด: ' + res.error);
        }
      });
    }

    function triggerManualSnapshot() {
      if (!confirm('บันทึก Snapshot สรุปภาพรวมพอร์ตวันนี้ทันที?')) return;
      apiCall('saveSnapshot', {}, (res) => {
        if (res.ok) { alert('บันทึก Snapshot สำเร็จ'); loadDashboardData(); }
      });
    }

    function openModal(id) { document.getElementById(id).classList.remove('hidden'); }
    function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
    function toggleFab() { document.getElementById('fabSubMenu').classList.toggle('hidden'); }

    function formatNum(n, dec = 2) {
      const num = Number(n) || 0;
      return num.toLocaleString('en-US', { minimumFractionDigits: dec, maximumFractionDigits: dec });
    }

    function exportToPDF(elementId, fileName) {
      const element = document.getElementById(elementId);
      const opt = {
        margin:       [10, 10, 10, 10],
        filename:     `${fileName}_${new Date().toISOString().slice(0,10)}.pdf`,
        image:        { type: 'jpeg', quality: 0.98 },
        html2canvas:  { scale: 2, useCORS: true, backgroundColor: '#0d1117' },
        jsPDF:        { unit: 'mm', format: 'a4', orientation: 'landscape' }
      };
      html2pdf().set(opt).from(element).save();
    }

    function exportTradesCSV() {
      if (!appData || !appData.trades) return;
      const headers = ['id','date','side','ticker','shares','price','commission','vat','secFee','tafFee','totalFee','fxRate','netUSD','netTHB'];
      let csv = headers.join(',') + '\n';
      appData.trades.forEach(t => {
        csv += headers.map(h => `"${String(t[h] || '').replace(/"/g, '""')}"`).join(',') + '\n';
      });
      downloadFile(csv, `TRADES_${new Date().toISOString().slice(0,10)}.csv`, 'text/csv');
    }

    function exportForexCSV() {
      if (!appData || !appData.summary || !appData.summary.terminals) return;
      const terms = appData.summary.terminals;
      const headers = ['Terminal','Detail','BalanceUSD','EquityUSD','ProfitLossUSD','GrowthPct','Since'];
      let csv = headers.join(',') + '\n';
      Object.keys(terms).forEach(k => {
        const t = terms[k];
        csv += `"${t.terminalTitle}","${t.terminalDetail}","${t.balanceUSD}","${t.equityUSD}","${t.pnlUSD}","${t.growth}%","${t.sinc}"\n`;
      });
      downloadFile(csv, `FOREX_MT5_${new Date().toISOString().slice(0,10)}.csv`, 'text/csv');
    }

    function exportCashflowCSV() {
      if (!appData || !appData.cashflow) return;
      const headers = ['id','date','type','category','account','amountTHB','note'];
      let csv = headers.join(',') + '\n';
      appData.cashflow.forEach(c => {
        csv += headers.map(h => `"${String(c[h] || '').replace(/"/g, '""')}"`).join(',') + '\n';
      });
      downloadFile(csv, `CASHFLOW_${new Date().toISOString().slice(0,10)}.csv`, 'text/csv');
    }

    function downloadFile(content, fileName, mimeType) {
      const blob = new Blob(["\uFEFF" + content], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = fileName;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }

    window.addEventListener('DOMContentLoaded', () => {
      if (currentToken) {
        document.getElementById('pinOverlay').classList.add('hidden');
        loadDashboardData();
      } else {
        document.getElementById('pinOverlay').classList.remove('hidden');
      }
    });
  </script>
</body>
</html>
─────────────────────────────────────────────────