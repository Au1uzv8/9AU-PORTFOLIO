//+------------------------------------------------------------------+
//|  9AU_3PAIRS_BB_RSI_ADX_M15_CAP300_V2_3.mq5                        |
//|  Consultant: James                                               |
//|  3-Pair Correlation Hedge + Dual-Basket Isolation                |
//|  + Compound Selective + Multi-Level Safety                       |
//|  Version 2.3 : Fix entry signal: iClose bar0 replaces tick.bid,  |
//|                remove redundant last_update guard in ManageSymbol |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "2.3"
#property strict

#include <Trade\Trade.mqh>

//=== DIRECTION CONSTANTS ===
#define DIR_BUY  0
#define DIR_SELL 1

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "== Global Settings =="
input string   Inp_Symbols           = "AUDCAD#,NZDCAD#,AUDNZD#";
input long     Inp_Magic             = 515252;
input int      Inp_Max_Symbols       = 3;

input group "== ADX Trend Pause =="
input int      Inp_ADX_Period        = 14;
input double   Inp_ADX_Pause_Level   = 26.0;  // หยุดเปิด+add grid เมื่อ ADX > 26
input double   Inp_ADX_Resume_Level  = 23.0;  // กลับมาทำงานเมื่อ ADX < 23

input group "== Correlation DD Guard =="
input double   Inp_Corr_DD_Pct       = 5.0;   // 2+ pairs floating loss >5% -> หยุดเปิดใหม่

input group "== Lot Sizing =="
input double   Inp_Fixed_Lot         = 0.01;
input double   Inp_Max_Lot           = 0.30;
input double   Inp_Max_Spread        = 2.5;

input group "== Dual Basket Settings =="
input bool     Inp_Enable_Sell       = false;   // false = Long-only (reproduce v1.4 baseline)
// Sell basket ใช้ lot cap เล็กกว่า Buy เพราะ counter-trend บน pairs เหล่านี้
input double   Inp_Sell_Lot_Cap_Pct  = 50.0;  // Sell max lot = Buy max lot x 50%
input int      Inp_Sell_Max_Trades   = 1;      // Sell grid จำกัด 2 ขั้น (conservative)

input group "== Trailing & Partial Close =="
input bool     Inp_Use_Trailing      = true;
input double   Inp_Trail_Start       = 10.0;  // เริ่ม trailing ที่ 10 pips
input double   Inp_Trail_Step        = 4.0;   // ขยับ TP ทุก 4 pips
input bool     Inp_Use_Partial       = true;
input double   Inp_Partial_Level1    = 8.0;   // ปิด 30% ที่ 8 pips
input double   Inp_Partial_Level2    = 15.0;  // ปิด 40% ที่ 15 pips
input double   Inp_Partial_Level3    = 25.0;  // ปิด 20% ที่ 25 pips

input group "== Risk Management =="
input double   Inp_Max_Daily_Loss_Pct  = 5.0;   // ขาดทุนสะสมในวัน >5% -> หยุดทั้งวัน
input double   Inp_BreakEven_Pips      = 10.0;
input double   Inp_Equity_Trail_DD_Pct = 12.0;   // ปิดทั้งหมดเมื่อ equity DD จาก peak > 8%
input bool     Inp_Use_EquityTrail     = true;

input group "== Kill Switch =="
input double   Inp_KillSwitch_DD_Pct   = 15.0;  // DD จาก initial deposit -> ExpertRemove
input bool     Inp_KillSwitch          = false;  // Manual kill

input group "== Compound Selective =="
input bool     Inp_Use_Compound        = false;  // false = Fixed lot (Stage 1)
// Compound เปิดเมื่อ balance >= BaseBalance x Inp_Compound_Start_Multiple
input double   Inp_Compound_Start_Multiple = 1.5;
// SoftBrake ON เมื่อ floating DD ของ symbol นั้น >= % นี้ จาก BaseBalance
input double   Inp_Compound_Brake_On_Pct  = 15.0;
// SoftBrake OFF เมื่อ floating DD กลับมา < % นี้
input double   Inp_Compound_Brake_Off_Pct = 10.0;
// Kill Switch สำหรับ Compound mode (equity DD จาก base)
input double   Inp_Compound_Kill_DD_Pct   = 20.0;

input group "== Telegram =="
input string   InpToken              = "8663985469:AAGo473sGCgrWBhKNFLz6p-LGe86ftDvxZE";
input string   InpChatID             = "8053031320";

input group "== Strategy (BB & RSI) =="
input int      Inp_BB_Period         = 20;
input double   Inp_BB_Deviation      = 2.0;
input int      Inp_RSI_Period        = 14;
input double   Inp_RSI_Max_Value     = 68.0;  // Buy: RSI < (100 - 68) = 32 -> oversold
input double   Inp_RSI_Sell_Level    = 68.0;  // Sell: RSI > 60 -> overbought (แยกจาก Buy)
input double   Inp_TP_Initial_Pips   = 10.0;
input double   Inp_TP_Grid_Pips      = 8.0;

