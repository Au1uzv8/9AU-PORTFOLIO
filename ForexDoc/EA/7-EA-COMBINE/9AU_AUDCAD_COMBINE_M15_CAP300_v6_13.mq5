//+------------------------------------------------------------------+
//|                              9AU_AUDCAD_COMBINE_M15_CAP300.mq5   |
//|                                               Consultant: James  |
//|                         Principles: Game Theory + Occam's Razor  |
//|                                 Safety-First + High Performance  |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "6.13"
#property strict
// v6.13 Fix J (CRITICAL): g_virtual_balance เดิมตั้งเป็น Inp_Virtual_Cap ตรงๆ ทุกครั้งที่ OnInit
//        ไม่มี ScanInitialRealizedProfit() เหมือน Gold/OIL-WTI/GBPJPY/USDJPY/3PAIRS ทำให้ Restart EA
//        (VPS Reboot/MT5 Update/Terminal Crash) ล้างกำไร-ขาดทุนสะสมทั้งหมดทิ้ง กระทบ Compound Trigger,
//        Peak Balance/Equity, Kill Switch DD% ทั้งระบบ แก้ด้วย Pattern เดียวกับ EA อื่นทั้งหมด
//        เพิ่ม Inp_DCAtoAdd (Manual DCA, Cumulative Total) + Global Variable Delta Guard + On-Chart Label
// v6.12: เพิ่ม SoftBrake (DD>=15% Brake / DD>=22% Kill) concept เดียวกับ OIL-WTI/GOLD ทุกจุด
//        Compound Active ถาวรเมื่อ Trigger แล้ว คุมความเสี่ยงด้วย Brake แทน Deactivate
//        Lot Scale เปลี่ยนฐานจาก Virtual Balance เป็น Virtual Equity (ตรงกับ OIL/GOLD concept)
// ตั้งชื่อตาม Combine Naming Convention: ไม่เพิ่มเลข Version เพราะไม่มีการปรับค่าเชิงประสิทธิภาพเพิ่มเติม
// (Regime Filter ของ v6.10 เป็นการปรับ Entry Logic ที่มาพร้อม EA เดี่ยวอยู่แล้ว ไม่ใช่การปรับเฉพาะ Combine)
// Version ต้องตรงกับ EA เดี่ยว (9AU_AUDCAD_MEAN_M15_CAP300_v6.10.mq5) เสมอเมื่อ Logic การเทรดเหมือนกัน
// v6.10 Sync Log: อัปเดตจาก Logic v6.8 (มีแค่ Fix G) เป็น v6.10 (มี Fix H+I, Regime Filter บน D1) เพื่อให้
//                 EA เดี่ยวกับ EA Combine ใช้ตรรกะการเข้าไม้ชุดเดียวกันเป๊ะ ต่างกันแค่ Money & Risk Management
// v6.4 Fix A: ย้าย Logic ทั้งหมดจาก OnTimer -> OnTick (OnTimer ไม่แม่นยำใน Strategy Tester)
// v6.4 Fix B: Kill Switch คำนวณ Drawdown จาก Peak Equity แทน Balance ปัจจุบัน (ตรงกับสูตร MT5 Equity DD Maximal)
// v6.5 Fix C (Perf): Throttle Risk Check (CheckDailyReset/UpdatePeaks/Drawdown) ให้รันสูงสุด 1 ครั้ง/วินาที
//                    แทนที่จะรันทุก Tick เพื่อลด Overhead บน Real-Ticks Backtest
// v6.5 Fix D (Logic): Re-arm Peak Equity/Balance หลัง Kill Switch ปิดไม้ทั้งหมด ป้องกัน EA หยุดเทรดถาวร
// v6.6 Fix E (Entry Logic): CheckEntry() ใช้ Shift 0 (แท่งที่ยังไม่ปิด) ในการอ่าน BB/RSI ทำให้สัญญาณ
//                    ขึ้นกับ Tick แรกที่มาถึงพอดีตอนตรวจจับแท่งใหม่ ไม่ Deterministic
//                    เปลี่ยนเป็น Shift 1 (แท่งที่ปิดสมบูรณ์แล้ว) ให้ค่า BB/RSI คงที่ ไม่ขึ้นกับจังหวะ Tick
// v6.7 Fix F (Logic): ApplyMultiPartialClose() ไม่มี State จำว่า Level ไหนถูกปิดไปแล้ว ทำให้ปิดซ้ำ
//                    ทุกครั้งที่ ManageSymbol ถูกเรียก (ทุกแท่ง M15) ตราบใดที่กำไรยังอยู่ในช่วงเดิม
//                    เพิ่ม Flag p1_done/p2_done/p3_done ต่อ Basket ให้แต่ละ Level ปิดได้แค่ครั้งเดียว
// v6.8 Fix G (Combine-Ready): Kill Switch/Peak/Daily-Loss เดิมใช้ AccountInfoDouble(BALANCE/EQUITY)
//                    ซึ่งเป็นค่ารวมทั้งบัญชี ถ้ารันคู่กับ EA อื่น (เช่น BTCUSD Magic 919295) บนบัญชีเดียวกัน
//                    ผลกำไร/ขาดทุนของ EA อื่นจะไป Trigger Kill Switch ของ EA นี้โดยไม่เกี่ยวข้องกัน
//                    เพิ่ม Virtual Balance/Equity ต่อ Magic Number (Inp_Virtual_Cap) แยกอิสระจากบัญชีจริง
//                    ตรงกับหลักการ Virtual Equity Rebasing ที่ใช้ได้ผลกับ Oil-Reserve Combine Gate
// v6.8 Fix G (Patch): แก้ Compiler Warning 'POSITION_COMMISSION' is deprecated ใน VirtualFloatingProfit()
//                    เอาออกเพราะ Commission ถูกนับผ่าน OnTradeTransaction ตอน Deal ปิดอยู่แล้ว ไม่กระทบผลลัพธ์
// v6.9 Fix H (Entry Logic - Regime Filter): จากผล Walk-Forward พบว่า RSI68/RSI71 เหมาะกับคนละ Market
//                    Regime (RSI68=Trend, RSI71=Range) ไม่มีค่าใดค่าหนึ่งที่ดีตลอด — เพิ่ม ADX(14) เป็น
//                    ตัวตรวจจับ Regime: ADX>=Inp_ADX_Trend_Threshold ถือเป็น Trend ใช้ Inp_RSI_Max_Trend
//                    ต่ำกว่านั้นถือเป็น Range ใช้ Inp_RSI_Max_Range สลับอัตโนมัติทุกแท่ง
//                    ปิดการทำงานได้ผ่าน Inp_Use_Regime_Filter=false (กลับไปใช้ Inp_RSI_Max_Value ค่าเดียวแบบเดิม)
// v6.10 Fix I (Timeframe Mismatch): ADX เดิมคำนวณบน M15 (Timeframe เดียวกับที่เทรด) ซึ่งไวและมี Noise สูง
//                    กว่า Regime ที่มองเห็นจริงบนกราฟ Daily มาก ผลคือ ADX แทบไม่เคยตกต่ำกว่า Threshold เลย
//                    ตลอด In-Sample (Walk-Forward ให้ผลเหมือน RSI68 Static เกือบเป๊ะ 119/119 ไม้)
//                    แก้โดยแยก Timeframe คำนวณ ADX ออกจาก Timeframe เทรด ผ่าน Inp_Regime_TF (Default = D1)
//                    ให้ตรงกับ Regime ที่ระบุจากกราฟ Daily จริงๆ ส่วน Entry (BB/RSI) ยังคงอยู่บน M15 เหมือนเดิม

