from sqlobject import *
import logging
from turbogears.database import PackageHub

hub = PackageHub("tgoar")
__connection__ = hub

class resources(SQLObject):

    class sqlmeta:
        fromDatabase = True
        table = "resources"
        idName  = "resource_id"
        style = MixedCaseStyle(longID=True)
    
    moldable_job_descriptions = RelatedJoin( 
                                 'moldable_job_descriptions',
                                 joinColumn='resource_id',
                                 otherColumn='resource_id',
                                 intermediateTable='gantt_jobs_resources')

    gantt_jobs_resources = RelatedJoin('gantt_jobs_resources', 
                                       joinColumn='resource_id', 
                                       otherColumn='moldable_job_id',
                                       intermediateTable='gantt_jobs_resources')

    assigned_resources = RelatedJoin('assigned_resources', 
                                      joinColumn='resource_id',
                                      otherColumn='resource_id',
                                      intermediateTable='assigned_resources')

    resource_logs = RelatedJoin('resource_logs',
                                 joinColumn='resource_id',
                                 otherColumn='resource_log_id',
                                 intermediateTable='resource_logs')

    def gantt_jobs(self):
        """
            Return scheduled jobs
        """
        js = []
        for g in self.gantt_jobs_resources: 
            js.extend(g.jobs)
        return js


    def get_running_jobs(self):
        """
            return running jobs
        """
        js = []; 
        for i in self.gantt_jobs(): 
            if i.state == 'Running':
                js = js + [ i ] 
        return js;

    def is_running(self):
        if self.get_running_jobs() != []: 
            return True
        return False

class resource_logs(SQLObject):

    class sqlmeta:
        fromDatabase = True
        table = "resource_logs"
        idName  = "resource_log_id"
        style = MixedCaseStyle(longID=True)


class gantt_jobs_resources(SQLObject):

    class sqlmeta:
        fromDatabase = True
        # FIXME: use _visu table 
        table = "gantt_jobs_resources"
        idName  = "moldable_job_id"
        style = MixedCaseStyle(longID=True)
    jobs = RelatedJoin('jobs',
                        joinColumn='moldable_id', 
                        otherColumn='moldable_job_id', 
                        intermediateTable='moldable_job_descriptions' )

class moldable_job_descriptions(SQLObject):
    class sqlmeta:
        fromDatabase = True
        table = "moldable_job_descriptions"
        idName = "moldable_id"
        style = MixedCaseStyle(longID=True)
    resources = RelatedJoin('resources',
                            joinColumn='moldable_job_id', 
                            otherColumn='resource_id',
                            intermediateTable='gantt_jobs_resources')

    # job_prediction = SingleJoin('gantt_jobs_predictions', 
    #                               joinColumn='moldable_job_id', 
    #                               otherColumn='moldable_job_id')



class jobs(SQLObject):
    class sqlmeta:
        fromDatabase = True
        table = "jobs"
        idName = "job_id"
        style = MixedCaseStyle(longID=True)
    gantt_jobs_resources=RelatedJoin(
                            'gantt_job_resources',
                            joinColumn='moldable_job_id', 
                            otherColumn='moldable_id',
                            intermediateTable='moldable_job_descriptions' )

    
    def get_state_logs(self): 
        return job_state_logs.selectBy(job_id=self.id)

    def get_current_state_log(self):
        return job_state_logs.select( job_state_logs.q.job_id==self.id,
                                      orderBy='date_start')[0]
        

class job_state_logs(SQLObject):
    class sqlmeta:
        fromDatabase = True
        table = "job_state_logs"
        idName = "job_id"
        style = MixedCaseStyle(longID=True)



class assigned_resources(SQLObject):
    class sqlmeta:
        fromDatabase = True
        table="assigned_resources"
        idName='moldable_job_id'
        style = MixedCaseStyle(longID=True)



"""
class gantt_jobs_predictions(SQLObject):

    class sqlmeta:
        fromDatabase = True
        table = "gantt_jobs_predictions"
        idName  = "moldable_job_id"
        style = MixedCaseStyle(longID=True)

    job_prediction = SingleJoin('moldable_job_descriptions',
                                joinColumn='moldable_job_id',
                                otherColumn='moldable_job_id')

"""


"""

class gantt_jobs_resources_visu(SQLObject):

    class sqlmeta:
        fromDatabase = True
        table = "gantt_jobs_resources_visu"
        idName  = "moldable_job_id"
        style = MixedCaseStyle(longID=True)
"""
"""
class gantt_jobs_prediction_visu(SQLObject):

    class sqlmeta:
        fromDatabase = True
        table = "gantt_jobs_prediction_visu"
        idName  = "moldable_job_id"
        style = MixedCaseStyle(longID=True)


class jobs(SQLObject):
     class sqlmeta:
        fromDatabase = True
        table = "jobs"
        idName  = "job_id"
        style = MixedCaseStyle(longID=True)

   """