input group "== Grid Settings (Static Fallback) =="
input double   Inp_Trade_Distance    = 25.0;
input double   Inp_Step_Lot1         = 0.02;
input double   Inp_Step_Lot2         = 0.04;
input int      Inp_Max_Trades        = 4;

input group "== Dynamic Grid (ATR) =="
input bool     Inp_Use_DynamicGrid   = true;
input int      Inp_ATR_Period_Grid   = 14;
input double   Inp_Grid_ATR_Mult     = 0.7;
input double   Inp_Grid_MinDist      = 12.0;
input double   Inp_Grid_MaxDist      = 45.0;

//+------------------------------------------------------------------+
//| DUAL BASKET STRUCT                                               |
//| แยก Buy/Sell อย่างสมบูรณ์ต่อ symbol                              |
//+------------------------------------------------------------------+
struct BasketInfo {
   int    count;        // จำนวน positions ที่เปิดอยู่
   double total_lots;   // lots รวม
   double avg_price;    // ราคาเฉลี่ย weighted
   double last_price;   // ราคา position ล่าสุดที่เปิด
   double total_profit; // floating profit รวมของ basket นี้
   ulong  last_update;  // timestamp อัปเดตล่าสุด
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
CTrade    m_trade;
string    g_symbols[];
int       g_handleBB[], g_handleRSI[], g_handleADX[], g_handleATR[];
double    g_pipsFactor[];
datetime  g_last_bar_time[];

// Dual basket: [symbol_index][DIR_BUY=0 / DIR_SELL=1]
BasketInfo g_basket[][2];

// Compound
double    g_base_balance       = 0.0;   // balance ตอน init
bool      g_compound_brake[];          // per-symbol SoftBrake flag
bool      g_compound_active    = false; // ถึง threshold แล้วหรือยัง

// Kill Switch & Halt
bool      g_kill_triggered     = false;
bool      g_halt_trading       = false;
datetime  g_halt_until         = 0;

// Daily Loss
datetime  g_last_day           = 0;
double    g_day_start_equity   = 0.0;

// Equity Trail (global peak — ไม่ reset รายวัน เพื่อ protect จาก cumulative loss)
double    g_peak_equity        = 0.0;

// ADX state per symbol (hysteresis)
bool      g_adx_trending[];

// Partial close level tracker: 0=none done, 1=L1 done, 2=L2 done, 3=L3 done
// [symbol_idx][DIR_BUY=0 / DIR_SELL=1]
int       g_partial_level[][2];

//+------------------------------------------------------------------+
//| TELEGRAM                                                         |
//+------------------------------------------------------------------+
void SendTelegram(const string msg)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(InpToken == "" || InpChatID == "") return;
   string url  = "https://api.telegram.org/bot" + InpToken + "/sendMessage";
   string body = "{\"chat_id\":\"" + InpChatID + "\",\"text\":\"" + msg + "\"}";
   char   data[], result[];
   string hdrs = "Content-Type: application/json\r\n";
   StringToCharArray(body, data, 0, StringLen(body));
   WebRequest("POST", url, hdrs, 5000, data, result, hdrs);
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(Inp_Magic);
   m_trade.SetDeviationInPoints(10);
   EventSetTimer(1);

   string temp[];
   int count = StringSplit(Inp_Symbols, ',', temp);
   if(count <= 0) { Print("ERROR: No symbols defined"); return INIT_FAILED; }

   ArrayResize(g_symbols,        count);
   ArrayResize(g_handleBB,       count);
   ArrayResize(g_handleRSI,      count);
   ArrayResize(g_handleADX,      count);
   ArrayResize(g_handleATR,      count);
   ArrayResize(g_pipsFactor,     count);
   ArrayResize(g_last_bar_time,  count);
   ArrayResize(g_basket,         count);
   ArrayResize(g_compound_brake, count);
   ArrayResize(g_adx_trending,   count);

   for(int i = 0; i < count; i++)
   {
      g_symbols[i] = temp[i];
      StringTrimLeft(g_symbols[i]);
      StringTrimRight(g_symbols[i]);

      if(!SymbolSelect(g_symbols[i], true))
      { Print("ERROR: Cannot select ", g_symbols[i]); return INIT_FAILED; }

      g_handleBB[i]  = iBands(g_symbols[i],  PERIOD_CURRENT, Inp_BB_Period, 0, Inp_BB_Deviation, PRICE_CLOSE);
      g_handleRSI[i] = iRSI(g_symbols[i],    PERIOD_CURRENT, Inp_RSI_Period, PRICE_CLOSE);
      g_handleADX[i] = iADX(g_symbols[i],    PERIOD_CURRENT, Inp_ADX_Period);
      g_handleATR[i] = iATR(g_symbols[i],    PERIOD_CURRENT, Inp_ATR_Period_Grid);

      if(g_handleBB[i]  == INVALID_HANDLE || g_handleRSI[i] == INVALID_HANDLE ||
         g_handleADX[i] == INVALID_HANDLE || g_handleATR[i] == INVALID_HANDLE)
      { Print("ERROR: Indicator handle failed for ", g_symbols[i]); return INIT_FAILED; }

      long digits = SymbolInfoInteger(g_symbols[i], SYMBOL_DIGITS);
      g_pipsFactor[i] = (digits == 3 || digits == 5) ? 10.0 : 1.0;

      // Init both baskets to zero
      for(int d = 0; d < 2; d++)
      {
         g_basket[i][d].count        = 0;
         g_basket[i][d].total_lots   = 0.0;
         g_basket[i][d].avg_price    = 0.0;
         g_basket[i][d].last_price   = 0.0;
         g_basket[i][d].total_profit = 0.0;
         g_basket[i][d].last_update  = 0;
      }

      g_last_bar_time[i]  = 0;
      g_compound_brake[i] = false;
      g_adx_trending[i]   = false;
   }