#include <Trade\Trade.mqh>
#include <Trade\DealInfo.mqh>

//--- INPUT PARAMETERS ---
input group "== Global Settings =="
input string   Inp_Symbols          = "AUDCAD#"; 
input long     Inp_Magic            = 515251;                
input double   Inp_Max_Drawdown_Pct = 12.0;   // Best Result Previous = 18.0                   
input int      Inp_Max_Symbols      = 1;
input double   Inp_Virtual_Cap      = 300.0;   // v6.8 Fix G: ทุนที่จัดสรรให้ EA นี้ (สำหรับ Combine กับ EA อื่นบนบัญชีเดียวกัน)                      

input group "== Lot Sizing & Risk =="
input double   Inp_Fixed_Lot        = 0.01;   // Best Result Previous = 0.02                
input double   Inp_Max_Lot          = 0.3;                    
input double   Inp_Max_Spread       = 2.5;   // Previous = 2.5                    

input group "== Compound Selective (Auto Dynamic Lot 1.5x + SoftBrake) =="
input bool     Inp_Use_Compound            = true;    // เปิด Auto Dynamic Lot ตามแผนใหม่
input double   Inp_Compound_Start_Multiple = 1.5;     // เริ่ม Compound เมื่อ Virtual Balance >= Virtual_Cap x 1.5
input double   Inp_Compound_DD_SoftBrake   = 15.0;    // DD (จาก Compound HWM) >= 15% -> Brake กลับ Fixed ชั่วคราว
input double   Inp_Compound_Max_DD         = 22.0;    // DD (จาก Compound HWM) >= 22% -> Kill Switch (CloseAll+ExpertRemove)

input group "== Manual DCA (Cumulative Total, ไม่ใช่ยอดต่อเดือน) =="
input double   Inp_DCAtoAdd                = 0.0;     // กรอกเป็นยอด DCA สะสมทั้งหมดตั้งแต่เริ่ม (เดือน1=25, เดือน2=50 ...)

input group "== Trailing & Partial Close (Multi Level) =="
input bool     Inp_Use_Trailing     = true;                   
input double   Inp_Trail_Start      = 12.0;                   
input double   Inp_Trail_Step       = 5.0;                    
input bool     Inp_Use_Partial      = true;                   
input double   Inp_Partial_Level1   = 10.0;   // ปิด 30%
input double   Inp_Partial_Level2   = 20.0;   // ปิด 40%
input double   Inp_Partial_Level3   = 30.0;   // ปิด 20%

input group "== Risk Management Advanced (New v1.40) =="
input double   Inp_Max_Daily_Loss_Pct = 5.0;     // Best Result Previous = 7.5
input double   Inp_BreakEven_Pips     = 15.0;    // Breakeven trigger

input group "== Strategy (BB & RSI) =="
input int      Inp_BB_Period        = 20;                     
input double   Inp_BB_Deviation     = 2.0;                    
input int      Inp_RSI_Period       = 14;                     
input double   Inp_RSI_Max_Value    = 68.0;   // ใช้เมื่อ Inp_Use_Regime_Filter=false (โหมดค่าคงที่แบบเดิม)
input double   Inp_TP_Initial_Pips  = 15.0;                   
input double   Inp_TP_Grid_Pips     = 10.0;                   

