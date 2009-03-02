#ifndef OAR_CONFLIB_H
#define OAR_CONFLIB_H

#include <string>

namespace conflib { 

unsigned int init_conf (std::string file);
std::string get_conf_with_default_param ( std::string key, std::string defval);
std::string get_conf ( std::string key ); 
bool is_conf ( std::string key );
int dump_conf ();
int reset_conf ();

};

#define CONFDEFAULT_INT(x,y) ( atoi( get_conf_with_default_param(x, y).c_str()) )
#define CONFDEFAULT_STR(x,y) ( get_conf_with_default_param(x, y).c_str() )

#endif
