#!/usr/bin/ruby
require 'oar_db_setting.rb'

def oar_conf_add_hierarchy nb_resources

  hierarchy_conf = "HIERARCHY_LABELS=\"resource_id\"\nresource_id=\"(1,1,#{nb_resources})\""
  system "cat oar_base.conf > oar.conf;
          echo '#{hierarchy_conf}' >> oar.conf"
end

def oar_conf_modify_hierarchy_1h nb_resources
  system "sudo sed 's/resource_id=\"(1,1,[0-9]*)\"/resource_id=\"(1,1,#{nb_resources})\"/' /etc/oar/oar.conf > /tmp/oar.conf_tmp;
    sudo sh -c 'cat /tmp/oar.conf_tmp >  /etc/oar/oar.conf'"
end


def oar_ressources_1h(nb_ressources)
  oar_truncate_resources
  nb_ressources.times do |i| oar_resource_insert end
end

def timed_exec sched
  t0 = Time.now; e = system sched; t1 = Time.now
  return t1-t0,e
end

def bench_stairway (steps,sched)
  if steps.class == Fixnum
    steps = [s]
  end 
  steps.each do |k|
    oar_db_clean
    k.times do |i| oar_resource_insert end
    oar_conf_add_hierarchy k
    k.times do |i|
       
      oar_job_insert(:res=>"resource_id=#{i}",:walltime=> 300) end
    t,e = timed_exec sched  
    if e 
      puts "bench_stairway (nb,tps) #{k} #{t}"
    else
      puts "bench_stairway ERROR system result = FASLE (nb) #{k}"
    end
  end
end


def simple_scheduler_test(nb_resources=100, nb_jobs=100)
  if (nb_jobs > nb_resources)
    puts "Nb resources must be >= nb jobs"
  else 
    oar_db_clean; oar_truncate_gantt; oar_reset_all_jobs
    puts "Create Ressources"
    oar_resource_insert(:nb_resources=>nb_resources)
    oar_conf_modify_hierarchy_1h(nb_resources)
    puts "Create Jobs"
    nb_jobs.times do |i|
      oar_job_insert(:res=>"resource_id=#{i+1}",:walltime=> 300) 
    end
    puts "Launch Scheduler"
    tps, ok = timed_exec "sudo /usr/local/lib/oar/schedulers/simple_cbf_mb_h_ct_oar_mysql"
    pp [tps, ok]
  end
end

def simple_scheduler_test_dec(nb_resources=100, nb_jobs=100)
  if (nb_jobs > nb_resources)
    puts "Nb resources must be >= nb jobs"
  else 
    oar_db_clean; oar_truncate_gantt; oar_reset_all_jobs
    puts "Create Ressources"
    oar_resource_insert(:nb_resources=>nb_resources)
    oar_conf_modify_hierarchy_1h(nb_resources)
    puts "Create Jobs"
    job_nb_res = nb_resources-1
    nb_jobs.times do |i|
      job_nb_res -= 1 if job_nb_res >= 2
      puts "job #{i}: resource_id=#{job_nb_res} walltime=> 300"
      oar_job_insert(:res=>"resource_id=#{job_nb_res}",:walltime=> 300) 
    end
    puts "Launch Scheduler"
    tps, ok = timed_exec "sudo /usr/local/lib/oar/schedulers/simple_cbf_mb_h_ct_oar_mysql"
    pp [tps, ok]
  end
end




