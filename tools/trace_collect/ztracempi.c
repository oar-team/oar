#define _GNU_SOURCE 
#define _REENTRANT

#include <unistd.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <sys/timeb.h>
#include <dlfcn.h>
#include <syslog.h>
#include <string.h>
#include "mpi.h"
//#include <linux/dirent.h>
#define  MPI_EVENTS 11
//#define  BUFFER_SIZE 100
#define  TIME_INTERVAL 1

/// Data structure for the MPICall ///

typedef struct reg_trace REG_TRACE;
typedef struct event_stat EVENT_STATS;
static int faketime=0;
static int buffer=0;
static char trace_dir[100];
static FILE *trace;
static int mpi_program=0;
struct reg_trace {
time_t  seconds;
time_t  useconds;
char * call;
int parameter;

};

struct event_stat {
char *call;
long long bytes;
int num;
};

extern const char *__progname;

//static REG_TRACE BuffTrace[BUFFER_SIZE];
static EVENT_STATS mpistat[MPI_EVENTS];
static time_t time_start_block;
static time_t interval;
static void writetodisk(void);
static void initstats(void);
static void printstats(time_t, time_t);

//Declaration of MPI's Calls

int ( *libMPI_Init) (int *, char ***);
int ( *libMPI_Init_thread) (int *, char ***, int, int*);
int ( *libMPI_Comm_size) (MPI_Comm, int *);
int ( *libMPI_Comm_rank) (MPI_Comm, int *);
int ( *libMPI_Barrier) (MPI_Comm);
int ( *libMPI_Wait) (MPI_Request *, MPI_Status *status);
int ( *libsend) (void *buf, int count, MPI_Datatype datatype,int dest, int tag,MPI_Comm comm);
int ( *librecv) (void *buf, int count, MPI_Datatype datatype,int source, int tag, MPI_Comm comm, MPI_Status *status);
int ( *libirecv) (void *buf, int count,  MPI_Datatype datatype,int source, int tag, MPI_Comm comm, MPI_Request *request);
int ( *libisend) ( void *buf, int count, MPI_Datatype datatype, int dest, int tag, MPI_Comm comm, MPI_Request *request );
int (* libMPI_Waitall) ( int count, MPI_Request array_of_requests[], MPI_Status array_of_statuses[] );
int (* libMPI_Bcast) ( void *buffer, int count, MPI_Datatype datatype, int root,MPI_Comm comm );
int (* libMPI_Allreduce )( void *sendbuf, void *recvbuf, int count,MPI_Datatype datatype, MPI_Op op, MPI_Comm comm );
int (* libMPI_Gather ) ( void *sendbuf, int sendcnt, MPI_Datatype sendtype, void *recvbuf, int recvcount, MPI_Datatype recvtype, int root, MPI_Comm comm );
int (* libMPI_Reduce ) ( void *sendbuf, void *recvbuf, int count, MPI_Datatype datatype, MPI_Op op, int root, MPI_Comm comm);



static int read_conf_file(void)
{
	FILE *conf;
	FILE *check;
	//############## PATH to configuration file  ############################
	conf=fopen("/etc/mpitrace.conf","r");
	//######################################################################
	char line[80];
	//char prefix[200];
        if(conf==NULL)
	{
		
     		openlog("mpi-trace", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_LOCAL1);
     		syslog (LOG_INFO, "Can't Open Configuration file");
		syslog (LOG_INFO,"Using /tmp/ to save the traces");
     		closelog();	
		strcpy(trace_dir,"/tmp/");
		return 0;
	}
	 while(fgets(line, 80, conf) != NULL)
   	{
	 sscanf (line, "%s", &trace_dir);
	 /* convert the string to a long int */
	 //printf ("%s\n", trace_dir);
   	}
	//check if we can write into the directory
	sprintf(line,"%smpi-trace-write",trace_dir);

	check=fopen(line,"w");
	if(check==NULL)
	{
		openlog("mpi-trace", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_LOCAL1);
                syslog (LOG_INFO, "The directory chosen is not writable");
                syslog (LOG_INFO,"Using /tmp/ to save the traces");
		strcpy(trace_dir,"/tmp/");
                closelog();
		return 0;
	}
	
	
}
static void initstats(void)
{
	int i;
	for(i=0;i<MPI_EVENTS;i++)
	{
		mpistat[i].bytes=0;
		mpistat[i].num=0;
	}
}

