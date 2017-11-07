/* Used for making a topology of nodes given a diameter (row length) and range
   Authors: Politof Kwstas, Papadopoulos Ioannis
   Last update: 6/Nov/2017
 
*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

 void MyTopology(int D , float range,char* filename);
 
 int Range_Between_two_nodes(int l1,int c1,int l2,int c2,float r);
 
 int main()
 {
    	printf("Configuring Topology \n");  
    	int D;
    	float R;
    	char* filename;
    	printf("Please give file name:\n");
	scanf("%s",filename);
	printf("Please give diameter and range:\n");
	scanf("%d%f", &D,&R);
	
		    
     MyTopology(D, R,filename);
     return 0;
 }


//checks if node2 is in range of node1 and if yes, prints it out on a string as line*D+col - line2*D+col2
//ex. 0 - 1
//    1 - 0

int Range_Between_two_nodes(int l1,int c1,int l2,int c2,float r)
{
	//we use the euclidian distance of the 2 nodes and compare it to the actual given range
	int dif_line = abs(l1-l2);
	int dif_col  = abs(c1-c2);
	float tmp_range = -1;
	
	//printf(" dif_l = %d , dif_c = %d\n",dif_line,dif_col);
	
	if(dif_line == 0 && dif_col ==0)
	{
		printf("Error: It's me!!!!\n");
	    return 0;
	}
	else if( (dif_line == 0 && dif_col !=0) || (dif_line != 0 && dif_col ==0) ) // orthogonal distance
	{
		 tmp_range = dif_line + dif_col;
	//	 printf("\ntmp_range = %f\n",tmp_range);
    	 return ( tmp_range <= r ) ? 1 : 0;
		 
	}
	else if(dif_line != 0 && dif_col !=0) // diagonal distance
	{
		tmp_range= sqrt( dif_line*dif_line+ dif_col*dif_col);
	  //  	printf("tmp_range = %f\n",tmp_range);
		return ( tmp_range <= r ) ? 1 : 0;
	}
		
	printf("Error: if\n");	
   	return 0;
}

 void MyTopology(int D , float range,char* filename)
 {

   int  line;
   int  column;
   int  cur_line;
   int  cur_column;
   int is_connected = 0;
   
   int max_node;
   FILE *fp;
   for(int id=0; id< D*D ; id++)	//for D^2 nodes
   {                         
       fp = fopen(filename, "a");
       if(fp==NULL){
       		printf("Error opening file. Exiting");
       		break;	
       	}
       if(id!=0)
       fprintf(fp,"\n");
       
      	line   = id/D;
	column = id%D;
	
	//we check a few nodes more than we should(all nodes in next few lines), that are not in range, but they won't pair
	//we do this to make sure no node is not checked when it should
	//for cases of matrix borders, X coord of squared floor(range)*floor(range)
	// should not be floor(range) but less,so we multiply floor(range)*D just in case
	
	if(floor(range)>(D-1-line))
		max_node =  (D-1-line)*D + (D-1-column);
	else
		max_node =  floor(range)*D + (D-1-column);
	
        //printf("\n %d\n",max_node);
	  	   
	  for( int k=id+1; k< max_node+id+1 ; k++ )// we check logD nodes (in range of outer node) - D, gives D^2 total if worst case, range > D
	  {
	  	
	     	cur_line   = k/D;
             	cur_column = k%D;	
        
		// printf("\n k = %d  and (cur_l,cur_c) = (%d,%d) \n",k,cur_line ,cur_column); 
         	 //printf("\n (l1,c1) = (%d,%d)  and (l2,c2) = (%d,%d) \n",line,column,cur_line,cur_column);
         	 is_connected = Range_Between_two_nodes( line,column,cur_line,cur_column,range);
         
         	if( is_connected == 1)
         	{  
         		//printf("\n====PAIR====\n");
         		
            		fprintf(fp," %d %d \n",id,k);
            		fprintf(fp," %d %d \n",k,id);
	    		is_connected = 0;				
	 	}
		   
	  }
   	fclose(fp);
	    		
   }
 }










