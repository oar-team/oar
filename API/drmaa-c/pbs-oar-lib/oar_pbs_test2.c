#include "oar_pbs.h"

// Test to see if we can choose to have a customized batch_status or not


int main(int argc, char **argv) {
		
	pbs_connect(NULL); 				// Take the default server
	
	char* jobId = pbs_submit(0,NULL,NULL,NULL,NULL);	// Submit default job
	
	batch_status *status;

	// Preparing the list of wanted attributes in the batch_status
	attrl *listOfAttributes = NULL;
	addNewAttribute(&listOfAttributes,"state",NULL,NULL);	
	addNewAttribute(&listOfAttributes,"Job_Id",NULL,NULL);	// Is it the same whether we use capitalized characters or not ???

	status = pbs_statjob(0, jobId, listOfAttributes, NULL);

	showBatchStatus(status);	// This is not a part of PBS functions >> a test function
	
	// I should create a function that will allow me to see the data saved into a batch_status structure to test if the information have been successfully passed here

	return 0;
}
