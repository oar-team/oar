*Interoperability with DRMAA*
-----------------------------


Description:
____________

In the High Performance Computing and Cluster context, several research groups put forward tools for managing cluster resources distributed jobs.

Some efforts have been recently made by the "OGF group":http://www.ogf.org to merge research results and standardize grid software interoperability.
Among this standards, "DRMAA":https://forge.gridforum.org/sf/projects/drmaa-wg and "SAGA":http://forge.ogf.org/sf/projects/saga-rg are available ( see "this document":http://www.michal.ejdys.pl/nauka/apis-and-endusers-report.pdf for more info).

DRMAA is an abstraction of the job management interface of the DRMS (Distributed Resource Management System). Its goal is to limit the user's application / DRMS coupling. Until now, DRMAA is supported by the following DRMS: SunGridEngine, Condor, GridWay and Torque/PBS. Our main competitor, PBS, has recently implemented a "DRMAA plugin":http://sourceforge.net/project/showfiles.php?group_id=175762 .

As PBS is the DRMS that is the closest from us by its mechanisms, it can be very interesting for us to analyze this implementation and to adapt for our DRMS.
As for SAGA, it has been created for a more standardized API. It can be thought of as a grand unification of the previous efforts and systems. The user should get a high level API with bindings for most popular languages.


Thus, analysing how OAR could implement SAGA and DRMAA and programming the interface layer would made our product much more interoperable and usable by more users.

The intern will be in constant relation with the team and will regularly discuss the work progression by audioconference and by email.


Classification: 
_______________

Hard


Intern required skills:
_______________________

* Perl
* C
* Distributed computing
* Linux
