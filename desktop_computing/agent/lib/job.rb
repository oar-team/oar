def Process.descendant_processes(base=Process.pid)
  descendants = Hash.new{|ht,k| ht[k]=[k]}
  Hash[*`ps -eo pid,ppid`.scan(/\d+/).map{|x|x.to_i}].each{|pid,ppid|
    descendants[ppid] << descendants[pid]
  }
  descendants[base].flatten - [base]
end

class Job

  attr_accessor :id, :client

  def initialize(job_id=nil, remotehost=nil)
    @job = JobResource.new(job_id)
  end


  # 
  def run
    @job.run
    
    system "mkdir #{@job.id}"
    if @job.has_stagein
      # Extracts and delete the tarball
      @job.get_stagein
      system "tar zxvf #{@job.id}/stagein.tgz -C ./#{@job.id} 1>/dev/null 2>/dev/null "
      system "rm -rf #{@job.id}stagein.tgz"
    end

    begin
      execute_command

      @job.terminate
    rescue
      @job.error
    end


    # Packs the stageout
    system "tar cvzf #{@job.id}.tgz #{@job.id}/ 1>/dev/null 2>/dev/null"
    @job.send_stageout

    # Clean
    system "rm -rf #{@job.id}.tgz"
    system "rm -rf #{@job.id}"

  end

  def kill
    children = Process.descendant_processes(@worker_pid)
    children.each{|pid| Process.kill("TERM", pid) }
    Process.kill("TERM", @worker_pid)
    @job.error
  end

  def fork
    @worker_pid = Process.fork { run }
  end
  private
    def execute_command
      if system("cd #{@job.id} && #{@job.get_command} 1>stdout 2>stderr") != true
        raise JobExecutionException
      end
    end
end

