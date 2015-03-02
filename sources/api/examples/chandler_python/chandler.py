#!/usr/bin/python
import requests
import json
from natsort import natsorted
import sys,os,time,re
from colorama import init, Fore, Back, Style
init()
import ConfigParser

config=ConfigParser.ConfigParser()
DEFAULT_CONFIG_FILE="/etc/oar/chandler.conf"
try:
    if not os.path.isfile(os.environ['CHANDLER_CONF_FILE']):
        raise
except:
    if os.path.isfile(DEFAULT_CONFIG_FILE):
        config.read(DEFAULT_CONFIG_FILE)
    else:
        sys.stderr.write("Error: could not load configuration file!\n")
        sys.stderr.write("The configuration file is searched into "+DEFAULT_CONFIG_FILE+" or in the location given by the $CHANDLER_CONF_FILE environement variable\n")
        sys.exit(1)
else: 
    config.read(os.environ['CHANDLER_CONF_FILE'])

# Get rid of http_proxy if necessary
if config.getboolean('misc', 'ignore_proxy'):
    try:
        del os.environ['http_proxy']
    except:
        pass
    try:
        del os.environ['https_proxy']
    except:
        pass

# Get some variables from the configuration file
APIURI=config.get('oarapi','uri')
APILIMIT=config.get('oarapi','limit')
COLS=config.getint('output','columns')
NODENAME_REGEX=config.get('output','nodename_regex')
COL_SIZE=config.getint('output','col_size')
COL_SPAN=config.getint('output','col_span')
try:
  COMMENT_PROPERTY=config.get('output','comment_property')
except:
  COMMENT_PROPERTY=""

# Functions
def get(uri):
    """
        Get an object from the api
    """
    headers = {'Accept': 'application/json'}
    r = requests.get(APIURI+uri+"?limit="+APILIMIT,headers=headers)
    if r.status_code != 200:
        print ("Could not get "+APIURI+uri)
        r.raise_for_status()
    return r.json

def cprint(str,*args):
    """
        Custom print function to get rid of trailing newline and space
    """
    sys.stdout.write(str % args)

# Print a waiting message
print('Querying OAR API...\n\033[1A'),

# Get the data from the API
#TODO: paginated results management
resources=get('/resources/details')["items"]
jobs=get('/jobs/details')["items"]

# Erase the waiting message
print("\033[2K")

# Compute assigned resources dictionnary
assigned_resources={ r["id"]: j["types"] for j in jobs 
                                         for r in j["resources"]
                                         if r["status"]=="assigned" }

# Compute sorted node list
nodes=natsorted(set([ r["network_address"] for r in resources ]))

# Get the comment property if necessary
if COMMENT_PROPERTY != '':
    comment={ r["network_address"]: r[COMMENT_PROPERTY] for r in resources }

# Loop on nodes and resources
col=0
down=0
for node in nodes:
    c=0
    node_resources = [ r for r in resources if r["network_address"]==node ]
    for r in node_resources:
        c+=1
        if r["state"] == "Dead":
            down+=1
            cprint (Back.RED+Fore.WHITE+"D")
        elif r["state"] == "Absent":
            if int(r["available_upto"]) > time.time():
                 cprint (Back.CYAN+Fore.WHITE+" ")
            else:
                down+=1
                cprint (Back.RED+Fore.WHITE+"A")
        elif r["state"] == "Suspected":
            down+=1
            cprint (Back.RED+Fore.WHITE+"S")
        elif r["state"] == "Alive":
            try: 
                types=assigned_resources[r["id"]]
            except:
                cprint (Back.GREEN+Fore.WHITE+" ")
            else:
                try:
                    types.index("besteffort")
                except:
                    cprint (Back.WHITE+Fore.BLACK+"J")
                else:
                    cprint (Back.GREEN+Fore.BLACK+"B")
    p=re.match(NODENAME_REGEX,node)
    node_str=p.group(1)
    if COMMENT_PROPERTY != '':
        node_str+=" ("+comment[node]+")"
    string=" "*(COL_SIZE - c)+node_str
    col+=1
    if col < COLS:
        string+=" "*(COL_SPAN-len(node_str))
    cprint(Fore.RESET + Back.RESET + string)
    if col >= COLS:
        col=0
        print

# Legend
print(Fore.RESET + Back.RESET)
print
cprint(Back.GREEN+" "+Back.RESET+"=Free ")
cprint(Back.GREEN+Fore.BLACK+"B"+Back.RESET+Fore.RESET+"=Besteffort ")
cprint(Back.CYAN+" "+Back.RESET+"=Standby ")
cprint(Back.WHITE+Fore.BLACK+"J"+Back.RESET+Fore.RESET+"=Job ")
print
cprint(Back.RED+Fore.BLACK+"S"+Back.RESET+Fore.RESET+"=Suspected ")
cprint(Back.RED+Fore.BLACK+"A"+Back.RESET+Fore.RESET+"=Absent ")
cprint(Back.RED+Fore.BLACK+"D"+Back.RESET+Fore.RESET+"=Dead ")
print
print

# Print summary
print "{} jobs, {} resources, {} down, {} used".format(len(jobs),len(resources),down,len(assigned_resources))

# Reset terminal styles
print(Fore.RESET + Back.RESET + Style.RESET_ALL)
