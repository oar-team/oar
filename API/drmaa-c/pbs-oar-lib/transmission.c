#include <curl/curl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <ctype.h>
#include <string.h>


#define TRUE 1
#define FALSE 0

// In order to get back the error number with old versions of libcurl
#if LIBCURL_VERSION_NUM < 0x070a03
#define CURLE_HTTP_RETURNED_ERROR CURLE_HTTP_NOT_FOUND
#endif

#define MAX_OAR_URL_LENGTH 150


static char *username, *password;


void toUpperCase(char *instruction)
{
      	for (; *instruction !='\0'; instruction++){
      		*instruction = toupper(*instruction);
	}	
}


int envoyer(char *URL, char* OPERATION, char* DATA)
{
  CURLcode res;
  CURL *curl;
  char *ipstr=NULL;
  char curl_errorstr[CURL_ERROR_SIZE];
  static struct curl_slist *pragma_header;





  if (curl_global_init(CURL_GLOBAL_ALL) != CURLE_OK) {
    fprintf(stderr, "curl_global_init() failed\n");
    return 10; 
  }

  if ((curl = curl_easy_init()) == NULL) {
    fprintf(stderr, "curl_easy_init() failed\n");
    curl_global_cleanup();
    return 10;
  }
  
  // Pour le SSL et les certificats de OAR-API
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
	
  // Pour la récupération des codes d'erreur
  curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, curl_errorstr);
  /*
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, pragma_header);
  */

  /*  curl_global_init(CURL_GLOBAL_ALL); */

  curl_easy_setopt(curl, CURLOPT_URL, URL);

  //curl_easy_setopt(curl, CURLOPT_HEADER, 1L); // should we keep it for the 4 operations: PUT, POST, GET, DELETE ??

  if (!strcmp("POST", OPERATION)) {

		struct curl_slist *headers = NULL;
		char content_type[]="Content-Type: application/json";
		
		/* set content type header */
                headers = curl_slist_append(headers, content_type);
		/* set options */
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
                curl_easy_setopt(curl, CURLOPT_URL, URL);
                //curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write_buffer);
                //curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&curl_response);
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, DATA);
                //curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, sizeof(DATA));
		
                curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, &curl_errorstr);
                //curl_easy_setopt(curl, CURLOPT_FAILONERROR, TRUE);
                curl_easy_setopt(curl, CURLOPT_NOSIGNAL, TRUE);
		curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);


		
		/*
		//curl_easy_setopt(curl, CURLOPT_POST, TRUE);
		curl_easy_setopt(curl, CURLOPT_POST, 1L);
		curl_easy_setopt(curl, CURLOPT_HEADER, 0); 
		curl_easy_setopt(curl, CURLOPT_VERBOSE, 1L);

		curl_easy_setopt(curl, CURLOPT_POSTFIELDS, DATA);
		//curl_easy_setopt(curl, CURLOPT_READDATA,&DATA);
		//curl_easy_setopt(curl,CURLOPT_CUSTOMREQUEST,"POST");
		*/
  } else if (!strcmp("PUT", OPERATION)) {        
	//curl_easy_setopt(curl, CURLOPT_HTTPHEADER, pragma_header);
        //curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, curl_errorstr);

		curl_easy_setopt(curl, CURLOPT_PUT, TRUE);
		curl_easy_setopt(curl, CURLOPT_READDATA, DATA);
                curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, sizeof(DATA));
		
		// For the moment, we are using Virtualbox + OAR Live CD with the user baygon => we don't need a password 
		/*                 
		curl_easy_setopt(curl, CURLOPT_USERPWD, password);
                curl_easy_setopt(curl, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
		*/

  } else if (!strcmp("GET", OPERATION)) {
		curl_easy_setopt(curl, CURLOPT_HTTPGET, TRUE);
  } else if (!strcmp("DELETE", OPERATION)) {
		curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE"); 
		
  }else{
	fprintf(stderr, "\nOperation inconnue : %s\n",OPERATION);
	return 1;
  }

  res = curl_easy_perform(curl);
  
  if (res!=0){
	fprintf(stderr, "\n ERROR (%d) : %s \n",res, curl_errorstr);
  }

 /* if(!res) {
    res = curl_easy_getinfo(curl, CURLINFO_PRIMARY_IP, &ipstr);
    printf("IP: %s\n", ipstr);
  }*/

  curl_easy_cleanup(curl);
  curl_global_cleanup();

  return (int)res; //return the error number (0 = OK)
}


int main(int argc, char **argv)
{
  char *URL;
  URL = argv[2]; // provide this to the rest
  char *METHOD;
  METHOD = argv[1]; 

  toUpperCase(METHOD); // Puts the HTTP method name into uppercase so we can make tests easier

  char full_url[MAX_OAR_URL_LENGTH];

  char *DONNES_PAR_DEFAUT;
  DONNES_PAR_DEFAUT = "{\"script_path\":\"\\/usr\\/bin\\/id\",\"resource\":\"\\/nodes=2\\/cpu=1\"}";
  //DONNES_PAR_DEFAUT = "{\"script\":\"\",\"resource\":\"\\/nodes=2\\/cpu=1\", \"workdir\":\".\"}";
  
  strncpy(full_url, "http://192.168.0.1/oarapi", sizeof(full_url)); // for the moment, we are using Virtualbox + OAR Live CD with the IP : 192.168.0.1
  strncat(full_url, URL, sizeof(full_url));

  fprintf(stderr, "\n-----------------------------------------------------------------\n");
  fprintf(stderr, "URL    : %s\nMETHODE: %s\n", full_url, METHOD);
  if (argc>3) {fprintf(stderr, "DONNEES_RENTRES_AU_CLAVIER\n");} else {fprintf(stderr, "DONNEES_PAR_DEFAUT : %s\n",DONNES_PAR_DEFAUT);}
  fprintf(stderr, "-----------------------------------------------------------------\n\n");

  if (argc>3){ // If wa want to use customized data fields with POST and PUT
	fprintf(stderr, "\n!! MODE MANUEL !!\n");
	return envoyer(full_url,METHOD,argv[3]);
  }

  fprintf(stderr, "\n!! MODE AUTOMATIQUE !!\n");
  
  return envoyer(full_url,METHOD,DONNES_PAR_DEFAUT);
}