static reg_trace(int parameter,char *call)
{

        ///Codigo testing 
	//I have to revise the time start and compared with the currentime	
        struct timeval tim;
	gettimeofday(&tim, NULL);
	if(tim.tv_sec > time_start_block+TIME_INTERVAL) //we have to print the acumulated values 
	{
		printstats(time_start_block,tim.tv_sec);	
		time_start_block=tim.tv_sec;	
	}
	/*
	BuffTrace[buffer].seconds=tim.tv_sec;
        BuffTrace[buffer].useconds=tim.tv_usec;
        BuffTrace[buffer].call=call;
        BuffTrace[buffer].parameter=parameter;
        faketime++;
	buffer++;
	if(buffer>BUFFER_SIZE-1)
	{
		//writetodisk();		
		buffer=0;
	}
	*/
}

static void writetodisk()
{
	//char *filename;
        //printf(" printing data node : %s \n",buf);
        int index;
	for(index=0;index<buffer;index++){
                //fprintf(trace," data:  %lu.%lu \t%s\t%d\n",BuffTrace[index].seconds,BuffTrace[index].useconds,BuffTrace[index].call,BuffTrace[index].parameter);
		//printf("data:  %lu\t%s\t%d\n",BuffTrace[index].time,BuffTrace[index].call,BuffTrace[index].parameter);
                }
	
	//initstats();


}

static void printstats(time_t start, time_t end)
{
	int i;
	fprintf(trace,"Time interval  %lu - %lu \n ",start, end);
	fprintf(trace,"Call\tNumberBytes\tNumber of Calls \n");
	fprintf(trace,"------------------------------------------------------\n");
	for(i=0;i<MPI_EVENTS;i++){if(mpistat[i].num!=0){fprintf(trace," %s\t%llu\t%d\n",mpistat[i].call,mpistat[i].bytes,mpistat[i].num);}}
	fprintf(trace,"------------------------------------------------------\n");
	initstats();
}

//////////////////////////////////


int MPI_Barrier (MPI_Comm c)
{
  	
  reg_trace(1,"MPI_Barrier");
  mpistat[3].num++;
  return libMPI_Barrier(c);
}

int MPI_Bcast ( void *buffer, int count, MPI_Datatype datatype, int root, MPI_Comm comm )
{
	mpistat[7].num++;
        mpistat[7].bytes+=count;
	return libMPI_Bcast(buffer,count,datatype,root,comm);
}

int MPI_Allreduce ( void *sendbuf, void *recvbuf, int count, MPI_Datatype datatype, MPI_Op op, MPI_Comm comm )
{
	mpistat[8].num++;
	mpistat[8].bytes+=count;
	return libMPI_Allreduce(sendbuf,recvbuf,count,datatype,op,comm);
}

int MPI_Reduce(void *sendbuf, void *recvbuf, int count,MPI_Datatype datatype, MPI_Op op, int root, MPI_Comm comm) 
{
	mpistat[10].num++;
	mpistat[10].bytes+=count;
	return libMPI_Reduce(sendbuf,recvbuf,count,datatype,op,root,comm);
}
int MPI_Gather ( void *sendbuf, int sendcnt, MPI_Datatype sendtype, void *recvbuf, int recvcount, MPI_Datatype recvtype, int root, MPI_Comm comm )
{
	mpistat[9].num++;
        mpistat[9].bytes+=sendcnt+recvcount;
	return libMPI_Gather(sendbuf,sendcnt,sendtype,recvbuf,recvcount,recvtype,root,comm);

}
int  MPI_Wait (MPI_Request  *request, MPI_Status   *status)
{
	reg_trace(1,"MPI_Wait");
	mpistat[2].num++;
	return libMPI_Wait(request,status);
}

