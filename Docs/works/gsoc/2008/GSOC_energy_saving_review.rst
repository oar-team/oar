*Implementing energy saving upon OAR Resource Management System*
---------------------------------------------------------------

Description:
____________

To adapt OAR with energy efficient functionalities we
decided to treat the problem with two complementary approaches.
Initially we have to deal with the waste of energy when
the cluster is ’under-utilized’ (functioning with no or few
jobs to treat). This drives a need to create an automated
system to manage the energy demand of the cluster. The
system adapts to ’under-utilization’ periods of the cluster
and takes appropriate actions.
In parallel, we decided to deal with energy concious
users and clever applications that are aware of which devices
are going to be in use during the computation. Hence,
OAR provides a way to specify the usage of specific node
devices per job, so as to consume less energy.

1)Prediction based energy energy efficient
scheduling

Energy demand in cluster environment is directly proportional
to the size of the cluster. The typical usage of
the machines varies with time. During daytime, the load
is likely to be more than during night. Similarly, the load
drastically decreases over the weekend. Ofcourse workloads
can change upon different cluster configurations and
utilizations. Energy saving can occur if this pattern can be
captured.
Hence a need for a prediction model arises. Here, we
explore this behavior of load cycles to power down nodes
when idle time period is large. A past repository aids in
maintaining the periodic load of the system.
Our prediction model is based upon an algorithm which
scans for current and future workload and tries to correlate
with the past load history.

2)PowerSaving Jobs

A new type of jobs called
’powersaving’ has been introduced to allow users and applications
to exploit new energy saving possibilities.
Our choices of the hardware devices that can be treated,
were defined by the fact that they have to be either parameterized
to function slower, consuming less energy, or provide
the possibility of a complete power off. 
OAR supports different kind of jobs, like besteffort jobs
(lowest priority jobs used for global computing ) or deploy
type of jobs (used for environment deployment).
The implementation of the new powersaving type of job
allows the user to control the device power consumption
of the computing nodes during their job execution. 

Experiments are on the way to measure the energetical
gain of each power state of every device, considering reallife
applications and workload conditions.

This GSOC project produced new research issues upon Resource Management on clusters and grids and it merged with a wider energy saving framework called GREEN-NET [3]. It took part on a publication titled "The green-net framework: Energy efficiency in large scale distributed systems" In HPPAC 2009 : High Performance Power Aware Computing Workshop [4][5].


Status: 
_______

The feature is currently under evaluation and it will be soon integrated in the future OAR releases.

References-Code:
----------------

[1]:http://code.google.com/soc/2008/oar/appinfo.html?csaid=B50F933C546B30D5
[2]:http://google-summer-of-code-2008-oar.googlecode.com/files/Kamal_Sharma.tar.gz
[3]:http://www.ens-lyon.fr/LIP/RESO/Projects/GREEN-NET/
[4]:http://hppac.cs.vt.edu/
[5]:http://www.ens-lyon.fr/LIP/RESO/Projects/GREEN-NET/Publis.html



Developers: 
___________

Kamal Sharma

Contact: 
________

Yiannis Georgiou (yiannis(DOT)georgiou(AT)imag(DOT)fr)