input group "== Regime Filter (v6.9 Fix H, v6.10 Fix I) =="
input bool     Inp_Use_Regime_Filter = true;   // true = สลับ RSI Threshold ตาม Regime, false = ใช้ Inp_RSI_Max_Value คงที่
input ENUM_TIMEFRAMES Inp_Regime_TF  = PERIOD_D1;  // v6.10 Fix I: Timeframe คำนวณ ADX (แยกจาก Timeframe เทรด M15)
input int      Inp_ADX_Period          = 14;
input double   Inp_ADX_Trend_Threshold = 25.0; // ADX >= ค่านี้ = Trend, ต่ำกว่า = Range
input double   Inp_RSI_Max_Trend       = 68.0; // ใช้ตอน ADX>=Threshold (Trend) — Pullback สั้นก็เข้าได้
input double   Inp_RSI_Max_Range       = 71.0; // ใช้ตอน ADX<Threshold (Range) — ต้องรอสุดขั้วจริงเท่านั้น

input group "== Grid Settings (Step Lot) =="
input double   Inp_Trade_Distance   = 25.0;                   
input double   Inp_Step_Lot1        = 0.01;     // Best Result Previous = 0.02                  
input double   Inp_Step_Lot2        = 0.02;     // Best Result Previous = 0.04                 
input int      Inp_Max_Trades       = 5;                      

//--- STRUCT FOR POSITION CACHE ---
struct PositionCache {
   int                count;
   double             total_lots;
   double             avg_price;
   double             last_price;
   ENUM_POSITION_TYPE type;
   ulong              last_update;
   bool               p1_done;   // v6.7 Fix F: Partial Level1 ปิดไปแล้วหรือยัง (ต่อ Basket)
   bool               p2_done;   // v6.7 Fix F: Partial Level2 ปิดไปแล้วหรือยัง (ต่อ Basket)
   bool               p3_done;   // v6.7 Fix F: Partial Level3 ปิดไปแล้วหรือยัง (ต่อ Basket)
};

PositionCache g_pos_cache[];

//--- GLOBAL VARIABLES ---
CTrade             m_trade;
string             g_symbols[];
int                g_handleBB[], g_handleRSI[], g_handleADX[];
double             g_pipsFactor[];
datetime           g_last_bar_time[];

//--- Risk Manager Globals (v1.40) ---
datetime           g_last_day = 0;
double             g_day_start_equity = 0.0;

//--- Kill Switch Peak Tracking Globals (v6.4 Fix B) ---
double             g_peak_balance = 0.0;
double             g_peak_equity  = 0.0;

//--- Virtual Balance/Equity per Magic Number (v6.8 Fix G, สำหรับ Combine กับ EA อื่น) ---
double             g_virtual_balance = 0.0;
double             g_vRealizedProfit = 0.0;   // v6.13 Fix J: กำไร/ขาดทุนสะสมเฉพาะ Magic นี้ จาก Deal History (กันหายตอน Restart)
bool               g_compound_active  = false;  // Auto Dynamic Lot 1.5x — Active flag (permanent เมื่อ Trigger แล้ว เหมือน OIL/GOLD)
bool               g_compound_brake   = false;  // SoftBrake — true เมื่อ DD จาก Compound HWM >= SoftBrake threshold
double             g_compound_hwm     = 0.0;    // High Water Mark ของ Virtual Equity นับจากวินาทีที่ Compound Active