   g_base_balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   g_peak_equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   g_kill_triggered  = false;
   g_halt_trading    = false;
   g_halt_until      = 0;
   g_last_day        = 0;
   g_day_start_equity = 0.0;
   g_compound_active = false;

   InitPartialLevels();  // init partial close level tracker

   Print("9AU_3PAIRS v2.3 | Dual-Basket | Compound=", Inp_Use_Compound,
         " | Sell=", Inp_Enable_Sell, " | RSI_Sell=", Inp_RSI_Sell_Level,
         " | Symbols=", Inp_Symbols);
   SendTelegram("9AU_3PAIRS v2.3 INIT | Dual-Basket + Compound Selective | " + Inp_Symbols);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i = 0; i < ArraySize(g_handleBB); i++)
   {
      if(g_handleBB[i]  != INVALID_HANDLE) IndicatorRelease(g_handleBB[i]);
      if(g_handleRSI[i] != INVALID_HANDLE) IndicatorRelease(g_handleRSI[i]);
      if(g_handleADX[i] != INVALID_HANDLE) IndicatorRelease(g_handleADX[i]);
      if(g_handleATR[i] != INVALID_HANDLE) IndicatorRelease(g_handleATR[i]);
   }
}

//+------------------------------------------------------------------+
//| OnTrade — refresh cache เมื่อ position เปลี่ยน                   |
//+------------------------------------------------------------------+
void OnTrade()
{
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      RefreshBasket(i, DIR_BUY);
      RefreshBasket(i, DIR_SELL);
   }
}

//+------------------------------------------------------------------+
//| CORE: RefreshBasket                                              |
//| แยก loop ตาม POSITION_TYPE — ไม่มีทางผสม avg_price ข้าม direction|
//+------------------------------------------------------------------+
void RefreshBasket(int idx, int dir)
{
   ENUM_POSITION_TYPE pt = (dir == DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   string sym = g_symbols[idx];

   g_basket[idx][dir].count        = 0;
   g_basket[idx][dir].total_lots   = 0.0;
   g_basket[idx][dir].avg_price    = 0.0;
   g_basket[idx][dir].last_price   = 0.0;
   g_basket[idx][dir].total_profit = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != sym)        continue;
      if(PositionGetInteger(POSITION_MAGIC)  != Inp_Magic)  continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;

      double vol   = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);

      g_basket[idx][dir].count++;
      g_basket[idx][dir].total_lots   += vol;
      g_basket[idx][dir].avg_price    += price * vol;
      g_basket[idx][dir].last_price    = price;
      g_basket[idx][dir].total_profit += PositionGetDouble(POSITION_PROFIT);
   }

   if(g_basket[idx][dir].count > 0 && g_basket[idx][dir].total_lots > 1e-8)
      g_basket[idx][dir].avg_price /= g_basket[idx][dir].total_lots;

   g_basket[idx][dir].last_update = (ulong)TimeCurrent();

   // Reset partial level เมื่อ basket ปิดหมด
   if(g_basket[idx][dir].count == 0 && ArraySize(g_partial_level) > idx)
      g_partial_level[idx][dir] = 0;
}

//+------------------------------------------------------------------+
//| CORE: CloseBasket                                                |
//| ปิดเฉพาะ direction ที่ระบุ — ไม่กระทบ basket อีกฝั่ง            |
//+------------------------------------------------------------------+
void CloseBasket(int idx, int dir, string reason)
{
   ENUM_POSITION_TYPE pt = (dir == DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   string sym = g_symbols[idx];
   int closed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != sym)       continue;
      if(PositionGetInteger(POSITION_MAGIC)  != Inp_Magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;

      if(m_trade.PositionClose(ticket))
         closed++;
      else
         Print("[CloseBasket] Failed ticket=", ticket, " err=", m_trade.ResultRetcodeDescription());
   }

   if(closed > 0)
   {
      string dir_str = (dir == DIR_BUY) ? "BUY" : "SELL";
      Print("[CloseBasket] ", sym, " ", dir_str, " | ", reason, " | closed=", closed);
      SendTelegram("9AU_3PAIRS: Close " + sym + " " + dir_str + " | " + reason);
   }

   RefreshBasket(idx, dir);
}

