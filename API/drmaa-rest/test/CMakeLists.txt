cmake_minimum_required(VERSION 2.6)

project (DRMAA-REST-test)

include_directories (/usr/include/glib-2.0 /usr/lib/glib-2.0/include /usr/include/json-glib-1.0 /usr/include/curl)


add_executable (json-glib-test json-glib-test.c)
add_executable (curl-test curl-test.c)

target_link_libraries (json-glib-test json-glib-1.0)
target_link_libraries (curl-test curl)
 
