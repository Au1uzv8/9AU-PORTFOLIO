/* ============================================================
 *  i18n.js — 9AU Portfolio shared TH/EN translator  (v1.0, 2026-09-29)
 *  วางไฟล์นี้ไว้โฟลเดอร์เดียวกับ MyAssets*.html ทั้ง 6 ไฟล์
 *
 *  หลักการ
 *  - ภาษาที่บันทึกใน localStorage 'portfolio_lang' ('th' | 'en') ใช้ร่วมกันทุกหน้า
 *  - โหมด EN: แปลข้อความไทยทั้งหน้า (text node, placeholder, title, alert/confirm/prompt)
 *    และแปลเนื้อหาที่ JS สร้างใหม่ทีหลังด้วย MutationObserver
 *  - โหมด TH: คืนข้อความเดิมทุกจุด
 *  - ปุ่มแสดง "ภาษาปลายทาง": หน้าไทยแสดง EN / หน้าอังกฤษแสดง TH
 *  - ข้อความที่ไม่มีในพจนานุกรมจะแสดงเป็นภาษาเดิม (ไม่ทำให้หน้าพัง)
 *  - window.t(text) ใช้แปลข้อความบน Chart (canvas) ซึ่ง DOM translator แตะไม่ได้
 *  - หน้าที่มี Chart กำหนด window.onLangChange = function(lang){...} เพื่อ re-render
 * ============================================================ */