//+------------------------------------------------------------------+
//| CORE: CloseAllPositions (Kill Switch / Equity Trail)             |
//| ปิดทุก position ทุก symbol ทุก direction                         |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   Print("[CloseAll] ", reason);
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
         if(m_trade.PositionClose(ticket)) closed++;
   }
   if(closed > 0)
      SendTelegram("9AU_3PAIRS: CloseAll | " + reason + " | " + IntegerToString(closed) + " positions");

   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      RefreshBasket(i, DIR_BUY);
      RefreshBasket(i, DIR_SELL);
   }
}

//+------------------------------------------------------------------+
//| COMPOUND: GetLot                                                 |
//| per-symbol compound lot — ใช้ balance ไม่ใช่ equity              |
//+------------------------------------------------------------------+
double GetLot(int idx, int dir)
{
   double base = Inp_Fixed_Lot;

   // Compound active check
   if(Inp_Use_Compound && g_compound_active && !g_compound_brake[idx])
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_base_balance > 0)
      {
         double ratio = balance / g_base_balance;
         base = Inp_Fixed_Lot * ratio;
      }
   }

   // Sell direction: cap ที่ Inp_Sell_Lot_Cap_Pct ของ max lot
   double max_lot = Inp_Max_Lot;
   if(dir == DIR_SELL)
      max_lot = Inp_Max_Lot * (Inp_Sell_Lot_Cap_Pct / 100.0);

   base = MathMin(base, max_lot);

   // Normalize to broker lot step
   double lot_step = SymbolInfoDouble(g_symbols[idx], SYMBOL_VOLUME_STEP);
   if(lot_step > 0)
      base = MathFloor(base / lot_step) * lot_step;

   double min_lot = SymbolInfoDouble(g_symbols[idx], SYMBOL_VOLUME_MIN);
   return MathMax(base, min_lot);
}

//+------------------------------------------------------------------+
//| COMPOUND: UpdateCompoundState                                    |
//+------------------------------------------------------------------+
void UpdateCompoundState()
{
   if(!Inp_Use_Compound) return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Activate compound เมื่อถึง threshold
   if(!g_compound_active && balance >= g_base_balance * Inp_Compound_Start_Multiple)
   {
      g_compound_active = true;
      Print("[Compound] ACTIVATED | balance=", DoubleToString(balance,2));
      SendTelegram("9AU_3PAIRS: Compound ACTIVATED | Balance=" + DoubleToString(balance,2));
   }

   if(!g_compound_active) return;

   // SoftBrake per symbol — อิงจาก floating profit ของทั้ง 2 baskets ต่อ symbol
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      double floating = g_basket[i][DIR_BUY].total_profit + g_basket[i][DIR_SELL].total_profit;
      double brake_on_usd  = g_base_balance * (Inp_Compound_Brake_On_Pct  / 100.0);
      double brake_off_usd = g_base_balance * (Inp_Compound_Brake_Off_Pct / 100.0);

      if(!g_compound_brake[i] && floating < -brake_on_usd)
      {
         g_compound_brake[i] = true;
         Print("[Compound] SoftBrake ON | ", g_symbols[i], " floating=", DoubleToString(floating,2));
      }
      else if(g_compound_brake[i] && floating > -brake_off_usd)
      {
         g_compound_brake[i] = false;
         Print("[Compound] SoftBrake OFF | ", g_symbols[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| DAILY RESET                                                      |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   datetime current_day = TimeCurrent() - TimeCurrent() % 86400;
   if(current_day != g_last_day)
   {
      g_last_day         = current_day;
      g_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      // g_peak_equity ไม่ reset รายวัน — protect cumulative equity peak
      Print("[DailyReset] day_start_equity=", DoubleToString(g_day_start_equity,2));
   }
}

bool IsDailyLossExceeded()
{
   if(g_day_start_equity <= 0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return equity < g_day_start_equity * (1.0 - Inp_Max_Daily_Loss_Pct / 100.0);
}

//+------------------------------------------------------------------+
//| EQUITY TRAIL (global peak — ไม่ reset รายวัน)                    |
//+------------------------------------------------------------------+
bool IsEquityTrailBreached()
{
   if(!Inp_Use_EquityTrail) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peak_equity) g_peak_equity = equity;
   if(g_peak_equity <= 0) return false;
   double dd = (g_peak_equity - equity) / g_peak_equity * 100.0;
   return dd >= Inp_Equity_Trail_DD_Pct;
}

//+------------------------------------------------------------------+
//| KILL SWITCH (from initial deposit)                               |
//+------------------------------------------------------------------+
bool IsKillSwitchBreached()
{
   if(g_base_balance <= 0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_base_balance - equity) / g_base_balance * 100.0;

   // Compound mode มี tighter kill
   if(Inp_Use_Compound && g_compound_active && dd >= Inp_Compound_Kill_DD_Pct) return true;
   return dd >= Inp_KillSwitch_DD_Pct;
}

//+------------------------------------------------------------------+
//| CORRELATION DD GUARD                                             |
//+------------------------------------------------------------------+
bool IsCorrelationDDBreached()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return false;
   int pairs_in_loss = 0;
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      double floating = g_basket[i][DIR_BUY].total_profit + g_basket[i][DIR_SELL].total_profit;
      if(floating < -(balance * Inp_Corr_DD_Pct / 100.0))
         pairs_in_loss++;
   }
   return pairs_in_loss >= 2;
}

//+------------------------------------------------------------------+
//| ADX TREND PAUSE (hysteresis)                                     |
//+------------------------------------------------------------------+
bool IsAdxTrending(int idx)
{
   double adx_buf[];
   ArraySetAsSeries(adx_buf, true);
   if(CopyBuffer(g_handleADX[idx], 0, 0, 2, adx_buf) < 2) return false;
   double adx = adx_buf[1]; // ใช้ bar ที่ปิดแล้ว

   if(!g_adx_trending[idx] && adx >= Inp_ADX_Pause_Level)
      g_adx_trending[idx] = true;
   else if(g_adx_trending[idx] && adx <= Inp_ADX_Resume_Level)
      g_adx_trending[idx] = false;

   return g_adx_trending[idx];
}

//+------------------------------------------------------------------+
//| DYNAMIC GRID DISTANCE                                            |
//+------------------------------------------------------------------+
double GetDynamicGridDistance(int idx)
{
   if(!Inp_Use_DynamicGrid || g_handleATR[idx] == INVALID_HANDLE)
      return Inp_Trade_Distance;
   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(g_handleATR[idx], 0, 0, 1, atr_buf) < 1) return Inp_Trade_Distance;
   double point = SymbolInfoDouble(g_symbols[idx], SYMBOL_POINT);
   if(point <= 0) return Inp_Trade_Distance;
   double atr_pips = atr_buf[0] / (point * g_pipsFactor[idx]);
   double dist = atr_pips * Inp_Grid_ATR_Mult;
   return MathMax(Inp_Grid_MinDist, MathMin(Inp_Grid_MaxDist, dist));
}

