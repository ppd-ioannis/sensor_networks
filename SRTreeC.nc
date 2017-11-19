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
	uint8_t  round; 
	uint16_t parentID;

    uint16_t  Childern_id[Max_children];
    uint16_t  Childern_val[Max_children];
    uint16_t  Childern_valofSquares[Max_children];
    uint16_t  Childern_CountnNum[Max_children];

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
	   uint8_t i;
         // έχουμε πάντα το ράδιο ανοιχτώ
		call RadioControl.start();
		
		setRoutingSendBusy(FALSE);
		setNotifySendBusy(FALSE);

		
		if(TOS_NODE_ID == 0)
		{
			curdepth=0;
			parentID=0;
			dbg("Boot", " I wake up  Nid %d \n",TOS_NODE_ID);
		}
		else
		{
			curdepth=-1;
			parentID=-1;
			dbg("Boot", " I wake up  Nid %d \n",TOS_NODE_ID);
		}
      
       atomic{        
         for(i=0; i < Max_children ; i++)
         {
            Childern_id[i] = -1;
            Childern_val[i] = 0;
            Childern_valofSquares[i] = 0;
            Childern_CountnNum[i] = 0;
         }
       }
 
	}
	
	event void RadioControl.startDone(error_t err)
	{
		if (err == SUCCESS)
		{
	
			if (TOS_NODE_ID==0)
			{
				call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
                call  EndRoutingTimer.startOneShot(5000);
			}

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
           // time slot = (TIMER_EPOCH/Max_depth) = 6000 ms  
           // Προσθέτουμε (TOS_NODE_ID*2) ανάλογα με το id του κόμβου για να μην στέλνουν όλα τα παιδιά μαζί
            uint32_t StartSending; 
            atomic{
               StartSending =  (TOS_NODE_ID*2) + 6000 - (curdepth*6000)/Max_depth;
            }
            call NotifyTimer.startPeriodicAt(StartSending,TIMER_EPOCH);
    }

	event void  NotifyTimer.fired()
    {
         uint8_t i;
         uint16_t tmpVal;
	     message_t tmp;
         error_t enqueueDone;
	     NotifyParentMsg* mrpkt;

	     if(call NotifySendQueue.full())
	     {
                dbg("SRTreeC", "NotifySendQueue is FULL!!! \n");
		        return;
	     }
		
	     mrpkt = (NotifyParentMsg*) (call NotifyPacket.getPayload(&tmp, sizeof(NotifyParentMsg)));

	     if(mrpkt==NULL)
	     {
		      dbg("SRTreeC","NotifyMsgTimer.fired(): No valid payload... \n");
		      return;
	     }

            tmpVal = call RandNum.rand16();
            atomic{    
                tmpVal = TOS_NODE_ID + (tmpVal % 20);
                
                mrpkt->Sum   = 10; // tmpVal;
                mrpkt->SumOfSquares = 10*10; // tmpVal*tmpVAl;
                mrpkt->Count = 1;

               for(i=0; i < Max_children ; i++)
               {
                    if(Childern_id[i] != 65535)
                    {
                        mrpkt->Count += Childern_CountnNum[i];
                        mrpkt->Sum += Childern_val[i];
                        mrpkt->SumOfSquares += Childern_valofSquares[i];
                    }
                    else
                    {
                       break;
                    }
               }       
		        mrpkt->senderID = TOS_NODE_ID;
                mrpkt->parentID = parentID; // κάτω .set
            }
         
           if( TOS_NODE_ID == 0 )
           {
                round += 1;
                dbg("SRTreeC", " ############################## Round %d ############################ \n",round);
                dbg("SRTreeC", " The results are ... \n");
                dbg("SRTreeC", " Count  =  %d\n",mrpkt->Count);
                dbg("SRTreeC", " Sum  =  %d\n", mrpkt->Sum);
                dbg("SRTreeC", " SumOfSquares  =  %d\n",mrpkt->SumOfSquares);
                dbg("SRTreeC", " The AVG  =  %f\n",(double) mrpkt->Sum/mrpkt->Count);
                dbg("SRTreeC", " The VAR  =  %f\n",(double) mrpkt->SumOfSquares/mrpkt->Count);
           }
           else
           {
                call NotifyAMPacket.setDestination(&tmp,parentID);
                call NotifyPacket.setPayloadLength(&tmp,sizeof(NotifyParentMsg));
                enqueueDone = call NotifySendQueue.enqueue(tmp);
                  
                if( enqueueDone==SUCCESS)
		        {
			       if (call NotifySendQueue.size() == 1 )
			       {
					   post sendNotifyTask();
			       }
		        }
		   	    else
		        {
			 		dbg("SRTreeC","NotifyMsg failed to be enqueued in SendingQueue!!!");
		   		}
        	}
    }

	event void RoutingMsgTimer.fired()
	{
		message_t tmp;
		error_t enqueueDone;
		RoutingMsg* mrpkt;

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
		
		/*if(!(call RoutingSendQueue.empty())) //Δεν μπαίνει
		{
			post sendRoutingTask(); //Προσπάθω να στείλω τα μνμ τις ουράς ένα ένα
		}*/	
	}
	
	event void NotifyAMSend.sendDone(message_t *msg , error_t err)
	{
		setNotifySendBusy(FALSE);
		
		/*if(!(call NotifySendQueue.empty())) /Δεν μπαίνει
		{
			post sendNotifyTask();
		}*/
	}
	
	event message_t* NotifyReceive.receive( message_t* msg , void* payload , uint8_t len)
	{
		error_t enqueueDone;
		message_t tmp;
		uint16_t msource;
		
		msource = call NotifyAMPacket.source(msg);
		
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
			post receiveRoutingTask();
		}
		else
		{
			dbg("SRTreeC","RoutingMsg enqueue failed!!! \n");	
		}
		return msg;
	}
	
