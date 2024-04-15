oarprint
--------
Pretty printer for a job resources.

Examples

From the job head node (where $OAR_RESOURCE_PROPERTIES_FILE is defined):
::
   oarprint host -P host,cpu,core -F "host: % cpu: % core: %" -C+

On the submission frontend:
::
   oarstat -j 42 -p | oarprint core -P host,cpuset,mem -F "%[%] (%)" -f -

