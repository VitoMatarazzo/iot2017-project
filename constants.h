/**
 *  Header file containing all constants
 */

#ifndef CONSTANTS_H
#define CONSTANTS_H

typedef nx_struct {
	nx_uint8_t msg_type;
} conn_msg_t;

typedef nx_struct{
	nx_uint8_t msg_type;
	nx_uint16_t msg_id;
	nx_uint8_t topic;
	nx_uint16_t data;
	nx_uint8_t qos;
} pub_msg_t;

typedef nx_struct {
	nx_uint8_t msg_type;
	nx_uint16_t msg_id;
	nx_uint8_t topic;
	nx_uint8_t qos;
} sub_msg_t;

//quality of service
enum{	
	LOWQ,
	HIGHQ,
	NOT_SUB, //used in subscription matrix to represent a missing subscription
	NOT_CONN //used in subscription matrix to represent an disconneted client
};

//topics
enum{
	TEMPERATURE,
	HUMIDITY,
	LUMINOSITY,
	NUM_OF_TOPICS
};

//message types
enum{
    CONNECT,
	SUBSCRIBE,
	PUBLISH	
};

enum{
    READ_PERIOD = 4000,
    CONNECT_TIMEOUT = 500
};

//client status
enum{
    FREE,  //every action can be done
    SENDING, //a publish message is being sent
    QUEUED_VALUE //the sensor has read a new value while a send was in progress (only for client)
};

//general_constants
enum{
    AM_MY_MSG = 6,
    MAX_CLIENTS = 8,
    BROKER //automatically set to max_client + 1
};

#endif
