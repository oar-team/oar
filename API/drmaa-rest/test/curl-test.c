#include <curl/curl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

int test(char *URL)
{
  CURLcode res;
  CURL *curl;
  char *ipstr=NULL;

  if (curl_global_init(CURL_GLOBAL_ALL) != CURLE_OK) {
    fprintf(stderr, "curl_global_init() failed\n");
    return 10; 
  }

  if ((curl = curl_easy_init()) == NULL) {
    fprintf(stderr, "curl_easy_init() failed\n");
    curl_global_cleanup();
    return 10;
  }

  curl_easy_setopt(curl, CURLOPT_URL, URL);
  curl_easy_setopt(curl, CURLOPT_HEADER, 1L);

  res = curl_easy_perform(curl);
/*
  if(!res) {
    res = curl_easy_getinfo(curl, CURLINFO_PRIMARY_IP, &ipstr);
    printf("IP: %s\n", ipstr);
  }
*/
  curl_easy_cleanup(curl);
  curl_global_cleanup();

  return (int)res;
}


int main(int argc, char **argv)
{
  char *URL;
  URL = argv[1]; /* provide this to the rest */
  fprintf(stderr, "URL: %s\n", URL);
  return test(URL);
}

