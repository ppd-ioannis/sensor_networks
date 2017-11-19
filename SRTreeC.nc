#include "SimpleRoutingTree.h"

#ifdef PRINTFDBG_MODE
	#include "printf.h"
#endif

module SRTreeC
{
	uses interface Boot;
	uses interface SplitControl as RadioControl;

	uses interface AMSend as RoutingAMSend;
	uses interface AMPacket as RoutingAMPacket;
	uses interface Packet as RoutingPacket;
	
	uses interface AMSend as NotifyAMSend;
	uses interface AMPacket as NotifyAMPacket;
	uses interface Packet as NotifyPacket;

	uses interface Timer<TMilli> as RoutingMsgTimer;  // θα τρέξει μια φορά
       // uses interface Timer<TMilli> as NodeValTimer; // ektos
        uses interface Timer<TMilli> as EndRoutingTimer;
        uses interface Timer<TMilli> as NotifyTimer;

        uses interface Random as RandNum ;
 	
	uses interface Receive as RoutingReceive; 
	uses interface Receive as NotifyReceive;
	
	uses interface PacketQueue as RoutingSendQueue;
	uses interface PacketQueue as RoutingReceiveQueue;
	
	uses interface PacketQueue as NotifySendQueue;
	uses interface PacketQueue as NotifyReceiveQueue;
}
implementation
{	
	message_t radioRoutingSendPkt;
	message_t radioNotifySendPkt;
	
	bool RoutingSendBusy=FALSE;
	bool NotifySendBusy=FALSE;

	uint8_t  curdepth;
	uint16_t parentID;

        uint16_t NodeVal;
        uint16_t interval;
         
        uint32_t StartSending;
	
       // Άρα έχουμε 4 task
	task void sendRoutingTask();
	task void sendNotifyTask();
	task void receiveRoutingTask();
	task void receiveNotifyTask();

	void setRoutingSendBusy(bool state)
	{
		atomic{
		RoutingSendBusy=state;
		}
	}
	
	void setNotifySendBusy(bool state)
	{
		atomic{
		NotifySendBusy=state;
		}
	}

	event void Boot.booted()
	{
                // έχουμε πάντα το ράδιο ανοιχτώ
		call RadioControl.start();
		
		setRoutingSendBusy(FALSE);
		setNotifySendBusy(FALSE);

		
		if(TOS_NODE_ID == 0)
		{
			curdepth=0;
			parentID=0;
                        interval = TIMER_EPOCH;
			dbg("Boot", " I wake up  Nid %d \n",TOS_NODE_ID);
		}
		else
		{
			curdepth=-1;
			parentID=-1;
			dbg("Boot", " I wake up  Nid %d \n",TOS_NODE_ID);
		}
	}
	
	event void RadioControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
			//dbg("Radio" , "Radio initialized successfully!!!\n");

			if (TOS_NODE_ID==0)
			{
				call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
                                call  EndRoutingTimer.startOneShot(5000);
			}
                      //  λαθος γιατι βαράει για όλους τους κόμβους
                      //  call  EndRoutingTimer.startOneShot(5000);// after 5sec Routing end
		}
		else
		{
			dbg("Radio" , "Radio initialization failed! Retrying...\n");

			call RadioControl.start();
		}
	}
	
	event void RadioControl.stopDone(error_t err)
	{ 
		dbg("Radio", "Radio stopped!\n");
	}

	event void  EndRoutingTimer.fired()
        {
           // time slot = (TIMER_EPOCH/Max_depth) = 6000  
           // Προσθέτουμε (TOS_NODE_ID*2) ανάλογα με το id του κόμβου για να μην στέλνουν όλα τα παιδιά μαζί
            StartSending =  (TOS_NODE_ID*2) + 6000 - (curdepth*6000)/Max_depth;

            call NotifyTimer.startPeriodicAt(StartSending,TIMER_EPOCH);
           //dbg("SRTreeC", " End Routing Timer =  %d \n",call EndRoutingTimer.getNow());

           //test 
           //call NotifyTimer.startOneShotAt(StartSending,TIMER_EPOCH);
        }

	event void  NotifyTimer.fired()
        {
           dbg("SRTreeC", " NotifyTimer.fired()  id =  %d \n",TOS_NODE_ID);

            // Υπολογίζουμε ότι θέλουμε 
        
        }

	event void RoutingMsgTimer.fired()
	{
		message_t tmp;
		error_t enqueueDone;
		RoutingMsg* mrpkt;

              // dbg("SRTreeC", "RoutingMsgTimer.fired RoutingMsgTimer.fired  \n");
 
		if(call RoutingSendQueue.full())
		{
                     dbg("SRTreeC", "RoutingSendQueue is FULL!!! \n");
			return;
		}
		
		mrpkt = (RoutingMsg*) (call RoutingPacket.getPayload(&tmp, sizeof(RoutingMsg)));

		if(mrpkt==NULL)
		{
			dbg("SRTreeC","RoutingMsgTimer.fired(): No valid payload... \n");
			return;
		}

		atomic{
		mrpkt->senderID = TOS_NODE_ID;
		mrpkt->depth = curdepth;
		}

		call RoutingAMPacket.setDestination(&tmp, AM_BROADCAST_ADDR);
		call RoutingPacket.setPayloadLength(&tmp, sizeof(RoutingMsg));
		
		enqueueDone=call RoutingSendQueue.enqueue(tmp);
		
		if( enqueueDone==SUCCESS)
		{
			if (call RoutingSendQueue.size()==1)
			{
				post sendRoutingTask();
			}
		}
		else
		{
			dbg("SRTreeC","RoutingMsg failed to be enqueued in SendingQueue!!!");
		}		
	}
	

	event void RoutingAMSend.sendDone(message_t * msg , error_t err) // Signaled in response to an accepted send request.
	{   
		setRoutingSendBusy(FALSE); // Σταματάω να προσπαθώ να στείλω μνμ
		
		if(!(call RoutingSendQueue.empty())) // Αν η ουρά δεν είναι άδεια     // Μαλον είναι εκτοσ (???)
		{
                     dbg("SRTreeC", "RAMSend.sd WE SEND AGAINNNNNNNNNNNNNNNNNNN \n");
			post sendRoutingTask(); //Προσπάθω να στείλω τα μνμ τις ουράς ένα ένα
		}	
	}
	
	event void NotifyAMSend.sendDone(message_t *msg , error_t err)
	{
		dbg("SRTreeC", "A Notify package sent... %s \n",(err==SUCCESS)?"True":"False");

		setNotifySendBusy(FALSE);
		
		if(!(call NotifySendQueue.empty()))
		{
			post sendNotifyTask();
		}
	}
	
	event message_t* NotifyReceive.receive( message_t* msg , void* payload , uint8_t len)
	{
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;
		
		msource = call NotifyAMPacket.source(msg);
		
		dbg("SRTreeC", "### NotifyReceive.receive() start ##### \n");
		dbg("SRTreeC", "Something received!!!  from %u = %u \n",((NotifyParentMsg*) payload)->senderID, msource);

		atomic{
		memcpy(&tmp,msg,sizeof(message_t));
		}
		enqueueDone=call NotifyReceiveQueue.enqueue(tmp);
		
		if( enqueueDone== SUCCESS)
		{
			post receiveNotifyTask();
		}
		else
		{
			dbg("SRTreeC","NotifyMsg enqueue failed!!! \n");	
		}
		//dbg("SRTreeC", "### NotifyReceive.receive() end ##### \n");
		return msg;
	}


	event message_t* RoutingReceive.receive( message_t * msg , void * payload, uint8_t len)
	{
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;
		
     /* .source(...) Return the AM address of the source of the AM packet.
      If input is not an AM packet, the results of this command  are undefined.*/
		msource =call RoutingAMPacket.source(msg); 
		
		atomic{
		memcpy(&tmp,msg,sizeof(message_t));
		}

		enqueueDone=call RoutingReceiveQueue.enqueue(tmp);

		if(enqueueDone == SUCCESS)
		{
			dbg("SRTreeC","R.rec posting receiveRoutingTask()!!!!   Nid  = %d \n", TOS_NODE_ID);
			post receiveRoutingTask();
		}
		else
		{
			dbg("SRTreeC","RoutingMsg enqueue failed!!! \n");	
		}
		//dbg("SRTreeC", "R.rec RoutingReceive.receive() end\n\n");
		return msg;
	}
	
