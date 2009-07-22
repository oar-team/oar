cmake_minimum_required(VERSION 2.6)

project (OAR-DRMAA-C)

include_directories (/usr/include/glib-2.0 /usr/lib/glib-2.0/include /usr/include/json-glib-1.0 /usr/include/curl)


#add_executable (jparser jparser.c presult.c)
add_executable (generator generator.c)
add_executable (oar_exchange oar_exchange.c jparser.c presult.c)
#add_executable (oar_pbs oar_pbs.c oar_exchange.c jparser.c presult.c)


#target_link_libraries (jparser json-glib-1.0 glib-2.0 gobject-2.0)
target_link_libraries (generator json-glib-1.0)
target_link_libraries (oar_exchange curl json-glib-1.0 glib-2.0 gobject-2.0)
#target_link_libraries (oar_pbs curl json-glib-1.0 glib-2.0 gobject-2.0)
