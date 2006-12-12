"""
    TGOAR controlers 
    
    Fix the way data is passed to templates from OAR models 



"""

import logging
import cherrypy
import turbogears
from turbogears import controllers, expose, validate, redirect
from tgoar import json
import datetime

# import OAR models 
from tgoar.model import resources
from tgoar.model import resource_logs


###############################################################################
# Configurable display setting 
# FIXME change this to configuration settings in the configuration file 

# Store resources properties and the corresponding description displayed 
resources_properties_fields={ 'resource_id': "Resource Id", 
                       'network_address': "Network address", 
                       'state': "Node state", 
                       'finaud_decision': 'Manualy defined status',
                       'next_finaud_decision': 'Automatic next status',
                       'running': "Running status",
                       'type': "Node type", 
                       'next_state': "Future node state", 
                       'state_num': "State change index", 
                       'switch': "Node switch name",
                       'os': "Operating system",
                       'arch': "Hardware architecture",
                       'divers': "Distribution/Version",
                       'suspended_jobs': "Suspended jobs",
                       'cpu': 'CPU number',
                       'besteffort': 'Accept besteffort jobs',
                       'deploy': 'Deployable resource',
                       'desktop_computing': 'Desktop computing resource',
                       'last_job_date': 'Last job date',
                       'cm_availability': 'Foo'
                       }

### store fields order
resources_properties_fields_order = [ ( 'resource_id', True ),
                                      ('running', True),
                                      ('network_address', True),
                                      ('type', True),
                                      ('state', True),
                                      ('next_state', True),
                                      ('switch', True),
                                      ('os', True) ]

resource_list_fields_order = [ ( 'resource_id', False ),
                               ('network_address', True ),
                               ('running', True ),
                               ('arch', True),
                               ('os', True),
                               ('divers', True),
                               ('state', True) ]
                                
resource_logs_fields_order = [ ( 'attribute', True ),
                               ( 'value', True ),
                               ( 'finaud_decision', True ),
                               ( 'date_start', True ),
                               ( 'date_stop', True ) ]
 
job_short_fields_order = [ ( 'job_id', True ),
                           ( 'job_name', True ),
                           ( 'job_user', True ),
                           ( 'job_env', True ),
                           ( 'job_type', True),
                           ( 'state',True ),
                           ( 'queue_name', True ),
                           ( 'start_time',True ),
                           ( 'stop_time', True ) ]





### store resource log fields to display when seeing a resource logs 
resource_logs_fields={ 
                       'resource_log_id': "Log id", 
                       'attribute': 'Changed attribute', 
                       'value': 'Changed attribute value', 
                       'date_start': 'interval start date', 
                       'date_stop': 'interval stop date',
                       'finaud_decision': 'Manual change' }




### store job felds to display when seeing a resource's jobs
job_short_fields={
    'job_id': 'Job ID',
    'project': 'Job project name',
    'properties': 'Job properties',
    'job_name': 'Job name', 
    'job_env': 'Job environment', 
    'job_type': 'Job type',
    'state': 'Job status',
    'job_user': 'Job user',
    'queue_name': 'Job queue',
    'start_time': 'Job start', 
    'stop_time': 'Job stop'
}

# ... and the corresponding display order


# get logger 
log = logging.getLogger("tgoar.controllers")


##### MANDATORY FIEDS ( don't touch this ) #########
resource_list_mandatory_fields = [ ( 'resource_id', False ),
                                   ( 'type', False ),
                                   ('network_address', False), 
                                   ('running', False) ]

resources_properties_mandatory_fields = [ ('resource_id', False ),
                                          ( 'type', False ),
                                          ('network_address', False),
                                          ('running', False) ]

resource_logs_mandatory_fields = [ ( 'attribute', False ),
                                   ( 'date_start', False ),
                                   ( 'date_stop', False ) ]

job_mandatory_fields = [ ( 'job_id', False ), 
                         ( 'job_user', False ),
                         ( 'start_time', False ),
                         ( 'stop_time', False ) ]


################################################################################
### Internal functions - misc 

def date_to_string(timestamp):
    if timestamp == 0: 
        return "Undefined"
    else:
        return datetime.datetime.fromtimestamp(int(timestamp)).isoformat(" ")

### End of internal functions #################################################




