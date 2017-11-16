#include "SimpleRoutingTree.h"
#ifdef PRINTFDBG_MODE
	#include "printf.h"
#endif

module SRTreeC
{
	uses interface Boot;
	uses interface SplitControl as RadioControl;
/*
#ifdef SERIAL_EN
	uses interface SplitControl as SerialControl; 
#endif*/

	uses interface AMSend as RoutingAMSend;
	uses interface AMPacket as RoutingAMPacket;
	uses interface Packet as RoutingPacket;
	
	uses interface AMSend as NotifyAMSend;
	uses interface AMPacket as NotifyAMPacket;
	uses interface Packet as NotifyPacket;

/*
#ifdef SERIAL_EN
	uses interface AMSend as SerialAMSend;
	uses interface AMPacket as SerialAMPacket;
	uses interface Packet as SerialPacket;
#endif*/
	//uses interface Leds;

	uses interface Timer<TMilli> as RoutingMsgTimer;  // θα τρέξει μια φορά

	//uses interface Timer<TMilli> as Led0Timer; 
	//uses interface Timer<TMilli> as Led1Timer;
	//uses interface Timer<TMilli> as Led2Timer;
	//uses interface Timer<TMilli> as LostTaskTimer;
	
	uses interface Receive as RoutingReceive; 
	uses interface Receive as NotifyReceive;
	//uses interface Receive as SerialReceive;
	
	uses interface PacketQueue as RoutingSendQueue;
	uses interface PacketQueue as RoutingReceiveQueue;
	
	uses interface PacketQueue as NotifySendQueue;
	uses interface PacketQueue as NotifyReceiveQueue;
}
implementation
{
	uint16_t  roundCounter;  // μπορούμε και να το βγάλουμε
	
	message_t radioRoutingSendPkt;
	message_t radioNotifySendPkt;
	
	
	//message_t serialPkt;
	////message_t serialRecPkt;
	
	bool RoutingSendBusy=FALSE;
	bool NotifySendBusy=FALSE;
/*
#ifdef SERIAL_EN
	bool serialBusy=FALSE;
#endif*/
	/* εκτός 
	bool lostRoutingSendTask=FALSE;
	bool lostNotifySendTask=FALSE;
	bool lostRoutingRecTask=FALSE;
	bool lostNotifyRecTask=FALSE;*/
	
	uint8_t curdepth;
	uint16_t parentID;
	
       // Άρα έχουμε 4 task
	task void sendRoutingTask();
	task void sendNotifyTask();
	task void receiveRoutingTask();
	task void receiveNotifyTask();
	
	/*void setLostRoutingSendTask(bool state)
	{
		atomic{
			lostRoutingSendTask=state;
		}
		if(state==TRUE)
		{
			//call Leds.led2On();
		}
		else 
		{
			//call Leds.led2Off();
		}
	}
	
	void setLostNotifySendTask(bool state)
	{
		atomic{
		lostNotifySendTask=state;
		}
		
		if(state==TRUE)
		{
			//call Leds.led2On();
		}
		else 
		{
			//call Leds.led2Off();
		}
	}
	
	void setLostNotifyRecTask(bool state)
	{
		atomic{
		lostNotifyRecTask=state;
		}
	}
	
	void setLostRoutingRecTask(bool state)
	{
		atomic{
		lostRoutingRecTask=state;
		}
	}*/

	void setRoutingSendBusy(bool state)
	{
		atomic{
		RoutingSendBusy=state;
		}
		/*if(state==TRUE)
		{
			call Leds.led0On();
			call Led0Timer.startOneShot(TIMER_LEDS_MILLI);
		}
		else 
		{
			//call Leds.led0Off();
		}*/
	}
	
	void setNotifySendBusy(bool state)
	{
		atomic{
		NotifySendBusy=state;
		}
		dbg("SRTreeC","NotifySendBusy = %s\n", (state == TRUE)?"TRUE":"FALSE");
#ifdef PRINTFDBG_MODE
		printf("\t\t\t\t\t\tNotifySendBusy = %s\n", (state == TRUE)?"TRUE":"FALSE");
#endif
		/*
		if(state==TRUE)
		{
			call Leds.led1On();
			call Led1Timer.startOneShot(TIMER_LEDS_MILLI);
		}
		else 
		{
			//call Leds.led1Off();
		}*/
	}
/*
#ifdef SERIAL_EN
	void setSerialBusy(bool state)
	{
		serialBusy=state;
		//if(state==TRUE)
		{
			//call Leds.led2On();
			call Led2Timer.startOneShot(TIMER_LEDS_MILLI);
		}
		else
		{
			//call Leds.led2Off();
		}
	}
#endif 
*/ 
	event void Boot.booted()
	{
		/////// arxikopoiisi radio kai serial
                // έχουμε πάντα το ράδιο ανοιχτώ
		call RadioControl.start();
		
		setRoutingSendBusy(FALSE);
		setNotifySendBusy(FALSE);
/*
#ifdef SERIAL_EN
		setSerialBusy(FALSE);
#endif
*/
		roundCounter = 0;
		
		if(TOS_NODE_ID == 0)
		{
/*
#ifdef SERIAL_EN
			call SerialControl.start();
#endif
*/
			curdepth=0;
			parentID=0;
			dbg("Boot", "curdepth = %d  ,  parentID= %d \n", curdepth , parentID);
#ifdef PRINTFDBG_MODE
			printf("Booted NodeID= %d : curdepth= %d , parentID= %d \n", TOS_NODE_ID ,curdepth , parentID);
			printfflush();
#endif
		}
		else
		{
			curdepth=-1;
			parentID=-1;
			dbg("Boot", "curdepth = %d  ,  parentID= %d \n", curdepth , parentID);
#ifdef PRINTFDBG_MODE
			printf("Booted NodeID= %d : curdepth= %d , parentID= %d \n", TOS_NODE_ID ,curdepth , parentID);
			printfflush();
#endif
		}
	}
	
	event void RadioControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			dbg("Radio" , "Radio initialized successfully!!!\n");
#ifdef PRINTFDBG_MODE
			printf("Radio initialized successfully!!!\n");
			printfflush();
#endif
			
			//call RoutingMsgTimer.startOneShot(TIMER_PERIOD_MILLI);
			//call RoutingMsgTimer.startPeriodic(TIMER_PERIOD_MILLI);
			//call LostTaskTimer.startPeriodic(SEND_CHECK_MILLIS);
			if (TOS_NODE_ID==0)
			{
				call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
			}
		}
		else
		{
			dbg("Radio" , "Radio initialization failed! Retrying...\n");
#ifdef PRINTFDBG_MODE
			printf("Radio initialization failed! Retrying...\n");
			printfflush();
#endif
			call RadioControl.start();
		}
	}
	
	event void RadioControl.stopDone(error_t err)
	{ 
		dbg("Radio", "Radio stopped!\n");
#ifdef PRINTFDBG_MODE
		printf("Radio stopped!\n");
		printfflush();
#endif
	}