//--- Risk Check Throttle (v6.5 Fix C) ---
datetime           g_last_risk_check = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(Inp_Magic);
   m_trade.SetDeviationInPoints(10);
   
   string temp_arr[];
   int count = StringSplit(Inp_Symbols, ',', temp_arr);
   
   ArrayResize(g_symbols, count);
   ArrayResize(g_handleBB, count);
   ArrayResize(g_handleRSI, count);
   ArrayResize(g_handleADX, count);
   ArrayResize(g_pipsFactor, count);
   ArrayResize(g_pos_cache, count);
   ArrayResize(g_last_bar_time, count);
   
   for(int i = 0; i < count; i++)
   {
      g_symbols[i] = temp_arr[i];
      StringTrimLeft(g_symbols[i]);
      StringTrimRight(g_symbols[i]);
      
      if(!SymbolSelect(g_symbols[i], true))
      {
         Print("ERROR: Cannot select symbol ", g_symbols[i]);
         return INIT_FAILED;
      }
      
      g_handleBB[i]  = iBands(g_symbols[i], PERIOD_CURRENT, Inp_BB_Period, 0, Inp_BB_Deviation, PRICE_CLOSE);
      g_handleRSI[i] = iRSI(g_symbols[i], PERIOD_CURRENT, Inp_RSI_Period, PRICE_CLOSE);
      g_handleADX[i] = iADX(g_symbols[i], Inp_Regime_TF, Inp_ADX_Period);   // v6.10 Fix I: HTF แยกจาก Timeframe เทรด
      
      if(g_handleBB[i] == INVALID_HANDLE || g_handleRSI[i] == INVALID_HANDLE || g_handleADX[i] == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create indicator for ", g_symbols[i]);
         return INIT_FAILED;
      }
      
      long digits = SymbolInfoInteger(g_symbols[i], SYMBOL_DIGITS);
      g_pipsFactor[i] = (digits == 3 || digits == 5) ? 10.0 : 1.0;
      
      g_pos_cache[i].count = 0;
      g_pos_cache[i].total_lots = 0.0;
      g_pos_cache[i].avg_price = 0.0;
      g_pos_cache[i].last_price = 0.0;
      g_pos_cache[i].type = (ENUM_POSITION_TYPE)-1;
      g_pos_cache[i].last_update = 0;
      g_pos_cache[i].p1_done = false;
      g_pos_cache[i].p2_done = false;
      g_pos_cache[i].p3_done = false;
      
      g_last_bar_time[i] = 0;
   }
   
   g_last_day = 0;
   g_day_start_equity = 0.0;

   // v6.13 Fix J (CRITICAL): แทนที่ g_virtual_balance = Inp_Virtual_Cap ตรงๆ ด้วยการกู้คืนจาก Deal History
   // ป้องกัน Restart EA ล้างกำไร/ขาดทุนสะสมทิ้ง (Bug เดิมทำให้ Compound/Kill Switch/Peak ผิดหลัง Restart)
   ScanInitialRealizedProfit();
   g_virtual_balance = Inp_Virtual_Cap + g_vRealizedProfit;
   ApplyDCAIfNeeded();
   DrawDCALabel();

   g_peak_balance = g_virtual_balance;
   g_peak_equity  = g_virtual_balance;

   Print("9AU_AUDCAD initialized with Breakeven + Daily Loss Limit 5% + Max DD 12% (Peak-Equity Basis, Virtual Cap=", DoubleToString(Inp_Virtual_Cap,2), ", VirtualBalance=", DoubleToString(g_virtual_balance,2), ")");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| v6.13 Fix J: กู้คืน Realized P/L สะสมเฉพาะ Magic นี้จาก History     |
//| (Pattern เดียวกับ Gold/OIL-WTI/GBPJPY/USDJPY/3PAIRS)              |
//+------------------------------------------------------------------+
void ScanInitialRealizedProfit()
{
   g_vRealizedProfit = 0.0;
   if(!HistorySelect(0, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != Inp_Magic) continue;
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      g_vRealizedProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                          + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                          + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   }
}

//+------------------------------------------------------------------+
//| MANUAL DCA — Cumulative Total + Global Variable Delta Guard        |
//+------------------------------------------------------------------+
string GVName_DCA() { return "9AU_DCA_APPLIED_" + IntegerToString(Inp_Magic); }

void ApplyDCAIfNeeded()
{
   string gv = GVName_DCA();
   double lastApplied = GlobalVariableCheck(gv) ? GlobalVariableGet(gv) : 0.0;
   double delta = Inp_DCAtoAdd - lastApplied;
   if(MathAbs(delta) < 0.01) return;

   g_virtual_balance += delta;
   GlobalVariableSet(gv, Inp_DCAtoAdd);
   Print("[DCA] AUDCAD Applied Delta=$", DoubleToString(delta,2),
         " | Cumulative Target=$", DoubleToString(Inp_DCAtoAdd,2),
         " | New VBal=$", DoubleToString(g_virtual_balance,2));
}

void DrawDCALabel()
{
   string name = "9AU_DCA_LABEL_" + IntegerToString(Inp_Magic);
   double applied = GlobalVariableCheck(GVName_DCA()) ? GlobalVariableGet(GVName_DCA()) : 0.0;
   string txt = StringFormat("AUDCAD(%d) DCA Cumulative=$%.2f | VBase=$%.2f | VBal=$%.2f",
                              Inp_Magic, applied, Inp_Virtual_Cap, g_virtual_balance);
   if(ObjectFind(0, name) < 0)
   {
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
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < ArraySize(g_handleBB); i++)
   {
      if(g_handleBB[i] != INVALID_HANDLE) IndicatorRelease(g_handleBB[i]);
      if(g_handleRSI[i] != INVALID_HANDLE) IndicatorRelease(g_handleRSI[i]);
      if(g_handleADX[i] != INVALID_HANDLE) IndicatorRelease(g_handleADX[i]);
   }
   ObjectDelete(0, "9AU_DCA_LABEL_" + IntegerToString(Inp_Magic));
}

//+------------------------------------------------------------------+
//| v6.8 Fix G: สะสม Realized P&L เข้า Virtual Balance เฉพาะ Deal      |
//| ของ Magic Number นี้เท่านั้น ไม่ปนกับ Deal ของ EA อื่นบนบัญชีเดียวกัน|
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   
   long deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(deal_magic != Inp_Magic) return;
   
   double profit     = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double swap        = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   double commission  = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   
   g_virtual_balance += (profit + swap + commission);
}

//+------------------------------------------------------------------+
//| Daily Reset & Risk Checks                                        |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   datetime current_day = TimeCurrent() - TimeCurrent() % 86400; // midnight
   if(current_day != g_last_day)
   {
      g_last_day = current_day;
      g_day_start_equity = VirtualEquity();   // v6.8 Fix G: Virtual แทน Account-wide
      Print("New trading day started. Day start Virtual Equity: ", DoubleToString(g_day_start_equity, 2));
   }
}

