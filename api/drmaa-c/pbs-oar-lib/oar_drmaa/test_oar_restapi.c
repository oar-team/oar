/* gcc */
/* gcc -lcurl -o test_oar_restapi test_oar_restapi.c */
#include <stdio.h>
#include <curl/curl.h>

int main(void)
{
    CURL *curl_handle;
    CURLcode res;
    struct curl_slist *headers = NULL;

    char rest_req[] = "{\"script_path\":\"sleep\"}";

    curl_handle = curl_easy_init();
    if(curl_handle)
    {
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl_handle, CURLOPT_URL, "http://localhost/oarapi/jobs.json");
        curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER, headers);

        curl_easy_setopt(curl_handle, CURLOPT_POSTFIELDS, rest_req);
        printf("YOP\n");
        res = curl_easy_perform(curl_handle);

        printf("YOP\n");

        /* always cleanup */
        curl_easy_cleanup(curl_handle);
  }
  return 0;
}
