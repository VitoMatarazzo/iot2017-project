/**
 *  Source file for implementation of module BrokerC.
 *  This component works as a MTTQ Broker that
 *  allows clients to connect, publish and subscribe.
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#include "../constants.h"
#include "printf.h"
 

module BrokerC {

    uses {
	interface Boot;
	interface AMPacket;
	interface Packet;
	interface PacketAcknowledgements;
	interface AMSend;
	interface SplitControl;
	interface Receive;
    }

}

implementation {

	uint8_t counter=0;
 	uint8_t rec_id;
	message_t packet;
	
	//matrix storing the QoS of each subscription, NOT_CONN if the client
	//isn't connected or NOT_SUB if the client hasn't subscribed to the topic. 
	uint8_t subscriptions[NUM_OF_TOPICS][MAX_CLIENTS];


	//tasks can't have parameters and must return void
    void forwardPublishMessage(pub_msg_t *msg, uint8_t client){
	  if(subscriptions[msg->topic][client] == 1)
		call PacketAcknowledgements.requestAck( &packet );
	  if(subscriptions[msg->topic][client] < NOT_SUB){
		pub_msg_t* payload_pointer=(pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
		printf("BROKER.forwardPublishMessage: Forwarding msg %u to client %u\n", payload_pointer->msg_id, client);
		*payload_pointer = *msg;
		msg->dup_flag = 0;
		call AMSend.send(client, &packet, sizeof(pub_msg_t));
	  }
	}
	
	//instanciate connection
	void process_conn_message(message_t* buf, conn_msg_t* msg){
		uint8_t i, source = call AMPacket.source( buf );

		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
		dbg_clear("radio_rec", "\n ");
		dbg_clear("radio_pack","\n");
		printf("BROKER.process_conn_message: msg_type = %u\n", msg->msg_type);

		for(i = 0; i < NUM_OF_TOPICS; i++){
		    subscriptions[i][source-1] = NOT_SUB;
		}
		printf("BROKER.process_conn_message: current connection status: ");
		for(i = 0; i < MAX_CLIENTS; i++){
		    printf("%u ", subscriptions[0][i]);
		}
		printf("\n");
	}

	//add client to subscribers to requested topic
	void process_sub_message(message_t* buf, sub_msg_t* msg){
		uint8_t source = call AMPacket.source( buf );

		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
		dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
		dbg_clear("radio_pack", "\t\t topic: %hhu \n", msg->topic);
		dbg_clear("radio_pack", "\t\t QoS: %hhu \n", msg->qos);
		dbg_clear("radio_rec", "\n ");
		dbg_clear("radio_pack","\n");
		printf("BROKER: msg_type = %u, msg_id = %u, topic = %u, QoS = %u\n", msg->msg_type, 
			msg->msg_id, msg->topic, msg->qos);

		subscriptions[msg->topic][source] = msg->qos;
	}

	//forward pubblication to all the subscribers to the related topic
	void process_pub_message(message_t* buf, pub_msg_t* msg){
		uint8_t i;

		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
		dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
		dbg_clear("radio_pack", "\t\t value: %hhu \n", msg->topic);
		dbg_clear("radio_pack", "\t\t data: %hhu \n", msg->data);
		dbg_clear("radio_pack", "\t\t duplicate flag: %hhu \n", msg->dupflag);
		dbg_clear("radio_rec", "\n");
		dbg_clear("radio_pack","\n");
		printf("BROKER.process_pub_message: msg_type = %u, msg_id = %u, topic = %u, data = %u\n", msg->msg_type, 
			msg->msg_id, msg->topic, msg->data);

		for(i = 0; i < MAX_CLIENTS; i++)
		    forwardPublishMessage(msg, i);
	}
	
	//***************** Boot interface ********************//
	event void Boot.booted() {
	    int i, j;
	    for(i = 0; i < NUM_OF_TOPICS; i++){
	        for(j = 0; j < MAX_CLIENTS; j++){
	            subscriptions[i][j] = NOT_CONN;
	        } 
	    }
	    dbg("boot","Application booted.\n");
	    printf("BROKER.booted: Application booted, my id is %u, broker id should be %u\n", TOS_NODE_ID, BROKER);
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
	
	event void SplitControl.stopDone(error_t err) {
	    // do nothing
	}
  
  //****************** Receive interface ******************
  event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {
	
	dbg("radio_rec","Message received at time %s \n", sim_time_string());
	dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n",
	        call Packet.payloadLength( buf ) );
	dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
	dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
	printf("BROKER: Message received:\nSource = %u, Destination = %u\n",
		call AMPacket.source( buf ), call AMPacket.destination( buf ) );
	
	switch (len) {
		case sizeof(conn_msg_t): {
		  conn_msg_t* mess = (conn_msg_t*)payload;
		  if(mess->msg_type == CONNECT)
			process_conn_message(buf, mess);
		  //break;
		  }
		case sizeof(sub_msg_t): {
		  sub_msg_t* mess = (sub_msg_t*)payload;
		  if(mess->msg_type == SUBSCRIBE)
			process_sub_message(buf, mess);
		  //break;
		  }
		case sizeof(pub_msg_t): {
		  pub_msg_t* mess = (pub_msg_t*)payload;
		  if(mess->msg_type == PUBLISH)
			process_pub_message(buf, mess);
		  //break;
		  }
	}

    return buf;

  }
  
  
	event void AMSend.sendDone(message_t* buf, error_t err) {

		
		if( &packet == buf && err == SUCCESS ) {
		    
			dbg("radio_send", "Packet sent...");

			if ( call PacketAcknowledgements.wasAcked( buf ) ) {
			  dbg_clear("radio_ack", "and ack received");
			} 
			else {
			  pub_msg_t* msg=(pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));  
			  dbg_clear("radio_ack", "but ack was not received");
			  msg->dup_flag = 1;
			  call AMSend.send(call AMPacket.source( buf ), &packet, sizeof(pub_msg_t));
			}
			dbg_clear("radio_send", " at time %s \n", sim_time_string());
		}

	}
  
}