bool IsDailyLossExceeded()
{
   if(g_day_start_equity <= 0) return false;
   double equity = VirtualEquity();   // v6.8 Fix G: Virtual แทน Account-wide
   return equity < g_day_start_equity * (1.0 - Inp_Max_Daily_Loss_Pct / 100.0 + 0.000001);
}

//+------------------------------------------------------------------+
//| Tick function - main logic (v6.4 Fix A: was OnTimer)             |
//+------------------------------------------------------------------+
void OnTick()
{
   // v6.5 Fix C: Risk Check (Account-level) ไม่จำเป็นต้องรันทุก Tick — throttle เหลือ 1 ครั้ง/วินาที
   // (เท่ากับความถี่เดิมที่ตั้งใจไว้ตอนใช้ EventSetTimer(1)) เพื่อลด Overhead มหาศาลบน Real-Ticks Backtest
   datetime now = TimeCurrent();
   if(now != g_last_risk_check)
   {
      g_last_risk_check = now;
      
      CheckDailyReset();
      UpdatePeaks();   // v6.4 Fix B: อัปเดต Peak Balance/Equity ก่อนเช็ค Drawdown
      UpdateCompoundState();   // Auto Dynamic Lot 1.5x — เช็ค Threshold ทุกวินาทีเหมือน Risk Check อื่น
      
      bool dd_hit = IsDrawdownExceeded();
      if(dd_hit || IsDailyLossExceeded())
      {
         CloseAllPositions(dd_hit ? "Max Equity Drawdown (from Peak) Reached" : "Max Daily Loss 5% Reached");
         
         // v6.5 Fix D: Re-arm Peak หลังปิดไม้ทั้งหมด ไม่เช่นนั้น Peak เดิมจะค้างสูงตลอดไป
         // และ EA จะไม่สามารถเทรดใหม่ได้อีกเลยตลอดช่วงที่เหลือของการทดสอบ/บัญชี
         if(dd_hit)
         {
            g_peak_balance = g_virtual_balance;   // v6.8 Fix G: Virtual แทน Account-wide
            g_peak_equity  = VirtualEquity();     // v6.8 Fix G: Virtual แทน Account-wide
         }
         return;
      }
   }
   
   int total_active = 0;
   for(int i = 0; i < ArraySize(g_symbols); i++)
      if(g_pos_cache[i].count > 0) total_active++;
   
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      if(IsNewBar(i))
         ManageSymbol(i, total_active);
   }
}

//+------------------------------------------------------------------+
//| Check new bar per symbol                                         |
//+------------------------------------------------------------------+
bool IsNewBar(int index)
{
   datetime current = iTime(g_symbols[index], PERIOD_CURRENT, 0);
   if(current > g_last_bar_time[index] && current != 0)
   {
      g_last_bar_time[index] = current;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Trade event                                                      |
//+------------------------------------------------------------------+
void OnTrade()
{
   for(int i = 0; i < ArraySize(g_symbols); i++)
      if(g_pos_cache[i].count > 0)
         RefreshPositionCache(i);
}

//+------------------------------------------------------------------+
//| Refresh position cache                                           |
//+------------------------------------------------------------------+
void RefreshPositionCache(int index)
{
   string symbol = g_symbols[index];
   
   g_pos_cache[index].count       = 0;
   g_pos_cache[index].total_lots  = 0.0;
   g_pos_cache[index].avg_price   = 0.0;
   g_pos_cache[index].last_price  = 0.0;
   g_pos_cache[index].type        = (ENUM_POSITION_TYPE)-1;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetString(POSITION_SYMBOL) == symbol && 
         PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
      {
         double vol   = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         g_pos_cache[index].count++;
         g_pos_cache[index].total_lots += vol;
         g_pos_cache[index].avg_price  += price * vol;
         g_pos_cache[index].last_price  = price;
         g_pos_cache[index].type        = ptype;
      }
   }
   
   if(g_pos_cache[index].count > 0 && g_pos_cache[index].total_lots > 0.000001)
      g_pos_cache[index].avg_price /= g_pos_cache[index].total_lots;
   
   // v6.7 Fix F: Basket ปิดหมดแล้ว (count==0) รีเซ็ต Partial-Close flags ให้พร้อมรับ Basket ใหม่
   // ถ้ายังมีไม้เปิดอยู่ (count>0) ต้องไม่แตะ Flag เพื่อรักษาสถานะ "ปิดไปแล้ว" ของ Basket นี้ไว้
   if(g_pos_cache[index].count == 0)
   {
      g_pos_cache[index].p1_done = false;
      g_pos_cache[index].p2_done = false;
      g_pos_cache[index].p3_done = false;
   }
   
   g_pos_cache[index].last_update = (ulong)TimeCurrent();
}

//+------------------------------------------------------------------+
//| Manage one symbol                                                |
//+------------------------------------------------------------------+
void ManageSymbol(int index, int total_active)
{
   string symbol = g_symbols[index];
   
   if(g_pos_cache[index].count == 0 || g_pos_cache[index].last_update == 0)
      RefreshPositionCache(index);
   
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) return;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = (tick.ask - tick.bid) / (point * g_pipsFactor[index]);
   if(spread > Inp_Max_Spread) return;
   
   if(g_pos_cache[index].count == 0)
   {
      if(total_active < Inp_Max_Symbols)
         CheckEntry(index, tick);
   }
   else
   {
      CheckGrid(index, tick);
      if(Inp_Use_Trailing)
      {
         ApplyBreakeven(index, tick);      // v1.40 Breakeven
         ApplyMultiPartialClose(index, tick);
         ApplyTrailingStop(index, tick);
      }
      else
         ApplyBasketTP(index);
   }
}

