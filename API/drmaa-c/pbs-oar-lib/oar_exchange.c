/******************************************************************


OAR DRMAA-C : A C library for using the OAR DRMS
Copyright (C) 2009  LIG <http://www.liglab.fr/>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
<http://www.gnu.org/licenses/>

**********************************************************************/



#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include "oar_exchange.h"


#define TRUE 1
#define FALSE 0

// In order to get back the error number with old versions of libcurl
#if LIBCURL_VERSION_NUM < 0x070a03
#define CURLE_HTTP_RETURNED_ERROR CURLE_HTTP_NOT_FOUND
#endif

#define MAX_OAR_URL_LENGTH 200
#define MAX_BODY_SIZE      20000


static char *username, *password;


void toUpperCase(char *instruction)
{
      	for (; *instruction !='\0'; instruction++){
      		*instruction = toupper(*instruction);
	}	
}


size_t headerHandler(void *buffer, size_t size, size_t nmemb, int *output) {
 // int *rq = (int *)output;
  size_t bytes = size * nmemb;
  float version;			// It can be helpful in the future if some OAR-API instructions are not supported by some HTTP versions
  int status = 0;			// The HTTP return status
  u_char *ptr;

  if(bytes > 7 && strncmp(buffer,"HTTP/",5) == 0) {
    version = atof(buffer+5);

    for(ptr=buffer+8;ptr < (u_char *)(buffer+bytes) && !isdigit(*ptr);++ptr);
    status = strtol(ptr,(char **)&ptr,10);
    
    //*rq = status;
    *output = status;    

//    printf("status = %d\n",status);

//  } else {
//	printf("UNKNOWN HTTP HEADER FORM, bytes = %d\n",bytes);
//	printf("BUFFER = %s\n",(char *)buffer);
  }
  

  return bytes;
}


size_t bodyHandler(void *buffer, size_t size, size_t nmemb, char *output) {
//  char *stream = (char *)output;
//  char *stream;



// *output = *((char *) buffer);

  size_t bytes = size * nmemb;
//  printf("DATA BUFFER1 = %s\n",(char *)buffer);
//  stream = strcat(stream,buffer);
  strcat(output, (char *)buffer);
//  printf("DATA BUFFER2\n");
//  printf("DATA BUFFER2 = %s\n",stream);

  return bytes;
}



exchange_result *oar_request_transmission (char *URL, char* OPERATION, char* DATA) {

  CURLcode res;
  CURL *curl;
  char *ipstr=NULL;
  char curl_errorstr[CURL_ERROR_SIZE];

// We create a new exchange_result element
   exchange_result *xr = malloc(sizeof(exchange_result));

  int headerStatus;
  char stream[MAX_BODY_SIZE];	// Perhaps we should use malloc instead of this ?! 
  strcpy(stream, "");




  if (curl_global_init(CURL_GLOBAL_ALL) != CURLE_OK) {
    fprintf(stderr, "curl_global_init() failed\n");
    xr->code = 500; // Internal error
    xr->data = NULL;
    return xr; 
  }

  if ((curl = curl_easy_init()) == NULL) {
    fprintf(stderr, "curl_easy_init() failed\n");
    curl_global_cleanup();
    xr->code = 500; // Internal error
    xr->data = NULL;
    return xr; 
  }
  
  // Pour le SSL et les certificats de OAR-API
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
	
  // Pour la récupération des codes d'erreur
  curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, curl_errorstr);

  //  curl_global_init(CURL_GLOBAL_ALL);

  curl_easy_setopt(curl, CURLOPT_URL, URL);

  // send header and all data to these functions
  curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, headerHandler);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, bodyHandler);

  // we want to store the HTTP status and the JSON stream in these variables
  curl_easy_setopt(curl,   CURLOPT_WRITEHEADER, &headerStatus);
  curl_easy_setopt(curl,   CURLOPT_WRITEDATA, stream);

  if (!strcmp("POST", OPERATION)) {

		struct curl_slist *headers = NULL;
		char content_type[]="Content-Type: application/json";
		
		// set content type header
                headers = curl_slist_append(headers, content_type);
		// set options 
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
                curl_easy_setopt(curl, CURLOPT_URL, URL);
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, DATA);
                curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, &curl_errorstr);
                curl_easy_setopt(curl, CURLOPT_NOSIGNAL, TRUE);
		curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);


  } else if (!strcmp("PUT", OPERATION)) {        

		curl_easy_setopt(curl, CURLOPT_PUT, TRUE);
		curl_easy_setopt(curl, CURLOPT_READDATA, DATA);
                curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, sizeof(DATA));
		
		// For the moment, we are using Virtualbox + OAR Live CD with the user baygon => we don't need a password 
		                 
		// curl_easy_setopt(curl, CURLOPT_USERPWD, password);
                // curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
		

  } else if (!strcmp("GET", OPERATION)) {
		curl_easy_setopt(curl, CURLOPT_HTTPGET, TRUE);
  } else if (!strcmp("DELETE", OPERATION)) {
		curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE"); 
		
  }else{
	fprintf(stderr, "\nOperation inconnue : %s\n",OPERATION);
	xr->code = 500; // Internal error
    	xr->data = NULL;
    	return xr; 
  }


  res = curl_easy_perform(curl);

	
	// We load the json parsing result from the stream 
	jresult *jr;
	jr = load_json_from_stream(stream);	


	// We fill it with the received information
	xr->code = headerStatus;	
	xr->data = jr->data;


  if (res!=0){
	fprintf(stderr, "\n ERROR (%d) : %s \n",res, curl_errorstr);
  }

  curl_easy_cleanup(curl);

  curl_global_cleanup();

  return xr;
} 