/*
	event void SerialControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			dbg("Serial" , "Serial initialized successfully! \n");
#ifdef PRINTFDBG_MODE
			printf("Serial initialized successfully! \n");
			printfflush();
#endif
			//call RoutingMsgTimer.startPeriodic(TIMER_PERIOD_MILLI);
		}
		else
		{
			dbg("Serial" , "Serial initialization failed! Retrying... \n");
#ifdef PRINTFDBG_MODE
			printf("Serial initialization failed! Retrying... \n");
			printfflush();
#endif
			call SerialControl.start();
		}
	}

	event void SerialControl.stopDone(error_t err)
	{
		dbg("Serial", "Serial stopped! \n");
#ifdef PRINTFDBG_MODE
		printf("Serial stopped! \n");
		printfflush();
#endif
	}
*/

  /*	//Δεν μπάινει ποτέ
        event void LostTaskTimer.fired()     // Ξανατρέχει τα Tasks
	{
		if (lostRoutingSendTask)
		{
			post sendRoutingTask();
			setLostRoutingSendTask(FALSE);
		}
		
		if( lostNotifySendTask)
		{
			post sendNotifyTask();
			setLostNotifySendTask(FALSE);
		}
		
		if (lostRoutingRecTask)
		{
			post receiveRoutingTask();
			setLostRoutingRecTask(FALSE);
		}
		
		if ( lostNotifyRecTask)
		{
			post receiveNotifyTask();
			setLostNotifyRecTask(FALSE);
		}
	}  */
	
	event void RoutingMsgTimer.fired()
	{
		message_t tmp;
		error_t enqueueDone;
		
		RoutingMsg* mrpkt;
		dbg("SRTreeC", "RoutingMsgTimer fired!  radioBusy = %s \n",(RoutingSendBusy)?"True":"False");
#ifdef PRINTFDBG_MODE
		printfflush();
		printf("RoutingMsgTimer fired!  radioBusy = %s \n",(RoutingSendBusy)?"True":"False");
		printfflush();
#endif

              dbg("SRTreeC", "\n\naaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa   id = %d\n",TOS_NODE_ID);

              /*
		if (TOS_NODE_ID==0)    // Πρέπει να είναι εκτός δεν ξαναστέλνουμε Routing msg και πλεον το roundCounter μετράει πόσες εποχές θα τρέξει
		{ 
			roundCounter+=1;  //
			
			dbg("SRTreeC", "\n ##################################### \n");
			dbg("SRTreeC", "#######   ROUND   %u    ############## \n", roundCounter);
			dbg("SRTreeC", "#####################################\n");
			
                       //The <code>fired</code> will be signaled when the timer expires.
		       call RoutingMsgTimer.startOneShot(TIMER_PERIOD_MILLI); //εκτοσ
		}*/
		
		if(call RoutingSendQueue.full())
		{
#ifdef PRINTFDBG_MODE
			printf("RoutingSendQueue is FULL!!! \n");
			printfflush();
#endif
			return;
		}
		
		
		mrpkt = (RoutingMsg*) (call RoutingPacket.getPayload(&tmp, sizeof(RoutingMsg)));

		if(mrpkt==NULL)
		{
			dbg("SRTreeC","RoutingMsgTimer.fired(): No valid payload... \n");
#ifdef PRINTFDBG_MODE
			printf("RoutingMsgTimer.fired(): No valid payload... \n");
			printfflush();
#endif
			return;
		}

		atomic{
		mrpkt->senderID = TOS_NODE_ID;
		mrpkt->depth = curdepth;
		}

		dbg("SRTreeC" , "Sending RoutingMsg... \n");

#ifdef PRINTFDBG_MODE
		printf("NodeID= %d : RoutingMsg sending...!!!! \n", TOS_NODE_ID);
		printfflush();
#endif		
		call RoutingAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
		call RoutingPacket.setPayloadLength(&tmp, sizeof(RoutingMsg));
		
		enqueueDone=call RoutingSendQueue.enqueue(tmp);
		
		if( enqueueDone==SUCCESS)
		{
			if (call RoutingSendQueue.size()==1)
			{
				dbg("SRTreeC", "SendTask() posted!!\n");
#ifdef PRINTFDBG_MODE
				printf("SendTask() posted!!\n");
				printfflush();
#endif
				post sendRoutingTask();
			}
			
			dbg("SRTreeC","RoutingMsg enqueued successfully in SendingQueue!!!\n");
#ifdef PRINTFDBG_MODE
			printf("RoutingMsg enqueued successfully in SendingQueue!!!\n");
			printfflush();
#endif
		}
		else
		{
			dbg("SRTreeC","RoutingMsg failed to be enqueued in SendingQueue!!!");
#ifdef PRINTFDBG_MODE			
			printf("RoutingMsg failed to be enqueued in SendingQueue!!!\n");
			printfflush();
#endif
		}		
	}
	
	/*event void Led0Timer.fired()
	{
		call Leds.led0Off();
	}
	event void Led1Timer.fired()
	{
		call Leds.led1Off();
	}
	event void Led2Timer.fired()
	{
		call Leds.led2Off();
	}*/
	

	event void RoutingAMSend.sendDone(message_t * msg , error_t err) // Signaled in response to an accepted send request.
	{   // Πέτυχα ή Απέτυχα να στείλω το μνμ => Πέτυχα ή Απέτυχα να λάβει ο πραλήπτης το μνμ

		dbg("SRTreeC", "A Routing package sent... %s \n",(err==SUCCESS)?"True":"False");
#ifdef PRINTFDBG_MODE
		printf("A Routing package sent... %s \n",(err==SUCCESS)?"True":"False");
		printfflush();
#endif
		
		dbg("SRTreeC" , "Package sent %s \n", (err==SUCCESS)?"True":"False");
#ifdef PRINTFDBG_MODE
		printf("Package sent %s \n", (err==SUCCESS)?"True":"False");
		printfflush();
#endif
		setRoutingSendBusy(FALSE); // Σταματάω να προσπαθώ να στείλω μνμ
		
		if(!(call RoutingSendQueue.empty())) // Αν η ουρά δεν είναι άδεια     // Μαλον είναι εκτοσ (???)
		{
			post sendRoutingTask(); //Προσπάθω να στείλω τα μνμ τις ουράς ένα ένα
		}
		//call Leds.led0Off();		
	}
	
	event void NotifyAMSend.sendDone(message_t *msg , error_t err)
	{
		dbg("SRTreeC", "A Notify package sent... %s \n",(err==SUCCESS)?"True":"False");
#ifdef PRINTFDBG_MODE
		printf("A Notify package sent... %s \n",(err==SUCCESS)?"True":"False");
		printfflush();
#endif
		
	
		dbg("SRTreeC" , "Package sent %s \n", (err==SUCCESS)?"True":"False");
#ifdef PRINTFDBG_MODE
		printf("Package sent %s \n", (err==SUCCESS)?"True":"False");
		printfflush();
#endif
		setNotifySendBusy(FALSE);
		
		if(!(call NotifySendQueue.empty()))
		{
			post sendNotifyTask();
		}
		//call Leds.led0Off();
		
		
	}
