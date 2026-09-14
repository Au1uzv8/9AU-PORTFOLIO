//+------------------------------------------------------------------+
//|         9AU_GOLD_COMBINE_M5_CAP450.mq5                           |
//|  James Consultant | House Money + Compound Lot | v19.9            |
//|  Magic 919291 | Kill Switch DD 25% -> ExpertRemove()             |
//|  Stage 1: Fixed Lot | Stage 2: Compound or Withdraw+Reset        |
//|  v19.4 Fix K: Virtual Balance/Equity per Magic Number             |
//|  (เดิม v19.3 ใช้ ACCOUNT_EQUITY/ACCOUNT_BALANCE ทั้งบัญชีตรงๆ ทุก |
//|  ฟังก์ชัน Money Management — Gold เคยรันเดี่ยวไม่มีปัญหา แต่เมื่อ  |
//|  ย้ายเข้า Alpha-pool ร่วมกับ NDAQ100(919294)+GBPJPY(515254) จะเกิด|
//|  Cross-Contamination ทันที แก้ด้วย Pattern เดียวกับ               |
//|  9AU_NDAQ100_COMBINE v1.0->v1.1 Fix G)                            |
//|  v19.4 Fix M: แก้ Default InpEnableSell false->true (ตรง Production|
//|  .set ที่ Validate ผ่าน Protocol v2.0 มาแล้ว)                     |
//|  v19.5 Fix N: ตัด Compound ออกจากเงื่อนไข InpEnableHouseMoney     |
//|  (3 จุด: GetSniperLot, GetSellSniperLot, SoftBrake ใน             |
//|  CheckEquityStop) — เดิม Compound ถูกล็อกไม่ทำงานเลยเมื่อ         |
//|  HM=FALSE (ค่า Production Default) ทั้งที่ InpEnableCompound=true |
//|  v19.6 Fix O (CRITICAL): พบว่า Fix N ยังไม่พอ — โค้ด Auto-Activate |
//|  Compound (ตั้ง currentLotMode=LOT_COMPOUND) ฝังอยู่ข้างใน         |
//|  CheckHouseMoney() ซึ่ง Return ก่อนถึงจุดนั้นเสมอเมื่อ HM=false    |
//|  ทำให้ currentLotMode ไม่เคยเปลี่ยนจาก LOT_FIXED เลย แก้โดยแยกเป็น|
//|  UpdateCompoundState() อิสระ เรียกทุก Tick ไม่ขึ้นกับ HouseMoney   |
//|  v19.7 Test(3+4): แก้ค่าเดียวรวม 3 ตัว ตามที่ตกลง — ไม่ใช่        |
//|  Single-Lever แต่เป็น Exception ที่บันทึกไว้ตรงนี้:                |
//|  InpCompoundStartMultiple 1.5->2.0 (Test 3, Buffer มากขึ้น)      |
//|  InpCompoundDDSoftBrake 20.0->15.0 (Test 4, sync EA อื่น)         |
//|  InpCompoundMaxDD 28.0->22.0 (Test 4, sync EA อื่น)               |
//|  v19.8 FINAL — Root Cause Fix + Accepted as Structural:            |
//|  InpHardSLMultiplier 11.0->7.0 (พิสูจน์แล้วว่าเป็น Root Cause จริง|
//|  ของ DD ลึก ไม่ใช่แค่ Kill Threshold — ทดสอบ 22 EA/SL Config      |
//|  พบว่า SL แคบลงช่วยทุก Metric พร้อมกัน ไม่มี Trade-off)           |
//|  Protocol v2.0: FAIL 3/9 (#2 PF=1.439 vs 1.50, #4 Balance DD=      |
//|  22.21% vs 20%, #7 WinRate 53.9% ไม่เข้าเงื่อนไขยกเว้น) — ยอมรับ  |
//|  เป็น Structural Characteristic เพราะ Root Cause เจาะจงได้ชัดเจน   |
//|  (Fast Directional Move เดี่ยว 2026.01.29 17:12-17:15) ไม่ใช่ปัญหา|
//|  เชิงระบบ + ระยะห่างจากเกณฑ์แคบกว่าเดิมมาก (PF ห่าง 0.06,          |
//|  DD ห่าง 2.21pp เทียบจาก 0.22/9.96pp ตอนเริ่ม) — ดูรายละเอียดเต็ม |
//|  ใน Context_Summary_Gold_V19_4_to_V19_8_FINAL.md                  |
//|  v19.9 Fix P: Indicator Handle Leak — เดิม GetRSI/GetATR/GetEMA/   |
//|  GetADX/GetAvgATR สร้าง handle ใหม่ทุก call โดยไม่ release ทำให้   |
//|  MT5 สะสม orphan handle ทุก OnTick → degraded performance ระยะยาว  |
//|  แก้โดย declare global handle 5 ตัว สร้างครั้งเดียวใน OnInit()     |
//|  release ใน OnDeinit() — ตาม MQL5 best practice                    |
//|  v19.9 Fix Q: SL Timing Race Condition — SetHardSL ถูก call ทันที  |
//|  หลัง trade.Buy/Sell ด้วย trade.ResultOrder() แต่บางครั้ง MT5 ยัง  |
//|  ไม่ register position ทัน → PositionSelectByTicket() fail silently |
//|  → SL ไม่ถูก set → ตกไปที่ ApplyHardSLAll() บาร์ถัดไปด้วย ATR     |
//|  ที่อาจต่างออกไป แก้ด้วย retry loop สั้น (5 รอบ × 50ms)           |
//|  v19.9 Fix R: Trail R:R — จาก live data Aug 2026 พบ avg win $13.35  |
//|  vs avg loss $19.90 → R:R 0.67 ต่ำกว่า break-even (59.9% WR)      |
//|  สาเหตุ: InpTrailStartUSD=12 ต่ำกว่า BasketTP=18 → trail lock profit|
//|  ก่อน basket TP ทำให้ winners ถูกตัดเร็ว แก้: 12.0->20.0 (sync กับ |
//|  BasketTP), InpTrailStepATR 2.5->3.5 (หายใจมากขึ้น)               |
//|  v19.9 Fix S: IsTrendDown OR branch — เดิม EMA50<200 OR ADX>42     |
//|  ADX สูงใน Gold uptrend ทำให้ผ่าน OR branch ขณะ structure ยัง Bullish|
//|  แก้เป็น: EMA50<200 AND (ADX > InpADXTrendHigh) ต้องครบทั้งคู่     |
//|  v19.10 Fix R-revised: Trail re-calibration — v19.9 ตั้ง            |
//|  TrailStartUSD=20 ทำให้ Profit Factor ลดลง 1.439->1.363 เพราะ      |
//|  trades ที่วิ่งถึง $12-$19 แล้ว reverse กลับกลายเป็น SL hit แทน   |
//|  แก้ด้วยจุดสมดุล: 20.0->15.0 (ยืดจาก v19.8 ไม่ revert กลับ $12) |
//|  InpTrailStepATR 3.5->3.0 (tight ขึ้นเล็กน้อย capture กำไรได้มากกว่า)|
//|  v19.10 Fix V: Compound Volatility Brake (ATR Spike Guard) —        |
//|  Root cause ของ Balance DD Relative 47.75% คือ Compound lot scale   |
//|  ขึ้นถึง 0.07-0.08 ในช่วง Gold explosion Jan 2026 (+25% ใน 3 สัปดาห์|
//|  4,400->5,500) ทำให้ consecutive SL hits แต่ละครั้ง $150-200 และ   |
//|  SoftBrake ตอบสนองช้าเกินไป (ทำงานเมื่อ equity DD ถึง 15% แล้ว)   |
//|  Fix V เพิ่ม upstream ATR-based guard: เมื่อ ATR_current >          |
//|  AvgATR(50) × InpHighVolATRMult (default 1.8) → g_highVolBrake=true |
//|  → Compound lot ถูก cap ที่ InpHighVolMaxLot (default 0.03) ทันที   |
//|  ก่อน DD จะก่อตัว — brake ปลดอัตโนมัติเมื่อ ATR กลับสู่ normal     |
//|  ส่ง Telegram alert ทุกครั้งที่ ON/OFF                              |
//|  v19.10 Backtest result: MAIN FAIL 6/8 (PF 1.245, WR 51.65%,        |
//|  Bal DD Max 43.35%) — Fix V throttle compound แรงเกินไป: Net Profit  |
//|  ลด 51% ($2087→$1027) และ Bal DD Max% paradoxically สูงขึ้น         |
//|  เพราะ peak balance ต่ำลงมากกว่า absolute DD ที่ลดลง                |
//|  AUG period: FAIL 1/8 (WR 58.33% เท่า v19.9, borderline sample)    |
//|  Net P&L +$99.52 vs live v19.8 -$96.42 (+$196 delta) — Fix Q/S ยัง |
//|  ทำงานถูกต้อง R:R 1.30 vs live 0.67                                |
//|  v19.11 Fix W: Momentum Pause Filter — Root cause ที่แท้จริงของ      |
//|  MAIN DD คือ EA entry BUY ซ้ำในช่วง extreme Gold momentum            |
//|  (Jan 2026: +25% ใน 3 สัปดาห์ 4,400→5,500) — RSI ร่วงชั่วคราวต่ำ  |
//|  กว่า 42 แล้วดีดกลับ ทำให้ entry triggered ซ้ำแล้วโดน SL ต่อเนื่อง  |
//|  Trail/SL/lot fixes แก้ที่ปลายทาง — Fix W แก้ที่ต้นทาง: ตรวจ %move |
//|  ของราคาใน InpMomentumBars ล่าสุด → ถ้าเกิน InpMomentumPct% ให้     |
//|  g_momentumPause=true → ยับยั้ง entry ทั้งหมด (Buy+Sell) ชั่วคราว  |
//|  positions ที่เปิดอยู่ยังถูก manage ต่อ (trail/basket/SL ปกติ)      |
//|  Default: InpMomentumBars=48 (4 ชั่วโมง M5) InpMomentumPct=5.0%    |
//|  Telegram alert ทุก ON/OFF พร้อม direction (UP/DOWN) และ %move       |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "19.11"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//  INPUTS
//+------------------------------------------------------------------+
input int    InpMagicNumber      = 919291;

