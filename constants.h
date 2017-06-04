/**
 *  Header file containing all constants
 */

#ifndef CONSTANTS_H
#define CONSTANTS_H

typedef nx_struct conn_msg {
	nx_uint8_t msg_type;
} conn_msg_t;

typedef nx_struct sub_msg {
	nx_uint8_t msg_type;
	nx_uint16_t msg_id;
	nx_uint8_t topic;
	nx_uint8_t qos;
} sub_msg_t;

typedef nx_struct pub_msg {
	nx_uint8_t msg_type;
	nx_uint16_t msg_id;
	nx_uint8_t topic;
	nx_uint8_t qos;
	nx_uint16_t data;
} pub_msg_t;

typedef nx_struct data_msg {
	nx_uint8_t msg_type;
	nx_uint16_t msg_id;
	nx_uint8_t topic;
	nx_uint16_t data;
} data_msg_t;

enum{
	//AM type
	AM_MY_MSG = 6,
	//quality of service
	LOWQ = 0,
	HIGHQ = 1,
	//topics:
	TEMPERATURE = 2,
	HUMIDITY = 3,
	LUMINOSITY = 4,
	//msg types
	SUBSCRIBE = 7,
	PUBLISH = 8,
	CONNECT = 9
};

#endif