//+------------------------------------------------------------------+
//| MODIFY BASKET TP — filter ตาม direction อย่างเคร่งครัด           |
//+------------------------------------------------------------------+
void ModifyBasketTP(int idx, int dir, double target_tp)
{
   ENUM_POSITION_TYPE pt = (dir == DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   string sym = g_symbols[idx];
   bool modified = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != sym)       continue;
      if(PositionGetInteger(POSITION_MAGIC)  != Inp_Magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;

      double cur_tp = PositionGetDouble(POSITION_TP);
      if(MathAbs(cur_tp - target_tp) > SymbolInfoDouble(sym, SYMBOL_POINT))
         if(m_trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), target_tp))
            modified = true;
   }
   if(modified) RefreshBasket(idx, dir);
}

//+------------------------------------------------------------------+
//| APPLY BASKET TP                                                  |
//+------------------------------------------------------------------+
void ApplyBasketTP(int idx, int dir, MqlTick &tick)
{
   int    bk_count     = g_basket[idx][dir].count;
   double bk_avg_price = g_basket[idx][dir].avg_price;
   if(bk_count == 0) return;

   string sym = g_symbols[idx];
   double pips_val = SymbolInfoDouble(sym, SYMBOL_POINT) * g_pipsFactor[idx];
   double offset = ((bk_count == 1) ? Inp_TP_Initial_Pips : Inp_TP_Grid_Pips) * pips_val;

   double target_tp;
   if(dir == DIR_BUY)
      target_tp = bk_avg_price + offset;
   else
      target_tp = bk_avg_price - offset;

   ModifyBasketTP(idx, dir, target_tp);
}

//+------------------------------------------------------------------+
//| APPLY BREAKEVEN                                                  |
//+------------------------------------------------------------------+
void ApplyBreakeven(int idx, int dir, MqlTick &tick)
{
   int    bk_count     = g_basket[idx][dir].count;
   double bk_avg_price = g_basket[idx][dir].avg_price;
   if(bk_count == 0) return;

   string sym = g_symbols[idx];
   double pips_val = SymbolInfoDouble(sym, SYMBOL_POINT) * g_pipsFactor[idx];
   double profit_pips;

   if(dir == DIR_BUY)
      profit_pips = (tick.bid - bk_avg_price) / pips_val;
   else
      profit_pips = (bk_avg_price - tick.ask) / pips_val;

   if(profit_pips < Inp_BreakEven_Pips) return;

   double buffer = pips_val;
   double sl_price = (dir == DIR_BUY) ? bk_avg_price + buffer : bk_avg_price - buffer;
   ENUM_POSITION_TYPE pt = (dir == DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != sym)       continue;
      if(PositionGetInteger(POSITION_MAGIC)  != Inp_Magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;
      double cur_sl = PositionGetDouble(POSITION_SL);
      if(MathAbs(cur_sl - sl_price) > SymbolInfoDouble(sym, SYMBOL_POINT))
         m_trade.PositionModify(ticket, sl_price, PositionGetDouble(POSITION_TP));
   }
}

