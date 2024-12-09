# bongkem//+------------------------------------------------------------------+
//|                                  MorningEvening StarDoji RSI.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

#define SIGNAL_BUY    1             // Buy signal (Tín hiệu mua)
#define SIGNAL_NOT    0             // no trading signal (không có tín hiệu giao dịch)
#define SIGNAL_SELL  -1             // Sell signal (Tín hiệu bán)

#define CLOSE_LONG    2             // signal to close Long (Tín hiệu đóng vị thế mua)
#define CLOSE_SHORT  -2             // signal to close Short (Tín hiệu đóng vị thế bán)

//--- Input parameters
input int InpAverBodyPeriod=12; // period for calculating average candlestick size (kỳ để tính kích thước trung bình của nến)
input int InpPeriodRSI =37; // RSI period (kỳ của RSI)
input ENUM_APPLIED_PRICE InpPrice=PRICE_CLOSE; // price type (loại giá)

//--- trade parameters
input uint InpDuration=10; // position holding time in bars (thời gian giữ vị thế tính theo số thanh nến)
input uint InpSL =200; // Stop Loss in points (Dừng lỗ tính theo điểm)
input uint InpTP =200; // Take Profit in points (Chốt lời tính theo điểm)
input uint InpSlippage=10; // slippage in points (độ trượt tính theo điểm)
//--- money management parameters
input double InpLot=0.1; // lot (lô giao dịch)
//--- Expert ID
input long InpMagicNumber=130300;   // Magic Number (Số Magic)

//--- global variables
int ExtAvgBodyPeriod; // average candlestick calculation period (kỳ tính kích thước trung bình của nến)
int ExtSignalOpen =0; // Buy/Sell signal (Tín hiệu mua/bán)
int ExtSignalClose =0; // signal to close a position (Tín hiệu đóng vị thế)
string ExtPatternInfo =""; // current pattern information (Thông tin mẫu hình hiện tại)
string ExtDirection =""; // position opening direction (Hướng mở vị thế)
bool ExtPatternDetected=false; // pattern detected (Mẫu hình được phát hiện)
bool ExtConfirmed =false; // pattern confirmed (Mẫu hình được xác nhận)
bool ExtCloseByTime =true; // requires closing by time (Yêu cầu đóng vị thế theo thời gian)
bool ExtCheckPassed =true; // status checking error (Lỗi kiểm tra trạng thái)
//---  indicator handle
int    ExtIndicatorHandle=INVALID_HANDLE;

//--- service objects
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("InpSL=", InpSL); // In ra giá trị của InpSL
   Print("InpTP=", InpTP); // In ra giá trị của InpTP
//--- set parameters for trading operations (thiết lập các tham số cho hoạt động giao dịch)
   ExtTrade.SetDeviationInPoints(InpSlippage); // slippage (độ trượt giá)
   ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Expert Advisor ID (ID của Chuyên gia Cố vấn)
   ExtTrade.LogLevel(LOG_LEVEL_ERRORS); // logging level (mức độ ghi nhật ký)

   ExtAvgBodyPeriod=InpAverBodyPeriod;
//--- indicator initialization (khởi tạo chỉ báo)
   ExtIndicatorHandle=iRSI(_Symbol, _Period, InpPeriodRSI, InpPrice);
   if(ExtIndicatorHandle==INVALID_HANDLE)
     {
      Print("Error creating RSI indicator"); // In ra lỗi khi tạo chỉ báo RSI
      return(INIT_FAILED);
     }