/*	
	event void SerialAMSend.sendDone(message_t* msg , error_t err)
	{
		if ( &serialPkt == msg)
		{
			dbg("Serial" , "Package sent %s \n", (err==SUCCESS)?"True":"False");
#ifdef PRINTFDBG_MODE
			printf("Package sent %s \n", (err==SUCCESS)?"True":"False");
			printfflush();
#endif
			setSerialBusy(FALSE);
			
			//call Leds.led2Off();
		}
	}
	*/
	
	event message_t* NotifyReceive.receive( message_t* msg , void* payload , uint8_t len)
	{
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;
		
		msource = call NotifyAMPacket.source(msg);
		
		dbg("SRTreeC", "### NotifyReceive.receive() start ##### \n");
		dbg("SRTreeC", "Something received!!!  from %u   %u \n",((NotifyParentMsg*) payload)->senderID, msource);
#ifdef PRINTFDBG_MODE		
		printf("Something Received!!!, len = %u , npm=%u , rm=%u\n",len, sizeof(NotifyParentMsg), sizeof(RoutingMsg));
		printfflush();
#endif

		//if(len!=sizeof(NotifyParentMsg))
		//{
			//dbg("SRTreeC","\t\tUnknown message received!!!\n");
//#ifdef PRINTFDBG_MODE
			//printf("\t\t Unknown message received!!!\n");
			//printfflush();
//#endif
			//return msg;http://courses.ece.tuc.gr/
		//}
		
		//call Leds.led1On();
		//call Led1Timer.startOneShot(TIMER_LEDS_MILLI);
		atomic{
		memcpy(&tmp,msg,sizeof(message_t));
		//tmp=*(message_t*)msg;
		}
		enqueueDone=call NotifyReceiveQueue.enqueue(tmp);
		
		if( enqueueDone== SUCCESS)
		{
#ifdef PRINTFDBG_MODE
			printf("posting receiveNotifyTask()!!!! \n");
			printfflush();
#endif
			post receiveNotifyTask();
		}
		else
		{
			dbg("SRTreeC","NotifyMsg enqueue failed!!! \n");
#ifdef PRINTFDBG_MODE
			printf("NotifyMsg enqueue failed!!! \n");
			printfflush();
#endif			
		}
		
		//call Leds.led1Off();
		dbg("SRTreeC", "### NotifyReceive.receive() end ##### \n");
		return msg;
	}

