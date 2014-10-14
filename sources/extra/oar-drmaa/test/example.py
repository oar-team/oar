#!/usr/bin/env python

import drmaa
import os

def main():
    """Submit a job.
    Note, need file called sleeper.sh in current directory.
    """
    s = drmaa.Session()
    s.initialize()
    print 'Creating job template'
    jt = s.createJobTemplate()
    jt.remoteCommand = os.getcwd() + '/sleeper.sh'
    jt.args = ['42','Simon says:']
    #jt.nativeSpecification = "--type besteffort --project yop --name poy --hold"
    
    #jt.nativeSpecification = "-q yop --name poy -O s1 -E lksdf " -> OK
    jt.nativeSpecification = "--type besteffort "
    #jt.nativeSpecification = "--hold" -> OK

    #hardWallclockTimeLimit  = _h.Attribute(_c.WCT_HLIMIT, _h.IntConverter)
    #'Hard' Wallclock time limit, in seconds.
    jt.joinFiles=True #not supported yet support in OAR
    
    jobid = s.runJob(jt)
    print 'Your job has been submitted with id ' + jobid

    print 'Cleaning up'
    s.deleteJobTemplate(jt)
    s.exit()
    
if __name__=='__main__':
    main()