//--- OK
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- release indicator handle (giải phóng handle của chỉ báo)
   IndicatorRelease(ExtIndicatorHandle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- save the next bar start time; all checks at bar opening only lưu thời gian bắt đầu thanh nến tiếp theo; tất cả các kiểm tra chỉ thực hiện khi mở thanh nến
   static datetime next_bar_open=0; 

//--- Phase 1 - check the emergence of a new bar and update the status
   if(TimeCurrent()>=next_bar_open)
     {
      //--- get the current state of environment on the new bar (lấy trạng thái hiện tại của môi trường trên thanh nến mới)
      // namely, set the values of global variables: (cụ thể là, thiết lập các giá trị của biến toàn cục)
      // ExtPatternDetected - pattern detection (phát hiện mẫu hình)
      // ExtConfirmed - pattern confirmation (xác nhận mẫu hình)
      // ExtSignalOpen - signal to open (tín hiệu để mở)
      // ExtSignalClose - signal to close (tín hiệu để đóng)
      // ExtPatternInfo - current pattern information (thông tin mẫu hình hiện tại)
      if(CheckState())
        { 
        //--- set the new bar opening time (thiết lập thời gian mở thanh nến mới)
         next_bar_open=TimeCurrent();
         next_bar_open-=next_bar_open%PeriodSeconds(_Period);
         next_bar_open+=PeriodSeconds(_Period);

         //--- report the emergence of a new bar only once within a bar (báo cáo sự xuất hiện của thanh nến mới chỉ một lần trong mỗi thanh nến)
         if(ExtPatternDetected && ExtConfirmed)
            Print(ExtPatternInfo);
        }
      else
        {
         //--- error getting the status, retry on the next tick
         return;
        }
     }

//--- Phase 2 - if there is a signal and no position in this direction (nếu có tín hiệu và không có vị thế theo hướng này)
   if(ExtSignalOpen && !PositionExist(ExtSignalOpen))
     {
      Print("\r\nSignal to open position ", ExtDirection);
      PositionOpen();
      if(PositionExist(ExtSignalOpen))
         ExtSignalOpen=SIGNAL_NOT;
     }

//--- Phase 3 - close if there is a signal to close (đóng nếu có tín hiệu để đóng)
   if(ExtSignalClose && PositionExist(ExtSignalClose))
     {
      Print("\r\nSignal to close position ", ExtDirection);
      CloseBySignal(ExtSignalClose);
      if(!PositionExist(ExtSignalClose))
         ExtSignalClose=SIGNAL_NOT;
     }

//--- Phase 4 - close upon expiration (đóng khi hết hạn)
   if(ExtCloseByTime && PositionExpiredByTimeExist())
     {
      CloseByTime();
      ExtCloseByTime=PositionExpiredByTimeExist();
     }
  }
//+------------------------------------------------------------------+
//| Get the current environment and check for a pattern | // Lấy môi trường hiện tại và kiểm tra mẫu hình
//+------------------------------------------------------------------+
bool CheckState()
  {
//--- check if there is a pattern (kiểm tra xem có mẫu hình hay không)
   if(!CheckPattern())
     {
      Print("Error, failed to check pattern");
      return(false);
     }

//--- check for confirmation (kiểm tra xác nhận)
   if(!CheckConfirmation())
     {
      Print("Error, failed to check pattern confirmation");
      return(false);
     }
//--- if there is no confirmation, cancel the signal (nếu không có xác nhận, hủy tín hiệu)
   if(!ExtConfirmed)
      ExtSignalOpen=SIGNAL_NOT;

//--- check if there is a signal to close a position (kiểm tra xem có tín hiệu đóng vị thế hay không)
   if(!CheckCloseSignal())
     {
      Print("Error, failed to check the closing signal");
      return(false);
     }
     
//--- if positions are to be closed after certain holding time in bars (nếu các vị thế cần được đóng sau một thời gian giữ nhất định tính theo số thanh nến)
   if(InpDuration)
      ExtCloseByTime=true; // set flag to close upon expiration
     
//--- all checks done (tất cả các kiểm tra đã xong)
   return(true);
  }