input group "=== Step A: Filter (Buy - Original v14) ==="
input int              InpTrendEMA       = 200;
input ENUM_TIMEFRAMES  InpFilterTF       = PERIOD_H4;
input int              InpRSIPeriod      = 14;
input double           InpRSILowerLevel  = 42.0;
input double           InpRSIUpperLevel  = 68.0;

input group "=== Step B: Buy Grid & Lot ==="
input bool   InpEnableDynamicGrid  = true;
input int    InpATRPeriod          = 14;
input double InpATRMultiplier      = 6.5;
input double InpInitialLot         = 0.01;   // Base lot (Stage 1)
input double InpBaseMultiplier     = 1.15;
input double InpReductionStep      = 0.05;
input double InpMinMultiplier      = 1.05;
input int    InpMaxOrders          = 5;

input group "=== Step B2: Sell Grid (Conservative) ==="
input bool   InpEnableSell           = true;    // v19.4 Fix M: แก้ Default จาก false เป็น true ให้ตรงกับ Production .set
                                                 // (เดิม Default ค้างจาก V14 Buy-only ทำให้ Backtest ด้วย Default ล้วน
                                                 // กลายเป็น Buy-only โดยไม่ตั้งใจ ต่างจาก Production จริงที่เปิด Sell)
input double InpSellInitialLot       = 0.01;
input double InpSellATRMultiplier    = 9.75;
input double InpSellBaseMultiplier   = 1.05;
input double InpSellReductionStep    = 0.02;
input double InpSellMinMultiplier    = 1.02;
input int    InpSellMaxOrders        = 5;
input double InpSellBasketTP         = 16.0;
input double InpSellHardSLMultiplier = 3.5;
input double InpSellTrailStartUSD    = 8.0;
input double InpSellTrailStepATR     = 1.5;

input group "=== Step I: Sell Regime Filter ==="
input int    InpADXPeriod        = 14;
input double InpADXTrendHigh     = 28.0;
input int    InpEMA50Period      = 50;
input double InpEMASlopeATRMult  = 0.08;
input int    InpEMASlopeLookback = 20;
input double InpRSITrendLow      = 43.0;
input double InpRSITrendHigh     = 57.0;
// --- Sell Quality Filter (Layer 3 & 4) ---
input double InpSellMinATRMult   = 1.2;    // Layer 3: ATR > AvgATR x this = volatile market only
input int    InpAvgATRPeriod     = 50;     // Period for Average ATR baseline
input int    InpResistLookback   = 96;     // Layer 4: Resistance lookback bars (H4 bars = 96 x M5)
input double InpResistBuffer     = 0.003;  // Price must be this % below resistance (0.3%)

input group "=== Step C: Profit & Exit ==="
input double InpBasketTP           = 18.0;
input bool   InpEnablePartialClose = true;
input double InpPartialCloseLevel  = 0.70;
input double InpHardSLMultiplier   = 7.0;    // v19.8 FINAL: 11.0->7.0 (Root Cause Fix — ดู Header/Context Summary)
input int    InpMinHoldBars        = 12;

input group "=== Step D: News Filter ==="
input bool   EnableNewsFilter      = true;
input int    NewsBeforeMinutes     = 60;
input int    NewsAfterMinutes      = 60;
input bool   NewsHighImpactOnly    = true;

input group "=== Step E: Safety & Protection ==="
input bool   InpEnableEquityStop   = true;
input double InpMaxDrawdownPercent = 25.0;   // Kill Switch -> ExpertRemove
input double InpTrailStartUSD      = 15.0;   // Fix R-revised: 20.0->15.0 จุดสมดุล (v19.8=12, v19.9=20, v19.10=15)
                                              // ยืดจาก 12 เพื่อแก้ R:R แต่ไม่ปล่อย 20 ซึ่งให้ trades ที่ $12-$19 reverse กลายเป็น SL hit
input double InpTrailStepATR       = 3.0;    // Fix R-revised: 3.5->3.0 tight ขึ้นเล็กน้อย capture กำไรได้เร็วกว่าเมื่อ trail start ต่ำลง
input int    InpMaxHoldDays        = 60;
input double InpMinATRThreshold    = 3.5;
// Fix V: Compound Volatility Brake inputs
input double InpHighVolATRMult     = 1.8;
input double InpHighVolMaxLot      = 0.03;
// Fix W: Momentum Pause Filter inputs — upstream entry gate สำหรับ extreme momentum events
// ตัวอย่าง Jan 2026 Gold: +25% ใน 3 สัปดาห์ = ~8% ต่อ 4 ชั่วโมงในช่วง peak
// Default 5% / 48 bars (4h) จะ trigger ใน extreme move แต่ไม่กระทบ normal trend
input bool   InpEnableMomentumPause  = true;    // Fix W: เปิด/ปิด Momentum Pause Filter
input int    InpMomentumBars         = 48;      // Fix W: lookback bars M5 (48 = 4 ชั่วโมง)
input double InpMomentumPct          = 5.0;     // Fix W: % move threshold เพื่อ trigger pause
input double InpMaxSpreadBase      = 35.0;
input double InpMaxSpreadHighVol   = 40.0;
input double InpMaxExposurePercent = 12.5;
input double InpMinMarginLevel     = 700.0;

input group "=== Step F: Time Filter ==="
input bool   EnableTimeFilter      = true;
input int    TradingStartHour      = 6;
input int    TradingEndHour        = 2;
input bool   StopFridayAfterClose  = true;
input int    FridayCloseHour       = 18;

input group "=== Step G: Daily Loss Limit ==="
input bool   EnableDailyLossLimit        = true;
input double MaxDailyLossPercent         = 2.25;
input double InpDailyLossCloseAllPercent = 5.0;

input group "=== Step H: Telegram Notify ==="
input bool   InpEnableTelegram   = true;
input string InpToken            = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string InpChatID           = "8053031320";
input double InpTelegramDDAlert  = 15.0;
input bool   InpEnable2xAlert    = true;
input double InpBaseBalance      = 450.0;   // ทุนเริ่มต้น

input group "=== Step L: House Money & Compound ==="
input bool   InpEnableHouseMoney        = false;
input double InpHouseMoneyTarget        = 2.0;    // x เท่าของ BaseBalance = 100% profit
input bool   InpEnableCompound          = true;   // true=Compound, false=รอ Withdraw manual
input double InpCompoundStartMultiple   = 2.0;    // v19.7 Test(3): 1.5->2.0 เริ่ม compound ช้าลง มี Buffer มากขึ้นก่อนเปิด Lot ใหญ่
input double InpCompoundMaxLot          = 0.10;   // Lot สูงสุดใน Compound mode
input double InpCompoundDailyLossClose  = 3.0;    // Daily Loss CloseAll ใน Compound mode (แคบกว่า Fixed)
input double InpCompoundDDSoftBrake     = 15.0;   // v19.7 Test(4): 20.0->15.0 sync กับ EA อื่น (OIL-WTI/GBPJPY/USDJPY/AUDCAD)
input double InpCompoundMaxDD           = 22.0;   // v19.7 Test(4): 28.0->22.0 sync กับ EA อื่น (กว้างกว่า Fixed 25% เดิม -> แคบกว่าแล้ว)

