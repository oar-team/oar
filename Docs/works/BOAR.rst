*Combining OAR with the power of volunteer computing through BOINC*
-------------------------------------------------------------------

Description:
____________

In the current scenario, we can observe two distinct class of resources that are
used for grid computing. Each of these classes has its own advantages and 
advantages. On one hand, there are high-end, clusters or microprocessors that 
provide rich-feature sets dedicated to computation of user submitted jobs, 
whereas on the other hand, we have Desktop grids that combine the power of 
thousands of light-weight systems (desktops) and utilize their idle times to 
execute applications. However, in order to fully harness the potential of grid 
computing, it is necessary to develop an interface that can communicate with 
both these classes with equal ease, in order to use the best features offered by
each ofthese platform types. Hence, in this project, we try to integrate two 
different resource managementsystems. These are namely the 
Berkeley Open Infrastructure for Network Computing (BOINC), which is a resource
management middleware for volunteer computing and desktop grid computing, 
and OAR, which a resource manager (batch scheduler) for large clusters and Grids.
We implement a B-OAR interface that understands the underlying architectures of 
both these systems and translates the data storage and interpretation formats, 
in order to make the two systems communicate.

Status: 
_______

Jobs submitted through OAR can run on volunteer resources  through a BOINC server.

Future work:
____________

We are currently looking for real compute-intensive applications to utilize this
new tool. 
We are also implementing virtual resources in OAR to give a user the perception 
of a dedicated platform built from volatile resources.

Developers: 
___________

Nagarjun Kota, Olivier Richard, Derrick Kondo with much guidance from the OAR team.

Contact: 
________

Derrick Kondo (derrick.kondo :: inria.fr)
