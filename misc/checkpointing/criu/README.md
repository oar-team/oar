Simple bash daemon for CRIU checkpointing on a OAR cluster
==========================================================

CRIU: https://criu.org

Install
-------

*  Install CRIU on all nodes and check it (`criu --check`). You can get CRIU 
   packages from this page: https://criu.org/Packages
*  Copy the bash daemon into /usr/local/sbin and create a link (on every node):
```
cp criu-daemon.bash /usr/local/sbin
ln -s /usr/local/sbin/criu-daemon.bash /usr/local/sbin/criu-daemon
```
*  Copy the systemd config file and start the service (on every node):
```
cp criu.service /etc/systemd/system
systemctl start criu
```

Usage
-----

The file `test.script.checkpoint.oar` contains a typical checkpointed and 
idempotent (automatically restarted after checkpoint) OAR job example. It 
launches a program called "obiclean". Of course, adapt this script to your
needs. Be sure to launch your job into a directory that is shared and accessible
from all the nodes of the computing cluster. 
Be aware that the resume of a checkpointed job might not work if your job is
restarted on nodes that have different architectures (system version, memory 
size, ...) so, you may have to add some properties filtering into your OAR 
submission, to be sure to restart on compatible nodes. Take also care of the 
available space into your working directory. This directory must be shared on 
all the nodes. A sub-directory `checkpoint` will be created and it will 
generally be the size of the dumped memory of your program.
Note that the standard outputs of your program will be appended to the output 
files of the first job, even if this job is dead and replaced by resumed jobs.

How does it work
----------------

CRIU is a tool that allows dumping an entire process tree and it's memory to 
disk. It needs to be run as a privileged user (root) and must not be part of 
the dumped process tree. It means that a job cannot directly call criu to 
checkpoint itself (see https://criu.org/Self_dump).

So we created a simple daemon that checks for files created into a temporary 
directory of the computing node (typically `/var/lib/checkpoints/`) in which 
OAR jobs will create `<job_id>.checkpoint` or `<job_id>.resume` files to trig
a checkpoint or a resume of a job. The daemon does some security checks and 
launches `criu dump` or `criu restore` as necessary. Some informations are passed
to the deamon inside the temporary files: the pid of the process to dump and the
working directory. When resuming a job, the daemon will take care of placing the
resumed process into the OAR cpuset of the new job.