class Resources:
    """
        this class is the resource's related controler
    """

    @expose(template='tgoar.templates.resources_list')
    def index(self, display_type='list', **kwargs):
        '''
        Print index of /resources/
        '''
        return self.resources_list(display_type, **kwargs)
    


    def resources_list(self, display_type = "list", **kwargs):
        '''
        Print a list of resources in various formats 
        ''' 
        log.debug("Listing all available resources")
        
        # default sort field
        sf='network_address'
        so=''
        if kwargs.has_key('sf') and resources_properties_fields.has_key(kwargs['sf']):
            sf = kwargs['sf']
            if kwargs.has_key('so'):
                if kwargs['so'] == 'd':
                    so = '-'
        
        ress = resources.select(orderBy=str(so+sf))

        fields = []
        for i in resource_list_mandatory_fields + resource_list_fields_order: 
            property = {}
            property['name'] = i[0]
            if resources_properties_fields.has_key(i[0]):
                property['desc'] = resources_properties_fields[i[0]]
            else:
                property['desc'] = 'Unknown'
            property['visible']=i[1]
            a = True
            for j in fields: 
                if j['name'] == i[0]:
                    j['desc'] = property['desc']
                    j['visible'] = property['visible']
                    a = False
            if a:
                fields = fields + [ property ]

        r = []
        for res in ress:
            line = []
            for i in fields:
                # special cases of params 
                if i['name'] == 'running':
                    if res.is_running():
                        property = 'Running'
                    else:
                        property = 'Idle'
                elif i['name'] == 'resource_id': 
                    property = res.id
                else:
                    property =  str(res.__dict__['_SO_val_'+ i['name']])
                line = line + [ property ]
            r = r + [ line ]
        
        fazz = [ fields ] +  [ r ] 
        return dict(resources=fazz, display_type=display_type)


    @expose('json') 
    def get_resource_repr(self, resource=None, resource_id=-1):
        '''
        This function retrieve a resource representation suitable
        for template passing : 
        [ { 'name': name, 'visible': visible,
            'desc': param_description,
            'value': value }, 
            { 'name': ..... }, {} ...]
        '''
        if resource_id >=0 and not resource:
            rlist = resources.selectBy(id = str(resource_id))
            if resources == []:
                return False
            resource = rlist[0]

        fields = []
        # for each mandatory properties and user configured ..
        for i in resources_properties_mandatory_fields + resources_properties_fields_order: 
            property = {}

            # fix property name 
            property['name'] = i[0]

            # check this property has a description 
            if resources_properties_fields.has_key(i[0]):
                property['desc'] = resources_properties_fields[i[0]]
            # else keep property name as a description, better than none
            else:
                property['desc'] = property['name']
            
            # visible or not ? 
            property['visible']=i[1]
           
            # special property name have a special treatment
            # as the 'running' property is not taken from the resources table
            if property['name'] == 'running':
                if resource.is_running():
                    property['value'] = 'Running'
                else:
                    property['value'] = 'Idle'
            
            # resource_id is a special case too,
            # primary key name renamed by SQLObject to 'id'
            elif property['name'] == 'resource_id': 
                property['value'] = resource.id
            else:
               property['value'] = str(
                    resource.__dict__['_SO_val_'+ property['name']]
                                      )

            # check is this property is present more than one in 
            # [ resources_properties_mandatory_fields 
            #    + resources_properties_fields_order ]
            # if yes, replace the alreadey appened 
            a = True
            for j in fields: 
                if j['name'] == i[0]:
                    j['desc'] = property['desc']
                    j['visible'] = property['visible']
                    j['value'] =  property['value']
                    a = False
            if a:
                fields = fields + [ property ]
        
        return fields

 
    @expose(template="tgoar.templates.resource")
    # @validate( validators = { "resource_id": validators.Int() } )
    def resource(self, resource_id):
        """
        This function display a resource information:
            - Resource properties
            - Resource logs 
            - Resource scheduled jobs


        FIXME: Add a sorting capability for logs and a max-line capability
        """

        log.debug("Showing resource number "+resource_id)
        
        # check for an int() passed 
        # FIXME : replace width @validate
        try:
            int(resource_id)
        except:
            return dict(error_flag=1)
    
        res = resources.selectBy(id = str(resource_id))
        if not res:
            return dict(error_flag)
            
        resource_repr = self.get_resource_repr(resource = res[0])

        lfields = []

        for i in resource_logs_mandatory_fields + resource_logs_fields_order:
            property = {}
            property['name'] = i[0]
            if resource_logs_fields.has_key(i[0]):
                property['desc'] = resource_logs_fields[i[0]]
            else:
                property['desc'] = 'Unknown'
            property['visible']=i[1]
            a = True
            for j in lfields: 
                if j['name'] == i[0]:
                    j['desc'] = property['desc']
                    j['visible'] = property['visible']
                    a = False
            if a:
                lfields = lfields + [ property ]
        

        resourcelogs=resource_logs.selectBy(resource_id = str(resource_id))

        llines = []
        for rlog in resourcelogs:
            line = []
            for i in lfields:
                # special cases of params 
                if i['name'] == 'date_start' or i['name'] == 'date_stop': 
                    property = date_to_string(
                                int((rlog.__dict__['_SO_val_'+ i['name']]))
                                ) 
                elif i['name'] == 'resource_log_id':
                    property = rlog.id
                else:
                    property =  str(rlog.__dict__['_SO_val_'+ i['name']])
                line = line + [ property ]
            llines = llines + [ line ]
        
        rlogs = [ lfields ] +  [ llines ] 

        
        jfields = []
        for i in job_mandatory_fields + job_short_fields_order:
            property = {}
            property['name'] = i[0]
            if job_short_fields.has_key(i[0]):
                property['desc'] = job_short_fields[i[0]]
            else:
                property['desc'] = 'Unknown'
            property['visible'] = i[1]
            a = True
            for j in jfields:
                if j['name'] == i[0]:
                    j['desc'] = property['desc']
                    j['visible'] = property['visible']
                    a = False
            if a:
                jfields = jfields + [ property ]

        jlines = []
        for job in res[0].gantt_jobs():
            line = []
            for i in jfields:
                if i['name'] == 'start_time' or i['name'] == 'stop_time' or i['name'] == 'submission_time':
                    property = date_to_string(int(job.__dict__['_SO_val_'+i['name']]))
                elif i['name'] == 'job_id':
                    property = job.id
                else:
                    property = str(job.__dict__['_SO_val_'+str(i['name'])])
                line = line + [ property ]
            jlines = jlines + [ line ]
        
        jobs = [ jfields ] + [ jlines ]
        return dict( resource=resource_repr,
                     resource_logs=rlogs,
                     jobs=jobs,
                     error_flag=0
                    )




class Root(controllers.RootController):

    resources = Resources()

    @expose(template="tgoar.templates.welcome")
    def index(self):
        log.debug("Wellcome page")
        # FIXME : fix what to display on first page
        return dict()
