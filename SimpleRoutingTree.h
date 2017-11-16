#ifndef SIMPLEROUTINGTREE_H
#define SIMPLEROUTINGTREE_H


enum{
	SENDER_QUEUE_SIZE=5,
	RECEIVER_QUEUE_SIZE=3,

	AM_SIMPLEROUTINGTREEMSG=22,
	AM_ROUTINGMSG=22,
	AM_NOTIFYPARENTMSG=12,

	SEND_CHECK_MILLIS=70000,

	TIMER_PERIOD_MILLI=150000, // 600.000 ms
	TIMER_FAST_PERIOD=200,   // epoch = 60.000ms 

	TIMER_LEDS_MILLI=1000,   // ektos
};
/*uint16_t AM_ROUTINGMSG = AM_SIMPLEROUTINGTREEMSG;
uint16_t AM_NOTIFYPARENTMSG = AM_SIMPLEROUTINGTREEMSG;
*/

typedef nx_struct RoutingMsg
{
	nx_uint16_t  senderID;
        nx_uint16_t  interval; //Delivery interval
	nx_uint8_t   depth;

} RoutingMsg;


typedef nx_struct NotifyParentMsg
{
	nx_uint16_t senderID;
	nx_uint16_t parentID;
        nx_uint16_t value1;
        nx_uint16_t value2;
	nx_uint8_t depth; 

} NotifyParentMsg;


#endif