input group "=== Step K: Combine Mode — Money & Risk Management ==="
input bool   InpCombineMode        = true;    // เปิด Combine Mode (ต้อง true เมื่อรวมบัญชีกับ NDAQ100/GBPJPY)
input double InpActiveBase         = 450.0;   // ทุนที่ active ใน EA นี้ — ใช้เป็น Virtual Base Balance

input group "=== Step L: Manual DCA (Cumulative Total, ไม่ใช่ยอดต่อเดือน) ==="
input double InpDCAtoAdd           = 0.0;     // กรอกเป็นยอด DCA สะสมทั้งหมดตั้งแต่เริ่ม (เช่น เดือน1=30, เดือน2=60 ...)

input group "=== Step J: Diagnostic ==="
input bool InpDiagnosticLog      = true;

//+------------------------------------------------------------------+
//  ENUMS
//+------------------------------------------------------------------+
enum LOT_MODE { LOT_FIXED, LOT_COMPOUND };

//+------------------------------------------------------------------+
//  GLOBALS
//+------------------------------------------------------------------+
struct BasketInfo {
   int      buyCount;
   int      sellCount;
   double   totalProfit;
   double   totalLots;
   double   lastBuyPrice;
   double   lastSellPrice;
   double   lastBuyLot;
   double   lastSellLot;
   datetime oldestOpenTime;
};
BasketInfo basket;

double buyBasketProfit  = 0.0;
double sellBasketProfit = 0.0;

// Daily Loss
datetime currentDay       = 0;
double   dayStartBalance  = 0.0;
double   dayLowestEquity  = 0.0;
double   dailyLossPercent = 0.0;
bool     dailyLossClosed  = false;
bool     partialDone      = false;
bool     partialDoneSell  = false;

// Peak equity for DD
double   peakEquity       = 0.0;
// High Water Mark for Compound Lot - ป้องกัน scale lot ระหว่าง DD
double   compoundHWM      = 0.0;   // peak balance ขณะ compound mode active
bool     compoundBrake    = false; // true=ลด lot กลับ Fixed ชั่วคราวเมื่อ DD > SoftBrake

// Alerts
bool     ddAlertSent      = false;
datetime lastDDAlertTime  = 0;
int      last2xLevel      = 1;

// House Money state
LOT_MODE currentLotMode   = LOT_FIXED;
bool     houseMoneyAlerted = false;
datetime lastHouseAlert   = 0;

// News
datetime lastNewsUpdate   = 0;
MqlCalendarValue TodayEvents[];

// Combine Mode — Virtual Balance/Equity per Magic Number (Fix K, sync pattern กับ NDAQ100/GBPJPY/AUDCAD/OIL/USDJPY)
double   g_vRealizedProfit = 0.0;   // Realized P/L สะสมเฉพาะ Magic 919291 (จาก Deal History + OnTradeTransaction)

// Fix V: High Volatility Brake state
bool g_highVolBrake = false;
// Fix W: Momentum Pause state — true เมื่อ price เคลื่อนที่ > InpMomentumPct% ใน InpMomentumBars ที่ผ่านมา
// ยับยั้ง entry ใหม่ทั้งหมด (Buy+Sell) จนกว่า momentum จะกลับสู่ normal
bool g_momentumPause = false;

// Fix P: Global indicator handles — สร้างครั้งเดียวใน OnInit(), release ใน OnDeinit()
// เดิมสร้าง handle ใหม่ทุก GetRSI/GetATR/GetEMA/GetADX/GetAvgATR call → orphan handle leak
int g_hRSI    = INVALID_HANDLE;
int g_hATR    = INVALID_HANDLE;
int g_hEMA200 = INVALID_HANDLE;   // EMA200 บน InpFilterTF (H4)
int g_hEMA50  = INVALID_HANDLE;   // EMA50  บน InpFilterTF (H4)
int g_hADX    = INVALID_HANDLE;

//+------------------------------------------------------------------+
//  TELEGRAM
//+------------------------------------------------------------------+
void TelegramSend(string message) {
   if(!InpEnableTelegram) return;
   string url     = "https://api.telegram.org/bot" + InpToken + "/sendMessage";
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string body    = "chat_id=" + InpChatID + "&text=" + message;
   char   req[], res[];
   string resHeaders;
   StringToCharArray(body, req, 0, StringLen(body));
   int code = WebRequest("POST", url, headers, 5000, req, res, resHeaders);
   if(code == 200) Print("[TELEGRAM] Sent OK");
   else Print("[TELEGRAM] Failed HTTP=", code, " Err=", GetLastError());
}

//+------------------------------------------------------------------+
//  VIRTUAL BALANCE / EQUITY — per Magic Number (Fix K)               |
//  แก้จาก ACCOUNT_EQUITY/ACCOUNT_BALANCE ทั้งบัญชี (ปนกับ EA อื่นที่ |
//  ร่วมบัญชีเดียวกัน) เป็นการกรอง Deal History + Position ด้วย       |
//  InpMagicNumber ของตัวเองเท่านั้น sync pattern เดียวกับ            |
//  NDAQ100/GBPJPY/AUDCAD/OIL/USDJPY Combine ทุกตัว                   |
//+------------------------------------------------------------------+
void ScanInitialRealizedProfit() {
   g_vRealizedProfit = 0.0;
   if(!HistorySelect(0, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++) {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      g_vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) return;
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;
   g_vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                      + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                      + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
}

double GetVirtualBalance() {
   if(!InpCombineMode) return AccountInfoDouble(ACCOUNT_BALANCE);
   return InpActiveBase + g_vRealizedProfit;
}

double GetVirtualEquity() {
   if(!InpCombineMode) return AccountInfoDouble(ACCOUNT_EQUITY);
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return GetVirtualBalance() + floating;
}

//+------------------------------------------------------------------+
//  MANUAL DCA — Cumulative Total + Global Variable Delta Guard (Fix L, sync กับ USDJPY v1.4) |
//+------------------------------------------------------------------+
string GVName_DCA() {
   return "9AU_DCA_APPLIED_" + IntegerToString(InpMagicNumber);
}

void ApplyDCAIfNeeded() {
   string gv = GVName_DCA();
   double lastApplied = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   double delta = InpDCAtoAdd - lastApplied;
   if(MathAbs(delta) < 0.01) return;

   g_vRealizedProfit += delta;
   GlobalVariableSet(gv, InpDCAtoAdd);
   Print("[DCA] Gold Applied Delta=$", DoubleToString(delta,2),
         " | Cumulative Target=$", DoubleToString(InpDCAtoAdd,2),
         " | New VBal=$", DoubleToString(GetVirtualBalance(),2));
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD DCA APPLIED | Delta=$" + DoubleToString(delta,2)
                   + " | Cumulative=$" + DoubleToString(InpDCAtoAdd,2)
                   + " | New VBal=$" + DoubleToString(GetVirtualBalance(),2));
}

void DrawDCALabel() {
   string name = "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber);
   double applied = GlobalVariableCheck(GVName_DCA()) ? GlobalVariableGet(GVName_DCA()) : 0.0;
   string txt = StringFormat("GOLD(%d) DCA Cumulative=$%.2f | VBase=$%.2f | VBal=$%.2f",
                              InpMagicNumber, applied, InpActiveBase, GetVirtualBalance());
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 40);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