int MPI_Comm_size(MPI_Comm c, int *s)
{
  return libMPI_Comm_size(c, s);  
}


int MPI_Waitall( int count,  MPI_Request array_of_requests[], MPI_Status array_of_statuses[] )
{
	reg_trace(1,"MPI_Waitall");
	mpistat[6].num++;
	return libMPI_Waitall(count, array_of_requests, array_of_statuses );
}

int MPI_Comm_rank(MPI_Comm c, int *r)
{
  int rank;
  char buf[100];
  char hostname[40];
  char *pch;
  static lock=0;
  libMPI_Comm_rank(c, r);
  if(lock==0) // to avoid entering twice
  {
  	rank=*r;
        struct timeval tim;
	gettimeofday(&tim,NULL);
	time_t  iseed=tim.tv_usec;
    	srand(iseed);
  	pch=strtok(getenv("OAR_CPUSET"),"_");
  	pch=strtok(NULL,"_");
	if(pch==NULL)
	{
		  pch="OAR_JOB_ID";
	}
  	sprintf(buf,"%strace-MPI.node-%d-%s-%d",trace_dir,rank,pch,rand());
  	//sprintf(buf,"%strace-MPI.node-%d-%s",trace_dir,rank,pch);
	#ifdef DEBUG
		printf(" File name: %s\n",buf);
	#endif
  	trace=fopen(buf, "w");
  	gethostname(hostname,40);
  	fprintf(trace,"########################################################\n");
  	fprintf(trace,"Trace  HOST: %s \n",hostname);
  	//fprintf(trace,"OAR_CPUSET = %s\n", getenv("OAR_CPUSET"));
  	fprintf(trace,"OAR JOB ID : %s \n",pch);
	fprintf(trace,"Executable name: %s \n",__progname);
  	fprintf(trace,"ID NODE  %d\n",rank);
  	fprintf(trace,"########################################################\n");
  	//printf("Entering to the Rank function \n");
	lock=1;
  }
  return;

}

/*int MPI_Init_thread (int *argc, char ***argv, int required, int *provided)
{
  int ret = libMPI_Init_thread(argc, argv, required, provided);
  int rank = -1;
  int size = -1;

  libMPI_Comm_size(MPI_COMM_WORLD, &size);
  libMPI_Comm_rank(MPI_COMM_WORLD, &rank);

  char* filename=NULL;
  asprintf(&filename, "prof_file_user_rank_%d", rank);
  eztrace_set_filename(filename);

  libMPI_Barrier(MPI_COMM_WORLD);
  return ret;

}
*/

int MPI_Init(int * argc, char***argv)
{
  int ret = libMPI_Init(argc, argv);
  int rank = -1;
  int size = -1;
  mpi_program=1;
  read_conf_file();
     mpistat[0].call="MPI_Send";
     mpistat[1].call="MPI_Recv";
     mpistat[2].call="MPI_Wait";
     mpistat[3].call="MPI_Barrier";
     mpistat[4].call="MPI_Irecv";
     mpistat[5].call="MPI_Isend";
     mpistat[6].call="MPI_Waitall";
     mpistat[7].call="MPI_Bcast";
     mpistat[8].call="MPI_Allreduce";
     mpistat[9].call="MPI_Gather";    
     mpistat[10].call="MPI_Reduce";
     interval=1;
  return ret;
}


int MPI_Send(void *buf, int count, MPI_Datatype datatype,int dest, int tag, MPI_Comm comm)
{
	reg_trace(count,"MPI_Send");
	mpistat[0].bytes+=count;
	mpistat[0].num++;
        libsend(buf,count,datatype,dest,tag,comm);
	return 0;
}

