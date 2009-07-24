#include "oar_pbs.h"

// Test to see whether the default settings are working or not

int main(int argc, char **argv) {
		
	pbs_connect(NULL); 				// Take the default server
	
	char* jobId = pbs_submit(0,NULL,NULL,NULL,NULL);	// Submit default job
	
	batch_status *status;
	status = pbs_statjob(0, jobId, NULL, NULL);

	showBatchStatus(status);	// This is not a part of PBS functions >> a test function
	
	// I should create a function that will allow me to see the data saved into a batch_status structure to test if the information have been successfully passed here

	return 0;
}