//+------------------------------------------------------------------+
//  INIT / DEINIT
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);

   // Fix P: สร้าง indicator handle ครั้งเดียวใน OnInit() — ไม่สร้างซ้ำใน GetRSI/GetATR/GetEMA/GetADX
   g_hRSI    = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_hATR    = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   g_hEMA200 = iMA(_Symbol, InpFilterTF, InpTrendEMA,    0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50  = iMA(_Symbol, InpFilterTF, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
   g_hADX    = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   if(g_hRSI    == INVALID_HANDLE ||
      g_hATR    == INVALID_HANDLE ||
      g_hEMA200 == INVALID_HANDLE ||
      g_hEMA50  == INVALID_HANDLE ||
      g_hADX    == INVALID_HANDLE) {
      Print("[INIT FAILED] Indicator handle creation error. Err=", GetLastError());
      return INIT_FAILED;
   }

   // Combine Mode — กู้คืน Realized P/L สะสมเฉพาะ Magic นี้จาก History (per-Magic isolation)
   ScanInitialRealizedProfit();
   ApplyDCAIfNeeded();
   DrawDCALabel();
   if(InpCombineMode)
      Print("[COMBINE] RealizedProfit(this Magic)=", DoubleToString(g_vRealizedProfit,2),
            " | ActiveBase=", DoubleToString(InpActiveBase,2));

   double vBal   = GetVirtualBalance();
   peakEquity    = GetVirtualEquity();
   dayStartBalance = vBal;
   dayLowestEquity = vBal;
   last2xLevel   = (int)MathFloor(vBal / InpBaseBalance);
   if(last2xLevel < 1) last2xLevel = 1;

   // Determine starting lot mode
   currentLotMode   = (vBal >= InpBaseBalance * InpCompoundStartMultiple && InpEnableCompound)
                      ? LOT_COMPOUND : LOT_FIXED;
   compoundHWM       = (currentLotMode == LOT_COMPOUND) ? vBal : 0.0;
   houseMoneyAlerted = false;

   Print("=== 9AU_GOLD v19.11 | Mode=", (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"),
         " | CombineMode=", InpCombineMode ? "ON" : "OFF",
         " | VBal=$", DoubleToString(vBal,2),
         " | Target=", InpHouseMoneyTarget, "x",
         " | MaxDD=", InpMaxDrawdownPercent, "%",
         " | MomPause=", InpEnableMomentumPause?"ON":"OFF",
         " (", InpMomentumBars, "bars/", InpMomentumPct, "%) ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD v19.11 Started | " + _Symbol
                   + " | CombineMode=" + (InpCombineMode ? "ON" : "OFF")
                   + " | VBal $" + DoubleToString(vBal,2)
                   + " | ActiveBase $" + DoubleToString(InpActiveBase,0)
                   + " | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED")
                   + " | Target $" + DoubleToString(InpBaseBalance*InpHouseMoneyTarget,0)
                   + " | MomPause " + (InpEnableMomentumPause?"ON":"OFF")
                   + " " + IntegerToString(InpMomentumBars) + "bars/"
                   + DoubleToString(InpMomentumPct,1) + "%");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, "HM_");   // ลบ label ทั้งหมด
   ObjectDelete(0, "9AU_DCA_LABEL_" + IntegerToString(InpMagicNumber));
   // Fix P: release global indicator handles เพื่อคืน resource ให้ MT5
   if(g_hRSI    != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   if(g_hATR    != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hEMA200 != INVALID_HANDLE) IndicatorRelease(g_hEMA200);
   if(g_hEMA50  != INVALID_HANDLE) IndicatorRelease(g_hEMA50);
   if(g_hADX    != INVALID_HANDLE) IndicatorRelease(g_hADX);
   Print("=== 9AU_GOLD v19.11 Stopped. Reason=", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD v19.11 Stopped | Reason=" + IntegerToString(reason)
                   + " | VBal $" + DoubleToString(GetVirtualBalance(),2));
}

//+------------------------------------------------------------------+
//  HOUSE MONEY: Label กระพริบ + Telegram
//+------------------------------------------------------------------+
void DrawBlinkLabel(string name, string text, color clr, int x, int y) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   }
   // กระพริบโดย toggle สี
   static bool blink = false;
   blink = !blink;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, blink ? clr : clrBlack);
   ChartRedraw();
}

void CheckHouseMoney() {
   if(!InpEnableHouseMoney) return;
   double bal = GetVirtualBalance();
   double target = InpBaseBalance * InpHouseMoneyTarget;
   if(bal < target) {
      // ลบ label ถ้า balance ตกลงมา (เช่นหลัง withdrawal)
      ObjectDelete(0, "HM_LABEL");
      houseMoneyAlerted = false;
      return;
   }

   // วาด label กระพริบทุก tick
   string txt = "*** HOUSE MONEY REACHED $" + DoubleToString(bal,2)
                + " | WITHDRAW $" + DoubleToString(bal - InpBaseBalance,2)
                + " THEN RESET EA ***";
   DrawBlinkLabel("HM_LABEL", txt, clrYellow, 10, 30);

   // Telegram แจ้งเตือนครั้งแรก และทุก 1 ชั่วโมง
   datetime now = TimeCurrent();
   if(!houseMoneyAlerted || (now - lastHouseAlert) > 3600) {
      string msg = "*** HOUSE MONEY ALERT 9AU_GOLD ***"
                   + " | Balance $" + DoubleToString(bal,2)
                   + " (Target $" + DoubleToString(target,2) + " reached!)"
                   + " | PROFIT $" + DoubleToString(bal - InpBaseBalance,2)
                   + " | ACTION: Withdraw $" + DoubleToString(bal - InpBaseBalance,2)
                   + " then Reset EA with $" + DoubleToString(InpBaseBalance,0)
                   + " | OR: Enable Compound Mode auto-activates"
                   + " | " + _Symbol + " " + TimeToString(now, TIME_DATE|TIME_MINUTES);
      TelegramSend(msg);
      houseMoneyAlerted = true;
      lastHouseAlert    = now;
      Print("[HOUSE MONEY] Target reached! Balance=", DoubleToString(bal,2));
   }
}

//+------------------------------------------------------------------+
//  v19.5 Fix O (CRITICAL): แยก Auto-Compound-Activation ออกจาก        |
//  CheckHouseMoney() — เดิมโค้ดนี้ฝังอยู่ข้างใน CheckHouseMoney()   |
//  ซึ่งมี Early Return 2 ชั้น (!InpEnableHouseMoney และ              |
//  bal<HouseMoneyTarget) ทำให้ currentLotMode ไม่เคยเปลี่ยนจาก       |
//  LOT_FIXED เป็น LOT_COMPOUND เลยตราบใดที่ HouseMoney=false —       |
//  Fix N ที่แก้ GetSniperLot/GetSellSniperLot/SoftBrake ก่อนหน้านี้  |
//  จึงยังไม่มีผลจริง เพราะ currentLotMode ค้างที่ LOT_FIXED ตลอดกาล |
//  ฟังก์ชันนี้ต้องรันอิสระทุก Tick ไม่ขึ้นกับ House Money เลย        |
//+------------------------------------------------------------------+
void UpdateCompoundState() {
   if(!InpEnableCompound) return;
   double bal = GetVirtualBalance();

   // Auto-switch to Compound mode เมื่อ balance > Base x InpCompoundStartMultiple
   double compoundThresh = InpBaseBalance * InpCompoundStartMultiple;
   if(currentLotMode == LOT_FIXED && bal >= compoundThresh) {
      currentLotMode = LOT_COMPOUND;
      compoundHWM    = bal;   // set HWM เริ่มต้น
      Print("[COMPOUND] Mode activated at Balance=$", DoubleToString(bal,2),
            " | HWM=$", DoubleToString(compoundHWM,2));
      if(InpEnableTelegram)
         TelegramSend("9AU_GOLD COMPOUND MODE ON | Balance $" + DoubleToString(bal,2)
                      + " | HWM $" + DoubleToString(compoundHWM,2)
                      + " | MaxLot=" + DoubleToString(InpCompoundMaxLot,2));
   }
   // Update HWM เมื่อ balance ทำ new high
   if(currentLotMode == LOT_COMPOUND && bal > compoundHWM) {
      compoundHWM = bal;
      Print("[HWM] New High $", DoubleToString(compoundHWM,2));
   }
}

//+------------------------------------------------------------------+
//  Fix V: HIGH VOLATILITY BRAKE — ATR Spike Guard for Compound Lot  |
//  เรียกทุก New Bar หลัง GetATR() ได้ค่าแล้ว                         |
//  Logic: ATR_current > AvgATR(50) × InpHighVolATRMult → brake ON   |
//  ↓ Compound lot จะถูก cap ที่ InpHighVolMaxLot ใน GetSniperLot()   |
//  ↓ brake OFF อัตโนมัติเมื่อ ATR กลับสู่ < InpHighVolATRMult        |
//  Telegram alert ทั้ง ON และ OFF เพื่อ audit trail ที่ชัดเจน        |
//+------------------------------------------------------------------+
void UpdateHighVolBrake(double atr) {
   if(!InpEnableCompound) return;          // ไม่จำเป็นถ้าไม่ได้ใช้ Compound
   if(currentLotMode != LOT_COMPOUND) return; // ทำงานเฉพาะ Compound mode
   double avgATR = GetAvgATR();
   if(avgATR <= 0) return;
   bool spike = (atr > avgATR * InpHighVolATRMult);

   if(spike && !g_highVolBrake) {
      g_highVolBrake = true;
      Print("[HIGH VOL BRAKE ON] ATR=", DoubleToString(atr,2),
            " AvgATR=", DoubleToString(avgATR,2),
            " Ratio=", DoubleToString(atr/avgATR,2), "x (threshold=", InpHighVolATRMult, "x)",
            " -> Compound lot capped at ", InpHighVolMaxLot);
      if(InpEnableTelegram)
         TelegramSend("9AU_GOLD HIGH VOL BRAKE ON | ATR=" + DoubleToString(atr,2)
                      + " > AvgATR×" + DoubleToString(InpHighVolATRMult,1)
                      + " (" + DoubleToString(atr/avgATR,2) + "x)"
                      + " | Compound lot capped at " + DoubleToString(InpHighVolMaxLot,2)
                      + " | Balance $" + DoubleToString(GetVirtualBalance(),2));
   } else if(!spike && g_highVolBrake) {
      g_highVolBrake = false;
      Print("[HIGH VOL BRAKE OFF] ATR=", DoubleToString(atr,2),
            " normalised below ", InpHighVolATRMult, "x AvgATR=", DoubleToString(avgATR,2));
      if(InpEnableTelegram)
         TelegramSend("9AU_GOLD HIGH VOL BRAKE OFF | ATR normalised"
                      + " | ATR=" + DoubleToString(atr,2)
                      + " AvgATR=" + DoubleToString(avgATR,2)
                      + " | Compound lot restored | Balance $" + DoubleToString(GetVirtualBalance(),2));
   }
}

