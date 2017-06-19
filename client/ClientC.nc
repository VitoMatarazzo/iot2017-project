/**
 *  Source file for implementation of module ClientC, which can
 *  send messages to the Broker of the network (connect, publish
 *  subscribe) and can read from a sensor a value to publish
 *
 *  @author Giuseppe Manzi
 *  @author Vito Matarazzo
 */

#include "../constants.h"
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
		interface Random;
	}
}

implementation {
    message_t packet;
    //bool radio_busy = FALSE; TODO: forse qui non serve perchè facciamo nuove send solo dopo la sendDone
    uint8_t sent_msg_type;
    uint8_t my_topic;
    uint16_t msg_cnt;
    uint8_t num_of_sub;
    
    void sendConnect();
    void sendSubscribe(sub_msg_t* msg);
    void subscribe();
    void nodeRun();
    void sendPublish(pub_msg_t* msg);
    
    event void Boot.booted() {
	    
	    my_topic = TOS_NODE_ID%NUM_OF_TOPICS;
	    dbg("boot","Client application booted. I'm node %hu, my topic is %hhu\n", TOS_NODE_ID, my_topic );
	    printf("CLIENT.booted: Client application booted. I'm node %u, my topic is %u\n", TOS_NODE_ID, my_topic );
	    call SplitControl.start();
    }
    
    event void SplitControl.startDone(error_t err){
		if(err == SUCCESS) {
		    dbg("radio","Radio on!\n");
		    printf("CLIENT.startDone: Radio on!\n");
		    //each node waits for node_id seconds before connecting to the broker to avoid collisions
		    call BootTimer.startOneShot(TOS_NODE_ID*1000);
		}
		else{
			dbg("radio","An error occurred during radio start up. Trying again to start it...\n");
			printf("CLIENT.startDone: An error occurred during radio start up. Trying again to start it...\n");
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
	    printf("CLIENT.sendConnect: Sending connect message to the broker\n");
	
	    call PacketAcknowledgements.requestAck( &packet );
	    if(call AMSend.send(BROKER, &packet, sizeof(conn_msg_t)) == SUCCESS){
	        dbg("connect","Connect message passed to lower layer!\n");
		    printf("CLIENT.sendConnect: Connect message passed to lower layer!\n");
	    }
    }
    
    event void SplitControl.stopDone(error_t err) {
	    // do nothing
    }
    
    event void AMSend.sendDone(message_t* buf, error_t err) {
        
	    if(&packet == buf && err == SUCCESS ) {
	        dbg("radio", "Packet sent with type = %hu...", sent_msg_type);
	        printf("CLIENT.sendDone: Packet sent with type = %u...", sent_msg_type);
            //now check the type of message
            switch (sent_msg_type){
		        case CONNECT:{
			      	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
					    dbg("radio", " and ack received\n");
					    printf(" and ack received\n");
					    //start the node specific run
					    num_of_sub = 0;
					    subscribe();        
	            	}
				    else {
					    dbg("radio", " but ack was not received\n");
					    printf(" but ack was not received\n");
					    sendConnect();
				    }
				    break;
			    }
			    case PUBLISH:{
			         
				    pub_msg_t* pub_msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
				
				    if(pub_msg->qos != LOWQ){
				        if ( call PacketAcknowledgements.wasAcked( buf ) ) {
					        dbg("radio", " and ack received\n");
					        printf(" and ack received\n");
				        }
				        else {
			                dbg("radio", " but ack was not received. Trying to resend the packet again\n");
					        printf(" but ack was not received. Trying to resend the packet again\n");
					        pub_msg->dup_flag = 1;
					        sendPublish(pub_msg);
				        }
				    }
				    else {
				        dbg("radio", " and not waiting for ack!\n");
					    printf(" and not waiting for ack!\n");
				    }
				    break;
			    }
			    case SUBSCRIBE:{
			      	if ( call PacketAcknowledgements.wasAcked( buf ) ) {
					    dbg("radio", " and ack received\n");
					    printf(" and ack received\n");
					    //next subscription
					    num_of_sub++;
					    subscribe();
	            	}
				    else {
				        sub_msg_t* msg = (sub_msg_t*)(call Packet.getPayload(&packet,sizeof(sub_msg_t)));
					    dbg("radio", " but ack was not received\n");
					    printf(" but ack was not received\n");
					    sendSubscribe(msg);
				    }
				    break;
			    }
            }
	    }

    }
    
    event void ReadTimer.fired() {
         call Read.read();
 	}
	
	void sendPublish(pub_msg_t* msg){
	    if(call AMSend.send(BROKER, &packet, sizeof(pub_msg_t)) == SUCCESS){
		    dbg("radio_send", "Publish message passed to lower layer!\n");
		    dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
		    dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
		    dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
		    dbg_clear("radio_pack","\t\t Payload \n" );
		    dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
		    dbg_clear("radio_pack", "\t\t topic: %hhu \n", msg->topic);
		    dbg_clear("radio_pack", "\t\t data: %hhu \n", msg->data);
		    dbg_clear("radio_pack", "\t\t QoS: %hhu \n", msg->qos);
		    dbg_clear("radio_send", "\n ");
		    dbg_clear("radio_pack", "\n");
		    printf("CLIENT.sendPublish: Publish message passed to lower layer!\n");
		    printf("CLIENT.sendPublish: Payload length = %u, Source = %u, Destination = %u\n", call Packet.payloadLength( &packet ),
		        call AMPacket.source( &packet ), call AMPacket.destination( &packet ) );
		    printf("CLIENT.sendPublish: Payload>>> msg_id = %u, topic = %u, data = %u, Qos = %u\n", msg->msg_id, msg->topic,
		        msg->data, msg->qos);
	    }
	}
	
    event void Read.readDone(error_t result, uint16_t data) {
        
        if(result == SUCCESS) {
		    pub_msg_t* msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
		    msg->msg_type = PUBLISH;
		    sent_msg_type = PUBLISH;
		    msg->msg_id = TOS_NODE_ID*1000 + msg_cnt;
		    msg_cnt++;
		    msg->qos = (uint8_t) call Random.rand16()%2;
		    msg->topic = my_topic;
		
		    msg->data = data;
		    msg->dup_flag = 0;
		      
		    dbg("read", "Read the value %hhu\n", data);
		    printf("CLIENT.readDone: Read the value %u\n", data);
		    if(msg->qos == HIGHQ) {
			    call PacketAcknowledgements.requestAck( &packet );
		    }
		      
		    dbg("read", "Publishing the read value\n");
		    printf("CLIENT.readDone: Publishing the read value\n");
		    sendPublish(msg);
        }
		else {
			dbg("read", "Error while reading from sensor. Trying to read again");
			printf("CLIENT.readDone: Error while reading from sensor. Trying to read again");
			call Read.read();
		}
        
    }
    
    //***************************** Receive interface *****************//
    event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
    
        dbg("radio_rec","Message received at time %s from source = %hhu\n", sim_time_string(), call AMPacket.source( buf ));
	    printf("CLIENT.receive: Message received from source = %u \n", call AMPacket.source( buf ) );
        if(len == sizeof(pub_msg_t)) {
            pub_msg_t* msg=(pub_msg_t*)payload;
         
            dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
            dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
            dbg_clear("radio_pack","\t\t Payload \n" );
            dbg_clear("radio_pack", "\t\t msg_type: %hhu \n", msg->msg_type);
            dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
            dbg_clear("radio_pack", "\t\t topic: %hhu \n", msg->topic);
		    dbg_clear("radio_pack", "\t\t data: %hhu \n", msg->data);
		    dbg_clear("radio_pack", "\t\t QoS: %hhu \n", msg->qos);
            dbg_clear("radio_rec", "\n ");
            dbg_clear("radio_pack","\n");
		    printf("CLIENT.receive: Payload length = %u, Destination = %u\n", call Packet.payloadLength( &packet ),
		        call AMPacket.destination( &packet ) );
		    printf("CLIENT.receive: Payload>>> msg_type = %u, msg_id = %u, topic = %u, data = %u, QoS = %u\n", msg->msg_type, msg->msg_id,
		        msg->topic, msg->data, msg->qos);
        }
        else{
            dbg("radio_rec","Wrong receive!\n");
            printf("CLIENT.receive: Wrong receive!\n");
        }
	    
	    return buf;

    }
    
    void subscribe(){
        if(num_of_sub == my_topic)
	        num_of_sub++;
	    if(num_of_sub < NUM_OF_TOPICS) {
	        sub_msg_t* msg = (sub_msg_t*)(call Packet.getPayload(&packet,sizeof(sub_msg_t)));
		    msg->msg_type = SUBSCRIBE;
		    sent_msg_type = SUBSCRIBE;
		    msg->msg_id = msg_cnt;
	        msg_cnt++;
	        msg->qos = (uint8_t) call Random.rand16()%2;
	        msg->topic = num_of_sub;
	        dbg("subscribe", "Suscribing to topic %hu\n", msg->topic);
	        printf("CLIENT.subscribe: Suscribing to topic %u\n", msg->topic);
	        sendSubscribe(msg);
	    }
	    else //finished subscribtions
	        call ReadTimer.startPeriodic(700);
    }
    
    void sendSubscribe(sub_msg_t* msg){
        
	    if(call AMSend.send(BROKER, &packet, sizeof(sub_msg_t)) == SUCCESS){
		    dbg("radio_send", "Subscribe message passed to lower layer!\n");
		    dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
		    dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
		    dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
		    dbg_clear("radio_pack","\t\t Payload \n" );
		    dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", msg->msg_id);
		    dbg_clear("radio_pack", "\t\t topic: %hhu \n", msg->topic);
		    dbg_clear("radio_pack", "\t\t QoS: %hhu \n", msg->qos);
		    dbg_clear("radio_send", "\n ");
		    dbg_clear("radio_pack", "\n");
		    printf("CLIENT.sendSubscribe: Subscribe message passed to lower layer!\n");
		    printf("CLIENT.sendSubscribe: Payload length = %u, Source = %u, Destination = %u\n", call Packet.payloadLength( &packet ),
		        call AMPacket.source( &packet ), call AMPacket.destination( &packet ) );
		    printf("CLIENT.sendSubscribe: Payload>>> msg_id = %u, topic = %u, Qos = %u\n", msg->msg_id, msg->topic, msg->qos);
	    }
	}
	
    
}