(function () {
  'use strict';

  var KEY   = 'portfolio_lang';
  var THAI  = /[\u0E00-\u0E7F]/;
  var lang  = (function () { try { return localStorage.getItem(KEY) === 'en' ? 'en' : 'th'; } catch (e) { return 'th'; } })();

  /* ── พจนานุกรม TH -> EN (key ต้องตรงกับข้อความหลัง trim) ── */
  var DICT = {
    /* ทั่วไป / PIN */
    'กรุณากรอกรหัสความปลอดภัย 6 หลัก': 'Please enter your 6-digit security PIN',
    'ล้าง': 'Clear',
    'รีเฟรช': 'Refresh',
    'รีเฟรช Bootstrap': 'Refresh Bootstrap',
    'ออกจากระบบ': 'Log out',
    'กำลังตรวจสอบ...': 'Verifying...',
    'รหัสผ่านไม่ถูกต้อง': 'Incorrect PIN',
    'รูปแบบรหัสไม่ถูกต้อง': 'Invalid PIN format',
    'กรุณาเข้าสู่ระบบ': 'Please log in',
    'บัตรผ่านหมดอายุ กรุณาเข้าสู่ระบบใหม่': 'Session expired. Please log in again',
    'บัตรผ่านไม่ถูกต้อง': 'Invalid session',
    'กำลังโหลดข้อมูลประวัติ...': 'Loading history data...',
    'กำลังโหลดข้อมูล...': 'Loading data...',
    'กำลังบันทึก...': 'Saving...',
    'ปิด': 'Close',
    'อัปเดต': 'Update',
    'ยกเลิก': 'Cancel',
    'บันทึก': 'Save',
    'แก้ไข': 'Edit',
    'ลบ': 'Delete',
    'จัดการ': 'Actions',
    'วันที่': 'Date',
    'ประเภท': 'Type',
    'จำนวน': 'Quantity',
    'หมายเหตุ': 'Note',
    'รายละเอียดเพิ่มเติม': 'Additional details',
    'ไม่พบรายการ': 'No records found',
    'อื่นๆ': 'Other',
    'ผิดพลาด': 'Error',
    'รวม:': 'Total:',
    'ดูรายละเอียด →': 'View details →',
    'หุ้นไทย': 'Thai Stocks',
    'สภาพคล่อง': 'Liquidity',
    'ปัจจุบัน': 'Current',
    'วันนี้': 'Today',
    'ถือครอง': 'Holding',
    'กรุณากรอกข้อมูลให้ครบ': 'Please fill in all required fields',
    'กรุณาระบุ Ticker': 'Please enter a Ticker',
    'กรุณาระบุสัญลักษณ์หลักทรัพย์': 'Please enter a security symbol',
    'จำนวนหุ้นต้องมากกว่าศูนย์': 'Share quantity must be greater than zero',
    'ราคาต่อหุ้นต้องมากกว่าศูนย์': 'Price per share must be greater than zero',
    'จำนวนเงินต้องมากกว่าศูนย์': 'Amount must be greater than zero',
    'กรุณากรอกจำนวนเงิน': 'Please enter an amount',
    'ยืนยันลบรายการนี้?': 'Confirm deleting this record?',
    'ยืนยันลบออกจาก Watchlist?': 'Confirm removing from Watchlist?',
    'ไม่พบรายการที่ต้องการลบ': 'Record to delete not found',
    'ไม่พบรายการที่ต้องการแก้ไข': 'Record to edit not found',
    'ยังไม่ได้ตั้งค่า telegramToken หรือ telegramChatId ในชีต SETTINGS': 'telegramToken or telegramChatId is not set in the SETTINGS sheet',
    'ส่ง Telegram ไม่สำเร็จ': 'Failed to send Telegram message',
    'ส่ง Telegram สำเร็จ!': 'Telegram sent successfully!',
    'บันทึกสำเร็จ': 'Saved successfully',
    'บันทึก Snapshot วันนี้?': "Save today's Snapshot?",
    'ข้อมูลยังไม่พร้อม กรุณารอโหลดเสร็จแล้วลองใหม่': 'Data is not ready. Please wait for loading to finish and try again',
    'เลือกเดือนของรายงาน (YYYY-MM)': 'Select the report month (YYYY-MM)',
    'SUMMARY (มูลค่า ณ เวลาที่ Export)': 'SUMMARY (values as of export time)',
    'ไม่มีข้อมูล SNAPSHOT ในเดือนนี้': 'No SNAPSHOT data for this month',

    /* กลุ่มการลงทุน / บัญชี (ค่าจากชีต) */
    'เสถียร (เติบโตตามมูลค่าสินทรัพย์)': 'Core (NAV growth)',
    'ดาวเทียม (เติบโตสูง ความเสี่ยงสูง)': 'Satellite (growth/risk)',
    'ดาวเทียม (เน้นโตสูง ความเสี่ยงสูง)': 'Satellite (growth/risk)',
    'ปันผลรายเดือน': 'Monthly Income',
    'เงินสด': 'Cash',
    'บัญชีใช้จ่าย': 'Spending Account',
    'เงินสำรองฉุกเฉิน': 'Emergency Fund',
    'บัญชีลงทุนสหรัฐ': 'US Investment Account',
    'บัญชีเงินตราต่างประเทศ': 'Foreign Currency Account',

    /* Dashboard */
    'มูลค่าสินทรัพย์สุทธิรวม (Net Worth)': 'Total Net Worth',
    'จัดการบัญชี Group-1': 'Manage Group-1 Accounts',
    'สัดส่วนสินทรัพย์รวม': 'Total Asset Allocation',
    'Group-1: สภาพคล่อง (THB)': 'Group-1: Liquidity (THB)',
    'เงินสดคงเหลือ': 'Cash Balance',
    'บัญชีธนาคาร': 'Bank Accounts',
    'Group-4: หุ้นไทย': 'Group-4: Thai Stocks',
    'ต้นทุนรวม': 'Total Cost',
    'มูลค่าปัจจุบัน': 'Current Value',
    'กำไร/ขาดทุน': 'Profit/Loss',
    'ต้นทุนรวม (netTHB)': 'Total Cost (net THB)',
    'Balance รวม': 'Total Balance',
    'Equity รวม': 'Total Equity',
    'จัดการยอดบัญชี Group-1': 'Manage Group-1 Account Balances',
    'เลือกบัญชี': 'Select Account',
    'ยอดเงิน (THB)': 'Amount (THB)',
    'เริ่มพอร์ต (08/01)': 'Portfolio start (08/01)',
    'เริ่มพอร์ต (2026-08-01)': 'Portfolio start (2026-08-01)',

    /* หุ้นไทย */
    '9AU Portfolio — หุ้นไทย': '9AU Portfolio — Thai Stocks',
    'หุ้นไทย (Thai Stocks)': 'Thai Stocks',
    'Group-4: สรุปพอร์ตหุ้นไทย (THB)': 'Group-4: Thai Stocks Portfolio Summary (THB)',
    'กำไร / ขาดทุน': 'Profit / Loss',
    'สัดส่วนตามกลุ่ม': 'Allocation by Group',
    'สัดส่วนรายหุ้น': 'Allocation by Stock',
    'พอร์ตหุ้นไทยที่ถือครอง': 'Thai Stock Holdings',
    'ดับเบิลคลิกที่แถวหุ้น เพื่อตั้งราคาเป้าหมาย': 'Double-click a stock row to set a target price',
    'ทุนเฉลี่ย (฿)': 'Avg Cost (฿)',
    'ราคา (฿)': 'Price (฿)',
    'ต้นทุนสุทธิ (฿)': 'Net Cost (฿)',
    'มูลค่า (฿)': 'Value (฿)',
    'ประวัติรายการหุ้นไทย': 'Thai Stock Trade History',
    'ค้นหา Ticker...': 'Search Ticker...',
    '+ บันทึกรายการ': '+ Add Entry',
    'ยอดสุทธิ (฿)': 'Net Amount (฿)',
    'บันทึกรายการหุ้นไทย': 'Record Thai Stock Trade',
    'แก้ไขรายการหุ้นไทย': 'Edit Thai Stock Trade',
    'ประเภทคำสั่ง': 'Order Type',
    'กลุ่มการลงทุน': 'Investment Group',
    'จำนวนหุ้น': 'Shares',
    'Fee: Commission 0.15% + Clearing 0.0072% + VAT 7% — คำนวณโดย Apps Script': 'Fee: Commission 0.15% + Clearing 0.0072% + VAT 7% — calculated by Apps Script',
    'Watchlist หุ้นไทย': 'Thai Stocks Watchlist',
    '+ เพิ่ม': '+ Add',
    'เป้าซื้อ': 'Buy Target',
    'เป้าขาย': 'Sell Target',
    'ราคาปัจจุบัน': 'Current Price',
    'เตือนเมื่ออยากซื้อ': 'Alert when I want to buy',
    'เตือนเมื่ออยากขาย': 'Alert when I want to sell',
    'ราคาเป้า (฿)': 'Target Price (฿)',
    'บันทึกแผนการเทรด': 'Trading Plan Note',
    'เช่น รอซื้อแถวแนวรับ 52W Low': 'e.g. Wait to buy near 52W Low support',
    'บันทึกเป้าหมาย': 'Save Targets',
    'ยังไม่มีหุ้นไทยในพอร์ต': 'No Thai stocks in the portfolio yet',
    'ยังไม่มีหุ้นไทยใน Watchlist': 'No Thai stocks in the Watchlist yet',
    'EXISTING (ในพอร์ต)': 'EXISTING (in portfolio)',

    /* US */
    'ต้นทุนรวม (Total Cost)': 'Total Cost',
    'มูลค่าปัจจุบัน (Market Value)': 'Market Value',
    'พอร์ต US ที่ถือครอง': 'US Holdings',
    'ราคา ($)': 'Price ($)',
    'ประวัติรายการ US (Trade Logs)': 'US Trade Logs',
    'บันทึกรายการ US Stocks/ETF': 'Record US Stocks/ETF Trade',
    'แก้ไขรายการ US Stocks/ETF': 'Edit US Stocks/ETF Trade',
    'เป้าซื้อ ($)': 'Buy Target ($)',
    'เป้าขาย ($)': 'Sell Target ($)',
    'ดับเบิลคลิกที่รายการ เพื่อตั้งราคาเป้าหมาย': 'Double-click a row to set a target price',
    'อยากซื้อ / ช้อนเพิ่ม': 'Want to buy / add more',
    'อยากขาย / ทำกำไร': 'Want to sell / take profit',
    'ไม่มีหุ้น US ในพอร์ต': 'No US stocks in the portfolio',
    'ยังไม่มีหุ้น US ใน Watchlist': 'No US stocks in the Watchlist yet',

    /* FOREX */
    'Group-3: FOREX MT5 รวม 4 Terminals (Firebase Realtime)': 'Group-3: FOREX MT5, All 4 Terminals (Firebase Realtime)',
    'Terminal Detail (ดึงสดจาก Firebase ← REALTIME Sheet)': 'Terminal Detail (live from Firebase ← REALTIME Sheet)',
    'อัปเดตทุก 5 นาทีโดย Apps Script Trigger': 'Updated every 5 minutes by Apps Script Trigger',
    'รายละเอียด EA': 'EA Details',
    'เริ่มเทรด': 'Trading Since',
    'เริ่มนับ 2026-08-01 | อัปเดตตาม Firebase Realtime': 'Counting from 2026-08-01 | Updated via Firebase Realtime',
    'สัดส่วน Equity แต่ละ Terminal': 'Equity Share by Terminal',

    /* Cashflow */
    'กระแสเงินสด (Cashflow)': 'Cashflow',
    'บันทึกเงินสดรับ-จ่าย และโอนย้ายสภาพคล่อง': 'Record cash inflows/outflows and liquidity transfers',
    'รับเข้าทั้งหมด': 'Total Inflow',
    'จ่ายออกทั้งหมด': 'Total Outflow',
    'กระแสสุทธิ': 'Net Cashflow',
    'รายการทั้งหมด': 'Total Records',
    'ประวัติกระแสเงินสด': 'Cashflow History',
    'ทุกทิศทาง': 'All Directions',
    'รับเข้า': 'Inflow',
    'จ่ายออก': 'Outflow',
    'ทิศทาง': 'Direction',
    'หมวดหมู่': 'Category',
    'บัญชี': 'Account',
    'จำนวน (฿)': 'Amount (฿)',
    'บันทึกกระแสเงินสด': 'Record Cashflow',
    'ทิศทางเงิน': 'Money Direction',
    'โอนออก / จ่ายออก': 'Transfer Out / Expense',
    'รับเข้า / โอนเข้าลงทุน': 'Inflow / Transfer to Invest',
    'บัญชีที่ใช้': 'Account Used',
    'จำนวนเงิน (฿)': 'Amount (฿)',
    'ไม่พบรายการกระแสเงินสด': 'No cashflow records found',
    'โอนเข้าลงทุน': 'Transfer to Invest',
    'เงินเดือน / รายได้': 'Salary / Income',
    'ถอนกำไรจากพอร์ต': 'Withdraw Portfolio Profit',
    'เงินปันผล / ดอกเบี้ย': 'Dividends / Interest',
    'เงินคืน / รายรับอื่นๆ': 'Refunds / Other Income',
    'โอนออก': 'Transfer Out',
    'ค่าใช้จ่ายทั่วไป': 'General Expenses',
    'ออมเงิน': 'Savings',
    'ถอนเงินสด': 'Cash Withdrawal',
    'ค่าธรรมเนียม / อื่นๆ': 'Fees / Other',

    /* README */
    'README — คู่มือระบบ': 'README — System Manual',
    'v8.2.0 | อัปเดต 2026-09-14': 'v8.2.0 | Updated 2026-09-14',
    'อัปเดตล่าสุด: 2026-09-25': 'Last updated: 2026-09-25',
    'คู่มือการใช้งาน & Context Summary': 'User Guide & Context Summary',
    'พิมพ์เขียวสถาปัตยกรรม | การแก้ไข | Hybrid Firebase Migration': 'Architecture Blueprint | Fixes | Hybrid Firebase Migration',
    '1. แนวคิดและที่มาของระบบ': '1. Concept and Origin of the System',
    'รวมศูนย์สินทรัพย์ 4 กลุ่มหลัก (All-in-One Net Worth):': 'Consolidates assets into 4 main groups (All-in-One Net Worth):',
    'สภาพคล่องเงินบาท — เงินสด, ธนาคาร, เงินสำรองฉุกเฉิน': 'THB liquidity — cash, bank, emergency fund',
    'หุ้น/ETF สหรัฐ (Dime! Broker) — True Reconciliation, ค่าธรรมเนียม SEC/TAF': 'US stocks/ETFs (Dime! Broker) — True Reconciliation, SEC/TAF fees',
    'หุ้นไทย (Dime! Broker) — Commission+Clearing+VAT': 'Thai stocks (Dime! Broker) — Commission + Clearing + VAT',
    '2. สถาปัตยกรรมระบบ v8.2 (Hybrid Firebase)': '2. System Architecture v8.2 (Hybrid Firebase)',
    '├── ราคาหุ้น US + Thai (priceMap)': '├── US + Thai stock prices (priceMap)',
    'Apps Script Trigger → Firebase RTDB ทุก 5 นาที': 'Apps Script Trigger → Firebase RTDB every 5 minutes',
    'สูตร Net Worth:': 'Net Worth formula:',
    '3. โครงสร้างไฟล์ (Multi-Page Architecture)': '3. File Structure (Multi-Page Architecture)',
    'ไฟล์': 'File',
    'เนื้อหา': 'Content',
    'บรรทัด': 'Lines',
    'หุ้นไทย + Trade Log + Watchlist + Alert': 'Thai Stocks + Trade Log + Watchlist + Alert',
    'Cashflow บันทึก/ลบ/กรอง': 'Cashflow record/delete/filter',
    'คู่มือนี้': 'This manual',
    '4. ไทม์ไลน์การพัฒนา (Milestones)': '4. Development Timeline (Milestones)',
    'งานหลัก': 'Main Work',
    'ผลลัพธ์': 'Result',
    'PIN 6 หลัก, Schema, Dark Mode': '6-digit PIN, Schema, Dark Mode',
    'ต้นทุนถัวเฉลี่ย, W-BUY/W-SELL, IMPORTMT5': 'Average cost, W-BUY/W-SELL, IMPORTMT5',
    'Direct Cell Mapping, Fallback ราคา': 'Direct Cell Mapping, price Fallback',
    'Firebase RTDB Live, 6 ไฟล์แยก, Timeout หมดปัญหา': 'Firebase RTDB Live, 6 separate files, Timeout resolved',
    '5. ปัญหาที่พบและแนวทางแก้ไข': '5. Problems Found and Solutions',
    'Apps Script Timeout (popup ใช้เวลานาน):': 'Apps Script Timeout (popups taking too long):',
    'แก้ด้วย Firebase Hybrid — ข้อมูล realtime ดึงจาก Firebase (<300ms) ไม่ต้องรอ Apps Script แล้ว': 'Solved with Firebase Hybrid — realtime data is fetched from Firebase (<300ms) with no need to wait for Apps Script',
    'ไฟล์ HTML เดียว 2800+ บรรทัด รวนเมื่อแก้ไข:': 'Single 2,800+ line HTML file breaking on edits:',
    'แก้ด้วย Multi-Page — แต่ละ Tab เป็น HTML แยก ~300-660 บรรทัด แก้ไขระบุไฟล์ชัดเจน': 'Solved with Multi-Page — each Tab is a separate HTML file of ~300-660 lines, so edits target a specific file',
    'ราคาหุ้น Google Finance เพี้ยน (SPCX=$0.01):': 'Google Finance stock prices incorrect (SPCX=$0.01):',
    'ใช้ REALTIME Sheet เป็น source of truth → push ไป Firebase ทุก 5 นาที มี Guard >1.0': 'Use the REALTIME Sheet as the source of truth → push to Firebase every 5 minutes with a Guard >1.0',
    'Token หมดอายุ ต้อง Login ซ้ำทุกหน้า:': 'Token expiry forcing a re-login on every page:',
    'ใช้ localStorage เก็บ token ร่วมกันทุกหน้า Login ครั้งเดียวใช้ได้ทุก Tab (12 ชั่วโมง)': 'Store the token in localStorage shared by all pages; one login works across every Tab (12 hours)',
    'ทุก 5 นาที (Time-based)': 'Every 5 minutes (Time-based)',
    '7. ข้อดีของระบบ': '7. System Strengths',
    'Firebase push <300ms แทน JSONP poll': 'Firebase push <300ms instead of JSONP polling',
    'ตรงกับ Dime App และ MT5': 'Matches Dime App and MT5',
    'แก้ไขง่าย ระบุไฟล์ชัดเจน ไม่รวน': 'Easy to edit, clear file targets, no breakage',
    'แจ้งเตือนราคาเป้าหมายอัตโนมัติ': 'Automatic target price alerts',
    '8. บทสรุป': '8. Summary',
    'ระบบ v8.2 Hybrid Firebase ได้แก้ปัญหา Timeout และไฟล์ขนาดใหญ่ ด้วยการแยก 1 Tab = 1 HTML ไฟล์ และเปลี่ยนข้อมูล Realtime มาดึงจาก Firebase RTDB แทน Apps Script โดยตรง ทำให้ระบบเสถียร แก้ไขง่าย และ Response เร็วขึ้นอย่างมีนัยสำคัญ':
      'The v8.2 Hybrid Firebase system solves the Timeout and oversized-file problems by splitting the app into 1 Tab = 1 HTML file and fetching Realtime data from Firebase RTDB instead of calling Apps Script directly. This makes the system stable, easy to edit, and significantly faster to respond.'
  };

  /* ── กฎสำหรับข้อความประกอบ (มีตัวเลข/ข้อความแปรผัน) ── */
  var RULES = [
    [/^ผิดพลาด: ([\s\S]*)$/,               function (m) { return 'Error: ' + inner(m[1]); }],
    [/^ส่งไม่สำเร็จ: ([\s\S]*)$/,           function (m) { return 'Send failed: ' + inner(m[1]); }],
    [/^ไม่พบรายการ id: ([\s\S]*)$/,         function (m) { return 'Record not found, id: ' + m[1]; }],
    [/^ไม่รู้จักคำสั่ง: ([\s\S]*)$/,         function (m) { return 'Unknown command: ' + m[1]; }],
    [/^ไม่พบแท็บชีต ([\s\S]*)$/,            function (m) { return 'Sheet tab not found: ' + m[1]; }],
    [/^รูปแบบเดือนไม่ถูกต้อง เช่น ([\s\S]*)$/, function (m) { return 'Invalid month format, e.g. ' + m[1]; }],
    [/^(.+?) หุ้น @ ([\s\S]*)$/,            function (m) { return m[1] + ' shares @ ' + m[2]; }],
    [/^รหัสไม่ถูกต้อง เหลืออีก (\d+) ครั้ง$/, function (m) { return 'Incorrect PIN, ' + m[1] + ' attempt(s) left'; }],
    [/^ถูกระงับชั่วคราว กรุณารออีก (\d+) นาที$/, function (m) { return 'Temporarily locked. Please wait ' + m[1] + ' more minute(s)'; }],
    [/^กรอกผิดครบ (\d+) ครั้ง ระงับ (\d+) นาที$/, function (m) { return 'Too many wrong attempts (' + m[1] + '). Locked for ' + m[2] + ' minutes'; }],
    [/^(.+) \((THB|USD)\)$/,               function (m) { var x = DICT[m[1]]; return x ? x + ' (' + m[2] + ')' : null; }],
    [/ตำแหน่งราคา/,                          function (m, s) { return s.replace(/ตำแหน่งราคา/g, 'price position'); }]
  ];

  function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
  function inner(s) { var r = lookup(s.trim()); return r === null ? s : r; }

  function lookup(core) {
    if (has(DICT, core)) return DICT[core];
    for (var i = 0; i < RULES.length; i++) {
      var m = core.match(RULES[i][0]);
      if (m) { var out = RULES[i][1](m, core); if (out !== null && out !== undefined) return out; }
    }
    return null;
  }

  /* แปลสตริง (เก็บช่องว่างหน้า-หลัง / รองรับหลายบรรทัด) — คืน null ถ้าไม่มีอะไรเปลี่ยน */
  function tr(s) {
    if (!s || !THAI.test(s)) return null;
    var core = s.trim();
    if (!core) return null;
    var lead = s.match(/^\s*/)[0], trail = s.match(/\s*$/)[0];
    var out = lookup(core);
    if (out === null && core.indexOf('\n') > -1) {
      var changed = false;
      var lines = s.split('\n').map(function (ln) {
        var c = ln.trim();
        if (!c || !THAI.test(c)) return ln;
        var r = lookup(c);
        if (r === null) return ln;
        changed = true;
        return ln.match(/^\s*/)[0] + r + ln.match(/\s*$/)[0];
      });
      return changed ? lines.join('\n') : null;
    }
    return out === null ? null : lead + out + trail;
  }

  /* ── DOM: text node ── */
  var nodeMap = new WeakMap();   // node -> { orig, out }
  var attrMap = new WeakMap();   // element -> { attr: { orig, out } }
  var ATTRS   = ['placeholder', 'title', 'aria-label'];
  var SKIP    = { SCRIPT: 1, STYLE: 1, TEXTAREA: 1, NOSCRIPT: 1 };

  function applyText(node) {
    var v = node.nodeValue, rec = nodeMap.get(node);
    if (rec && rec.out === v) return;
    var out = tr(v);
    if (out !== null && out !== v) { nodeMap.set(node, { orig: v, out: out }); node.nodeValue = out; }
  }
  function applyAttrs(el) {
    if (!el.getAttribute) return;
    ATTRS.forEach(function (a) {
      var v = el.getAttribute(a);
      if (v === null) return;
      var rec = attrMap.get(el), r = rec && rec[a];
      if (r && r.out === v) return;
      var out = tr(v);
      if (out !== null && out !== v) {
        if (!rec) { rec = {}; attrMap.set(el, rec); }
        rec[a] = { orig: v, out: out };
        el.setAttribute(a, out);
      }
    });
  }
  function walk(root, fn, afn) {
    if (!root) return;
    if (root.nodeType === 3) { if (!SKIP[root.parentNode && root.parentNode.nodeName]) fn(root); return; }
    if (root.nodeType !== 1 || SKIP[root.nodeName]) return;
    afn(root);
    var w = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, null);
    var n;
    while ((n = w.nextNode())) {
      if (n.nodeType === 3) { if (!SKIP[n.parentNode.nodeName]) fn(n); }
      else if (!SKIP[n.nodeName]) afn(n);
    }
  }
  function restoreText(node) {
    var rec = nodeMap.get(node);
    if (rec) { if (node.nodeValue === rec.out) node.nodeValue = rec.orig; nodeMap.delete(node); }
  }
  function restoreAttrs(el) {
    var rec = attrMap.get(el);
    if (!rec) return;
    Object.keys(rec).forEach(function (a) { if (el.getAttribute(a) === rec[a].out) el.setAttribute(a, rec[a].orig); });
    attrMap.delete(el);
  }

  var origTitle = document.title;
  function syncTitle() {
    if (lang === 'en') { var o = tr(origTitle); document.title = o !== null ? o : origTitle; }
    else document.title = origTitle;
  }
  function syncButtons() {
    var lbl = lang === 'th' ? 'EN' : 'TH';
    var els = document.querySelectorAll('.lang-btn-label');
    for (var i = 0; i < els.length; i++) els[i].textContent = lbl;
  }

  /* ── observer: แปลเนื้อหาที่ JS สร้าง/แก้ไขทีหลัง (ทำงานเฉพาะโหมด EN) ── */
  var observer = null;
  function startObserver() {
    if (observer || !window.MutationObserver || !document.body) return;
    observer = new MutationObserver(function (muts) {
      if (lang !== 'en') return;
      muts.forEach(function (m) {
        if (m.type === 'characterData') { if (!SKIP[m.target.parentNode && m.target.parentNode.nodeName]) applyText(m.target); }
        else if (m.type === 'attributes') applyAttrs(m.target);
        else m.addedNodes.forEach(function (n) { walk(n, applyText, applyAttrs); });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  }

  function setLang(l) {
    lang = (l === 'en') ? 'en' : 'th';
    try { localStorage.setItem(KEY, lang); } catch (e) {}
    document.documentElement.setAttribute('lang', lang);
    if (lang === 'en') walk(document.body, applyText, applyAttrs);
    else walk(document.body, restoreText, restoreAttrs);
    syncTitle();
    syncButtons();
    if (typeof window.onLangChange === 'function') { try { window.onLangChange(lang); } catch (e) { console.error(e); } }
  }

  /* ── alert / confirm / prompt ── */
  ['alert', 'confirm', 'prompt'].forEach(function (name) {
    var orig = window[name].bind(window);
    window[name] = function (msg, def) {
      var m = msg;
      if (lang === 'en' && msg !== undefined && msg !== null) { var o = tr(String(msg)); if (o !== null) m = o; }
      return name === 'prompt' ? orig(m, def) : orig(m);
    };
  });

  /* ── Public API ── */
  window.t          = function (s) { if (lang !== 'en' || s === undefined || s === null) return s; var o = tr(String(s)); return o !== null ? o : s; };
  window.getLang    = function () { return lang; };
  window.setLang    = setLang;
  window.toggleLang = function () { setLang(lang === 'th' ? 'en' : 'th'); };

  function init() {
    document.documentElement.setAttribute('lang', lang);
    startObserver();
    if (lang === 'en') walk(document.body, applyText, applyAttrs);
    syncTitle();
    syncButtons();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();