//+------------------------------------------------------------------+
//| Breakeven (v1.40) - Set SL to avg_price + buffer                 |
//+------------------------------------------------------------------+
void ApplyBreakeven(int index, MqlTick &tick)
{
   if(g_pos_cache[index].count == 0) return;
   
   double pips_val = SymbolInfoDouble(g_symbols[index], SYMBOL_POINT) * g_pipsFactor[index];
   double profit_pips = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? 
                        (tick.bid - g_pos_cache[index].avg_price) / pips_val : 
                        (g_pos_cache[index].avg_price - tick.ask) / pips_val;
   
   if(profit_pips >= Inp_BreakEven_Pips)
   {
      double buffer = pips_val; // 1 pip safety
      double sl_price = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? 
                        g_pos_cache[index].avg_price + buffer : 
                        g_pos_cache[index].avg_price - buffer;
      
      bool modified = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && 
            PositionGetString(POSITION_SYMBOL) == g_symbols[index] && 
            PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
         {
            double current_sl = PositionGetDouble(POSITION_SL);
            if(MathAbs(current_sl - sl_price) > SymbolInfoDouble(g_symbols[index], SYMBOL_POINT))
            {
               if(m_trade.PositionModify(ticket, sl_price, PositionGetDouble(POSITION_TP)))
                  modified = true;
               else
                  Print("Breakeven Modify Error ", g_symbols[index], ": ", m_trade.ResultRetcodeDescription());
            }
         }
      }
      if(modified)
         RefreshPositionCache(index);
   }
}

