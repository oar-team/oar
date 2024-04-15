oarwalltime
-----------

This command manages requests to change the walltime of a job.

Walltime changes can only be requested for a running job.

There is no warranty that walltime can be increased, since it depends on the resources availability (next jobs).

Once a request is registered, it will by handled during the next pass of scheduling and granted if it fits with other jobs.

As per configuration:

* the walltime change functionality may be disabled in your installation, and if not there is a maximum to the possible walltime increase

* a walltime increase request may only be applied some time before the predicted end of the job. That apply time may be computed as a percentage of the walltime of the job

* a walltime increase may happen incrementally, so that other scheduled jobs get more priority. That increment may be computed as a percentage of the walltime of the job

* the functionality may be configured differently from one queue to another.

Read your site's documentation or ask your administrator to know the configured settings.

See the manual page of the command for its usage.
