======================
The IDTRUIT experiment
======================

Some say that when we power off and on a computer for energy saving, it may be bad 
for the hardware's health. 

So, we took 4 nodes of an end-of-life cluster (idpot) and made a simple script idtruit.sh 
doing cyclicly, on each node:

- Send a hard poweroff (by pressing 4 seconds the power button via a serial command module)
- Wait 30 seconds
- Power on (by pressing 0,1s the power button)
- Wait for the system to boot and reply to a ssh scan
- Wait for 60 seconds

We did this during a few weeks and so made a huge number of power off/on cycles with a 
complete startup of the system, network and disk included.

We obtained the following number of reboots:

- idpot-1: 12233
- idpot-2: 14341
- idpot-3: 16558
- idpot-4: 13777

Some nodes made less cycles than the others because we had fiability problems with the 
module command (lock problems) and NIC problems on idpot-1 and idpot-4. Those NIC were
already buggy during the "normal" life of the cluster. But we ensure that no cluster
node were injured during the experiment ;-)

So about, 14000 power cycles without damaging the hardware. It means about 12 cycles
per day during 3 years. It's probably more than we are going to do on an ecological
cluster.
