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


Install bkm
===========
cd ~/prog/oar/trunk/modules/scheduler
scp -P 2222 -r black-maria root@localhost:/root
apt-get install phpmyadmin
apt-get install lua5.1 liblua5.1-copas0 blua5.1-coxpcall0 liblua5.1-sql-mysql-2 

echo "lua /root/black-maria/black-maria-sched.lua" > /usr/lib/oar/schedulers/black-maria-sched
chmod 755 /usr/lib/oar/schedulers/black-maria-sched



# install new oar queue (spades for instance)
oarnotify --add_queue "spades,5,black-maria-sched"




Multiple slurmd support:

slurm must be recompiled with "--enable-multiple-slurmd" parameter at configure step.
For more information, see:
https://computing.llnl.gov/linux/slurm/programmer_guide.html


20/11/10
========
*  ./kvm-tcp oar_slurm-v2.raw 


17/10/10
========
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


