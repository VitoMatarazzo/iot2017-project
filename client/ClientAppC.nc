/**
 *  Configuration file for Client application
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#define NEW_PRINTF_SEMANTICS
#include "../constants.h"

configuration ClientAppC {}

implementation {

    components MainC, ClientC as App, SerialPrintfC, RandomC;
    components new AMSenderC(AM_MY_MSG);
    components new AMReceiverC(AM_MY_MSG);
    components ActiveMessageC;
    components new TimerMilliC() as ConnectTimer;
    components new TimerMilliC() as ReadTimer;
    components new TimerMilliC() as Timeout;
    components new FakeSensorC();

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

    //Timer interfaces
    App.ConnectTimer -> ConnectTimer;
    App.ReadTimer -> ReadTimer;
    App.Timeout -> Timeout;

    //Fake Sensor reads a random number
    App.Read -> FakeSensorC;

    //Random interface and its initialization	
    App.Random -> RandomC;
    RandomC <- MainC.SoftwareInit;

}