//+------------------------------------------------------------------+
//| Check for initial entry                                          |
//+------------------------------------------------------------------+
void CheckEntry(int index, MqlTick &tick)
{
   // v6.6 Fix E: ใช้ start_pos=1 (Shift 1) เพื่ออ่านค่า BB/RSI ของแท่งที่ "ปิดสมบูรณ์แล้ว"
   // ไม่ใช่แท่งที่เพิ่งเปิด (Shift 0) ซึ่งค่าจะไม่นิ่งและขึ้นกับ Tick แรกที่มาถึงพอดี
   double bb_up[1], bb_low[1], rsi[1];
   if(CopyBuffer(g_handleBB[index], 1, 1, 1, bb_up) <= 0 ||
      CopyBuffer(g_handleBB[index], 2, 1, 1, bb_low) <= 0 ||
      CopyBuffer(g_handleRSI[index], 0, 1, 1, rsi) <= 0)
      return;
   
   // v6.9 Fix H: เลือก RSI Threshold ตาม Market Regime ที่ ADX ตรวจจับได้ (Shift 1 เช่นกัน)
   // Trend (ADX>=Threshold) ใช้ Inp_RSI_Max_Trend (หลวมกว่า จับ Pullback สั้น)
   // Range (ADX<Threshold) ใช้ Inp_RSI_Max_Range (เข้มกว่า รอจุดสุดขั้วจริงเท่านั้น)
   double active_rsi_max = Inp_RSI_Max_Value;
   if(Inp_Use_Regime_Filter)
   {
      double adx[1];
      if(CopyBuffer(g_handleADX[index], 0, 1, 1, adx) <= 0) return;   // อ่าน ADX ไม่ได้ ข้ามรอบนี้ไปก่อน (Fail-Safe)
      active_rsi_max = (adx[0] >= Inp_ADX_Trend_Threshold) ? Inp_RSI_Max_Trend : Inp_RSI_Max_Range;
   }
   
   if(tick.last > bb_up[0] && rsi[0] > active_rsi_max)
   {
      if(m_trade.Sell(GetCompoundLot(Inp_Fixed_Lot), g_symbols[index], tick.bid, 0, 0, "BB+RSI Sell"))
         RefreshPositionCache(index);
      else
         Print("Trade Error Sell ", g_symbols[index], ": ", m_trade.ResultRetcodeDescription());
   }
   else if(tick.last < bb_low[0] && rsi[0] < (100.0 - active_rsi_max))
   {
      if(m_trade.Buy(GetCompoundLot(Inp_Fixed_Lot), g_symbols[index], tick.ask, 0, 0, "BB+RSI Buy"))
         RefreshPositionCache(index);
      else
         Print("Trade Error Buy ", g_symbols[index], ": ", m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check grid addition                                              |
//+------------------------------------------------------------------+
void CheckGrid(int index, MqlTick &tick)
{
   if(g_pos_cache[index].count >= Inp_Max_Trades || g_pos_cache[index].count == 0) return;
   
   string symbol = g_symbols[index];
   double price = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? tick.ask : tick.bid;
   double gap = MathAbs(price - g_pos_cache[index].avg_price) / 
                (SymbolInfoDouble(symbol, SYMBOL_POINT) * g_pipsFactor[index]);
   
   if(gap >= Inp_Trade_Distance)
   {
      double next_lot = (g_pos_cache[index].count >= 3) ? Inp_Step_Lot2 : Inp_Step_Lot1;
      next_lot = GetCompoundLot(next_lot);   // Auto Dynamic Lot 1.5x — scale grid leg เช่นเดียวกับไม้แรก
      
      bool success = false;
      if(g_pos_cache[index].type == POSITION_TYPE_BUY && price < g_pos_cache[index].last_price)
         success = m_trade.Buy(next_lot, symbol, 0, 0, 0, "Grid Buy");
      else if(g_pos_cache[index].type == POSITION_TYPE_SELL && price > g_pos_cache[index].last_price)
         success = m_trade.Sell(next_lot, symbol, 0, 0, 0, "Grid Sell");
      
      if(success)
         RefreshPositionCache(index);
      else
         Print("Grid Trade Error ", symbol, ": ", m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Multi Level Partial Close                                        |
//+------------------------------------------------------------------+
void ApplyMultiPartialClose(int index, MqlTick &tick)
{
   if(!Inp_Use_Partial || g_pos_cache[index].count == 0) return;
   
   string symbol = g_symbols[index];
   double pips_val = SymbolInfoDouble(symbol, SYMBOL_POINT) * g_pipsFactor[index];
   double profit_pips = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? 
                        (tick.bid - g_pos_cache[index].avg_price) / pips_val : 
                        (g_pos_cache[index].avg_price - tick.ask) / pips_val;
   
   double close_pct = 0.0;
   // v6.7 Fix F: เพิ่มเงื่อนไข !p_done กันไม่ให้ Level เดิมปิดซ้ำทุกครั้งที่กำไรค้างอยู่ในช่วงเดิม
   // ถ้ากำไรกระโดดข้าม Level (เช่น ข้าม Level1/2 ไปถึง Level3 เลยในแท่งเดียว) ให้ถือว่า Level ที่ข้ามไป
   // "ใช้สิทธิ์ไปแล้ว" ด้วย (Mark done) เพื่อไม่ให้ย้อนมาปิดซ้ำตอนราคาพักตัวกลับมาที่ Level ต่ำกว่าในภายหลัง
   if(profit_pips >= Inp_Partial_Level3 && !g_pos_cache[index].p3_done)
   {
      close_pct = 0.20;
      g_pos_cache[index].p3_done = true;
      g_pos_cache[index].p2_done = true;
      g_pos_cache[index].p1_done = true;
   }
   else if(profit_pips >= Inp_Partial_Level2 && !g_pos_cache[index].p2_done)
   {
      close_pct = 0.40;
      g_pos_cache[index].p2_done = true;
      g_pos_cache[index].p1_done = true;
   }
   else if(profit_pips >= Inp_Partial_Level1 && !g_pos_cache[index].p1_done)
   {
      close_pct = 0.30;
      g_pos_cache[index].p1_done = true;
   }
   
   if(close_pct > 0.0)
   {
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
         {
            double vol = PositionGetDouble(POSITION_VOLUME);
            m_trade.PositionClosePartial(ticket, vol * close_pct);
            // ไม่ break → partial ทุก ticket ใน basket
         }
      }
      RefreshPositionCache(index);
   }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int index, MqlTick &tick)
{
   if(g_pos_cache[index].count == 0) return;
   
   string symbol = g_symbols[index];
   double pips_val = SymbolInfoDouble(symbol, SYMBOL_POINT) * g_pipsFactor[index];
   double profit_pips = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? 
                        (tick.bid - g_pos_cache[index].avg_price) / pips_val : 
                        (g_pos_cache[index].avg_price - tick.ask) / pips_val;
   
   if(profit_pips >= Inp_Trail_Start)
   {
      double new_tp = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? 
                      tick.bid + Inp_Trail_Step * pips_val : 
                      tick.ask - Inp_Trail_Step * pips_val;
      ModifyBasketTP(index, new_tp);
   }
}

//+------------------------------------------------------------------+
//| Apply basket TP                                                  |
//+------------------------------------------------------------------+
void ApplyBasketTP(int index)
{
   if(g_pos_cache[index].count == 0) return;
   
   string symbol = g_symbols[index];
   double offset = ((g_pos_cache[index].count == 1) ? Inp_TP_Initial_Pips : Inp_TP_Grid_Pips) * 
                   g_pipsFactor[index] * SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   double target_tp = (g_pos_cache[index].type == POSITION_TYPE_BUY) ? 
                      g_pos_cache[index].avg_price + offset : 
                      g_pos_cache[index].avg_price - offset;
   
   ModifyBasketTP(index, target_tp);
}

//+------------------------------------------------------------------+
//| Modify TP for all positions                                      |
//+------------------------------------------------------------------+
void ModifyBasketTP(int index, double target_tp)
{
   string symbol = g_symbols[index];
   bool modified = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetString(POSITION_SYMBOL) == symbol && 
         PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
      {
         double current_tp = PositionGetDouble(POSITION_TP);
         if(MathAbs(current_tp - target_tp) > SymbolInfoDouble(symbol, SYMBOL_POINT))
         {
            if(m_trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), target_tp))
               modified = true;
            else
               Print("Modify TP Error ", symbol, ": ", m_trade.ResultRetcodeDescription());
         }
      }
   }
   
   if(modified)
      RefreshPositionCache(index);
}

//+------------------------------------------------------------------+
//| v6.8 Fix G: Floating Profit เฉพาะโพซิชันของ Magic Number นี้เท่านั้น |
//| (ไม่รวม EA อื่นที่รันอยู่บนบัญชีเดียวกัน เช่น BTCUSD Magic 919295)   |
//+------------------------------------------------------------------+
double VirtualFloatingProfit()
{
   double floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != Inp_Magic) continue;
      
      // v6.8 Fix G (Patch): เอา POSITION_COMMISSION ออก (Deprecated ใน Build ปัจจุบัน)
      // Commission ของแต่ละ Deal ถูกนับสะสมเข้า g_virtual_balance ผ่าน OnTradeTransaction
      // ตอนที่ Deal เกิดขึ้นจริงอยู่แล้ว ไม่จำเป็นต้องอ่านซ้ำจากโพซิชันที่ยังเปิดอยู่
      floating += PositionGetDouble(POSITION_PROFIT)
                + PositionGetDouble(POSITION_SWAP);
   }
   return floating;
}

