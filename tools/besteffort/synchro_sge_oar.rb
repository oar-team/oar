#!/usr/bin/ruby
# Besteffort OAR/SGE coupling
# This script synchronizes the status of the OAR ressources depending on
# the SGE queues status. It uses the XML output of the SGE qstat cmd.

require 'rexml/document'

# Custom variables
$STATUSDIR='/home_nfs/bzizou/oar_status/'
$XML_STATUS_CMD='qstat -u "*" -f -xml'
$OARNODESETTING_CMD='/usr/local/sbin/oarnodesetting'

# Get the qstat output in XML format
xml_data=`#{$XML_STATUS_CMD}`

# Parse the XML output
doc = REXML::Document.new(xml_data)
cond="false"
doc.elements.each('job_info/queue_info/Queue-List') do |queue|
  # For each node
  node=queue.elements["name"].text.split('@')[1]
  core=0
  queue.elements.each('job_list') do |job|
    # For each job running on the node
    job_id=job.elements["JB_job_number"].text
    job_status_file=File.new("#{$STATUSDIR}/#{job_id}","a")
    job.elements["slots"].text.to_i.times do
      # Mark "slots" cores as used resources
      core += 1
      resource="#{node}.#{core}" 
      # Update the status file of the job
      job_status_file.puts(resource)
      # Touch a file identifing the used resource
      resource_status_file=File.new("#{$STATUSDIR}/#{resource}","w")
      resource_status_file.close
      # Update the SQL condition for oarnodesetting
      cond += " or (network_address='#{node}' and cpuset=#{core-1})"
    end
    job_status_file.close
  end
end

# Update the OAR resources
if cond != "false"
  `#{$OARNODESETTING_CMD} -s Alive --sql "besteffort='YES'"`
  `#{$OARNODESETTING_CMD} -s Absent --sql "#{cond}"`
end