//+------------------------------------------------------------------+
//  Fix W: MOMENTUM PAUSE FILTER — Upstream Entry Gate               |
//  ตรวจ % price move ใน InpMomentumBars ล่าสุด ทุก New Bar          |
//  ถ้าเกิน InpMomentumPct% → ยับยั้ง entry ใหม่ทั้งหมด             |
//  Positions ที่เปิดอยู่ยังถูก manage ปกติ (trail/basket/SL)         |
//  ปลด pause อัตโนมัติเมื่อ momentum กลับสู่ normal                  |
//  Logic ใช้ bar 1 (last CLOSED bar) — consistent กับ entry filter   |
//+------------------------------------------------------------------+
bool IsMomentumPause() {
   if(!InpEnableMomentumPause) return false;
   if(InpMomentumBars < 2)     return false;
   double closeRecent = iClose(_Symbol, PERIOD_CURRENT, 1);
   double closeN      = iClose(_Symbol, PERIOD_CURRENT, InpMomentumBars);
   if(closeN <= 0 || closeRecent <= 0) return false;
   double pctMove = MathAbs(closeRecent - closeN) / closeN * 100.0;
   return (pctMove > InpMomentumPct);
}

void UpdateMomentumPause() {
   if(!InpEnableMomentumPause) return;

   // คำนวณ direction และ %move เพื่อ log/alert (ทุก call ไม่ใช่แค่ตอน state change)
   double closeRecent = iClose(_Symbol, PERIOD_CURRENT, 1);
   double closeN      = iClose(_Symbol, PERIOD_CURRENT, InpMomentumBars);
   double pctMove     = (closeN > 0) ? MathAbs(closeRecent - closeN) / closeN * 100.0 : 0.0;
   string direction   = (closeRecent >= closeN) ? "UP" : "DOWN";

   bool pause = IsMomentumPause();

   if(pause && !g_momentumPause) {
      // --- PAUSE ON ---
      g_momentumPause = true;
      Print("[MOMENTUM PAUSE ON] ", direction, " ", DoubleToString(pctMove,2), "% in ",
            InpMomentumBars, " bars (threshold=", InpMomentumPct, "%)",
            " | Close[1]=", DoubleToString(closeRecent,2),
            " Close[", InpMomentumBars, "]=", DoubleToString(closeN,2),
            " | No new entries until momentum normalises");
      if(InpEnableTelegram)
         TelegramSend("9AU_GOLD MOMENTUM PAUSE ON | " + direction
                      + " " + DoubleToString(pctMove,2) + "% in "
                      + IntegerToString(InpMomentumBars) + " bars"
                      + " (threshold=" + DoubleToString(InpMomentumPct,1) + "%)"
                      + " | All new entries suspended"
                      + " | Balance $" + DoubleToString(GetVirtualBalance(),2));

   } else if(!pause && g_momentumPause) {
      // --- PAUSE OFF ---
      g_momentumPause = false;
      Print("[MOMENTUM PAUSE OFF] ", direction, " ", DoubleToString(pctMove,2), "%",
            " normalised below ", InpMomentumPct, "% threshold | Entries resumed");
      if(InpEnableTelegram)
         TelegramSend("9AU_GOLD MOMENTUM PAUSE OFF | " + direction
                      + " " + DoubleToString(pctMove,2) + "% normalised"
                      + " | Entries resumed"
                      + " | Balance $" + DoubleToString(GetVirtualBalance(),2));
   }
}

//+------------------------------------------------------------------+
//  COMPOUND LOT CALCULATION
//+------------------------------------------------------------------+
double GetSniperLot() {
   // v19.4 Fix N: เดิมผูก Compound ไว้กับ InpEnableHouseMoney ผิด (|| !InpEnableHouseMoney)
   // ทำให้ Production Default HM=FALSE ปัจจุบัน ล็อก Fixed Lot ตลอด ไม่ Compound เลย
   // ทั้งที่ InpEnableCompound=true — currentLotMode เองเพียงพอแล้ว (คุมด้วย InpEnableCompound
   // ที่ line 409 อยู่แล้ว) จึงตัดเงื่อนไข HouseMoney ออก ให้ Compound เป็นอิสระจาก House Money
   // เหมือน EA อีก 6 ตัวในพอร์ต
   if(currentLotMode == LOT_FIXED)
      return InpInitialLot;
   // Compound Brake (DD-based): ถ้า equity DD > SoftBrake ให้ใช้ Fixed lot ชั่วคราว
   if(compoundBrake) return InpInitialLot;
   // HWM-based compound: scale จาก peak Virtual Balance ไม่ใช่ equity ปัจจุบัน
   double bal   = GetVirtualBalance();
   double basis = MathMin(bal, compoundHWM);   // ใช้ค่าต่ำกว่าระหว่าง balance กับ HWM
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot   = InpInitialLot * (basis / InpBaseBalance);
   lot = NormalizeDouble(lot, 2);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, minL);
   lot = MathMin(lot, InpCompoundMaxLot);
   // Fix V: High Volatility Brake — cap lot ก่อน DD ก่อตัว (upstream guard)
   // ทำงานหลัง InpCompoundMaxLot เพื่อ cap ลงอีกชั้นหนึ่งในช่วง ATR spike
   if(g_highVolBrake && lot > InpHighVolMaxLot) {
      Print("[HIGH VOL BRAKE] BUY lot capped: ", DoubleToString(lot,2),
            " -> ", InpHighVolMaxLot);
      lot = InpHighVolMaxLot;
   }
   Print("[COMPOUND LOT] Basis=$", DoubleToString(basis,2),
         " HWM=$", DoubleToString(compoundHWM,2),
         " Lot=", DoubleToString(lot,2),
         " HighVolBrake=", g_highVolBrake ? "ON" : "OFF");
   return lot;
}

double GetSellSniperLot() {
   if(currentLotMode == LOT_FIXED)
      return InpSellInitialLot;
   if(compoundBrake) return InpSellInitialLot;
   double bal   = GetVirtualBalance();
   double basis = MathMin(bal, compoundHWM);
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot   = InpSellInitialLot * (basis / InpBaseBalance);
   lot = NormalizeDouble(lot, 2);
   if(step > 0) lot = MathRound(lot / step) * step;
   lot = MathMax(lot, minL);
   lot = MathMin(lot, InpCompoundMaxLot);
   // Fix V: High Volatility Brake — cap Sell lot เช่นเดียวกับ Buy
   if(g_highVolBrake && lot > InpHighVolMaxLot) {
      Print("[HIGH VOL BRAKE] SELL lot capped: ", DoubleToString(lot,2),
            " -> ", InpHighVolMaxLot);
      lot = InpHighVolMaxLot;
   }
   return lot;
}

//+------------------------------------------------------------------+
//  UTILITY
//+------------------------------------------------------------------+
bool IsNewBar() {
   static datetime lastBar = 0;
   datetime cur = iTime(_Symbol, PERIOD_M5, 0);
   if(cur != lastBar) { lastBar = cur; return true; }
   return false;
}

bool IsTradingTimeAllowed() {
   if(!EnableTimeFilter) return true;
   MqlDateTime dt;
   TimeLocal(dt);
   int hour = dt.hour;
   int dow  = dt.day_of_week;
   if(dow >= 1 && dow <= 4)
      return (hour >= TradingStartHour || hour < TradingEndHour);
   if(dow == 5) {
      if(StopFridayAfterClose) return (hour >= TradingStartHour && hour < FridayCloseHour);
      return (hour >= TradingStartHour || hour < TradingEndHour);
   }
   return false;
}

bool IsMinHoldPassed(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return true;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   return (Bars(_Symbol, PERIOD_M5, openTime, TimeCurrent()) >= InpMinHoldBars);
}

