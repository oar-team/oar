//#include "presult.h"
#include "jparser.h"

struct exchange_result_		// Results of the OAR request
{
    int   code; 		// HTTP return code
    presult *data; 		// JSON STREAM PARSING DATA
};

typedef struct exchange_result_ exchange_result;

exchange_result* oar_request_transmission();
