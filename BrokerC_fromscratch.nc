/**
 *  Source file for implementation of module BrokerC.
 *  This component works as a MTTQ Broker that
 *  allows clients to connect, publish and subscribe.
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#include "constants.h"
 

module BrokerC {

    uses {
        interface Boot;
        interface AMPacket;
        interface Packet;
	    interface PacketAcknowledgements;
    	interface AMSend;
    	interface SplitControl;
    	interface Receive;
	    interface Read<uint16_t>;
  }

}

implementation {

	uint8_t counter=0;
 	uint8_t rec_id;
	message_t packet;
	
	//matrix storing the QoS of each subscription, NOT_CONN if the client
	//isn't connected or NOT_SUB if the client hasn't subscribed to the topic. 
	uint8_t subscriptions[NUM_OF_TOPICS][MAX_CLIENTS];

	//***************** Boot interface ********************//
	event void Boot.booted() {
	    int i, j;
	    for(i = 0; i < NUM_OF_TOPICS; i++){
	        for(j = 0; j < MAX_CLIENTS; j++){
	            subscription[i][j] = NOT_CONN;
	        } 
	    }
	    dbg("boot","Application booted.\n");
	    call SplitControl.start();  //when booted, turn on the radio
	}

	event void SplitControl.startDone(error_t err){
      
	    if(err == SUCCESS) {
	        dbg("radio","Radio on!\n");
        }
    	else{
            dbg("radio","An error occurred during radio"
            "start up. Trying again to start it...");
            call SplitControl.start();
    	}
  }
  
  //****************** Receive interface ******************
  event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
	
	dbg("radio_rec","Message received at time %s \n", sim_time_string());
	dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n",
	        call Packet.payloadLength( buf ) );
	dbg_clear("radio_pack","\t Source: %hhu \n",call AMPacket.source( buf ) );
	dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
	dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
	dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
	
	switch (len) {
	    case sizeof(conn_message_t):
	        conn_message_t* mess = (conn_message_t*)payload;
	        if(mess->msg_type == CONNECTION)
	            process_conn_message(buf, mess);
		    //break;
		case sizeof(sub_message_t):
		    sub_message_t* mess = (sub_message_t*)payload;
	        if(mess->msg_type == SUBSCRIBE)
	            process_conn_message(buf, mess);
		    //break;
	    case sizeof(pub_message_t):
	        pub_message_t* mess = (pub_message_t*)payload;
	        if(mess->msg_type == PUBLISH)
	            process_conn_message(buf, mess);
		    //break;
	}

    return buf;

  }
  
  //instanciate connection
  void process_conn_message(message_t* buf, conn_message_t* msg){
    uint8_t i, source = call AMPacket.source( buf );
    
    dbg_clear("radio_pack","\t\t Payload \n" );
	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
	dbg_clear("radio_rec", "\n ");
	dbg_clear("radio_pack","\n");
	
	for(i = 0; i < NUM_OF_TOPICS; i++){
	    subscription[i][source] = NOT_SUB;
	}
  }
  
  //add client to subscribers to requested topic
  void process_sub_message(message_t* buf, sub_message_t msg){
    uint8_t source = call AMPacket.source( buf );
    
    dbg_clear("radio_pack","\t\t Payload \n" );
	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
	dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
	dbg_clear("radio_pack", "\t\t topic: %hhu \n", msg->topic);
	dbg_clear("radio_pack", "\t\t QoS: %hhu \n", msg->qos);
	dbg_clear("radio_rec", "\n ");
	dbg_clear("radio_pack","\n");
	
	subscription[msg->topic][source] = msg->qos;
  }
  
  //forward pubblication to all the subscribers to the related topic
  void process_pub_message(message_t* buf, pub_message_t* msg){
    uint8_t i;
    
    dbg_clear("radio_pack","\t\t Payload \n" );
	dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
	dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
	dbg_clear("radio_pack", "\t\t value: %hhu \n", msg->topic);
	dbg_clear("radio_pack", "\t\t data: %hhu \n", msg->data);
	dbg_clear("radio_pack", "\t\t duplicate flag: %hhu \n", msg->dupflag);
	dbg_clear("radio_rec", "\n");
	dbg_clear("radio_pack","\n");
	
	for(i = 0; i < MAX_CLIENTS; i++)
	    post sendReq(msg, i);
  }
  
    task void sendReq(pub_message_t* msg , uint8_t client){
        if(subscriptions[msg->topic][client] == 1)
            call PacketAcknowledgements.requestAck( &packet );
        if(subscriptions[msg->topic][client] < NOT_SUB){
            pub_message_t* payload_pointer=(pub_message_t*)(call Packet.getPayload(&packet,sizeof(pub_message_t)));
            *payload_pointer = *msg;
            msg->dupflag = false;
            call AMSend.send(i, &packet, sizeof(pub_message_t));
        }
    }
  
  event void AMSend.sendDone(message_t* buf,error_t err) {

    if((call Packet.getPayload(&packet,sizeof(pub_message_t)) == (call Packet.getPayload(buf,sizeof(pub_message_t))
                 && err == SUCCESS ) {
	dbg("radio_send", "Packet sent...");

	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
	  dbg_clear("radio_ack", "and ack received");
	} else {
	  dbg_clear("radio_ack", "but ack was not received");
	  post sendReq();
	}
	dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }

  }
  
}
