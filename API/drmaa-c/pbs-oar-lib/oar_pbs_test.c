#include "oar_pbs.h"

int main(int argc, char **argv) {
		
	pbs_connect(NULL); 				// Take the default server
	
	char* jobId = pbs_submit(0,NULL,NULL,NULL,NULL);	// Submit default job
	
	pbs_statjob(0, jobId, NULL, NULL);
	
	// I should create a function that will allow me to see the data saved into a batch_status structure to test if the information have been successfully passed here

	return 0;
}