//+------------------------------------------------------------------+
//| APPLY TRAILING STOP                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int idx, int dir, MqlTick &tick)
{
   int    bk_count     = g_basket[idx][dir].count;
   double bk_avg_price = g_basket[idx][dir].avg_price;
   if(bk_count == 0) return;

   string sym = g_symbols[idx];
   double pips_val = SymbolInfoDouble(sym, SYMBOL_POINT) * g_pipsFactor[idx];
   double profit_pips;

   if(dir == DIR_BUY)
      profit_pips = (tick.bid - bk_avg_price) / pips_val;
   else
      profit_pips = (bk_avg_price - tick.ask) / pips_val;

   if(profit_pips < Inp_Trail_Start) return;

   double new_tp;
   if(dir == DIR_BUY)
      new_tp = tick.bid + Inp_Trail_Step * pips_val;
   else
      new_tp = tick.ask - Inp_Trail_Step * pips_val;

   ModifyBasketTP(idx, dir, new_tp);
}

//+------------------------------------------------------------------+
//| APPLY MULTI-LEVEL PARTIAL CLOSE                                  |
//| Level tracking per [symbol][dir] เพื่อไม่ fire ซ้ำทุก bar       |
//| min-lot guard เพื่อหลีกเลี่ยง [Invalid volume]                   |
//+------------------------------------------------------------------+
void InitPartialLevels()
{
   int n = ArraySize(g_symbols);
   // MQL5: ArrayResize บน [][2] กำหนด dimension แรก, dimension 2 fix ที่ 2 จาก declaration
   ArrayResize(g_partial_level, n);
   ArrayInitialize(g_partial_level, 0);
}

void ResetPartialLevel(int idx, int dir)
{
   // เรียกเมื่อ basket ปิดหมด (count กลับเป็น 0)
   g_partial_level[idx][dir] = 0;
}

void ApplyPartialClose(int idx, int dir, MqlTick &tick)
{
   if(!Inp_Use_Partial) return;
   int    bk_count     = g_basket[idx][dir].count;
   double bk_avg_price = g_basket[idx][dir].avg_price;
   if(bk_count == 0)
   {
      ResetPartialLevel(idx, dir);
      return;
   }

   string sym      = g_symbols[idx];
   double pips_val = SymbolInfoDouble(sym, SYMBOL_POINT) * g_pipsFactor[idx];
   double min_lot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double lot_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double profit_pips;

   if(dir == DIR_BUY)
      profit_pips = (tick.bid - bk_avg_price) / pips_val;
   else
      profit_pips = (bk_avg_price - tick.ask) / pips_val;

   // ระบุ level ที่ควร fire (ใช้ highest level ที่ถึงแล้ว)
   int target_level = 0;
   if(profit_pips >= Inp_Partial_Level3)      target_level = 3;
   else if(profit_pips >= Inp_Partial_Level2) target_level = 2;
   else if(profit_pips >= Inp_Partial_Level1) target_level = 1;

   // ยังไม่ถึง level ใด หรือ level นั้น fire แล้ว -> return
   if(target_level == 0 || target_level <= g_partial_level[idx][dir]) return;

   // close_pct ตาม level ที่ fire ครั้งนี้
   double close_pct = 0.0;
   if(target_level == 1) close_pct = 0.30;
   else if(target_level == 2) close_pct = 0.40;
   else if(target_level == 3) close_pct = 0.20;

   ENUM_POSITION_TYPE pt = (dir == DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   bool any_closed = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != sym)       continue;
      if(PositionGetInteger(POSITION_MAGIC)  != Inp_Magic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;

      double vol        = PositionGetDouble(POSITION_VOLUME);
      double close_vol  = vol * close_pct;

      // Normalize close_vol to lot_step
      if(lot_step > 0)
         close_vol = MathFloor(close_vol / lot_step) * lot_step;

      // Guard: close_vol ต้องไม่ต่ำกว่า min_lot และไม่มากกว่า vol ทั้งหมด
      if(close_vol < min_lot) continue;
      if(close_vol >= vol)
      {
         // ถ้า vol เหลือน้อยมากจนปิด partial ไม่ได้ ปิดทั้งหมดแทน
         m_trade.PositionClose(ticket);
      }
      else
      {
         m_trade.PositionClosePartial(ticket, close_vol);
      }
      any_closed = true;
   }

   if(any_closed)
   {
      g_partial_level[idx][dir] = target_level;  // mark level นี้ว่า fire แล้ว
      Print("[Partial] ", sym, " ", (dir==DIR_BUY?"BUY":"SELL"),
            " L", target_level, " pips=", DoubleToString(profit_pips,1),
            " pct=", DoubleToString(close_pct*100,0), "%");
      RefreshBasket(idx, dir);
   }
}