//	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	event message_t* RoutingReceive.receive( message_t * msg , void * payload, uint8_t len)
	{
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;
		
     /* .source(...) Return the AM address of the source of the AM packet.
      If input is not an AM packet, the results of this command  are undefined.*/
		msource =call RoutingAMPacket.source(msg); 
		
		dbg("SRTreeC", "### RoutingReceive.receive() start ##### \n");
		dbg("SRTreeC", "Something received!!!  from %u  %u \n",((RoutingMsg*) payload)->senderID ,  msource);
		//dbg("SRTreeC", "Something received!!!\n");
#ifdef PRINTFDBG_MODE		
		printf("Something Received!!!, len = %u , npm=%u , rm=%u\n",len, sizeof(NotifyParentMsg), sizeof(RoutingMsg)); 
		printfflush();
#endif
		//call Leds.led1On();
		//call Led1Timer.startOneShot(TIMER_LEDS_MILLI);
		
		//if(len!=sizeof(RoutingMsg))
		//{
			//dbg("SRTreeC","\t\tUnknown message received!!!\n");
//#ifdef PRINTFDBG_MODE
			//printf("\t\t Unknown message received!!!\n");
			//printfflush();
//#endif
			//return msg;
		//}
		
		atomic{
		memcpy(&tmp,msg,sizeof(message_t));
		//tmp=*(message_t*)msg;
		}

		enqueueDone=call RoutingReceiveQueue.enqueue(tmp);

		if(enqueueDone == SUCCESS)
		{
#ifdef PRINTFDBG_MODE
			printf("posting receiveRoutingTask()!!!! \n");
			printfflush();
#endif
			post receiveRoutingTask();
		}
		else
		{
			dbg("SRTreeC","RoutingMsg enqueue failed!!! \n");
#ifdef PRINTFDBG_MODE
			printf("RoutingMsg enqueue failed!!! \n");
			printfflush();
#endif			
		}
		
		//call Leds.led1Off();
		
		dbg("SRTreeC", "### RoutingReceive.receive() end ##### \n");
		return msg;
	}
