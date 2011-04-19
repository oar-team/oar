#!/bin/bash
# $Id$
# Script to fix a corrupted oar database, where old job_ids still refer to CURRENT data in various tables.

OARCONFFILE=/etc/oar/oar.conf
if [ ! -r $OARCONFFILE ]; then
	cat <<EOF 2>&1
Error: 
 OAR configuration file not found or not readable.
 Please run this script as the user oar or root from OAR server machine.
EOF
	exit 1
fi
. $OARCONFFILE

TMPFILE=/tmp/$(basename $0).$$

if [ $DB_TYPE == "mysql" ]; then
	mysql -N -h$DB_HOSTNAME -u$DB_BASE_LOGIN -p$DB_BASE_PASSWD $DB_BASE_NAME <<EOF | sort -u > $TMPFILE
#assigned_resources
SELECT DISTINCT jobs.job_id
FROM moldable_job_descriptions, assigned_resources, jobs 
WHERE moldable_job_descriptions.moldable_id = assigned_resources.moldable_job_id
	AND moldable_job_descriptions.moldable_job_id = jobs.job_id
	AND ( state = "Error" OR state = "Terminated" )
	AND assigned_resources.assigned_resource_index = 'CURRENT';


#moldable_job_descriptions
SELECT DISTINCT jobs.job_id
FROM moldable_job_descriptions, jobs 
WHERE  moldable_job_descriptions.moldable_job_id = jobs.job_id
	AND ( state = "Error" OR state = "Terminated" )
	AND moldable_job_descriptions.moldable_index = 'CURRENT';

#job_types
SELECT DISTINCT jobs.job_id 
FROM jobs, job_types 
WHERE jobs.job_id = job_types.job_id
	AND ( state = "Error" OR state = "Terminated" )
	AND job_types.types_index = 'CURRENT';

#job_dependencies
SELECT DISTINCT jobs.job_id 
FROM jobs, job_dependencies 
WHERE jobs.job_id = job_dependencies.job_id  
	AND ( state = "Error" OR state = "Terminated" )
	AND job_dependencies.job_dependency_index = 'CURRENT';

#job_resource_groups
SELECT DISTINCT jobs.job_id
FROM moldable_job_descriptions, jobs, job_resource_groups
WHERE moldable_job_descriptions.moldable_job_id = jobs.job_id
	AND ( state = "Error" OR state = "Terminated" )
	AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
	AND job_resource_groups.res_group_index = 'CURRENT';

#job_resource_descriptions
SELECT DISTINCT jobs.job_id
FROM moldable_job_descriptions, jobs, job_resource_groups, job_resource_descriptions
WHERE moldable_job_descriptions.moldable_job_id = jobs.job_id
	AND job_resource_groups.res_group_moldable_id = moldable_job_descriptions.moldable_id
	AND job_resource_groups.res_group_id = job_resource_descriptions.res_job_group_id
	AND ( state = "Error" OR state = "Terminated" )
	AND job_resource_descriptions.res_job_index = 'CURRENT';
EOF
else 
	echo "Postgres is not supported"
	exit 3
fi

if [ ! -s $TMPFILE ]; then
	echo "Nothing to fix, everthing is ok !"
	exit 0
fi

echo "Need to fix tables for the following jobs:"
cat $TMPFILE
read -p"OK [y/N]" -n 1 -s 
if [ "x$REPLY" != "xy" ]; then
	echo
	echo Aborting.
	exit 2
fi 
echo
echo Fix in progress:
export OARCONFFILE
for j in $(sort -u $TMPFILE); do
	echo -n "$j "
#	oarstat -fj $j	
	(cd /usr/lib/oar; perl -e "use oar_iolib; \$db = iolib::connect(); iolib::log_job(\$db,$j); iolib::disconnect(\$db);")
done
echo
echo "done"
exit 0	
