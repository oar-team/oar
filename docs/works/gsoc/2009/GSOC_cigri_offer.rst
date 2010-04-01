*Advanced scheduler for the CiGri grid*
---------------------------------------


Introduction
____________

CiGri is a free software allowing to construct a computing grid which exploits idle processor cycles of a supercomputers group. CiGri is a lightweight grid which manages only "bag-of-tasks" applications that generaly result in a big number (>100000) of independant and idempotent sub-tasks. Running such applications at the grid level optimizes the load of supercomputers in a middle sized HPC center. Such a grid is running over HPC hosts of the Joseph Fourier university (Grenoble/FRANCE) since 2002, inside the "CIMENT" project. It manages today 2000 cpu cores and executed about 5 millions of tasks. The name CiGri comes originaly from this CIMENT project (CIment-GRId). CiGri is also an experimental platform for research on distributed computing scheduling at the computing laboratory of Grenoble (LIG).

Cigri structure
_______________

CiGri is currently composed of a MySQL database, some perl modules and some ruby modules. Communication and authentication mechanisms are based on simple and standard tools like SSH, SUDO and LDAP. A web PHP/Smarty interface allows users to check their job campaigns statuses and to interact if necessary. Everything has been developped and tested for Linux. The modules are cyclicly executed: nodes and tasks states update, tasks to submit scheduling, tasks launching, cleaning, error control, statistics update. An external asynchronous module is dedicated to results collecting.

Environnement
_____________

Development is done inside the "MESCAL" team of the "LIG" laboratory and guidelines are given by this team research projects and by the needs of the "CIMENT" project. It's a motivating environnement because you can talk with engineers and researchers working on complex problems about distributed computing. This "MESCAL" team is also in charge of the development of the OAR resources manager and is a major actor of the development and administration of the experimental french national grid called "Grid5000".

The need for a new scheduler
____________________________

The current scheduler module of CiGri is a basic FIFO and doesn't deal with parallel tasks. When the grid runs at a high load, it may happen that a user is blocked for days, even if he needs very few resources, for example if he only need to test a new campaign. Furthermore, the Grenoble's grid is becoming bigger and extends to other towns (Lyon, for the RaGrid project). That brings new needs like users priorities over some clusters, depending on their community.

We want to develop a new scheduler that will be able to manage users fairsharing, several queues with complex priorities and to take into account parallel tasks running on several nodes of a cluster. This new scheduler should also manage interactions with other new modules that are also currently under development, like a checkpointing module. We want to use a high level modern language, like Ruby, to have a very maintenable and scalable code. In addition to this development task, the trainee, if he wants, could approach more "system" aspects and participate to the implementation of other tools like checkpointing or distributed filesystems. Also note that this project is very close to the OAR project and Grid5000 administration.

Links
_____

* CIMENT project: http://ciment.ujf-grenoble.fr
* CiGri: http://cigri.imag.fr
* MESCAL Team: http://mescal.imag.fr/
* RaGrid: https://ciment.ujf-grenoble.fr/ragrid
* OAR: http://oar.imag.fr
* Grid5000: http://www.grid5000.fr

Contact
_______

Bruno Bzeznik <Bruno.Bzeznik@imag.fr>