/*	
	event message_t* SerialReceive.receive(message_t* msg , void* payload , uint8_t len)
	{
		// when receiving from serial port
		dbg("Serial","Received msg from serial port \n");
#ifdef PRINTFDBG_MODE
		printf("Reveived message from serial port \n");
		printfflush();
#endif
		return msg;
	}*/
	
	////////////// Tasks implementations //////////////////////////////
	
	
	task void sendRoutingTask() // Τραβάω μνμ απο την ούρα και το στέλνω
	{
		//uint8_t skip;
		uint8_t mlen;
		uint16_t mdest;
		error_t  trySend;// sendDone;
		//message_t radioRoutingSendPkt;
		
#ifdef PRINTFDBG_MODE
		printf("SendRoutingTask(): Starting....\n");
		printfflush();
#endif
		if (call RoutingSendQueue.empty()) 
		{
			dbg("SRTreeC","sendRoutingTask(): Q is empty!\n");
#ifdef PRINTFDBG_MODE		
			printf("sendRoutingTask():Q is empty!\n");
			printfflush();
#endif
			return;
		}
		 
                // Μέχρι εδώ έχω ένα μνμ στην ουρά να στείλω 
		
		if(RoutingSendBusy) // (???) // TRUE => Δεν μπορώ να στείλω νέο μνμ γιατί ήδη προσπαθώ να στείλω το προηγούμενο 
                                    // Όταν RoutingAMSend.send => RoutingAMSend.sendDone => Τότε θα έχει τελειώσει προσπάθεια να στείλω το προηγούμενο (επιτ ή αποτυχ) =>
                                    // => το RoutingSendBusy θα γίνει false
		{
			dbg("SRTreeC","sendRoutingTask(): RoutingSendBusy= TRUE!!!\n");
#ifdef PRINTFDBG_MODE
			printf(	"sendRoutingTask(): RoutingSendBusy= TRUE!!!\n");
			printfflush();
#endif
			//setLostRoutingSendTask(TRUE); // Περιμένω την LostTaskTimer.fired()
			return;
		}
		
		radioRoutingSendPkt = call RoutingSendQueue.dequeue(); // παίρνω το μνμ από την ουρά
		
		//call Leds.led2On();
		//call Led2Timer.startOneShot(TIMER_LEDS_MILLI);

                //βρίσκω τα στοιχεία του μνμ
		mlen= call RoutingPacket.payloadLength(&radioRoutingSendPkt);
		mdest=call RoutingAMPacket.destination(&radioRoutingSendPkt);

		if(mlen!=sizeof(RoutingMsg))
		{
			dbg("SRTreeC","\t\tsendRoutingTask(): Unknown message!!!\n");
#ifdef PRINTFDBG_MODE
			printf("\t\tsendRoutingTask(): Unknown message!!!!\n");
			printfflush();
#endif
			return;
		}

		//sendDone
                trySend =call RoutingAMSend.send(mdest,&radioRoutingSendPkt,mlen);  
               // δεν το έχω στείλει ακόμα άρα δεν είναι σωστό το όνομα sendDone
      
      /* AMSend.send(...)
      If send returns SUCCESS, then the component will signal the sendDone event in the future; =>
      => ότι ήταν επιτυχείς η αποστόλη του μνμ αλλά δεν ξέρω αν το έλαβε σωστά ο άλλος κόμβος =>
      => Αυτό το μαθαίνω από την AMSend.sendDone(...)
      if send returns an error, it will notsignal the event. 
      
      Note that a component may accept a send request which it later finds it cannot satisfy; 
      in this case, it will signal sendDone with error code.
       */	
                
		if ( trySend == SUCCESS) //sendDone== SUCCESS)// Έχω στείλει το μνμ 
		{
			dbg("SRTreeC","sendRoutingTask(): Send returned success!!!\n");
#ifdef PRINTFDBG_MODE
			printf("sendRoutingTask(): Send returned success!!!\n");
			printfflush();
#endif
			setRoutingSendBusy(TRUE);// προσπαθώ να στείλω το μνμ => Περίμενω να δω αν το έλαβε σωστά
		}
		else  // Απέτυχα να στείλω το μνμ
		{
			dbg("SRTreeC","send failed!!!\n");
#ifdef PRINTFDBG_MODE
			printf("SendRoutingTask(): send failed!!!\n");
#endif
			//setRoutingSendBusy(FALSE);
		}
	}
	/**
	 * dequeues a message and sends it
	 */
	task void sendNotifyTask()
	{
		uint8_t mlen;//, skip;
		error_t trySend;// sendDone;
		uint16_t mdest;
		NotifyParentMsg* mpayload;
		
		//message_t radioNotifySendPkt;
		
#ifdef PRINTFDBG_MODE
		printf("SendNotifyTask(): going to send one more package.\n");
		printfflush();
#endif
		if (call NotifySendQueue.empty())
		{
			dbg("SRTreeC","sendNotifyTask(): Q is empty!\n");
#ifdef PRINTFDBG_MODE		
			printf("sendNotifyTask():Q is empty!\n");
			printfflush();
#endif
			return;
		}
		
		if(NotifySendBusy==TRUE)
		{
			dbg("SRTreeC","sendNotifyTask(): NotifySendBusy= TRUE!!!\n");
#ifdef PRINTFDBG_MODE
			printf(	"sendTask(): NotifySendBusy= TRUE!!!\n");
			printfflush();
#endif
			//setLostNotifySendTask(TRUE);
			return;
		}
		
		radioNotifySendPkt = call NotifySendQueue.dequeue();
		
		//call Leds.led2On();
		//call Led2Timer.startOneShot(TIMER_LEDS_MILLI);
		mlen=call NotifyPacket.payloadLength(&radioNotifySendPkt);
		
		mpayload= call NotifyPacket.getPayload(&radioNotifySendPkt,mlen);
		
		if(mlen!= sizeof(NotifyParentMsg))
		{
			dbg("SRTreeC", "\t\t sendNotifyTask(): Unknown message!!\n");
#ifdef PRINTFDBG_MODE
			printf("\t\t sendNotifyTask(): Unknown message!!\n");
			printfflush();
#endif
			return;
		}
		
		dbg("SRTreeC" , " sendNotifyTask(): mlen = %u  senderID= %u \n",mlen,mpayload->senderID);
#ifdef PRINTFDBG_MODE
		printf("\t\t\t\t sendNotifyTask(): mlen=%u\n",mlen);
		printfflush();
#endif
		mdest= call NotifyAMPacket.destination(&radioNotifySendPkt);
		
		
		//sendDone
                 trySend = call NotifyAMSend.send(mdest,&radioNotifySendPkt, mlen);
		
		if ( trySend == SUCCESS) //sendDone== SUCCESS)
		{
			dbg("SRTreeC","sendNotifyTask(): Send returned success!!!\n");
#ifdef PRINTFDBG_MODE
			printf("sendNotifyTask(): Send returned success!!!\n");
			printfflush();
#endif
			setNotifySendBusy(TRUE);
		}
		else
		{
			dbg("SRTreeC","send failed!!!\n");
#ifdef PRINTFDBG_MODE
			printf("SendNotifyTask(): send failed!!!\n");
#endif
			//setNotifySendBusy(FALSE);
		}
	}
	////////////////////////////////////////////////////////////////////
	//*****************************************************************/
	///////////////////////////////////////////////////////////////////
	/**
	 * dequeues a message and processes it
	 */
	
	task void receiveRoutingTask()
	{
		//message_t tmp;
		uint8_t len;
		message_t radioRoutingRecPkt;
		
#ifdef PRINTFDBG_MODE
		printf("ReceiveRoutingTask():received msg...\n");
		printfflush();
#endif
		radioRoutingRecPkt= call RoutingReceiveQueue.dequeue(); //βγάζω το μνμ (που έλαβα) από την ουρά
		
		len= call RoutingPacket.payloadLength(&radioRoutingRecPkt);
		
		dbg("SRTreeC","ReceiveRoutingTask(): len=%u \n",len);
#ifdef PRINTFDBG_MODE
		printf("ReceiveRoutingTask(): len=%u!\n",len);
		printfflush();
#endif
		// processing of radioRecPkt
		
		// pos tha xexorizo ta 2 diaforetika minimata (από adel)
				
		if(len == sizeof(RoutingMsg))  // Έχω λάβει κάποιο μνμ
		{
			//NotifyParentMsg* m;
			RoutingMsg * mpkt = (RoutingMsg*) (call RoutingPacket.getPayload(&radioRoutingRecPkt,len));
			
			//if(TOS_NODE_ID >0)  (adel)
			//{  
				//call RoutingMsgTimer.startOneShot(TIMER_PERIOD_MILLI);
			//}
			//
			
			dbg("SRTreeC" , "receiveRoutingTask():senderID= %d , depth= %d \n", mpkt->senderID , mpkt->depth);
#ifdef PRINTFDBG_MODE
			printf("NodeID= %d , RoutingMsg received! \n",TOS_NODE_ID);
			printf("receiveRoutingTask():senderID= %d , depth= %d \n", mpkt->senderID , mpkt->depth);
			printfflush();
#endif
			if ( (parentID<0)||(parentID>=65535)) //Δεν έχω ακόμα πατέρα 
			{
				// tote den exei akoma patera
				parentID= call RoutingAMPacket.source(&radioRoutingRecPkt);//mpkt->senderID; // Αυτός που έστειλε έιναι ο πατέρας μου
				curdepth= mpkt->depth + 1;
#ifdef PRINTFDBG_MODE
				printf("NodeID= %d : curdepth= %d , parentID= %d \n", TOS_NODE_ID ,curdepth , parentID);
				printfflush();
#endif
				/*// tha stelnei kai ena minima NotifyParentMsg ston patera
				
				m = (NotifyParentMsg *) (call NotifyPacket.getPayload(&tmp, sizeof(NotifyParentMsg)));
				m->senderID=TOS_NODE_ID;
				m->depth = curdepth;
				m->parentID = parentID;
				dbg("SRTreeC" , "receiveRoutingTask():NotifyParentMsg sending to node= %d... \n", parentID);
#ifdef PRINTFDBG_MODE
				printf("NotifyParentMsg NodeID= %d sent!!! \n", TOS_NODE_ID);
				printfflush();
#endif
				call NotifyAMPacket.setDestination(&tmp, parentID);
				call NotifyPacket.setPayloadLength(&tmp,sizeof(NotifyParentMsg));
				
				if (call NotifySendQueue.enqueue(tmp)==SUCCESS)
				{
					dbg("SRTreeC", "receiveRoutingTask(): NotifyParentMsg enqueued in SendingQueue successfully!!!");
#ifdef PRINTFDBG_MODE
					printf("receiveRoutingTask(): NotifyParentMsg enqueued successfully!!!");
					printfflush();
#endif
					if (call NotifySendQueue.size() == 1)
					{
						post sendNotifyTask();
					}
				}*/

				if (TOS_NODE_ID!=0)
				{
					call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD); // για να ξανατρέξει ένα καιούργιο round
				}
			}
			/*else //Έχω πατέρα 
			{
				
				if (( curdepth > mpkt->depth +1) || (mpkt->senderID==parentID)) // Αλλάζω πατέρα
				{
					uint16_t oldparentID = parentID;
					
				
					parentID= call RoutingAMPacket.source(&radioRoutingRecPkt);//mpkt->senderID; //βρίσκω τον πατέρα που απέχουμε βάθος 1
					curdepth = mpkt->depth + 1;
				
#ifdef PRINTFDBG_MODE
					printf("NodeID= %d : curdepth= %d , parentID= %d \n", TOS_NODE_ID ,curdepth , parentID);
					printfflush();
#endif					
									
					
					dbg("SRTreeC" , "NotifyParentMsg sending to node= %d... \n", oldparentID);
#ifdef PRINTFDBG_MODE
					printf("NotifyParentMsg sending to node=%d... \n", oldparentID);
					printfflush();
#endif
					if ( (oldparentID<65535) || (oldparentID>0) || (oldparentID==parentID)) //Αν δεν βρήκα νέο πατέρα
					{
                                                // στέλνω ένα NotifyParentMsg στον παλιό πατέρα
						m = (NotifyParentMsg *) (call NotifyPacket.getPayload(&tmp, sizeof(NotifyParentMsg)));
						m->senderID=TOS_NODE_ID;
						m->depth = curdepth;
						m->parentID = parentID;
						
						call NotifyAMPacket.setDestination(&tmp,oldparentID);
						//call NotifyAMPacket.setType(&tmp,AM_NOTIFYPARENTMSG);
						call NotifyPacket.setPayloadLength(&tmp,sizeof(NotifyParentMsg));
								
						if (call NotifySendQueue.enqueue(tmp)==SUCCESS)
						{
							dbg("SRTreeC", "receiveRoutingTask(): NotifyParentMsg enqueued in SendingQueue successfully!!!\n");
#ifdef PRINTFDBG_MODE
							printf("receiveRoutingTask(): NotifyParentMsg enqueued successfully!!!");
							printfflush();
#endif
							if (call NotifySendQueue.size() == 1)
							{
								post sendNotifyTask();
							}
						}
					}

					if (TOS_NODE_ID!=0)  // δεν τρεχει προς το παρον  ???
					{
						call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD); 
					}

					// tha stelnei kai ena minima NotifyParentMsg   (adel)
					// ston kainourio patera kai ston palio patera. (adel)
					
					if (oldparentID!=parentID) // Έχω νέο πατέρα
					{
                                               // στέλνω ένα NotifyParentMsg στον νέο πατέρα και       στον παλιό ???
						m = (NotifyParentMsg *) (call NotifyPacket.getPayload(&tmp, sizeof(NotifyParentMsg)));
						m->senderID=TOS_NODE_ID;
						m->depth = curdepth;
						m->parentID = parentID;
						dbg("SRTreeC" , "receiveRoutingTask():NotifyParentMsg sending to node= %d... \n", parentID);
#ifdef PRINTFDBG_MODE
						printf("NotifyParentMsg NodeID= %d sent!!! \n", TOS_NODE_ID);
						printfflush();
#endif
						call NotifyAMPacket.setDestination(&tmp, parentID);
						call NotifyPacket.setPayloadLength(&tmp,sizeof(NotifyParentMsg));
						
						if (call NotifySendQueue.enqueue(tmp)==SUCCESS)
						{
							dbg("SRTreeC", "receiveRoutingTask(): NotifyParentMsg enqueued in SendingQueue successfully!!! \n");
#ifdef PRINTFDBG_MODE					
							printf("receiveRoutingTask(): NotifyParentMsg enqueued successfully!!!");
							printfflush();
#endif
							if (call NotifySendQueue.size() == 1)
							{
								post sendNotifyTask();
							}
						}
					}
				}
				
				
			}*/
		}
		else
		{
			dbg("SRTreeC","receiveRoutingTask():Empty message!!! \n");
#ifdef PRINTFDBG_MODE
			printf("receiveRoutingTask():Empty message!!! \n");
			printfflush();
#endif
			//setLostRoutingRecTask(TRUE);
			return;
		}
		
	}