//+------------------------------------------------------------------+
//| Open a position in the direction of the signal | // Mở vị thế theo hướng của tín hiệu
//+------------------------------------------------------------------+
bool PositionOpen()
  {
   ExtSymbolInfo.Refresh();
   ExtSymbolInfo.RefreshRates(); // Làm mới tỷ giá và thông tin biểu đồ

   double price=0;
//--- Stop Loss and Take Profit are not set by default (Dừng lỗ và Chốt lời không được thiết lập theo mặc định)
   double stoploss=0.0;
   double takeprofit=0.0;

   int    digits=ExtSymbolInfo.Digits();
   double point=ExtSymbolInfo.Point();
   double spread=ExtSymbolInfo.Ask()-ExtSymbolInfo.Bid();

//--- uptrend (Xu hướng tăng)
   if(ExtSignalOpen==SIGNAL_BUY)
     {
      price=NormalizeDouble(ExtSymbolInfo.Ask(), digits); // Lấy giá hỏi (Ask) và chuẩn hóa số chữ số thập phân
      //--- if Stop Loss is set (nếu Dừng lỗ được thiết lập)
      if(InpSL>0)
        {
         if(spread>=InpSL*point)
           {
            PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread/point);
            stoploss = NormalizeDouble(price-spread, digits);
           }
         else
            stoploss = NormalizeDouble(price-InpSL*point, digits);
        }
      //--- if Take Profit is set (nếu Chốt lời được thiết lập)
      if(InpTP>0)
        {
         if(spread>=InpTP*point)
           {
            PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
            takeprofit = NormalizeDouble(price+spread, digits);
           }
         else
            takeprofit = NormalizeDouble(price+InpTP*point, digits);
        }

      if(!ExtTrade.Buy(InpLot, Symbol(), price, stoploss, takeprofit))
        {
         PrintFormat("Failed %s buy %G at %G (sl=%G tp=%G) failed. Ask=%G error=%d",
                     Symbol(), InpLot, price, stoploss, takeprofit, ExtSymbolInfo.Ask(), GetLastError());
         return(false);
        }
     }

//--- downtrend (Xu hướng giảm)
   if(ExtSignalOpen==SIGNAL_SELL)
     {
      price=NormalizeDouble(ExtSymbolInfo.Bid(), digits);
      //--- if Stop Loss is set (nếu Dừng lỗ được thiết lập)
      if(InpSL>0)
        {
         if(spread>=InpSL*point)
           {
            PrintFormat("StopLoss (%d points) <= current spread = %.0f points. Spread value will be used", InpSL, spread/point);
            stoploss = NormalizeDouble(price+spread, digits);
           }
         else
            stoploss = NormalizeDouble(price+InpSL*point, digits);
        }
      //--- if Take Profit is set (nếu Chốt lời được thiết lập)
      if(InpTP>0)
        {
         if(spread>=InpTP*point)
           {
            PrintFormat("TakeProfit (%d points) < current spread = %.0f points. Spread value will be used", InpTP, spread/point);
            takeprofit = NormalizeDouble(price-spread, digits);
           }
         else
            takeprofit = NormalizeDouble(price-InpTP*point, digits);
        }

      if(!ExtTrade.Sell(InpLot, Symbol(), price,  stoploss, takeprofit))
        {
         PrintFormat("Failed %s sell at %G (sl=%G tp=%G) failed. Bid=%G error=%d",
                     Symbol(), price, stoploss, takeprofit, ExtSymbolInfo.Bid(), GetLastError());
         ExtTrade.PrintResult();
         Print("   ");
         return(false);
        }
     }

   return(true);
  }
