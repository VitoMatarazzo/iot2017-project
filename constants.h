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
	nx_uint8_t dupflag; //duplicate flag, set to true if the message is resent because the
			            //broker didn't acknowledge the original msg. Useful when QoS > 0
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
	NOT_SUB; //used in subscription matrix to represent a missing subscription
	NOT_CONN; //used in subscription matrix to represent an disconneted client
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
	PUBLISH,
	UNSUBSCRIBE,
	DISCONNECT,
	/*
	CONNACK,
	SUBACK,
	PUBACK,
	UNSUBACK
	*/
};

//general_constants
enum{
    BROKER = 0,
    AM_MY_MSG = 6,
    MAX_CLIENTS = 8
};

/*
enum{
	OK,
	UNACCEPTABLE,
	ID_REJECTED,
	SERVER_UNAVAILABLE
};*/
#endif