////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////	
	
	 
	task void receiveNotifyTask()
	{
		message_t tmp;
		uint8_t len;
		message_t radioNotifyRecPkt;
		
#ifdef PRINTFDBG_MODE
		printf("ReceiveNotifyTask():received msg...\n");
		printfflush();
#endif
		radioNotifyRecPkt = call NotifyReceiveQueue.dequeue(); //βγάζω το μνμ (που έλαβα) από την ουρά
		
		len = call NotifyPacket.payloadLength(&radioNotifyRecPkt);
		
		dbg("SRTreeC","ReceiveNotifyTask(): len=%u \n",len);
#ifdef PRINTFDBG_MODE
		printf("ReceiveNotifyTask(): len=%u!\n",len);
		printfflush();
#endif
		if(len == sizeof(NotifyParentMsg))  // Έχω λάβει κάποιο μνμ
		{
                        //    (adel)
			// an to parentID == TOS_NODE_ID tote   // (**)
			// tha proothei to minima pros tin riza xoris broadcast
			// kai tha ananeonei ton tyxon pinaka paidion..
			// allios tha diagrafei to paidi apo ton pinaka paidion
			
			NotifyParentMsg* mr = (NotifyParentMsg*) (call NotifyPacket.getPayload(&radioNotifyRecPkt,len));
			
			dbg("SRTreeC" , "NotifyParentMsg received from %d !!! \n", mr->senderID);
#ifdef PRINTFDBG_MODE
			printf("NodeID= %d NotifyParentMsg from senderID = %d!!! \n",TOS_NODE_ID , mr->senderID);
			printfflush();
#endif
			if ( mr->parentID == TOS_NODE_ID) // (**) Αν το μύνητα που έλαβε έχει ως πατέρα τον ίδιο τον κόμβο 
			{                                 // Τότε βάζει τον κόμβο που το έστειλε ως παιδί του   
 
				// tote prosthiki stin lista ton paidion.
				
			}
			else  
			{
				// apla diagrafei ton komvo apo paidi tou..  // ??? γιατί πότε τον είχε βάλει στην λίστα παιδιά του
				
			}

			if ( TOS_NODE_ID==0)//SOOOOOOOOOOOOOOOOOOOOOOOOS  (???) // ΑΝ είναι η ρίζα
			{
/*
#ifdef SERIAL_EN
				if (!serialBusy) //  (???)
				{
                                        // mipos mporei na mpei san task?
					NotifyParentMsg * m = (NotifyParentMsg *) (call SerialPacket.getPayload(&serialPkt, sizeof(NotifyParentMsg)));
					m->senderID=mr->senderID;
					m->depth = mr->depth;
					m->parentID = mr->parentID;
					dbg("Serial", "Sending NotifyParentMsg to PC... \n");
#ifdef PRINTFDBG_MODE
					printf("Sending NotifyParentMsg to PC..\n");
					printfflush();
#endif
					if (call SerialAMSend.send(parentID, &serialPkt, sizeof(NotifyParentMsg))==SUCCESS)
					{
						setSerialBusy(TRUE);
					}
				}
#endif
*/
			}
			else
			{
				NotifyParentMsg* m;
				memcpy(&tmp,&radioNotifyRecPkt,sizeof(message_t));
				
				m = (NotifyParentMsg *) (call NotifyPacket.getPayload(&tmp, sizeof(NotifyParentMsg)));
				//m->senderID=mr->senderID;
				//m->depth = mr->depth;
				//m->parentID = mr->parentID;
				
				dbg("SRTreeC" , "Forwarding NotifyParentMsg from senderID= %d  to parentID=%d \n" , m->senderID, parentID);
#ifdef PRINTFDBG_MODE
				printf("NotifyParentMsg NodeID= %d sent!\n", TOS_NODE_ID);
				printfflush();
#endif
				call NotifyAMPacket.setDestination(&tmp, parentID);
				call NotifyPacket.setPayloadLength(&tmp,sizeof(NotifyParentMsg));
				
				if (call NotifySendQueue.enqueue(tmp)==SUCCESS)
				{
					dbg("SRTreeC", "receiveNotifyTask(): NotifyParentMsg enqueued in SendingQueue successfully!!!\n");
					if (call NotifySendQueue.size() == 1)
					{
						post sendNotifyTask();
					}
				}

				
			}
			
		}
		else
		{
			dbg("SRTreeC","receiveNotifyTask():Empty message!!! \n");
#ifdef PRINTFDBG_MODE
			printf("receiveNotifyTask():Empty message!!! \n");
			printfflush();
#endif
			//setLostNotifyRecTask(TRUE);
			return;
		}
		
	}
	
}
