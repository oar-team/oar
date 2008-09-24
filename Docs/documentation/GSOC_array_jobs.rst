*Implementing array jobs and improving job dependencies in OAR*
---------------------------------------------------------------

Description:
____________

During the summer 2008, the OAR team took part of the Google Summer of Code event
(see http://code.google.com/soc/2008/ for further details).
One of the OAR projects was implementing array jobs and improving the job 
dependencies mechanism (including array dependencies). With job arrays, one 
invokes the same executable to run many related tasks or sub-jobs with a range 
of input parameters. This is highly useful for throughput-oriented job streams 
in disciplines such as image rendering, financial risk and security modeling, 
bioinformatics and cluster benchmarking studies. While the algorithms in each of
these cases are different, ranging from searching and scoring to Monte Carlo to 
computing an objective function, each of these application areas can benefit by 
creating a set of tasks that are then run in parallel.

Sometimes users want to submit large numbers of jobs based on the same job script.
Rather than using a script to repeatedly call oarsub, the user could use the 
feature known as job arrays to allow the creation of multiple jobs with one 
oarsub command.

With job arrays, a subset of related jobs is sent to each processing node. Each 
subset may represent a range of one or more parameters for a model computation, 
or a range of search sequences, for example. Such job streams are typically run
on clusters or Grids of varying size since there is limited communication between
the tasks until the final stages of the workload, when the results are aggregated.

Status: 
_______

The feature is now implemented and fully functionnal in a branch of the svn 
repository.

Future work:
____________

We still need to merge the array jobs branch with the trunk to integrate Elton's
work in the current OAR version.

Developers: 
___________

Elton Mathias.

Contact: 
________

Joseph Emeras (joseph.emeras :: inria.fr)
