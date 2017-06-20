/**
 *  Source file for implementation of module BrokerC.
 *  This component works as a MQTT Broker that
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

	uint16_t msg_cnt;
	message_t packet;
	uint8_t status;
	uint8_t client;
	
	//matrix storing the QoS of each subscription, NOT_CONN if the client
	//isn't connected or NOT_SUB if the client hasn't subscribed to the topic. 
	uint8_t subscriptions[NUM_OF_TOPICS][MAX_CLIENTS];
	
	//array storing one queued value for each topic, used to store publish messages
	//received while the broker is forwarding a previous message (packet)
	pub_msg_t queued_msgs[NUM_OF_TOPICS];
	//array indicating if there is a queueud value for each topic
	bool msg_in_queue[NUM_OF_TOPICS];


    void process_pub_message(pub_msg_t* payload);
    
	//forward the published message to the next client
    void forwardPublishMessage(pub_msg_t *msg){
        
        if(client == MAX_CLIENTS) {  //finished forwarding of packet
            uint8_t i;
            //check if a message is in queue
            for(i=0; i<MAX_CLIENTS; i++) {
                if( msg_in_queue[i] ) {
                    msg_in_queue[i] = FALSE;
                    dbg("queue", "Sending message in queue of topic %hu\n", i);
                    printf("BROKER.forwardPublishMessage: Sending message in queue of topic %u\n", i);
                    queued_msgs[i].msg_id = msg_cnt;
                    process_pub_message(&queued_msgs[i]);
                    return;
                }
            }
            //if no queued messages, free the status
            status = FREE;
            return;
        }
        if(subscriptions[msg->topic][client] < NOT_SUB){
        
            if(subscriptions[msg->topic][client] == HIGHQ)
                call PacketAcknowledgements.requestAck( &packet );
            printf("BROKER.forwardPublishMessage: Forwarding msg %u to client %u, with qos = %u\n", msg->msg_id, (client+1), subscriptions[msg->topic][client] );
            //change the qos of the packet to the one requested by that client
            msg->qos = subscriptions[msg->topic][client];
            call AMSend.send(client+1, &packet, sizeof(pub_msg_t));
        }
        else {
            client++;
            forwardPublishMessage(msg);
        }
	}
	
	//forward pubblication to all the subscribers to the related topic
	void process_pub_message(pub_msg_t* payload){

        pub_msg_t* msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
        
		dbg_clear("radio_pack","\t\t Payload \n" );
		dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", payload->msg_type);
		dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", payload->msg_id);
		dbg_clear("radio_pack", "\t\t value: %hhu \n", payload->topic);
		dbg_clear("radio_pack", "\t\t data: %hhu \n", payload->data);
		dbg_clear("radio_pack", "\t\t duplicate flag: %hhu \n", payload->dupflag);
		dbg_clear("radio_rec", "\n");
		dbg_clear("radio_pack","\n");
		printf("BROKER.process_pub_message: msg_type = %u, msg_id = %u, topic = %u, data = %u\n", payload->msg_type, 
			payload->msg_id, payload->topic, payload->data);
        
        
        msg->msg_type = payload->msg_type;
        msg->topic = payload->topic;
        msg->data = payload->data;
	    msg->dup_flag = 0;
	    msg->msg_id = msg_cnt;
	    msg_cnt++;
	    client = 0;
	    status = SENDING;
		forwardPublishMessage(msg);
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
		    //if a client is connected, print 1, otherwise 0
		    printf("%u ", (subscriptions[0][i] < NOT_CONN) );
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

		subscriptions[msg->topic][source-1] = msg->qos;
	}

	
	//***************** Boot interface ********************//
	event void Boot.booted() {
	    int i, j;
	    for(i = 0; i < NUM_OF_TOPICS; i++){
	        msg_in_queue[i] = FALSE;
	        for(j = 0; j < MAX_CLIENTS; j++){
	            subscriptions[i][j] = NOT_CONN;
	        } 
	    }
	    msg_cnt = 0;
	    dbg("boot","Application booted. My id is %u\n", TOS_NODE_ID);
	    printf("BROKER.booted: Application booted. My id is %u\n", TOS_NODE_ID);
	    call SplitControl.start();
	}

	event void SplitControl.startDone(error_t err){

		if(err == SUCCESS) {
			dbg("radio","Radio on!\n");
			printf("BROKER.startDone: Radio on!\n");
		}
		else{
			dbg("radio","An error occurred during radio start up. Trying again to start it...\n");
			printf("BROKER.startDone: An error occurred during radio start up. Trying again to start it...\n");
			call SplitControl.start();
		}
	}
	
	event void SplitControl.stopDone(error_t err) {
	    // do nothing
	}
  
    void saveMsgInQueue(pub_msg_t* payload) {
        msg_in_queue[payload->topic] = TRUE;
        queued_msgs[payload->topic].msg_type = payload->msg_type;
        queued_msgs[payload->topic].topic = payload->topic;
        queued_msgs[payload->topic].qos = payload->qos;
        queued_msgs[payload->topic].data = payload->data;
    }
    
    //****************** Receive interface ******************
    event message_t* Receive.receive(message_t* buf, void* payload, uint8_t len) {

        dbg("radio_rec","Message received at time %s \n", sim_time_string());
        dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n",
                call Packet.payloadLength( buf ) );
        dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( buf ) );
        dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
        printf("BROKER.receive: Message received: Source = %u, Destination = %u , Payload length = %u\n",
	        call AMPacket.source( buf ), call AMPacket.destination( buf ) , call Packet.payloadLength( buf ));

        switch (len) {
            case sizeof(conn_msg_t): {
                conn_msg_t* mess = (conn_msg_t*)payload;
                if(mess->msg_type == CONNECT)
                    process_conn_message(buf, mess);
                //break; //no break because the lengths of messages could be equal
            }
            case sizeof(sub_msg_t): {
                sub_msg_t* mess = (sub_msg_t*)payload;
                if(mess->msg_type == SUBSCRIBE)
                    process_sub_message(buf, mess);
                //break;
            }
            case sizeof(pub_msg_t): {
                pub_msg_t* mess = (pub_msg_t*)payload;
                
                if(mess->msg_type == PUBLISH) {
                    //if broker is already sending, store the new message in queued_msgs
                    if(status == SENDING) {
                        printf("BROKER.receive: The broker is busy, saving the message in queue\n");
                        saveMsgInQueue(mess);
                    }
                    else {
                        process_pub_message(mess);
                    }
                }
                //break;
            }
        }
        return buf;
    }
    
  
  
	event void AMSend.sendDone(message_t* buf, error_t err) {

		if( &packet == buf && err == SUCCESS ) {
		    
			pub_msg_t* pub_msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
			dbg("radio_send", "Packet sent...");
			printf("BROKER.sendDone: Packet sent...");
			
			//if QoS = 0, check the ack	
		    if(pub_msg->qos != LOWQ){
		        if ( call PacketAcknowledgements.wasAcked( buf ) ) {
			        dbg("radio", " and ack received\n");
			        printf(" and ack received\n");
			        //send the same message to the next subscribed client, if present
			        pub_msg->dup_flag = 0;
			        client++;
			        forwardPublishMessage(pub_msg);
		        }
		        else {
	                dbg("radio", " but ack was not received. Trying to resend the packet again\n");
			        printf(" but ack was not received. Trying to resend the packet again\n");
			        pub_msg->dup_flag = 1;
			        call PacketAcknowledgements.requestAck( &packet );
			        call AMSend.send(call AMPacket.destination (buf), &packet, sizeof(pub_msg_t));
		        }
		    }
		    else {
		        dbg("radio", " and not waiting for ack!\n");
			    printf(" and not waiting for ack!\n");
			    //send the same message to the next subscribed client, if present
			    pub_msg->dup_flag = 0;
			    client++;
			    forwardPublishMessage(pub_msg);
		    }
		}

	}
  
}