//+------------------------------------------------------------------+
//| Close a position based on the specified signal | // Đóng vị thế dựa trên tín hiệu đã chỉ định
//+------------------------------------------------------------------+
void CloseBySignal(int type_close)
  {
//--- if there is no signal to close, return successful completion (nếu không có tín hiệu để đóng, trả về hoàn thành thành công)
   if(type_close==SIGNAL_NOT)
      return;
//--- if there are no positions opened by our EA (nếu không có vị thế nào được mở bởi EA của chúng ta)
   if(PositionExist(ExtSignalClose)==0)
      return;

//--- closing direction (hướng đóng vị thế)
   long type;
   switch(type_close)
     {
      case CLOSE_SHORT:
         type=POSITION_TYPE_SELL;
         break;
      case CLOSE_LONG:
         type=POSITION_TYPE_BUY;
         break;
      default:
         Print("Error! Signal to close not detected");
         return;
     }

//--- check all positions and close ours based on the signal (kiểm tra tất cả các vị thế và đóng các vị thế của chúng ta dựa trên tín hiệu)
   int positions=PositionsTotal();
   for(int i=positions-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket!=0)
        {
         //--- get the name of the symbol and the position id (magic) (lấy tên biểu đồ và ID vị thế (magic))
         string symbol=PositionGetString(POSITION_SYMBOL);
         long   magic =PositionGetInteger(POSITION_MAGIC);
         //--- if they correspond to our values (nếu chúng tương ứng với giá trị của chúng ta)
         if(symbol==Symbol() && magic==InpMagicNumber)
           {
            if(PositionGetInteger(POSITION_TYPE)==type)
              {
               ExtTrade.PositionClose(ticket, InpSlippage);
               ExtTrade.PrintResult();
               Print("   ");
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Close positions upon holding time expiration in bars | // Đóng các vị thế khi hết thời gian giữ vị thế tính theo số thanh nến
//+------------------------------------------------------------------+
void CloseByTime()
  {
//--- if there are no positions opened by our EA (nếu không có vị thế nào được mở bởi EA của chúng ta)
   if(PositionExist(ExtSignalOpen)==0)
      return;

//--- check all positions and close ours based on the holding time in bars (kiểm tra tất cả các vị thế và đóng các vị thế của chúng ta dựa trên thời gian giữ vị thế tính theo số thanh nến)
   int positions=PositionsTotal();
   for(int i=positions-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket!=0)
        {
         //--- get the name of the symbol and the position id (magic) (lấy tên biểu đồ và ID vị thế (magic))
         string symbol=PositionGetString(POSITION_SYMBOL);
         long   magic =PositionGetInteger(POSITION_MAGIC);
         //--- if they correspond to our values (nếu chúng tương ứng với giá trị của chúng ta)
         if(symbol==Symbol() && magic==InpMagicNumber)
           {
            //--- position opening time (thời gian mở vị thế)
            datetime open_time=(datetime)PositionGetInteger(POSITION_TIME);
            //--- check position holding time in bars (kiểm tra thời gian giữ vị thế tính theo số thanh nến)
            if(BarsHold(open_time)>=(int)InpDuration)
              {
               Print("\r\nTime to close position #", ticket);
               ExtTrade.PositionClose(ticket, InpSlippage);
               ExtTrade.PrintResult();
               Print("   ");
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Returns true if there are open positions | // Trả về true nếu có vị thế mở
//+------------------------------------------------------------------+
bool PositionExist(int signal_direction)
  {
   bool check_type=(signal_direction!=SIGNAL_NOT);

//--- what positions to search
   ENUM_POSITION_TYPE search_type=WRONG_VALUE;
   if(check_type)
      switch(signal_direction)
        {
         case SIGNAL_BUY:
            search_type=POSITION_TYPE_BUY;
            break;
         case SIGNAL_SELL:
            search_type=POSITION_TYPE_SELL;
            break;
         case CLOSE_LONG:
            search_type=POSITION_TYPE_BUY;
            break;
         case CLOSE_SHORT:
            search_type=POSITION_TYPE_SELL;
            break;
         default:
            //--- entry direction is not specified; nothing to search
            return(false);
        }

//--- go through the list of all positions
   int positions=PositionsTotal();
   for(int i=0; i<positions; i++)
     {
      if(PositionGetTicket(i)!=0)
        {
         //--- if the position type does not match, move on to the next one
         ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(check_type && (type!=search_type))
            continue;
         //--- get the name of the symbol and the expert id (magic number)
         string symbol =PositionGetString(POSITION_SYMBOL);
         long   magic  =PositionGetInteger(POSITION_MAGIC);
         //--- if they correspond to our values
         if(symbol==Symbol() && magic==InpMagicNumber)
           {
            //--- yes, this is the right position, stop the search
            return(true);
           }
        }
     }

//--- open position not found
   return(false);
  }
//+------------------------------------------------------------------+
//| Returns true if there are open positions with expired time       |
//+------------------------------------------------------------------+
bool PositionExpiredByTimeExist()
  {
//--- go through the list of all positions
   int positions=PositionsTotal();
   for(int i=0; i<positions; i++)
     {
      if(PositionGetTicket(i)!=0)
        {
         //--- get the name of the symbol and the expert id (magic number)
         string symbol =PositionGetString(POSITION_SYMBOL);
         long   magic  =PositionGetInteger(POSITION_MAGIC);
         //--- if they correspond to our values
         if(symbol==Symbol() && magic==InpMagicNumber)
           {
            //--- position opening time
            datetime open_time=(datetime)PositionGetInteger(POSITION_TIME);
            //--- check position holding time in bars
            int check=BarsHold(open_time);
            //--- id the value is -1, the check completed with an error
            if(check==-1 || (BarsHold(open_time)>=(int)InpDuration))
               return(true);
           }
        }
     }

//--- open position not found
   return(false);
  }
//+------------------------------------------------------------------+
//| Checks position closing time in bars                             |
//+------------------------------------------------------------------+
int BarsHold(datetime open_time)
  {
//--- first run a basic simple check
   if(TimeCurrent()-open_time<PeriodSeconds(_Period))
     {
      //--- opening time is inside the current bar
      return(0);
     }
//---
   MqlRates bars[];
   if(CopyRates(_Symbol, _Period, open_time, TimeCurrent(), bars)==-1)
     {
      Print("Error. CopyRates() failed, error = ", GetLastError());
      return(-1);
     }
//--- check position holding time in bars
   return(ArraySize(bars));
  }
//+------------------------------------------------------------------+
//| Returns the open price of the specified bar                      |
//+------------------------------------------------------------------+
double Open(int index)
  {
   double val=iOpen(_Symbol, _Period, index);
//--- if the current check state was successful and an error was received
   if(ExtCheckPassed && val==0)
      ExtCheckPassed=false;   // switch the status to failed

   return(val);
  }
//+------------------------------------------------------------------+
//| Returns the close price of the specified bar                     |
//+------------------------------------------------------------------+
double Close(int index)
  {
   double val=iClose(_Symbol, _Period, index);
//--- if the current check state was successful and an error was received
   if(ExtCheckPassed && val==0)
      ExtCheckPassed=false;   // switch the status to failed

   return(val);
  }
//+------------------------------------------------------------------+
//| Returns the low price of the specified bar                       |
//+------------------------------------------------------------------+
double Low(int index)
  {
   double val=iLow(_Symbol, _Period, index);
//--- if the current check state was successful and an error was received
   if(ExtCheckPassed && val==0)
      ExtCheckPassed=false;   // switch the status to failed

   return(val);
  }
//+------------------------------------------------------------------+
//| Returns the high price of the specified bar                      |
//+------------------------------------------------------------------+
double High(int index)
  {
   double val=iHigh(_Symbol, _Period, index);
//--- if the current check state was successful and an error was received
   if(ExtCheckPassed && val==0)
      ExtCheckPassed=false;   // switch the status to failed

   return(val);
  }
//+------------------------------------------------------------------+
//| Returns the middle body price for the specified bar              |
//+------------------------------------------------------------------+
double MidPoint(int index)
  {
   return(High(index)+Low(index))/2.;
  }
//+------------------------------------------------------------------+
//| Returns the middle price of the range for the specified bar      |
//+------------------------------------------------------------------+
double MidOpenClose(int index)
  {
   return((Open(index)+Close(index))/2.);
  }
//+------------------------------------------------------------------+
//| Returns the average candlestick body size for the specified bar  |
//+------------------------------------------------------------------+
double AvgBody(int index)
  {
   double sum=0;
   for(int i=index; i<index+ExtAvgBodyPeriod; i++)
     {
      sum+=MathAbs(Open(i)-Close(i));
     }
   return(sum/ExtAvgBodyPeriod);
  }
//+------------------------------------------------------------------+
//| Returns true in case of successful pattern check                 |
//+------------------------------------------------------------------+
bool CheckPattern()
  {
   ExtPatternDetected=false;
//--- check if there is a pattern (kiểm tra xem có mẫu hình hay không)
   ExtSignalOpen=SIGNAL_NOT;
   ExtPatternInfo="\r\nPattern not detected"; // Mẫu hình không được phát hiện
   ExtDirection="";

//--- check Evening Doji (kiểm tra Evening Doji)
   if((Close(3)-Open(3)>AvgBody(1))                && // bullish candlestick, its body is larger than average (nến tăng, thân nến lớn hơn trung bình) 
      (MathAbs(Close(2)-Open(2))<AvgBody(1)*0.1)   && // second candlestick body is doji (less than one tenth of the average candle body) (thân nến thứ hai là doji (ít hơn một phần mười của thân nến trung bình))
      (Close(2)>Close(3))                          && // second candlestick close is higher than first candlestick close (giá đóng của nến thứ hai cao hơn giá đóng của nến đầu tiên)
      (Open(2)>Open(3))                            && // second candlestick open is higher than first candlestick open (giá mở của nến thứ hai cao hơn giá mở của nến đầu tiên)
      (Open(1)<Close(2))                           && // down price gap on the last candlestick (khoảng cách giá giảm trên nến cuối cùng)
      (Close(1)<Close(2)))                            // last candlestick close lower than second candlestick close (giá đóng của nến cuối cùng thấp hơn giá đóng của nến thứ hai)
     {
      ExtPatternDetected=true;
      ExtSignalOpen=SIGNAL_SELL;
      ExtPatternInfo="\r\nEvening Doji detected"; // Phát hiện Evening Doji
      ExtDirection="Sell";
      return(true);
     }

//--- check Evening Star (kiểm tra Evening Star)
   if((Close(3)-Open(3)>AvgBody(1))                 && // bullish candlestick, its body is larger than average (nến tăng, thân nến lớn hơn trung bình) 
      (MathAbs(Close(2)-Open(2))<AvgBody(1)*0.5)    && // second candlestick body is short (less than a half of the average candle body) (thân nến thứ hai ngắn (ít hơn một nửa của thân nến trung bình))
      (Close(2)>Close(3))                           && // second candlestick close is higher than first candlestick close (giá đóng của nến thứ hai cao hơn giá đóng của nến đầu tiên)
      (Open(2)>Open(3))                             && // second candlestick open is higher than first candlestick open (giá mở của nến thứ hai cao hơn giá mở của nến đầu tiên)
      (Close(1)<MidOpenClose(3)))                      // last candlestick close is lower than the middle of the first (bullish) one (giá đóng của nến cuối cùng thấp hơn giữa nến đầu tiên (tăng))  
     {
      ExtPatternDetected=true;
      ExtSignalOpen=SIGNAL_SELL;
      ExtPatternInfo="\r\nEvening Star detected"; // Phát hiện Evening Star
      ExtDirection="Sell";
      return(true);
     }

//--- check Morning Doji (kiểm tra Morning Doji) 
  if((Open(3)-Close(3)>AvgBody(1))                && // bearish candlestick, its body is larger than average (nến giảm, thân của nó lớn hơn trung bình) 
      (MathAbs(Close(2)-Open(2))<AvgBody(1)*0.1)  && // second candlestick body is doji (less than one tenth of the average candle body) (thân nến thứ hai là doji (nhỏ hơn một phần mười thân nến trung bình)) 
      (Close(2)<Close(3))                         && // second candlestick close is lower than first candlestick close (giá đóng của nến thứ hai thấp hơn giá đóng của nến thứ nhất) 
      (Open(2)<Open(3))                           && // second candlestick open is lower than first candlestick open (giá mở của nến thứ hai thấp hơn giá mở của nến thứ nhất) 
      (Open(1)>Close(2))                          && // upward price gap on the last candlestick (khoảng giá tăng trên nến cuối cùng) 
      (Close(1)>Close(2)))                           // last candlestick close higher than second candlestick close (giá đóng của nến cuối cùng cao hơn giá đóng của nến thứ hai)
     { 
      ExtPatternDetected=true;
      ExtSignalOpen=SIGNAL_BUY;
      ExtPatternInfo="\r\nMorning Doji detected";
      ExtDirection="Buy";
      return(true);
     }
     
//--- check Morning Star (kiểm tra Morning Star)
  if((Open(3)-Close(3)>AvgBody(1))                 && // bearish candlestick, its body is larger than average (nến giảm, thân của nó lớn hơn trung bình)
      (MathAbs(Close(2)-Open(2))<AvgBody(1)*0.5)   && // second candlestick body is short (less than a half of the average candle body) (thân nến thứ hai ngắn (nhỏ hơn một nửa thân nến trung bình))
      (Close(2)<Close(3))                          && // second candlestick close is lower than first candlestick close (giá đóng của nến thứ hai thấp hơn giá đóng của nến thứ nhất)  
      (Open(2)<Open(3))                            && // second candlestick open is lower than first candlestick open (giá mở của nến thứ hai thấp hơn giá mở của nến thứ nhất)
      (Close(1)>MidOpenClose(3)))                     // last candlestick close is lower than the middle of the first (bearish) one (giá đóng của nến cuối cùng cao hơn giá giữa của nến đầu tiên (nến giảm))
     {
      ExtPatternDetected=true;
      ExtSignalOpen=SIGNAL_BUY;
      ExtPatternInfo="\r\nMorning Star detected";
      ExtDirection="Buy";
      return(true);
     }     

//--- result of checking
   return(ExtCheckPassed);
  }
//+------------------------------------------------------------------+
//| Returns true in case of successful confirmation check            |
//+------------------------------------------------------------------+
bool CheckConfirmation()
  {
   ExtConfirmed=false;
//--- if there is no pattern, do not search for confirmation
   if(!ExtPatternDetected)
      return(true);

//--- get the value of the stochastic indicator to confirm the signal
   double signal=RSI(1);
   if(signal==EMPTY_VALUE)
     {
      //--- failed to get indicator value, check failed
      return(false);
     }

//--- check the Buy signal
   if(ExtSignalOpen==SIGNAL_BUY && (signal<40))
     {
      ExtConfirmed=true;
      ExtPatternInfo+="\r\n   Confirmed: RSI<40";
     }

//--- check the Sell signal
   if(ExtSignalOpen==SIGNAL_SELL && (signal>60))
     {
      ExtConfirmed=true;
      ExtPatternInfo+="\r\n   Confirmed: RSI>60";
     }

//--- successful completion of the check
   return(true);
  }
//+------------------------------------------------------------------+
//| Check if there is a signal to close                              |
//+------------------------------------------------------------------+
bool CheckCloseSignal()
  {
   ExtSignalClose=false;
//--- if there is a signal to enter the market, do not check the signal to close (nếu có tín hiệu để vào thị trường, không kiểm tra tín hiệu để đóng)
   if(ExtSignalOpen!=SIGNAL_NOT)
      return(true);

//--- check if there is a signal to close a long position (kiểm tra xem có tín hiệu để đóng vị thế mua không)
   if(((RSI(1)<70) && (RSI(2)>70)) || ((RSI(1)<30) && (RSI(2)>30)))
     {
      //--- there is a signal to close a long position (có tín hiệu để đóng vị thế mua)
      ExtSignalClose=CLOSE_LONG;
      ExtDirection="Long";
     }

//--- check if there is a signal to close a short position (kiểm tra xem có tín hiệu để đóng vị thế bán không)
   if(((RSI(1)>30) && (RSI(2)<30)) || ((RSI(1)>70) && (RSI(2)<70)))
     {
     //--- there is a signal to close a short position (có tín hiệu để đóng vị thế bán)
      ExtSignalClose=CLOSE_SHORT;
      ExtDirection="Short";
     }

//--- successful completion of the check
   return(true);
  }
//+------------------------------------------------------------------+
//| RSI indicator value at the specified bar                         |
//+------------------------------------------------------------------+
double RSI(int index)
  {
   double indicator_values[];
   if(CopyBuffer(ExtIndicatorHandle, 0, index, 1, indicator_values)<0)
     {
      //--- if the copying fails, report the error code
      PrintFormat("Failed to copy data from the RSI indicator, error code %d", GetLastError());
      return(EMPTY_VALUE);
     }
   return(indicator_values[0]);
  }
//+------------------------------------------------------------------+
