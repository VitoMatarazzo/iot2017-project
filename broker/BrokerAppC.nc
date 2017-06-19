/**
 *  Configuration file for Client application
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#define NEW_PRINTF_SEMANTICS
#include "../constants.h"

configuration BrokerAppC {}

implementation {

  components MainC, BrokerC as App, SerialPrintfC;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC;
  //components new TimerMilliC();

  //Boot interface
  App.Boot -> MainC.Boot;

  //Send and Receive interfaces
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;

  //Radio Control
  App.SplitControl -> ActiveMessageC;

  //Interfaces to access package fields
  App.AMPacket -> AMSenderC;
  App.Packet -> AMSenderC;
  App.PacketAcknowledgements->ActiveMessageC;

  //Timer interface
  //App.MilliTimer -> TimerMilliC;


}