//+------------------------------------------------------------------+
//| CHECK ENTRY — พร้อม Dual-Basket Isolation Guard                  |
//+------------------------------------------------------------------+
void CheckEntry(int idx, MqlTick &tick, bool corr_guard, int total_active)
{
   // Isolation guard: ห้ามเปิด Buy ถ้า Sell basket มีอยู่ และในทางกลับกัน
   bool has_buy  = g_basket[idx][DIR_BUY].count  > 0;
   bool has_sell = g_basket[idx][DIR_SELL].count > 0;
   if(has_buy || has_sell) return;  // มี basket อยู่แล้ว → ไม่เปิดใหม่ (grid handle แยก)

   if(corr_guard) return;
   if(total_active >= Inp_Max_Symbols) return;

   double bb_up[1], bb_low[1], rsi[1];
   if(CopyBuffer(g_handleBB[idx],  1, 0, 1, bb_up)  <= 0) return;
   if(CopyBuffer(g_handleBB[idx],  2, 0, 1, bb_low) <= 0) return;
   if(CopyBuffer(g_handleRSI[idx], 0, 0, 1, rsi)    <= 0) return;

   string sym = g_symbols[idx];

   // ใช้ close price ของ bar ปัจจุบัน (bar index 0) สำหรับ BB signal
   // เหมือน v1.4 ที่ใช้ tick.last ซึ่งใน M15 Tester = close of current bar
   double close_price = iClose(sym, PERIOD_CURRENT, 0);
   if(close_price <= 0) return;

   // Sell signal: close > BB upper && RSI > Inp_RSI_Sell_Level
   if(Inp_Enable_Sell && close_price > bb_up[0] && rsi[0] > Inp_RSI_Sell_Level)
   {
      if(g_basket[idx][DIR_BUY].count == 0)
      {
         double lot = GetLot(idx, DIR_SELL);
         if(m_trade.Sell(lot, sym, tick.bid, 0, 0, "BB+RSI Sell"))
         {
            RefreshBasket(idx, DIR_SELL);
            Print("[Entry] SELL ", sym, " lot=", DoubleToString(lot,2));
            SendTelegram("SELL " + sym + " lot=" + DoubleToString(lot,2));
         }
      }
      return;
   }

   // Buy signal: close < BB lower && RSI < (100 - Inp_RSI_Max_Value)
   if(close_price < bb_low[0] && rsi[0] < (100.0 - Inp_RSI_Max_Value))
   {
      if(g_basket[idx][DIR_SELL].count == 0)
      {
         double lot = GetLot(idx, DIR_BUY);
         if(m_trade.Buy(lot, sym, tick.ask, 0, 0, "BB+RSI Buy"))
         {
            RefreshBasket(idx, DIR_BUY);
            Print("[Entry] BUY ", sym, " lot=", DoubleToString(lot,2));
            SendTelegram("BUY " + sym + " lot=" + DoubleToString(lot,2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CHECK GRID — รับ direction แยก, guard ภายใน                     |
//+------------------------------------------------------------------+
void CheckGrid(int idx, int dir, MqlTick &tick)
{
   int    bk_count      = g_basket[idx][dir].count;
   double bk_avg_price  = g_basket[idx][dir].avg_price;
   double bk_last_price = g_basket[idx][dir].last_price;
   int max_trades = (dir == DIR_SELL) ? Inp_Sell_Max_Trades : Inp_Max_Trades;
   if(bk_count == 0 || bk_count >= max_trades) return;

   // Isolation guard: ถ้า opposite basket มีอยู่ → ไม่ add grid
   int opp = (dir == DIR_BUY) ? DIR_SELL : DIR_BUY;
   if(g_basket[idx][opp].count > 0) return;

   string sym = g_symbols[idx];
   double price = (dir == DIR_BUY) ? tick.ask : tick.bid;
   double pips_val = SymbolInfoDouble(sym, SYMBOL_POINT) * g_pipsFactor[idx];
   double required_gap = GetDynamicGridDistance(idx);
   double gap = MathAbs(price - bk_avg_price) / pips_val;
   if(gap < required_gap) return;

   // Grid direction: Buy grid เพิ่มเมื่อราคาลง, Sell grid เพิ่มเมื่อราคาขึ้น
   bool should_add = false;
   if(dir == DIR_BUY  && price < bk_last_price) should_add = true;
   if(dir == DIR_SELL && price > bk_last_price) should_add = true;
   if(!should_add) return;

   double next_lot = (bk_count >= 3) ? Inp_Step_Lot2 : Inp_Step_Lot1;
   double max_lot  = (dir == DIR_SELL) ? Inp_Max_Lot * (Inp_Sell_Lot_Cap_Pct/100.0) : Inp_Max_Lot;
   next_lot = MathMin(next_lot, max_lot);

   // Compound lot ถ้า active
   if(Inp_Use_Compound && g_compound_active && !g_compound_brake[idx])
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_base_balance > 0)
         next_lot = MathMin(next_lot * (balance / g_base_balance), max_lot);
   }

   // Normalize
   double lot_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(lot_step > 0) next_lot = MathFloor(next_lot / lot_step) * lot_step;
   next_lot = MathMax(next_lot, SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN));

   bool success = false;
   if(dir == DIR_BUY)
      success = m_trade.Buy(next_lot, sym, 0, 0, 0, "Grid Buy");
   else
      success = m_trade.Sell(next_lot, sym, 0, 0, 0, "Grid Sell");

   if(success)
   {
      RefreshBasket(idx, dir);
      Print("[Grid] ", sym, " dir=", (dir==DIR_BUY?"BUY":"SELL"),
            " lot=", DoubleToString(next_lot,2), " gap=", DoubleToString(gap,1));
   }
}

//+------------------------------------------------------------------+
//| MANAGE SYMBOL — entry + grid + exit per symbol, per direction    |
//+------------------------------------------------------------------+
void ManageSymbol(int idx, int total_active, bool corr_guard)
{
   MqlTick tick;
   if(!SymbolInfoTick(g_symbols[idx], tick)) return;

   string sym    = g_symbols[idx];
   double point  = SymbolInfoDouble(sym, SYMBOL_POINT);
   double spread = (tick.ask - tick.bid) / (point * g_pipsFactor[idx]);
   if(spread > Inp_Max_Spread) return;

   bool has_any = (g_basket[idx][DIR_BUY].count > 0 || g_basket[idx][DIR_SELL].count > 0);

   // Entry: เฉพาะเมื่อยังไม่มี basket ใดๆ
   if(!has_any)
   {
      if(!IsAdxTrending(idx))
         CheckEntry(idx, tick, corr_guard, total_active);
      return;
   }

   // Exit & Grid: แยกต่อ direction
   for(int d = 0; d < 2; d++)
   {
      if(g_basket[idx][d].count == 0) continue;

      if(!IsAdxTrending(idx))
         CheckGrid(idx, d, tick);

      if(Inp_Use_Trailing)
      {
         ApplyBreakeven(idx, d, tick);
         ApplyPartialClose(idx, d, tick);
         ApplyTrailingStop(idx, d, tick);
      }
      else
         ApplyBasketTP(idx, d, tick);
   }
}

//+------------------------------------------------------------------+
//| NEW BAR CHECK per symbol                                         |
//+------------------------------------------------------------------+
bool IsNewBar(int idx)
{
   datetime current = iTime(g_symbols[idx], PERIOD_CURRENT, 0);
   if(current > g_last_bar_time[idx] && current != 0)
   {
      g_last_bar_time[idx] = current;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| RunSafetyChecks — Kill Switch + Halt + Daily Loss + Equity Trail |
//| return false = ให้หยุดทำงานทันที                                  |
//+------------------------------------------------------------------+
bool RunSafetyChecks()
{
   // 1. Permanent Kill Switch
   if(Inp_KillSwitch || IsKillSwitchBreached())
   {
      if(!g_kill_triggered)
      {
         g_kill_triggered = true;
         CloseAllPositions("Kill Switch DD=" + DoubleToString(Inp_KillSwitch_DD_Pct,1) + "%");
         SendTelegram("9AU_3PAIRS: KILL SWITCH ACTIVATED. EA stopped.");
         ExpertRemove();
      }
      return false;
   }
   if(g_kill_triggered) return false;

   // 2. Temporary halt check
   if(g_halt_trading)
   {
      if(TimeCurrent() < g_halt_until) return false;
      g_halt_trading = false;
      Print("[Halt] Trading resumed");
      SendTelegram("9AU_3PAIRS: Trading resumed");
   }

   // 3. Daily reset
   CheckDailyReset();

   // 4. Daily Loss Limit
   if(IsDailyLossExceeded())
   {
      CloseAllPositions("Daily Loss Limit " + DoubleToString(Inp_Max_Daily_Loss_Pct,1) + "%");
      g_halt_trading = true;
      datetime tomorrow = (TimeCurrent() - TimeCurrent() % 86400) + 86400;
      g_halt_until = tomorrow;
      SendTelegram("9AU_3PAIRS: Daily Loss Limit reached. Halted until tomorrow.");
      return false;
   }

   // 5. Equity Trail Stop
   if(IsEquityTrailBreached())
   {
      CloseAllPositions("Equity Trail " + DoubleToString(Inp_Equity_Trail_DD_Pct,1) + "% from peak");
      g_halt_trading = true;
      g_halt_until = TimeCurrent() + 3600;
      SendTelegram("9AU_3PAIRS: Equity Trail Stop. Halted 1 hour.");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| OnTick — Main loop: Safety + Trading (ทำงานทั้ง Tester และ Live) |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!RunSafetyChecks()) return;

   // Update compound state
   UpdateCompoundState();

   // Refresh all baskets
   for(int i = 0; i < ArraySize(g_symbols); i++)
   {
      RefreshBasket(i, DIR_BUY);
      RefreshBasket(i, DIR_SELL);
   }

   // Correlation guard
   bool corr_guard = IsCorrelationDDBreached();

   // Count active symbols
   int total_active = 0;
   for(int i = 0; i < ArraySize(g_symbols); i++)
      if(g_basket[i][DIR_BUY].count > 0 || g_basket[i][DIR_SELL].count > 0)
         total_active++;

   // Trading logic per symbol — new bar gate
   for(int i = 0; i < ArraySize(g_symbols); i++)
      if(IsNewBar(i))
         ManageSymbol(i, total_active, corr_guard);
}

//+------------------------------------------------------------------+
//| OnTimer — Safety check สำรอง สำหรับ Live เท่านั้น               |
//| ใน Tester: OnTimer ไม่ reliable บน M15 จึงไม่ใช้เป็น main loop  |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(MQLInfoInteger(MQL_TESTER)) return;  // ข้ามใน Tester ทั้งหมด
   RunSafetyChecks();
}
//+------------------------------------------------------------------+
