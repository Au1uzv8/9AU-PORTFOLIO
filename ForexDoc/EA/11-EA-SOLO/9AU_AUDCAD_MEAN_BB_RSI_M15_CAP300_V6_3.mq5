//+------------------------------------------------------------------+
//|                      9AU_AUDCAD_MEAN_BB_RSI_M15_CAP300_V6_3.mq5  |
//|                                               Consultant: James  |
//|                         Principles: Game Theory + Occam's Razor  |
//|                                 Safety-First + High Performance  |
//+------------------------------------------------------------------+
#property copyright "9Au & James Expert Consultant"
#property version   "6.3"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\DealInfo.mqh>

//--- INPUT PARAMETERS ---
input group "== Global Settings =="
input string   Inp_Symbols          = "AUDCAD#"; 
input long     Inp_Magic            = 515251;                
input double   Inp_Max_Drawdown_Pct = 12.0;   // Best Result Previous = 18.0                   
input int      Inp_Max_Symbols      = 1;                      

input group "== Lot Sizing & Risk =="
input double   Inp_Fixed_Lot        = 0.01;   // Best Result Previous = 0.02                
input double   Inp_Max_Lot          = 0.3;                    
input double   Inp_Max_Spread       = 2.5;   // Previous = 2.5                    

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
input double   Inp_RSI_Max_Value    = 68.0;                   
input double   Inp_TP_Initial_Pips  = 15.0;                   
input double   Inp_TP_Grid_Pips     = 10.0;                   

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
};

PositionCache g_pos_cache[];

//--- GLOBAL VARIABLES ---
CTrade             m_trade;
string             g_symbols[];
int                g_handleBB[], g_handleRSI[];
double             g_pipsFactor[];
datetime           g_last_bar_time[];

//--- Risk Manager Globals (v1.40) ---
datetime           g_last_day = 0;
double             g_day_start_equity = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(Inp_Magic);
   m_trade.SetDeviationInPoints(10);
   EventSetTimer(1);
   
   string temp_arr[];
   int count = StringSplit(Inp_Symbols, ',', temp_arr);
   
   ArrayResize(g_symbols, count);
   ArrayResize(g_handleBB, count);
   ArrayResize(g_handleRSI, count);
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
      
      if(g_handleBB[i] == INVALID_HANDLE || g_handleRSI[i] == INVALID_HANDLE)
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
      
      g_last_bar_time[i] = 0;
   }
   
   g_last_day = 0;
   g_day_start_equity = 0.0;
   
   Print("9AU_AUDCAD initialized with Breakeven + Daily Loss Limit 5% + Max DD 12%");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   for(int i = 0; i < ArraySize(g_handleBB); i++)
   {
      if(g_handleBB[i] != INVALID_HANDLE) IndicatorRelease(g_handleBB[i]);
      if(g_handleRSI[i] != INVALID_HANDLE) IndicatorRelease(g_handleRSI[i]);
   }
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
      g_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      Print("New trading day started. Day start equity: ", DoubleToString(g_day_start_equity, 2));
   }
}

bool IsDailyLossExceeded()
{
   if(g_day_start_equity <= 0) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return equity < g_day_start_equity * (1.0 - Inp_Max_Daily_Loss_Pct / 100.0 + 0.000001);
}

//+------------------------------------------------------------------+
//| Timer function - main logic                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckDailyReset();
   
   if(IsDrawdownExceeded() || IsDailyLossExceeded())
   {
      CloseAllPositions(IsDrawdownExceeded() ? "Max Drawdown 12% Reached" : "Max Daily Loss 5% Reached");
      return;
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
   double bb_up[1], bb_low[1], rsi[1];
   if(CopyBuffer(g_handleBB[index], 1, 0, 1, bb_up) <= 0 ||
      CopyBuffer(g_handleBB[index], 2, 0, 1, bb_low) <= 0 ||
      CopyBuffer(g_handleRSI[index], 0, 0, 1, rsi) <= 0)
      return;
   
   if(tick.last > bb_up[0] && rsi[0] > Inp_RSI_Max_Value)
   {
      if(m_trade.Sell(Inp_Fixed_Lot, g_symbols[index], tick.bid, 0, 0, "BB+RSI Sell"))
         RefreshPositionCache(index);
      else
         Print("Trade Error Sell ", g_symbols[index], ": ", m_trade.ResultRetcodeDescription());
   }
   else if(tick.last < bb_low[0] && rsi[0] < (100.0 - Inp_RSI_Max_Value))
   {
      if(m_trade.Buy(Inp_Fixed_Lot, g_symbols[index], tick.ask, 0, 0, "BB+RSI Buy"))
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
      next_lot = MathMin(next_lot, Inp_Max_Lot);
      
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
   if(profit_pips >= Inp_Partial_Level3)      close_pct = 0.20;
   else if(profit_pips >= Inp_Partial_Level2) close_pct = 0.40;
   else if(profit_pips >= Inp_Partial_Level1) close_pct = 0.30;
   
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
//| Drawdown check                                                   |
//+------------------------------------------------------------------+
bool IsDrawdownExceeded()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   return (balance - equity) > (balance * Inp_Max_Drawdown_Pct / 100.0 + 0.000001);
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
