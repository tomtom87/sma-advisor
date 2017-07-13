//+------------------------------------------------------------------+
//|                                               Double Sma ATR.mq4 |
//|                          Copyright 2017, Tom Whitbread + Mercury |
//|                                           http://www.gript.co.uk |
//+------------------------------------------------------------------+
#property copyright   "2017, Tom Whitbread & Mercury."
#property link        "http://www.gript.co.uk"
#property description "Smoothed Moving Average sample expert advisor"

#define MAGICNUM  20131111

// Define our Parameters
input double Lots          = 0.1;
input int PeriodOne        = 25; // The period for the first SMA
input int PeriodTwo        = 100; // The period for the second SMA
input int TakeProfit       = 0; // The take profit level (0 disable)
input int StopLoss         = 20; // The default stop loss (0 disable)
//+------------------------------------------------------------------+
//| expert initialization functions                                  |
//+------------------------------------------------------------------+
int init()
{
  return(0);
}
int deinit()
{
  return(0);
}
//+------------------------------------------------------------------+
//| Check for cross over of SMA                                      |
//+------------------------------------------------------------------+
int CheckForCross(double input1, double input2)
{
  static int previous_direction = 0;
  static int current_direction  = 0;

  // Up Direction = 1
  if(input1 > input2){
    current_direction = 1;
  }

  // Down Direction = 2
  if(input1 < input2){
    current_direction = 2;
  }

  // Detect a direction change
  if(current_direction != previous_direction){
    previous_direction = current_direction;
    return (previous_direction);
  } else {
    return (0);
  }
}

//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double LotsOptimized()
  {
   double lot = Lots;
   // Calculate Lot size as a fifth of available free equity.
   lot = NormalizeDouble((AccountFreeMargin()/5)/1000.0,1);
   if(lot<0.1) lot=0.1; //Ensure the minimal amount is 0.1 lots
   return(lot);
  }


//+------------------------------------------------------------------+
//+ Break Even                                                       |
//+------------------------------------------------------------------+
bool BreakEven(int MN){
  int Ticket;

  for(int i = OrdersTotal() - 1; i >= 0; i--) {
    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);

    if(OrderSymbol() == Symbol() && OrderMagicNumber() == MN){
      Ticket = OrderModify(OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), OrderTakeProfit(), 0, Green);
      if(Ticket < 0) Print("Error in Break Even : ", GetLastError());
        break;
      }
    }

  return(Ticket);
}

//+------------------------------------------------------------------+
//+ Run the algorithem                                               |
//+------------------------------------------------------------------+
int start()
{
  int cnt, ticket, total;
  double shortSma, longSma, ShortSL, ShortTP, LongSL, LongTP, atr, stop;
  stop = StopLoss;
  
  // Parameter Sanity checking
  if(PeriodTwo < PeriodOne){
    Print("Please check settings, Period Two is lesser then the first period");
    return(0);
  }

  if(Bars < PeriodTwo){
    Print("Please check settings, less then the second period bars available for the long SMA");
    return(0);
  }

  // Calculate the SMAs from the iMA indicator in MODE_SMMA using the close price
  shortSma = iMA(NULL, 0, PeriodOne, 0, MODE_SMMA, PRICE_CLOSE, 0);
  longSma = iMA(NULL, 0, PeriodTwo, 0, MODE_SMMA, PRICE_CLOSE, 0);

  // Check if there has been a cross on this tick from the two SMAs
  int isCrossed = CheckForCross(shortSma, longSma);

  // Get the current total orders
  total = OrdersTotal();

  // Calculate Stop Loss and Take profit
  if(StopLoss > 0){
    ShortSL = Bid+(StopLoss*Point);
    LongSL = Ask-(StopLoss*Point);
  }
  if(TakeProfit > 0){
    ShortTP = Bid-(TakeProfit*Point);
    LongTP = Ask+(TakeProfit*Point);
  }

  // Only open one trade at a time..
  if(total < 1){
    // Buy - Long position
    if(isCrossed == 1){
        ticket = OrderSend(Symbol(), OP_BUY, LotsOptimized(),Ask,5, LongSL, LongTP, "Double SMA Crossover",MAGICNUM,0,Blue);
        if(ticket > 0){
          if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            Print("BUY Order Opened: ", OrderOpenPrice(), " SL:", LongSL, " TP: ", LongTP);
          }
          else
            Print("Error Opening BUY  Order: ", GetLastError());
            return(0);
        }
    // Sell - Short position
    if(isCrossed == 2){
      ticket = OrderSend(Symbol(), OP_SELL, LotsOptimized(),Bid,5, ShortSL, ShortTP, "Double SMA Crossover",MAGICNUM,0,Red);
      if(ticket > 0){
        if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
          Print("SELL Order Opened: ", OrderOpenPrice(), " SL:", ShortSL, " TP: ", ShortTP);
        }
        else
          Print("Error Opening SELL Order: ", GetLastError());
          return(0);
      }
    }

  // Manage open orders for exit criteria
  for(cnt = 0; cnt < total; cnt++){
    OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if(OrderType() <= OP_SELL && OrderSymbol() == Symbol()){
      // Look for long positions
      if(OrderType() == OP_BUY){
        // Check for Exit criteria on buy - change of direction
        if(isCrossed == 2){
          OrderClose(OrderTicket(), OrderLots(), Bid, 3, Violet); // Close the position
          return(0);
        }
      }
      else //Look for short positions - inverse of prior conditions
      {
        // Check for Exit criteria on sell - change of direction
        if(isCrossed == 1){
          OrderClose(OrderTicket(), OrderLots(), Ask, 3, Violet); // Close the position
          return(0);
        }
      }
      // If we are in a loss - Try to BreakEven
      //Print("Current Unrealized Profit on Order: ", OrderProfit());
      //if(OrderProfit() < 0){
      //  BreakEven(MAGICNUM);
      //}
      
      //Trail the stop on the daily 14 period ATR
      atr = iATR(NULL, PERIOD_D1, 14, 0) / 2;
      
      if(OrderType() == OP_BUY){
        stop -= atr;
      } else {
        stop += atr;
      }
      
      OrderModify(OrderTicket(), StopLoss, OrderOpenPrice(), OrderTakeProfit(), 0, Green);
      
    }

  }

  return(0);
}