//////////////////////////// Tasks implementations //////////////////////////////
	
	
	task void sendRoutingTask() // Τραβάω μνμ απο την ούρα και το στέλνω
	{
		uint8_t mlen;
		uint16_t mdest;
		error_t  trySend;

		if (call RoutingSendQueue.empty()) 
		{
			dbg("SRTreeC","sendRoutingTask(): Q is empty!\n");
             	        return;
		}

		if(RoutingSendBusy)
		{
			dbg("SRTreeC","sendRoutingTask(): RoutingSendBusy= TRUE!!!\n");
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
		uint8_t mlen;
		error_t trySend;
		uint16_t mdest;
		NotifyParentMsg* mpayload;
		

		if (call NotifySendQueue.empty())
		{
			dbg("SRTreeC","sendNotifyTask(): Q is empty!\n");
			return;
		}

		if(NotifySendBusy==TRUE)
		{
			dbg("SRTreeC","sendNotifyTask(): NotifySendBusy= TRUE!!!\n");
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
		
		mdest= call NotifyAMPacket.destination(&radioNotifySendPkt);
        trySend = call NotifyAMSend.send(mdest,&radioNotifySendPkt, mlen);
		
		if ( trySend == SUCCESS)
		{
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

				if (TOS_NODE_ID!=0)
				{
					call RoutingMsgTimer.startOneShot(TIMER_FAST_PERIOD);
		                        atomic{
                                             _time = 5000 - (curdepth*5000)/Max_depth; 
                                        }
                                        call  EndRoutingTimer.startOneShot(_time);
				}
			}
			/*else //Έχω πατέρα 
			{
                               //  ...............
                            uint16_t p =call RoutingAMPacket.source(&radioRoutingRecPkt);
                           dbg("SRTreeC","rRTask  sender-> receiver:  %d -> %d \n",p,TOS_NODE_ID);
			}*/
		}
		else
		{
			dbg("SRTreeC","receiveRoutingTask():Empty message!!! \n");
			return;
		}
		
	}

 
	task void receiveNotifyTask()
	{
		uint8_t i;
		uint8_t len;
		message_t radioNotifyRecPkt;

		radioNotifyRecPkt = call NotifyReceiveQueue.dequeue(); //βγάζω το μνμ (που έλαβα) από την ουρά		
		len = call NotifyPacket.payloadLength(&radioNotifyRecPkt);
		
		if(len == sizeof(NotifyParentMsg))  // Έχω λάβει κάποιο μνμ
		{
			NotifyParentMsg* mr = (NotifyParentMsg*) (call NotifyPacket.getPayload(&radioNotifyRecPkt,len));
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

                  // Υπολογίζω

               // Επεξεργασία αποθηκεύω τα δεδομ που μου έχουν στείλει 
            
                        //    (adel)
			// an to parentID == TOS_NODE_ID tote   // (**)
			// tha proothei to minima pros tin riza xoris broadcast
			// kai tha ananeonei ton tyxon pinaka paidion..
			// allios tha diagrafei to paidi apo ton pinaka paidion
			

               // Όντως μήνυμα έιναι για μένα
		       if ( mr->parentID == TOS_NODE_ID) // (**) Αν το μύνητα που έλαβε έχει ως πατέρα τον ίδιο τον κόμβο 
	           {                                 // Τότε βάζει τον κόμβο που το έστειλε ως παιδί του   

               		//	dbg("SRTreeC"," 1111111111111111111111111111 id = %d\n",TOS_NODE_ID);
                 atomic
                 {
                  for(i=0; i < Max_children ; i++)
                  {
                        if(Childern_id[i] == mr->senderID ) // Ανανεώνω τις τιμές του παιδιού στην λίστα
                        {
                              Childern_CountnNum[i] = mr->Count; 
                              Childern_val[i] = mr->Sum;
                              Childern_valofSquares[i] = mr->SumOfSquares;
                        }  
                        else  if(Childern_id[i] == 65535)  // προσθέτουμε το παιδί στην λίστα
                        {
                              Childern_id[i] = mr->senderID;
                              Childern_CountnNum[i] = mr->Count; 
                              Childern_val[i] = mr->Sum;
                              Childern_valofSquares[i] = mr->SumOfSquares;
                              break;
                        } 
                  }
				 }
	           }
		/*	   else   // Δεν το έχουμε εμείς σαν  περίπτωση
	           {
			              // apla diagrafei ton komvo apo paidi tou.. 
	           } */

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			
		}
		else
		{
			dbg("SRTreeC","receiveNotifyTask():Empty message!!! \n");
			//setLostNotifyRecTask(TRUE);
			return;
		}	
	}
}
