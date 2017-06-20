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
		interface Timer<TMilli> as ConnectTimer;
		interface Timer<TMilli> as ReadTimer;
		interface Timer<TMilli> as Timeout;
		interface Random;
	}
}

implementation {
    message_t packet;
    uint8_t status;
    uint16_t new_value;
    uint8_t sent_msg_type;
    uint8_t my_topic;
    uint16_t msg_cnt;
    uint8_t num_of_sub;
    
    void sendConnect();
    void sendSubscribe(sub_msg_t* msg);
    void subscribe();
    void nodeRun();
    void sendPublish(pub_msg_t* msg);
    void initPublishMsg();
    
    event void Boot.booted() {
	    my_topic = TOS_NODE_ID % NUM_OF_TOPICS;
	
	    dbg("boot","Client application booted. I'm node %hu, my topic is %hhu\n", TOS_NODE_ID, my_topic );
	    printf("CLIENT.booted: Client application booted. I'm node %u, my topic is %u\n", TOS_NODE_ID, my_topic );
	    status = FREE;
	    call SplitControl.start();
    }
    
    event void SplitControl.startDone(error_t err){
		if(err == SUCCESS) {
		    dbg("radio","Radio on!\n");
		    printf("CLIENT.startDone: Radio on!\n");
		    //each node waits for node_id * connect_timeout ms before connecting to the broker to avoid collisions
		    call ConnectTimer.startOneShot(TOS_NODE_ID* CONNECT_TIMEOUT);
		}
		else{
			dbg("radio","An error occurred during radio start up. Trying again to start it...\n");
			printf("CLIENT.startDone: An error occurred during radio start up. Trying again to start it...\n");
			call SplitControl.start();
		}
    }
    
    event void ConnectTimer.fired() {
        //send connect message
		sendConnect();
    }
    
    event void Timeout.fired() {
        pub_msg_t* pub_msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
        dbg("timeout","Retransmission timeout fired!\n");
		printf("CLIENT.timeoutFired: Retransmission timeout fired!\n");
        pub_msg->dup_flag = 1;
        sendPublish(pub_msg);
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
					        dbg("radio", " and ack received");
					        printf(" and ack received");
				        }
				        else {
				            //wait a random timeout in [100, 500] ms before reattempting
				            uint16_t to = (call Random.rand16()%5 +1)*100;
			                dbg("radio", " but ack was not received. Trying to resend the packet again in %hu ms\n", to);
					        printf(" but ack was not received. Trying to resend the packet again in %u ms\n", to);
				            //freeing the status to allow transmission of new values
                            status = FREE;
				            call Timeout.startOneShot( to );
				            break;
					  
				        }
				    }
				    else {
				        dbg("radio", " and not waiting for ack!");
					    printf(" and not waiting for ack!");
				    }
				    if(status == QUEUED_VALUE) {
				        dbg("radio", "\nA more recent value is in queue, sending it\n");
					    printf("\nCLIENT.sendDone: A more recent value is in queue, sending it\n");
					    initPublishMsg();        
					}
					else {
					    dbg("radio", "\n");
					    printf("\n");
					    //freeing the status to allow transmission of new values
					    status = FREE;
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
	    status = SENDING;
	    if(msg->qos == HIGHQ) {
            call PacketAcknowledgements.requestAck( &packet );
	    }
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
	
	void initPublishMsg() {
	    pub_msg_t* msg = (pub_msg_t*)(call Packet.getPayload(&packet,sizeof(pub_msg_t)));
        msg->msg_type = PUBLISH;
        sent_msg_type = PUBLISH;
        msg->msg_id = TOS_NODE_ID*1000 + msg_cnt;
        msg_cnt++;
        msg->qos = (uint8_t) call Random.rand16()%2;
        msg->topic = my_topic;

        msg->data = new_value;
        msg->dup_flag = 0;
        sendPublish(msg);    
	}
	
	//a new value has been read from the sensor
    event void Read.readDone(error_t result, uint16_t data) {
        
        if(result == SUCCESS) {
            //stop eventual retransmission timeout, since the most recent value has priority
            call Timeout.stop();
            new_value = data;
            dbg("read", "Read the value %hhu\n", data);
	        printf("CLIENT.readDone: Read the value %u\n", data);
            if(status != SENDING) {  
	            dbg("read", "Publishing the read value\n");
	            printf("CLIENT.readDone: Publishing the read value\n");
	            initPublishMsg();
		    }
		    else {
		        status = QUEUED_VALUE;
		        dbg("read", "Radio busy, the value is queued\n");
	            printf("CLIENT.readDone: Radio busy, the value is queued\n");
		    }
        }
		else {
			dbg("read", "Error while reading from sensor. Trying to read again\n");
			printf("CLIENT.readDone: Error while reading from sensor. Trying to read again\n");
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
            dbg("radio_rec","Wrong type of packet received!\n");
            printf("CLIENT.receive: Wrong type of packet received!\n");
        }
	    
	    return buf;

    }
    
    //subscribe to a new topic except for my_topic
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
	    else //finished subscribtions, starting the read timer
	        call ReadTimer.startPeriodic(READ_PERIOD);
    }
    
    void sendSubscribe(sub_msg_t* msg){
        
        call PacketAcknowledgements.requestAck( &packet );
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
