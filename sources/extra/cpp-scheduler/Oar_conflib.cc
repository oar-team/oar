/**
###############################################################################
##  *** ConfLib: ***
##
## Description:
##   Home brewed module managing configuration file for OAR
##
## - Usage: init_conf(<filename>);
##   Read the first file matching <filename> in
##   . current directory
##   . $OARDIR directory
##   . /etc directory
##
## - Configuration file format:
## A line of the configuration file looks like that:
## > truc = 45 machin chose bidule 23 # any comment
## "truc" is a configuration entry being assigned "45 machin chose bidule 23"
## Anything placed after a dash (#) is ignored i
## (for instance lines begining with a dash are comment lines then ignored)
## Any line not matching the regexp defined below are also ignored
##
## Module must be initialized using init_conf(<filename>), then
## any entry is retrieved using get_conf(<entry>).
## is_conf(<entry>) may be used to check if any entry actually exists.
##
## - Example:
##  > use ConfLib qw(init_conf get_conf is_conf);
##  > init_conf("oar.conf");
##  > print "toto = ".get_conf("toto")."\n" if is_conf("toto");
##
###############################################################################
*/
#include <iostream>
#include <fstream>
#include <string>
#include <map>

#include <stdlib.h>
#include <time.h>

#include <QRegExp>

#include "Oar_conflib.H"

using namespace std;

/// ## configuration file regexp (one line).
/// inclusion of the quote matching in the main string
static QRegExp regexp(QString("^\\s*([^#=\\s]+)\\s*=\\s*([\\\"\\']?)([^#]*)\\2"));

/// unloaded conf
static bool loaded_conf = 0;

/// parameters container
static map<string, string> params;

/// full conf file name
static string filename;

namespace conflib {

/**
   ## Initialization of the configuration
   # param: configuration file pathname
   # Result: 0 if conf was already loaded
   #         1 if conf was actually loaded
   #         2 if conf was not found
*/
unsigned int init_conf (string file)
{
  // If file already loaded, exit immediately
  if (loaded_conf)
    return 0;

  // try to open the various files
  
  ifstream ifile;

  filename = file;
  ifile.open(filename.c_str());
  if ( ifile.fail() )
    {
      string oarpath =  getenv("OARDIR");
      filename = oarpath+file;
      ifile.open( filename.c_str() );

      if ( ifile.fail())
	{
	  filename = "/etc/"+file;
	  ifile.open( filename.c_str() );

	  if ( ifile.fail())
	    {
	      cerr << "Unable to open configuration file: " << filename
		   << endl;
	      return 2;
	    }
	}
    }

  while(! ifile.eof() )
    {
      string line;
      getline(ifile, line);
  
      int pos = regexp.indexIn(line.c_str());
      if (pos > -1)
	{
	  string key = regexp.cap(1).toStdString();
	  string val = regexp.cap(3).toStdString();

	  params[key] = val;
	}
    }

  ifile.close();
  loaded_conf = 1;

  return 1;
}

/** 
   ## retrieve a parameter if exists, set it to the default value otherwise
   ## params: arg1 param name, arg2 default value
*/

string get_conf_with_default_param ( string key, string defval) 
{
  map<string, string>::iterator keyval;
  keyval = params.find(key);
   
  if (keyval == params.end() )
    return defval;
  else
    return params[key];
}

/**
## retrieve a parameter
*/
string get_conf ( string key ) 
{
  map<string, string>::iterator keyval;
  keyval = params.find(key);
   
  if (keyval == params.end() )
    return "";
  else
    return params[key];
}

/**
   ## check if a parameter is defined
*/
bool is_conf ( string key ) 
{
  map<string, string>::iterator keyval;
  keyval = params.find(key);
   
  return (keyval != params.end() );
}

/**
  ## debug: dump parameters
*/
int dump_conf () 
{
  cout << "Config file is: " << filename << endl;
  for(map<string, string>::iterator keyval= params.begin();
      keyval != params.end();
      keyval++) 
    cout << " " << keyval->first << " = " << keyval->second << endl;
  return 1;
}

/*
  ## reset the module state
*/
int reset_conf () 
{
  filename = string();
  params = map<string,string>();
  return 1;
}

};