//+------------------------------------------------------------------+
//  DD
//+------------------------------------------------------------------+
bool CheckEquityStop() {
   if(!InpEnableEquityStop) return false;
   double bal    = GetVirtualBalance();
   double equity = GetVirtualEquity();
   if(bal <= 0) return false;
   double dd = (bal - equity) / bal * 100.0;

   // Soft Brake: ถ้า DD > InpCompoundDDSoftBrake ใน Compound mode -> ลด lot กลับ Fixed ชั่วคราว
   // v19.4 Fix N: ตัด && InpEnableHouseMoney ออก — SoftBrake ต้องทำงานทุกครั้งที่ Compound Active
   // ไม่ว่า House Money จะเปิดหรือปิด (เดิมถ้า HM=FALSE จะปิด SoftBrake ไปด้วยโดยไม่ตั้งใจ)
   if(currentLotMode == LOT_COMPOUND) {
      if(dd >= InpCompoundDDSoftBrake && !compoundBrake) {
         compoundBrake = true;
         Print("[COMPOUND BRAKE] DD=", DoubleToString(dd,2), "% >= SoftBrake=",
               InpCompoundDDSoftBrake, "% -> Lot capped to Fixed temporarily");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD COMPOUND BRAKE ON | DD=" + DoubleToString(dd,2)
                         + "% | Lot=FIXED until DD recovers | Balance $" + DoubleToString(bal,2));
      } else if(dd < InpCompoundDDSoftBrake * 0.75 && compoundBrake) {
         // ปลด brake เมื่อ DD ฟื้นกลับมา 75% ของ SoftBrake threshold
         compoundBrake = false;
         Print("[COMPOUND BRAKE] Released at DD=", DoubleToString(dd,2), "%");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD COMPOUND BRAKE OFF | DD=" + DoubleToString(dd,2)
                         + "% | Lot=COMPOUND restored | Balance $" + DoubleToString(bal,2));
      }
      // Kill Switch Compound: ใช้ InpCompoundMaxDD (กว้างกว่า)
      if(dd >= InpCompoundMaxDD) {
         Print("[KILL COMPOUND] DD=", DoubleToString(dd,2), "% >= ", InpCompoundMaxDD, "%");
         CloseAll("Kill Switch COMPOUND DD=" + DoubleToString(dd,2) + "%");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD KILL SWITCH COMPOUND | DD=" + DoubleToString(dd,2)
                         + "% | Balance $" + DoubleToString(bal,2)
                         + " | EA REMOVED from " + _Symbol);
         ExpertRemove();
         return true;
      }
   } else {
      // Fixed mode: ใช้ InpMaxDrawdownPercent ปกติ
      if(dd >= InpMaxDrawdownPercent) {
         Print("[KILL] DD=", DoubleToString(dd,2), "% >= ", InpMaxDrawdownPercent, "%");
         CloseAll("Kill Switch DD=" + DoubleToString(dd,2) + "%");
         if(InpEnableTelegram)
            TelegramSend("9AU_GOLD KILL SWITCH | DD=" + DoubleToString(dd,2)
                         + "% | Balance $" + DoubleToString(bal,2)
                         + " | EA REMOVED from " + _Symbol);
         ExpertRemove();
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//  DAILY LOSS
//+------------------------------------------------------------------+
void UpdateDailyLoss() {
   datetime today = TimeCurrent() / 86400 * 86400;
   if(today != currentDay) {
      currentDay       = today;
      dayStartBalance  = GetVirtualBalance();
      dayLowestEquity  = dayStartBalance;
      dailyLossPercent = 0.0;
      dailyLossClosed  = false;
      partialDone      = false;
      partialDoneSell  = false;
   }
   double equity = GetVirtualEquity();
   if(equity < dayLowestEquity) {
      dayLowestEquity  = equity;
      dailyLossPercent = (dayStartBalance > 0)
                         ? (dayStartBalance - dayLowestEquity) / dayStartBalance * 100.0
                         : 0.0;
   }
}

bool IsDailyLossExceeded() {
   if(!EnableDailyLossLimit) return false;
   return (dailyLossPercent >= MaxDailyLossPercent);
}

//+------------------------------------------------------------------+
//  ALERTS
//+------------------------------------------------------------------+
void CheckDDAlert() {
   if(!InpEnableTelegram) return;
   double bal    = GetVirtualBalance();
   double equity = GetVirtualEquity();
   if(bal <= 0) return;
   double dd = (bal - equity) / bal * 100.0;
   if(dd < InpTelegramDDAlert) { ddAlertSent = false; return; }
   datetime now = TimeCurrent();
   if(ddAlertSent && (now - lastDDAlertTime) < 3600) return;
   TelegramSend("9AU_GOLD DD Alert " + DoubleToString(dd,2)
                + "% | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED")
                + " | Equity $" + DoubleToString(equity,2));
   ddAlertSent     = true;
   lastDDAlertTime = now;
}

void Check2xBalance() {
   if(!InpEnable2xAlert || !InpEnableTelegram) return;
   double bal   = GetVirtualBalance();
   int    cur2x = (int)MathFloor(bal / InpBaseBalance);
   if(cur2x <= last2xLevel) return;
   last2xLevel = cur2x;
   TelegramSend("MILESTONE 9AU_GOLD | Balance $" + DoubleToString(bal,2)
                + " (" + IntegerToString(cur2x) + "x BaseBalance)"
                + " | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
}

//+------------------------------------------------------------------+
//  INDICATORS
//+------------------------------------------------------------------+
double GetRSI() {
   // Fix P: ใช้ global handle g_hRSI แทนการสร้างใหม่ทุก call
   double buf[1];
   if(g_hRSI == INVALID_HANDLE) return 50.0;
   if(CopyBuffer(g_hRSI, 0, 0, 1, buf) > 0) return buf[0];
   return 50.0;
}

double GetATR() {
   // Fix P: ใช้ global handle g_hATR แทนการสร้างใหม่ทุก call
   double buf[1];
   if(g_hATR == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_hATR, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetEMA(int period = 200, int shift = 0) {
   // Fix P: route ไปยัง global handle ตาม period — ไม่สร้าง handle ใหม่
   double buf[1];
   int h = (period == InpEMA50Period) ? g_hEMA50 : g_hEMA200;
   if(h == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(h, 0, shift, 1, buf) > 0) return buf[0];
   return 0.0;
}

double GetADX() {
   // Fix P: ใช้ global handle g_hADX แทนการสร้างใหม่ทุก call
   double buf[1];
   if(g_hADX == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_hADX, 0, 0, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//  SELL REGIME
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Average ATR (baseline volatility over InpAvgATRPeriod bars)
double GetAvgATR() {
   // Fix P: ใช้ global handle g_hATR (period เดียวกัน) แทนการสร้าง handle ใหม่
   double buf[];
   if(g_hATR == INVALID_HANDLE) return 0.0;
   ArrayResize(buf, InpAvgATRPeriod);
   if(CopyBuffer(g_hATR, 0, 0, InpAvgATRPeriod, buf) < InpAvgATRPeriod) return 0.0;
   double sum = 0;
   for(int i = 0; i < InpAvgATRPeriod; i++) sum += buf[i];
   return sum / InpAvgATRPeriod;
}

// Resistance level = highest high over InpResistLookback M5 bars
double GetResistanceLevel() {
   double hi[];
   ArrayResize(hi, InpResistLookback);
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, InpResistLookback, hi) < InpResistLookback) return 0.0;
   double highest = hi[0];
   for(int i = 1; i < InpResistLookback; i++)
      if(hi[i] > highest) highest = hi[i];
   return highest;
}

bool IsTrendDown(double atr, double closePrice) {
   double adx     = GetADX();
   double ema200  = GetEMA(InpTrendEMA, 0);
   double ema200p = GetEMA(InpTrendEMA, InpEMASlopeLookback);
   double ema50   = GetEMA(InpEMA50Period, 0);
   double slope   = ema200 - ema200p;
   double rsi     = GetRSI();
   // Layer 3: ATR volatility filter - Sell only in volatile market
   double avgATR    = GetAvgATR();
   bool   atrOk     = (avgATR > 0) && (atr >= avgATR * InpSellMinATRMult);

   // Layer 4: Resistance filter - price must be below recent swing high - buffer
   double resist    = GetResistanceLevel();
   bool   resistOk  = (resist > 0) && (closePrice < resist * (1.0 - InpResistBuffer));

   // Fix S: EMA50<200 เปลี่ยนจาก optional bonus เป็น hard requirement
   // เดิม: EMA50<200 OR (ADX > 42) → ADX สูงใน Gold uptrend ทำให้ผ่าน OR branch
   // ขณะที่ structure ยัง Bullish (EMA50>200) → false Sell signals (เห็นชัดใน Aug 4, 2026)
   // ใหม่: ต้องผ่านทั้ง EMA50<200 AND ADX > threshold — เข้มขึ้น ลด false signal
   bool ema50Bearish = (ema50 < ema200);   // Fix S: บังคับเป็น hard requirement แล้ว
   bool ok = (adx > InpADXTrendHigh)
             && (slope < -(atr * InpEMASlopeATRMult))
             && (closePrice < ema200)
             && (rsi >= InpRSITrendLow && rsi <= InpRSITrendHigh)
             && atrOk         // Layer 3: volatile market
             && resistOk      // Layer 4: below resistance
             && ema50Bearish; // Fix S: AND (ไม่ใช่ OR) — ต้องผ่านทั้ง EMA50<EMA200

   if(InpDiagnosticLog)
      Print("[SELL REGIME] ADX=", DoubleToString(adx,1),
            " Slope=", DoubleToString(slope,2),
            " EMA50<200=", (ema50<ema200),
            " RSI=", DoubleToString(rsi,1),
            " ATR=", DoubleToString(atr,2), "/AvgATR=", DoubleToString(avgATR,2),
            " ATR_OK=", atrOk,
            " Resist=", DoubleToString(resist,2), " ResistOK=", resistOk,
            " -> ", ok ? "TREND_DOWN" : "no");
   return ok;
}

//+------------------------------------------------------------------+
//  BASKET
//+------------------------------------------------------------------+
void UpdateBasketInfo() {
   basket.buyCount = basket.sellCount = 0;
   basket.totalProfit = basket.totalLots = 0;
   basket.lastBuyPrice = basket.lastSellPrice = 0;
   basket.lastBuyLot   = basket.lastSellLot   = 0;
   basket.oldestOpenTime = TimeCurrent() + 86400*365;
   buyBasketProfit  = 0.0;
   sellBasketProfit = 0.0;
   datetime oldest  = TimeCurrent() + 86400*365;

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      double lot    = PositionGetDouble(POSITION_VOLUME);
      double price  = PositionGetDouble(POSITION_PRICE_OPEN);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime oT   = (datetime)PositionGetInteger(POSITION_TIME);
      basket.totalProfit += profit;
      basket.totalLots   += lot;
      if(oT < oldest) oldest = oT;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         basket.buyCount++;
         basket.lastBuyLot   = lot;
         basket.lastBuyPrice = price;
         buyBasketProfit    += profit;
      } else {
         basket.sellCount++;
         basket.lastSellLot   = lot;
         basket.lastSellPrice = price;
         sellBasketProfit    += profit;
      }
   }
   basket.oldestOpenTime = (basket.buyCount+basket.sellCount > 0) ? oldest : 0;
}

//+------------------------------------------------------------------+
//  LOT
//+------------------------------------------------------------------+
double CalculateSmartLot(int count, double lastLot,
                          double baseM, double redStep, double minM) {
   double m   = baseM - (count * redStep);
   if(m < minM) m = minM;
   double lot  = NormalizeDouble(lastLot * m, 2);
   double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(stp > 0) lot = MathRound(lot / stp) * stp;
   lot = MathMax(lot, minL);
   lot = MathMin(lot, maxL);
   return lot;
}

//+------------------------------------------------------------------+
//  EXPOSURE
//+------------------------------------------------------------------+
bool IsExposureSafe() {
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(ml <= 0) return true;
   if(ml < InpMinMarginLevel) { Print("[SKIP BUY] Margin Level=", DoubleToString(ml,2)); return false; }
   return true;
}

bool IsExposureSafeSell() {
   double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(ml <= 0) return true;
   if(ml < InpMinMarginLevel) { Print("[SKIP SELL] Margin Level=", DoubleToString(ml,2)); return false; }
   double bal    = GetVirtualBalance();
   double maxExp = bal * (InpMaxExposurePercent * 0.5) / 100.0;
   double cSz    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double bidPx  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sellLots = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         sellLots += PositionGetDouble(POSITION_VOLUME);
   }
   if(sellLots * cSz * bidPx > maxExp) { Print("[SKIP SELL] Sell exposure exceeded"); return false; }
   return true;
}

//+------------------------------------------------------------------+
//  SL / TRAIL
//+------------------------------------------------------------------+
void SetHardSL(ulong ticket, double atr, double mult) {
   if(!PositionSelectByTicket(ticket)) return;
   double curSL  = PositionGetDouble(POSITION_SL);
   double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double dist = atr * mult;
   if(ptype == POSITION_TYPE_BUY) {
      double newSL = NormalizeDouble(openPx - dist, _Digits);
      if(curSL == 0 || newSL > curSL) {
         trade.PositionModify(ticket, newSL, 0);
         Print("[SL BUY] Ticket=", ticket, " SL=", DoubleToString(newSL,_Digits));
      }
   } else {
      double newSL = NormalizeDouble(openPx + dist, _Digits);
      if(curSL == 0 || newSL < curSL) {
         trade.PositionModify(ticket, newSL, 0);
         Print("[SL SELL] Ticket=", ticket, " SL=", DoubleToString(newSL,_Digits));
      }
   }
}

void ApplyHardSLAll(double atr) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetDouble(POSITION_SL) != 0) continue;
      double mult = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                    ? InpHardSLMultiplier : InpSellHardSLMultiplier;
      SetHardSL(t, atr, mult);
   }
}

