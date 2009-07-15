cmake_minimum_required(VERSION 2.6)

project (DRMAA-C-test)

include_directories (/usr/include/glib-2.0 /usr/lib/glib-2.0/include /usr/include/json-glib-1.0 /usr/include/curl)


add_executable (parser parser.c)
add_executable (parser2 parser2.c presult.c)
add_executable (generator generator.c)
add_executable (transmission transmission.c)


target_link_libraries (parser json-glib-1.0 glib-2.0 gobject-2.0)
target_link_libraries (parser2 json-glib-1.0 glib-2.0 gobject-2.0)
target_link_libraries (generator json-glib-1.0)
target_link_libraries (transmission curl)
