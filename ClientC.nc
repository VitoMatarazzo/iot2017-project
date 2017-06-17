/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#include "sendAck.h"
#include "Timer.h"

module sendAckC {

  uses {
	interface Boot;
    interface AMPacket;
	interface Packet;
	interface PacketAcknowledgements;
    interface AMSend;
    interface SplitControl;
    interface Receive;
	interface Read<uint16_t>;
	interface Timer<TMilli> as MilliTimer;
  }
}

implementation {
    message_t packet;
    int8_t typeofmsg; //TODO it is better like this or calling a getpaylod on packet?
    
    event void Boot.booted() {
	    dbg("boot","Application booted.\n");
	    call SplitControl.start();  //when booted, turn on the radio
	}
	
	event void SplitControl.startDone(error_t err){
      
	    if(err == SUCCESS) {
	        conn_msg_t* msg = (conn_msg_t*)(call Packet.getPayload(&packet,sizeof(conn_msg_t)));
	        dbg("radio","Radio on!\n");
	        msg->type = CONNECT;
	        typeofmsg = CONNECT;
	        call AMSend.send(BROKER, &msg, sizeof(conn_msg_t));
        }
    	else{
            dbg("radio","An error occurred during radio"
            "start up. Trying again to start it...");
            call SplitControl.start();
    	}
    }
    
    event void AMSend.sendDone(message_t* buf,error_t err) {
        
        if(&packet == buf && err == SUCCESS ) {
	        dbg("radio_send", "Packet sent...");
            
            switch (typeofmsg){
                case CONNECT:
                    call MilliTimer.startPeriodic( 1000 );
                break;
                case PUBLISH:
                    pub_msg_t* msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
                    if(msg -> QoS != 0)
                        if ( call PacketAcknowledgements.wasAcked( buf ) ) {
                              dbg_clear("radio_ack", "and ack received");
                            } else {
                              dbg_clear("radio_ack", "but ack was not received. Trying to resend packet...");
                              if(call AMSend.send(BROKER, &packet, sizeof(pub_msg_t)) == SUCCESS){
	                                dbg("radio_send", "Packet passed to lower layer successfully!\n");
	                                dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n",
	                                       call Packet.payloadLength( &packet ) );
	                                dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	                                dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	                                dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	                                dbg_clear("radio_pack","\t\t Payload \n" );
	                                dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", msg->msg_type);
	                                dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
	                                dbg_clear("radio_pack", "\t\t value: %hhu \n", msg->value);
	                                dbg_clear("radio_send", "\n ");
	                                dbg_clear("radio_pack", "\n");
            }
                            }
                    
                break;
                
            }
	        if ( call PacketAcknowledgements.wasAcked( buf ) ) {
	            dbg_clear("radio_ack", "and ack received");
	            call MilliTimer.stop();
	        }
	        else {
	            dbg_clear("radio_ack", "but ack was not received");
	            post sendReq();
	        }
	        dbg_clear("radio_send", " at time %s \n", sim_time_string());
	    }

    }
    
    event void MilliTimer.fired() {
        call Read.read()
	}
	
	event void Read.readDone(error_t result, uint16_t data) {
        
        if(result = SUCCESS) {
            pub_msg_t* msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
            msg->msg_type = PUBLISH;
	        msg->msg_id = TOS_NODE_ID;
	        msg->topic = TEMPERATURE;
	        msg->data = data;
	        msg->dupflag = false;
	        
	        dbg("radio_send", "Try to send a response to node 1 \n");
	        call PacketAcknowledgements.requestAck( &packet );
	        
	        if(call AMSend.send(BROKER, &packet, sizeof(pub_msg_t)) == SUCCESS){
	            dbg("radio_send", "Packet passed to lower layer successfully!\n");
	            dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	            dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
	            dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	            dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	            dbg_clear("radio_pack","\t\t Payload \n" );
	            dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", msg->msg_type);
	            dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
	            dbg_clear("radio_pack", "\t\t value: %hhu \n", msg->value);
	            dbg_clear("radio_send", "\n ");
	            dbg_clear("radio_pack", "\n");
            }
        }
        else {
            dbg("radio_read", "Error while reading from sensor. Trying to read again");
            call Read.read();
        }
    }
    
	
}
