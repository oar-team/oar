==================
 Black-Maria Test
==================

Some tests conduct with oar_slurm an BKM

locale: Cannot set LC_ALL to default locale: No such file or directory

sudo dpkg-reconfigure locales
en_US.UTF-8

locale-gen en_US.UTF-8 (a test pour le mode batch???)


copy des clés (?)
mkdir .ssh
scp -P 2222 ~/.ssh/id_rsa.pub root@localhost:/root/.ssh/authorized_keys


Install BKM
===========

Get oar source
---------------
apt-get install subversion
svn checkout svn://scm.gforge.inria.fr/svn/oar/trunk

cd ~/prog/oar/trunk/modules/scheduler
scp -P 2222 -r black-maria root@localhost:/root
apt-get install phpmyadmin
apt-get install lua5.1 liblua5.1-copas0 blua5.1-coxpcall0 liblua5.1-sql-mysql-2 

echo "lua /root/black-maria/black-maria-sched.lua \$1" > /usr/lib/oar/schedulers/black-maria-sched
ln -s /root/black-maria/oar.lua /usr/share/lua/5.1/
ln -s /root/black-maria/black-maria-pilot.sh /bin/
chmod 755 /usr/lib/oar/schedulers/black-maria-sched
chmod 755 /root

*IMPORTANT* oardodo est sensible ! 
ln -s /usr/local/bin/sbatch /usr/bin/sbatch_oardodo


#sync from external black-maria 
rsync -avL . kam:gvim /root/black-maria/

# install new oar queue (spades for instance)
oarnotify --add_queue "spades,5,black-maria-sched"

Multiple slurmd support:

slurm must be recompiled with "--enable-multiple-slurmd" parameter at configure step.
For more information, see:
https://computing.llnl.gov/linux/slurm/programmer_guide.html
(realized in kameleon's slurm step kameleon/steps/slurm)


Running and helpers:
====================
Launch BKM-sync:
----------------

sudo -iu oar lua /root/black-maria/black-maria-sync.lua 

Launch manually for test purpose BKM-sched
-------------------------------------------
sudo -iu oar /usr/lib/oar/schedulers/black-maria-sched spades


Truncate jobs
-------------
~/trunk/modules/scheduler/ocaml-schedulers/test# irb -r oar_db_setting.rb
irb(main):001:0> oar_truncate_jobs

Oarsub w/o container
--------------------
oarsub -q spades -l nodes=1,walltime=00:1:00 fo

test oarsub container 
----------------------

oarsub -t container -l nodes=1,walltime=00:10:00 "sleep 500"
[ADMISSION RULE] Modify resource description with type constraints
OAR_JOB_ID=1
oarsub -t inner=1 -l nodes=1,walltime=00:8:00 "sleep 200"

Oarsub simple cycle:
--------------------

oarsub -t container -q spades -l nodes=1,walltime=00:10:00 foo
oarsub -t inner=1 -l nodes=1,walltime=00:6:00 "sleep 200"



Slurm commandes:
----------------
sinfo, squeue, scancel
scancel -p test cancel all job from test partition

Logs tests:
===========

next
----
doc / install
log message
multiple nodes

06/03/11
--------
simple oarsub cycle ok:
oarsub -t container -q spades -l nodes=1,walltime=00:10:00 foo
oarsub -t inner=1 -l nodes=1,walltime=00:6:00 "sleep 200"


kameleon@kameleon:~$ squeue
  JOBID PARTITION     NAME     USER  ST       TIME  NODES NODELIST(REASON)
    138      test black-ma kameleon   R       4:20      1 node1

kameleon@kameleon:~$ oarstat
Job id     Name           User           Submission Date     S Queue
---------- -------------- -------------- ------------------- - ----------
1                         kameleon       2011-03-06 18:21:35 R spades    
2                         kameleon       2011-03-06 18:22:12 R default  



05/03/11
--------
* Besoin de vider la table job OAR:... en lua ??? -> non utilisation deruby 
* faire test cyle complet *


02/03/11
--------
*  ./kvm-tcp oar-slurm-v2.raw 
Notes: kvm-tcp -> sudo kvm -m 512 -redir tcp:2222::22 $1
oarsub -I 
 sinfo OK


17/10/10
--------
* test oar_slurm.raw
* user/pwd: root/kameleon
* fix locales
* test: oarsub -I OK
* test: 

slurmmeleon@kameleon:~$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
local*       up   infinite      1   idle kameleon


kameleon@kameleon:~$ squeue
  JOBID PARTITION     NAME     USER  ST       TIME  NODES NODELIST(REASON)

kameleon@kameleon:~$  scontrol show partition
PartitionName=local
   AllocNodes=ALL AllowGroups=ALL Default=YES
   DefaultTime=NONE DisableRootJobs=NO Hidden=NO
   MaxNodes=UNLIMITED MaxTime=UNLIMITED MinNodes=1
   Nodes=kameleon
   Priority=1 RootOnly=NO Shared=NO
   State=UP TotalCPUs=2 TotalNodes=1

kameleon@kameleon:~$ scontrol show node
NodeName=kameleon Arch=i686 CoresPerSocket=2
   CPUAlloc=0 CPUErr=0 CPUTot=2 Features=(null)
   OS=Linux RealMemory=2000 Sockets=1
   State=IDLE ThreadsPerCore=1 TmpDisk=0 Weight=1
   Reason=(null)


To update node when it's in down state
scontrol update NodeName=kameleon State=RESUME

SLURM_JOB_NODELIST is the list of allocated node in condensed format exemple
lx[15,18,32-33]
dev[0-8,18-25],edev[0-25] ??? is this possible ???
"rack[0-63]_blade[0-41]" => valid but we doesn't support it in BKM