//+------------------------------------------------------------------+
//| v6.8 Fix G: Virtual Equity = ทุนที่จัดสรร + Realized P&L สะสม      |
//| ของ Magic นี้ + Floating P&L ของ Magic นี้ (ไม่แตะ P&L ของ EA อื่น) |
//+------------------------------------------------------------------+
double VirtualEquity()
{
   return g_virtual_balance + VirtualFloatingProfit();
}

//+------------------------------------------------------------------+
//| Active แบบถาวรเมื่อ Virtual Balance >= Virtual_Cap x StartMult - คุมความเสี่ยงด้วย SoftBrake/Kill (concept เดียวกับ OIL-WTI/GOLD) |
//+------------------------------------------------------------------+
void UpdateCompoundState()
{
   if(!Inp_Use_Compound) return;

   double vBal = g_virtual_balance;
   double vEq  = VirtualEquity();

   if(!g_compound_active && vBal >= Inp_Virtual_Cap * Inp_Compound_Start_Multiple)
   {
      g_compound_active = true;
      g_compound_hwm    = vEq;
      Print("[Compound] AUDCAD ACTIVATED | VBal=", DoubleToString(vBal,2));
   }

   if(!g_compound_active) return;

   if(vEq > g_compound_hwm) g_compound_hwm = vEq;

   double cDD = (g_compound_hwm > 0) ? (g_compound_hwm - vEq) / g_compound_hwm * 100.0 : 0.0;

   if(!g_compound_brake && cDD >= Inp_Compound_DD_SoftBrake)
   {
      g_compound_brake = true;
      Print("[Compound Brake] AUDCAD ON. DD=", cDD);
   }

   if(g_compound_brake && cDD < Inp_Compound_DD_SoftBrake * 0.75)
   {
      g_compound_brake = false;
      Print("[Compound Brake] AUDCAD OFF. DD=", cDD);
   }

   if(cDD >= Inp_Compound_Max_DD)
   {
      Print("[Compound] AUDCAD KILL | DD=", cDD, "% >= ", Inp_Compound_Max_DD, "%");
      CloseAllPositions("COMPOUND KILL SWITCH");
      ExpertRemove();
   }
}

double GetCompoundLot(double base_lot)
{
   if(!g_compound_active || g_compound_brake) return base_lot;
   double ratio = VirtualEquity() / Inp_Virtual_Cap;
   double lot   = base_lot * ratio;
   return MathMin(lot, Inp_Max_Lot);
}

//+------------------------------------------------------------------+
//| Update running peak Balance / Equity (v6.4 Fix B, v6.8 Fix G)    |
//+------------------------------------------------------------------+
void UpdatePeaks()
{
   double balance = g_virtual_balance;     // v6.8 Fix G: Virtual แทน Account-wide
   double equity  = VirtualEquity();       // v6.8 Fix G: Virtual แทน Account-wide
   
   if(balance > g_peak_balance) g_peak_balance = balance;
   if(equity  > g_peak_equity)  g_peak_equity  = equity;
}

//+------------------------------------------------------------------+
//| Drawdown check (v6.4 Fix B, v6.8 Fix G)                          |
//| เดิม: เทียบ floating loss กับ Balance ปัจจุบัน ทำให้ตัวเลขไม่ตรงกับ  |
//|       Equity Drawdown Maximal ที่ MT5 รายงาน (ซึ่งอิง Peak Equity) |
//| ใหม่: เทียบ Equity ปัจจุบันกับ Peak Equity สูงสุดที่เคยทำได้        |
//|       ให้ Kill Switch สอดคล้องกับสูตรมาตรฐานของ MT5 โดยตรง          |
//| v6.8 Fix G: ใช้ Virtual Equity แทน Account Equity เพื่อไม่ให้ EA อื่น|
//|       ที่รันคู่กันบนบัญชีเดียวกัน (เช่น BTCUSD) มากระทบ Kill Switch  |
//+------------------------------------------------------------------+
bool IsDrawdownExceeded()
{
   if(g_peak_equity <= 0.0) return false;
   double equity = VirtualEquity();     // v6.8 Fix G: Virtual แทน Account-wide
   double dd_pct = (g_peak_equity - equity) / g_peak_equity * 100.0;
   return dd_pct > (Inp_Max_Drawdown_Pct + 0.000001);
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   Print("Closing all positions: ", reason);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
         m_trade.PositionClose(ticket);
   }
}
//+------------------------------------------------------------------+