int MPI_Isend( void *buf, int count, MPI_Datatype datatype, int dest, int tag, MPI_Comm comm, MPI_Request *request )
{
	reg_trace(count,"MPI_Isend");
	mpistat[5].bytes+=count;
	mpistat[5].num++;
	libisend(buf,count,datatype,dest,tag,comm,request);
	return 0;
}

int MPI_Recv(void *buf, int count, MPI_Datatype datatype,int source, int tag, MPI_Comm comm, MPI_Status *status)
{
	reg_trace(count,"MPI_Recv");
	mpistat[1].bytes+=count;
	mpistat[1].num++;
        librecv(buf, count, datatype, source, tag, comm, status);
	return 0;
}

int MPI_Irecv(void *buf, int count, MPI_Datatype datatype,int source, int tag, MPI_Comm comm, MPI_Request *request)
{
        reg_trace(count,"MPI_Irecv");
        mpistat[4].bytes+=count;
        mpistat[4].num++;
        libirecv(buf, count, datatype, source, tag, comm, request);
        return 0;
}

/*
#define  TREAT_ERROR()						\
  do {								\
    if ((error = dlerror()) != NULL)  {				\
      fputs(error, stderr);					\
      return;							\
    }								\
  }while(0) 

*/
void libinit(void) __attribute__ ((constructor));
void libinit(void)
{
    
    void * handle = RTLD_NEXT;
    char * error;
      
    #ifdef DEBUG
    printf("loading library \n");
    #endif
    libsend = (typeof (libsend)) (uintptr_t) dlsym (handle,"MPI_Send");
    librecv = (typeof (librecv)) (uintptr_t) dlsym (handle,"MPI_Recv");
    libirecv = (typeof (libirecv)) (uintptr_t) dlsym (handle,"MPI_Irecv");
    libisend= (typeof (libisend)) (uintptr_t) dlsym (handle,"MPI_Isend");
    //libMPI_Init_thread = (typeof (libMPI_Init_thread)) (uintptr_t) dlsym (handle,"MPI_Init_thread");
    libMPI_Waitall = (typeof  (libMPI_Waitall)) (uintptr_t) dlsym (handle,"MPI_Waitall");
    libMPI_Bcast = (typeof (libMPI_Bcast)) (uintptr_t) dlsym (handle, "MPI_Bcast");
    libMPI_Allreduce = (typeof (libMPI_Allreduce)) (uintptr_t) dlsym (handle,"MPI_Allreduce");
    libMPI_Reduce = (typeof (libMPI_Reduce)) (uintptr_t) dlsym (handle,"MPI_Reduce");
    libMPI_Gather = (typeof (libMPI_Gather)) (uintptr_t) dlsym (handle,"MPI_Gather");
    libMPI_Init = (typeof (libMPI_Init)) (uintptr_t) dlsym (handle,"MPI_Init");

    libMPI_Barrier = (typeof (libMPI_Barrier)) (uintptr_t) dlsym (handle,"MPI_Barrier");

    libMPI_Comm_size = (typeof (libMPI_Comm_size)) (uintptr_t) dlsym (handle,"MPI_Comm_size");

    libMPI_Comm_rank = (typeof (libMPI_Comm_rank)) (uintptr_t) dlsym (handle,"MPI_Comm_rank");
    libMPI_Wait = (typeof (libMPI_Wait)) (uintptr_t) dlsym (handle,"MPI_Wait");
     
     initstats();
     //starting timer
     struct timeval time;
     gettimeofday(&time,NULL);
     time_start_block=time.tv_sec;
     //printf("Time star : %llu \n");
     ///end timer block
     //read_conf_file();


     

    /* TODO: do not start eztrace right now.
     * We should wait for MPI_Init to be completed and get the local rank
     */
#ifdef EZTRACE_AUTOSTART
  //eztrace_start ();
#endif
}

void libfinalize(void) __attribute__ ((destructor));
void libfinalize(void)
{
   if(mpi_program!=0)
   {	struct timeval tim;
   	gettimeofday(&tim, NULL);
   	printstats(time_start_block,tim.tv_sec);
	fclose(trace);
  //writetodisk();
   }
  

}

