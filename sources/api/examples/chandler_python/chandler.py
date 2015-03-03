#!/usr/bin/env python
import requests
import json
from natsort import natsorted
import sys,os,time,re
from colorama import init, Fore, Back, Style
init()
import ConfigParser
from optparse import OptionParser
from collections import defaultdict
from distutils.version import StrictVersion as version

# Configuration file opening
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

# Get some variables from the configuration file
APIURI=config.get('oarapi','uri')
APILIMIT=config.get('oarapi','limit')
COLS=config.getint('output','columns')
NODENAME_REGEX=config.get('output','nodename_regex')
COL_SIZE=config.getint('output','col_size')
COL_SPAN=config.getint('output','col_span')
MAX_COLS=config.getint('output','max_cols')
USERS_STATS_BY_DEFAULT=config.getboolean('output','users_stats_by_default')
try:
    COMMENT_PROPERTY=config.get('output','comment_property')
except:
    COMMENT_PROPERTY=""
try:
    SEPARATIONS=config.get('output','separations')
except:
    SEPARATIONS=""
SEPARATIONS=SEPARATIONS.split(',')
CACHING=config.getboolean('oarapi','caching')
if CACHING:
    CACHING_RESOURCES_FILE=config.get('oarapi','caching_resources_file')
    CACHING_RESOURCES_DELAY=config.getint('oarapi','caching_resources_delay')
    CACHING_JOBS_FILE=config.get('oarapi','caching_jobs_file')
    CACHING_JOBS_DELAY=config.getint('oarapi','caching_jobs_delay')
else:
    CACHING_RESOURCES_FILE=""
    CACHING_RESOURCES_DELAY=0
    CACHING_JOBS_FILE=""
    CACHING_JOBS_DELAY=0

# Compute the number of columns depending on the COLUMNS environment variable
try:
    rows, columns = os.popen('stty size', 'r').read().split()
    COLS=int(int(columns) / COL_SIZE)
except:
    pass
if COLS==0:
    COLS=1
if COLS>MAX_COLS:
    COLS=MAX_COLS

# Options parsing
parser = OptionParser()
parser.add_option("-u", "--users",
                  action="store_true", dest="toggle_users", default=False,
                  help="Toggle printing users stats")
(options, args) = parser.parse_args()

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

# Functions
def get_from_api(uri):
    """
        Get an object from the api
    """
    headers = {'Accept': 'application/json'}
    r = requests.get(APIURI+uri+"?limit="+APILIMIT,headers=headers)
    if r.status_code != 200:
        print ("Could not get "+APIURI+uri)
        r.raise_for_status()
    if version(requests.__version__) >= version("2.0.0"):
        return r.json()
    else:
        return r.json

def get(uri,cache_file,cache_delay):
    """
        Get from the cache or from the api
    """
    if CACHING and os.path.isfile(cache_file) and time.time() - os.path.getmtime(cache_file) < cache_delay:
        json_data=open(cache_file)
        return json.load(json_data)
    else:
        data=get_from_api(uri)
    if CACHING:
        chmod=True
        if os.path.isfile(cache_file):
            chmod=False
        file=open(cache_file,'w')
        json.dump(data,file)
        file.close
        if chmod:
            os.chmod(cache_file, 0666)
    return data

def cprint(str,*args):
    """
        Custom print function to get rid of trailing newline and space
    """
    sys.stdout.write(str % args)

# Print a waiting message
print('Querying OAR API...\n\033[1A'),

# Get the data from the API
#TODO: paginated results management
resources=get('/resources/details',CACHING_RESOURCES_FILE,CACHING_RESOURCES_DELAY)["items"]
jobs=get('/jobs/details',CACHING_JOBS_FILE,CACHING_JOBS_DELAY)["items"]

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
    p=re.match(NODENAME_REGEX,node)
    node_str=p.group(1)
    if COMMENT_PROPERTY != '':
        node_str+=" ("+comment[node]+")"
    else:
        node_str+=": "
    string=node_str + " "*(COL_SPAN-len(node_str))
    cprint(Fore.RESET + Back.RESET + string)
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
                if "besteffort" in types:
                    cprint (Back.GREEN+Fore.BLACK+"B")
                elif "timesharing" in types:
                    cprint (Back.YELLOW+Fore.BLACK+"T")
                else:
                    cprint (Back.WHITE+Fore.BLACK+"J")
    cprint(Fore.RESET + Back.RESET)
    col+=1
    if col < COLS and node not in SEPARATIONS:
        cprint(" "*(COL_SIZE - COL_SPAN - c))
    else:
        col=0
        print

# Legend
print(Fore.RESET + Back.RESET)
print
cprint(Back.GREEN+" "+Back.RESET+"=Free ")
cprint(Back.GREEN+Fore.BLACK+"B"+Back.RESET+Fore.RESET+"=Besteffort ")
cprint(Back.CYAN+" "+Back.RESET+"=Standby ")
cprint(Back.WHITE+Fore.BLACK+"J"+Back.RESET+Fore.RESET+"=Job ")
cprint(Back.RED+Fore.BLACK+"S"+Back.RESET+Fore.RESET+"=Suspected ")
cprint(Back.RED+Fore.BLACK+"A"+Back.RESET+Fore.RESET+"=Absent ")
cprint(Back.RED+Fore.BLACK+"D"+Back.RESET+Fore.RESET+"=Dead ")
print
print

# Print summary
print "{} jobs, {} resources, {} down, {} used".format(len(jobs),len(resources),down,len(assigned_resources))

# Print users stats if necessary
if USERS_STATS_BY_DEFAULT ^ options.toggle_users and len(jobs)>0:
   print
   user_resources=defaultdict(int)
   user_running=defaultdict(int)
   user_waiting=defaultdict(int)
   user_nodes=defaultdict(list)
   for j in jobs:
       if j["state"]=="Running" or j["state"]=="Finishing" or j["state"]=="Launching" :
           user_running[j["owner"]]+=1
           user_resources[j["owner"]]+=len(j["resources"])
           user_nodes[j["owner"]]+=[ n["network_address"] for n in j["nodes"]]
       elif j["state"]=="Waiting":
           user_waiting[j["owner"]]+=1
           user_resources[j["owner"]]+=0  
           user_nodes[j["owner"]]+=[]

   print "               Jobs       Jobs"
   print "User          running    waiting   Resources    Nodes"
   print "====================================================="
   for u,r in user_resources.iteritems():
       nodes=set(user_nodes[u])
       print "{:<16} {:<10} {:<10} {:<10} {:<10}".format(u,user_running[u],user_waiting[u],r,len(nodes))
# Reset terminal styles
print(Fore.RESET + Back.RESET + Style.RESET_ALL)