//////////////////////////// Tasks implementations //////////////////////////////
	
	
	task void sendRoutingTask() // Τραβάω μνμ απο την ούρα και το στέλνω
	{
		//uint8_t skip;
		uint8_t mlen;
		uint16_t mdest;
		error_t  trySend;// sendDone;
		//message_t radioRoutingSendPkt;
		
               // dbg("SRTreeC","SRTask SendRoutingTask(): Starting  Nid = %d\n",TOS_NODE_ID);

		if (call RoutingSendQueue.empty()) 
		{
			dbg("SRTreeC","sendRoutingTask(): Q is empty!\n");
             	        return;
		}
		 
                // Μέχρι εδώ έχω ένα μνμ στην ουρά να στείλω 
		
		if(RoutingSendBusy) // (???) // TRUE => Δεν μπορώ να στείλω νέο μνμ γιατί ήδη προσπαθώ να στείλω το προηγούμενο 
   // Όταν RoutingAMSend.send => RoutingAMSend.sendDone => Τότε θα έχει τελειώσει προσπάθεια να στείλω το προηγούμενο            
   // (επιτ ή αποτυχ)  => το RoutingSendBusy θα γίνει false
		{
			dbg("SRTreeC","sendRoutingTask(): RoutingSendBusy= TRUE!!!\n");
			//setLostRoutingSendTask(TRUE); // Περιμένω την LostTaskTimer.fired()
			return;
		}
		
		radioRoutingSendPkt = call RoutingSendQueue.dequeue(); // παίρνω το μνμ από την ουρά
		mlen= call RoutingPacket.payloadLength(&radioRoutingSendPkt);
		mdest=call RoutingAMPacket.destination(&radioRoutingSendPkt);

		if(mlen!=sizeof(RoutingMsg))
		{
			dbg("SRTreeC","\t\tsendRoutingTask(): Unknown message!!!\n");
			return;
		}

                trySend =call RoutingAMSend.send(mdest,&radioRoutingSendPkt,mlen);  

		if ( trySend == SUCCESS)
		{
			setRoutingSendBusy(TRUE);// προσπαθώ να στείλω το μνμ => Περίμενω να δω αν το έλαβε σωστά
		}
		else  // Απέτυχα να στείλω το μνμ
		{
			dbg("SRTreeC","send failed!!!\n");
         		//setRoutingSendBusy(FALSE);
		}
	}


	task void sendNotifyTask()
	{
		uint8_t mlen;//, skip;
		error_t trySend;// sendDone;
		uint16_t mdest;
		NotifyParentMsg* mpayload;
		
		//message_t radioNotifySendPkt;
		dbg("SRTreeC","SendNotifyTask(): going to send one more package.\n");

		if (call NotifySendQueue.empty())
		{
			dbg("SRTreeC","sendNotifyTask(): Q is empty!\n");
			return;
		}
		
		if(NotifySendBusy==TRUE)
		{
			dbg("SRTreeC","sendNotifyTask(): NotifySendBusy= TRUE!!!\n");
			//setLostNotifySendTask(TRUE);
			return;
		}
		
		radioNotifySendPkt = call NotifySendQueue.dequeue();
		mlen=call NotifyPacket.payloadLength(&radioNotifySendPkt);
		mpayload= call NotifyPacket.getPayload(&radioNotifySendPkt,mlen);
		
		if(mlen!= sizeof(NotifyParentMsg))
		{
			dbg("SRTreeC", "\t\t sendNotifyTask(): Unknown message!!\n");
			return;
		}
		
		dbg("SRTreeC" , " sendNotifyTask(): mlen = %u  senderID= %u \n",mlen,mpayload->senderID);
		mdest= call NotifyAMPacket.destination(&radioNotifySendPkt);
		
                trySend = call NotifyAMSend.send(mdest,&radioNotifySendPkt, mlen);
		
		if ( trySend == SUCCESS)
		{
			dbg("SRTreeC","sendNotifyTask(): Send returned success!!!\n");
			setNotifySendBusy(TRUE);
		}
		else
		{
			dbg("SRTreeC","send failed!!!\n");
			//setNotifySendBusy(FALSE);
		}
	}

	
	task void receiveRoutingTask()
	{
		uint8_t  len;
                uint32_t _time;
		message_t radioRoutingRecPkt;
		
		radioRoutingRecPkt= call RoutingReceiveQueue.dequeue(); //βγάζω το μνμ (που έλαβα) από την ουρά
		
		len= call RoutingPacket.payloadLength(&radioRoutingRecPkt);
					
		if(len == sizeof(RoutingMsg))  // Έχω λάβει κάποιο μνμ
		{
			RoutingMsg * mpkt = (RoutingMsg*) (call RoutingPacket.getPayload(&radioRoutingRecPkt,len));
			
   		        if ( (parentID<0)||(parentID>=65535)) //Δεν έχω ακόμα πατέρα 
			{
                                // Αυτός που έστειλε έιναι ο πατέρας μου
				parentID = call RoutingAMPacket.source(&radioRoutingRecPkt);//mpkt->senderID; 
				curdepth = mpkt->depth + 1;
                                interval = mpkt->interval - (TIMER_EPOCH/curdepth);//-....

 //dbg("SRTreeC","rRTask Parent->intrval:  %d ,epoch/d = %d\n", mpkt->interval ,(TIMER_EPOCH/curdepth));
 //dbg("SRTreeC","rRTask Parent->Child:  %d -> %d , child_depth = %d ,interval = %d\n",  parentID,TOS_NODE_ID,curdepth,interval  );

				if (TOS_NODE_ID!=0)
				{
					call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
                                        _time = 5000 - (curdepth*4800)/Max_depth;

                                        call  EndRoutingTimer.startOneShot(_time);
				}
			}
			else //Έχω πατέρα 
			{
                               //  ...............
                            uint16_t p =call RoutingAMPacket.source(&radioRoutingRecPkt);
                           dbg("SRTreeC","rRTask  sender-> receiver:  %d -> %d \n",p,TOS_NODE_ID);
			}
		}
		else
		{
			dbg("SRTreeC","receiveRoutingTask():Empty message!!! \n");
			//setLostRoutingRecTask(TRUE);
			return;
		}
		
	}

 
	task void receiveNotifyTask()
	{
		uint8_t len;
		message_t radioNotifyRecPkt;
		
                dbg("SRTreeC","ReceiveNotifyTask():received msg...\n");

		radioNotifyRecPkt = call NotifyReceiveQueue.dequeue(); //βγάζω το μνμ (που έλαβα) από την ουρά		
		len = call NotifyPacket.payloadLength(&radioNotifyRecPkt);
		
		if(len == sizeof(NotifyParentMsg))  // Έχω λάβει κάποιο μνμ
		{
                        //    (adel)
			// an to parentID == TOS_NODE_ID tote   // (**)
			// tha proothei to minima pros tin riza xoris broadcast
			// kai tha ananeonei ton tyxon pinaka paidion..
			// allios tha diagrafei to paidi apo ton pinaka paidion
			
			NotifyParentMsg* mr = (NotifyParentMsg*) (call NotifyPacket.getPayload(&radioNotifyRecPkt,len));
			
			dbg("SRTreeC" , "NotifyParentMsg received from %d !!! \n", mr->senderID);

			if ( mr->parentID == TOS_NODE_ID) // (**) Αν το μύνητα που έλαβε έχει ως πατέρα τον ίδιο τον κόμβο 
			{                                 // Τότε βάζει τον κόμβο που το έστειλε ως παιδί του   
 
				// tote prosthiki stin lista ton paidion.
				
			}
			else  
			{
			// apla diagrafei ton komvo apo paidi tou..  // ??? γιατί πότε τον είχε βάλει στην λίστα παιδιά του
				
			}
			
		}
		else
		{
			dbg("SRTreeC","receiveNotifyTask():Empty message!!! \n");
			//setLostNotifyRecTask(TRUE);
			return;
		}	
	}
}