void TrailBasket(double atr) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Buy trail
   if(basket.totalProfit >= InpTrailStartUSD) {
      double dist = atr * InpTrailStepATR;
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
         if(!IsMinHoldPassed(t)) continue;
         double curSL = PositionGetDouble(POSITION_SL);
         double newSL = NormalizeDouble(bid - dist, _Digits);
         if(newSL > curSL) trade.PositionModify(t, newSL, 0);
      }
   }

   // Sell trail (tighter)
   if(sellBasketProfit >= InpSellTrailStartUSD) {
      double dist = atr * InpSellTrailStepATR;
      for(int i = PositionsTotal()-1; i >= 0; i--) {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
         if(!IsMinHoldPassed(t)) continue;
         double curSL = PositionGetDouble(POSITION_SL);
         double newSL = NormalizeDouble(ask + dist, _Digits);
         if(curSL == 0 || newSL < curSL) trade.PositionModify(t, newSL, 0);
      }
   }
}

//+------------------------------------------------------------------+
//  BASKET CLOSE
//+------------------------------------------------------------------+
void CloseAll(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE ALL: ", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD CLOSE ALL | " + reason
                   + " | VBal $" + DoubleToString(GetVirtualBalance(),2));
}

void CloseAllBuy(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE BUY: ", reason, " ===");
   if(InpEnableTelegram)
      TelegramSend("9AU_GOLD BUY CLOSED | " + reason
                   + " | VBal $" + DoubleToString(GetVirtualBalance(),2));
}

void CloseAllSell(string reason) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      trade.PositionClose(t);
   }
   Print("=== CLOSE SELL: ", reason, " ===");
}

void PartialCloseBasket() {
   if(!InpEnablePartialClose || partialDone) return;
   if(basket.totalProfit < InpBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / stp) * stp;
      if(half >= minL) trade.PositionClosePartial(t, half);
   }
   partialDone = true;
   Print("[PARTIAL BUY] Done at ", DoubleToString(InpPartialCloseLevel*100,0), "% of TP");
}

void PartialCloseBasketSell() {
   if(!InpEnablePartialClose || partialDoneSell) return;
   if(sellBasketProfit < InpSellBasketTP * InpPartialCloseLevel) return;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
      if(!IsMinHoldPassed(t)) continue;
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double half = NormalizeDouble(vol * 0.5, 2);
      half = MathRound(half / stp) * stp;
      if(half >= minL) trade.PositionClosePartial(t, half);
   }
   partialDoneSell = true;
}

//+------------------------------------------------------------------+
//  TIME EXIT & NEWS
//+------------------------------------------------------------------+
void CheckTimeExit() {
   if(basket.oldestOpenTime == 0) return;
   if(TimeCurrent() - basket.oldestOpenTime > InpMaxHoldDays * 86400)
      CloseAll("MaxHoldDays exceeded");
}

void UpdateNewsCalendar() {
   datetime from = TimeCurrent();
   ArrayFree(TodayEvents);
   CalendarValueHistory(TodayEvents, from, from + 86400*3);
   lastNewsUpdate = TimeCurrent();
}

