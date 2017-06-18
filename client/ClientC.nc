/**
 *  Source file for implementation of module ClientC, which can
 *  send messages to the Broker of the network (connect, publish
 *  subscribe) and can read from a sensor a value to publish
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#include "constants.h"
#include "Timer.h"
#include "printf.h"

module ClientC {

	uses {
		interface Boot;
		interface AMPacket;
		interface Packet;
		interface PacketAcknowledgements;
		interface AMSend;
		interface SplitControl;
		interface Receive;
		interface Read<uint16_t>;
		interface Timer<TMilli> as BootTimer;
		interface Timer<TMilli> as ReadTimer;
	}
}

implementation {
    message_t packet;
    uint8_t sent_msg_type; //TODO it is better like this or calling a getpaylod on packet? piu facile con la variabile
    
    void sendConnect();
    
    event void Boot.booted() {
	    dbg("boot","Client application booted. I'm node %hu\n", TOS_NODE_ID );
	    printf("BOOT: Client application booted. I'm node %u\n", TOS_NODE_ID );
	    call SplitControl.start();
    }
    
    event void SplitControl.startDone(error_t err){
	    if(err == SUCCESS) {
		    dbg("radio","Radio on!\n");
		    printf("RADIO: Radio on!\n");
		    //each node waits for node_id seconds before connecting to the broker to avoid collisions
		    call BootTimer.startOneShot(TOS_NODE_ID*1000);
	    }
    	else{
            dbg("radio","An error occurred during radio start up. Trying again to start it...\n");
            printf("RADIO: An error occurred during radio start up. Trying again to start it...\n");
            call SplitControl.start();
    	}
    }
    
    event void BootTimer.fired() {
        //send connect message
    	sendConnect();
    }
    
    void sendConnect(){
        conn_msg_t* msg = (conn_msg_t*)(call Packet.getPayload(&packet,sizeof(conn_msg_t)));
	    msg->msg_type = CONNECT;
	    sent_msg_type = CONNECT;
	    dbg("connect","Sending connect message to the broker at time %s\n", sim_time_string() );
	    printf("CONNECT: Sending connect message to the broker\n");
	
	    call PacketAcknowledgements.requestAck( &packet );
	    if(call AMSend.send(BROKER, &packet, sizeof(conn_msg_t)) == SUCCESS){
	      	dbg("connect","Connect message passed to lower layer!\n");
		    printf("CONNECT: Connect message passed to lower layer!\n");
	    }
    }
    
    event void SplitControl.stopDone(error_t err) {
	    // do nothing
    }
    
    event void AMSend.sendDone(message_t* buf, error_t err) {
        
	if(&packet == buf && err == SUCCESS ) {
	    pub_msg_t* pub_msg
	    
	    dbg("radio", "Packet sent with type = %hu...", sent_msg_type);
	    printf("RADIO: Packet sent with type = %u...", sent_msg_type);
        //now check the type of message
        switch (sent_msg_type){
		    case CONNECT:
			  	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
					dbg("radio", " and ack received\n");
					printf(" and ack received\n");
					//TODO How often should sensor read?
					call ReadTimer.startPeriodic(700);
	        	}
				else {
					dbg("radio", " but ack was not received\n");
					printf(" but ack was not received\n");
					sendConnect();
				}
				break;
			case PUBLISH:
				pub_msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
				
				/*TODO is it right that publication message has no qos field?
				if(pub_msg -> qos != 0){
				    if ( call PacketAcknowledgements.wasAcked( buf ) ) {
					    dbg_clear("radio_ack", "and ack received");
				    }
				    else {
			            dbg_clear("radio_ack", "but ack was not received. Trying to resend packet...");
					    if(call AMSend.send(BROKER, &packet, sizeof(pub_msg_t)) == SUCCESS){
				            dbg("radio_send", "Packet passed to lower layer successfully!\n");
					        dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n",
					        call Packet.payloadLength( &packet ) );
					        dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
					        dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
					        dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
					        dbg_clear("radio_pack","\t\t Payload \n" );
					        dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", pub_msg->msg_type);
					        dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", pub_msg->msg_id);
					        dbg_clear("radio_pack", "\t\t value: %hhu \n", pub_msg->value);
					        dbg_clear("radio_send", "\n ");
					        dbg_clear("radio_pack", "\n");
					    }
				    }
				}*/
				
				//TODO print pub_msg fields
				break;
			case SUBSCRIBE:
				if ( call PacketAcknowledgements.wasAcked( buf ) ) {
					dbg("radio", " and ack received\n");
					printf(" and ack received\n");
	        	}
				else {
					dbg("radio", " but ack was not received\n");
					printf(" but ack was not received\n");
					//send again the message
				
				}
				break;  
            }
	}

    }
    
    event void ReadTimer.fired() {
         call Read.read();
 	}
	
    event void Read.readDone(error_t result, uint16_t data) {
        
        if(result == SUCCESS) {
            pub_msg_t* msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
            msg->msg_type = PUBLISH;
            sent_msg_type = PUBLISH;
	        msg->msg_id = TOS_NODE_ID;
	        msg->topic = TEMPERATURE;
	        msg->data = data;
	        msg->dupflag = 0;
	        
	        dbg("radio_send", "Trying to publish the value\n");
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
    
    //***************************** Receive interface *****************//
    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {

	printf("RADIO: Received msg from source: %u \n", call AMPacket.source( buf ) );
	//TODO Implement receive pubish msg from broker
	
	/*
	my_msg_t* mess=(my_msg_t*)payload;
	rec_id = mess->msg_id;

	dbg("radio_rec","Message received at time %s \n", sim_time_string());
	dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
	dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
	dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
	dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
	dbg_clear("radio_pack","\t\t Payload \n" );
	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", mess->msg_type);
	dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
	dbg_clear("radio_pack", "\t\t value: %hhu \n", mess->value);
	dbg_clear("radio_rec", "\n ");
	dbg_clear("radio_pack","\n");

	if ( mess->msg_type == REQ ) {
		post sendResp();
	} */

	return buf;

    }
    
    
}