bool IsNewsWindowActive() {
   if(!EnableNewsFilter) return false;
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(TodayEvents); i++) {
      MqlCalendarEvent   ev;
      MqlCalendarCountry cntry;
      if(!CalendarEventById(TodayEvents[i].event_id, ev)) continue;
      if(!CalendarCountryById(ev.country_id, cntry)) continue;
      if(cntry.currency != "USD") continue;
      if(NewsHighImpactOnly && ev.importance < 3) continue;
      datetime et = TodayEvents[i].time;
      if(now >= et - NewsBeforeMinutes*60 && now <= et + NewsAfterMinutes*60) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//  OnTick
//+------------------------------------------------------------------+
void OnTick() {
   // --- Kill Switch (every tick) ---
   if(CheckEquityStop()) return;

   // --- House Money check (every tick) ---
   CheckHouseMoney();

   // --- Compound State (independent of House Money — Fix O) ---
   UpdateCompoundState();

   // --- Daily management ---
   UpdateDailyLoss();
   CheckDDAlert();
   Check2xBalance();

   // --- Daily Loss CloseAll ---
   // Daily Loss CloseAll - ใช้ limit แคบกว่าใน Compound mode เพื่อปกป้อง HWM
   double closeAllLimit = (currentLotMode == LOT_COMPOUND)
                          ? InpCompoundDailyLossClose
                          : InpDailyLossCloseAllPercent;
   if(EnableDailyLossLimit && !dailyLossClosed && dailyLossPercent >= closeAllLimit) {
      CloseAll("Daily Loss CloseAll " + DoubleToString(dailyLossPercent,2)
               + "% [" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED") + "]");
      dailyLossClosed = true;
      TelegramSend("9AU_GOLD DAILY LOSS CLOSE ALL | " + DoubleToString(dailyLossPercent,2)
                   + "% | Mode=" + (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
      return;
   }

   // --- New bar only ---
   if(!IsNewBar()) return;

   // --- Pre-trade filters ---
   if(EnableTimeFilter && !IsTradingTimeAllowed()) return;
   if(EnableNewsFilter && TimeCurrent() - lastNewsUpdate > 3600) UpdateNewsCalendar();
   if(IsNewsWindowActive()) return;

   double atrVal = GetATR();
   // Fix V: ATR spike guard — cap compound lot ทันที
   UpdateHighVolBrake(atrVal);
   // Fix W: Momentum Pause — ตรวจ %move ก่อน entry logic
   UpdateMomentumPause();

   if(atrVal < InpMinATRThreshold) return;

   long   spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double maxSpread = (atrVal > 100) ? InpMaxSpreadHighVol : InpMaxSpreadBase;
   if(spreadPts > maxSpread) return;

   double rsiVal    = GetRSI();
   double emaVal    = GetEMA(InpTrendEMA, 0);
   double closeBar1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stp       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   UpdateBasketInfo();
   CheckTimeExit();
   ApplyHardSLAll(atrVal);
   TrailBasket(atrVal);

   // Fix W: gate entry — momentum pause ยับยั้งเฉพาะ new entry
   // positions ที่เปิดอยู่ยัง manage ต่อปกติ (trail/basket/SL ทำงานแล้วข้างบน)
   if(g_momentumPause) {
      if(InpDiagnosticLog)
         Print("[MOMENTUM PAUSE] Entry suspended | %move>", InpMomentumPct,
               "% in ", InpMomentumBars, " bars");
      return;
   }

   // ============================================================
   //  BUY BASKET - original v14 logic + Compound Lot
   // ============================================================
   if(rsiVal < InpRSILowerLevel && closeBar1 > emaVal) {
      PartialCloseBasket();
      if(basket.buyCount > 0 && basket.totalProfit >= InpBasketTP) {
         CloseAllBuy("Buy TP=" + DoubleToString(InpBasketTP,2));
         partialDone = false;
         return;
      }

      if(IsDailyLossExceeded()) return;

      double dynDist = InpEnableDynamicGrid
                       ? MathMax(atrVal * InpATRMultiplier, 300.0 * _Point)
                       : 300.0 * _Point;

      if(basket.buyCount == 0) {
         if(IsExposureSafe()) {
            double lot = GetSniperLot();   // Fixed or Compound
            if(stp > 0) lot = MathRound(lot / stp) * stp;
            lot = MathMax(lot, minLot);
            if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_LEADER_GOLD")) {
               Print("[BUY] Sniper Lot=", DoubleToString(lot,2),
                     " Mode=", (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
               // Fix Q: retry loop — รอให้ MT5 register position ก่อน SetHardSL
               ulong tk = trade.ResultOrder();
               if(tk > 0) {
                  bool slSet = false;
                  for(int r = 0; r < 5 && !slSet; r++) {
                     if(PositionSelectByTicket(tk)) { SetHardSL(tk, atrVal, InpHardSLMultiplier); slSet = true; }
                     else Sleep(50);
                  }
                  if(!slSet) Print("[WARN] SetHardSL retry exhausted for BUY ticket=", tk,
                                   " — ApplyHardSLAll will catch on next bar");
               }
            }
         }
      } else if(basket.buyCount < InpMaxOrders) {
         if(ask < basket.lastBuyPrice - dynDist) {
            if(IsExposureSafe()) {
               double lot = CalculateSmartLot(basket.buyCount, basket.lastBuyLot,
                                               InpBaseMultiplier, InpReductionStep, InpMinMultiplier);
               if(stp > 0) lot = MathRound(lot / stp) * stp;
               lot = MathMax(lot, minLot);
               if(trade.Buy(lot, _Symbol, ask, 0, 0, "9AU_LEADER_GOLD")) {
                  Print("[BUY] Grid #", basket.buyCount+1, " Lot=", DoubleToString(lot,2));
                  // Fix Q: retry loop — รอให้ MT5 register position ก่อน SetHardSL
                  ulong tk = trade.ResultOrder();
                  if(tk > 0) {
                     bool slSet = false;
                     for(int r = 0; r < 5 && !slSet; r++) {
                        if(PositionSelectByTicket(tk)) { SetHardSL(tk, atrVal, InpHardSLMultiplier); slSet = true; }
                        else Sleep(50);
                     }
                     if(!slSet) Print("[WARN] SetHardSL retry exhausted for BUY Grid ticket=", tk);
                  }
               }
            }
         }
      }
   }

   // ============================================================
   //  SELL BASKET - TREND_DOWN Regime + Compound Lot
   // ============================================================
   if(!InpEnableSell) return;
   if(basket.buyCount > 0) return;

   if(IsTrendDown(atrVal, closeBar1)) {
      PartialCloseBasketSell();
      if(basket.sellCount > 0 && sellBasketProfit >= InpSellBasketTP) {
         CloseAllSell("Sell TP=" + DoubleToString(InpSellBasketTP,2));
         partialDoneSell = false;
         return;
      }

      if(IsDailyLossExceeded()) return;

      double sellDist = InpEnableDynamicGrid
                        ? MathMax(atrVal * InpSellATRMultiplier, 450.0 * _Point)
                        : 450.0 * _Point;

      if(basket.sellCount == 0) {
         if(IsExposureSafeSell()) {
            double lot = GetSellSniperLot();   // Fixed or Compound
            if(stp > 0) lot = MathRound(lot / stp) * stp;
            lot = MathMax(lot, minLot);
            if(trade.Sell(lot, _Symbol, bid, 0, 0, "9AU_LEADER_GOLD_S")) {
               Print("[SELL] Sniper Lot=", DoubleToString(lot,2),
                     " Mode=", (currentLotMode==LOT_COMPOUND?"COMPOUND":"FIXED"));
               // Fix Q: retry loop — รอให้ MT5 register position ก่อน SetHardSL
               ulong tk = trade.ResultOrder();
               if(tk > 0) {
                  bool slSet = false;
                  for(int r = 0; r < 5 && !slSet; r++) {
                     if(PositionSelectByTicket(tk)) { SetHardSL(tk, atrVal, InpSellHardSLMultiplier); slSet = true; }
                     else Sleep(50);
                  }
                  if(!slSet) Print("[WARN] SetHardSL retry exhausted for SELL ticket=", tk,
                                   " — ApplyHardSLAll will catch on next bar");
               }
            }
         }
      } else if(basket.sellCount < InpSellMaxOrders) {
         if(bid > basket.lastSellPrice + sellDist) {
            if(IsExposureSafeSell()) {
               double lot = CalculateSmartLot(basket.sellCount, basket.lastSellLot,
                                               InpSellBaseMultiplier, InpSellReductionStep, InpSellMinMultiplier);
               if(stp > 0) lot = MathRound(lot / stp) * stp;
               lot = MathMax(lot, minLot);
               if(trade.Sell(lot, _Symbol, bid, 0, 0, "9AU_LEADER_GOLD_S")) {
                  Print("[SELL] Grid #", basket.sellCount+1, " Lot=", DoubleToString(lot,2));
                  // Fix Q: retry loop — รอให้ MT5 register position ก่อน SetHardSL
                  ulong tk = trade.ResultOrder();
                  if(tk > 0) {
                     bool slSet = false;
                     for(int r = 0; r < 5 && !slSet; r++) {
                        if(PositionSelectByTicket(tk)) { SetHardSL(tk, atrVal, InpSellHardSLMultiplier); slSet = true; }
                        else Sleep(50);
                     }
                     if(!slSet) Print("[WARN] SetHardSL retry exhausted for SELL Grid ticket=", tk);
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
