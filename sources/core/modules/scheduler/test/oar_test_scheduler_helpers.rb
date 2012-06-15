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


def oar_resources_1h(nb_ressources)
  oar_truncate_resources
  nb_ressources.times do |i| oar_resource_insert end
end

def oar_resources_3h(h_r)
#HIERARCHY_LABELS="node,cpu,core"
#host="(1,16,2), (33,8,4)" start_index/size_block/nb_blocl
#cpu="(1,8,8)"
#core="(1,1,64)"
#oar_resources_3h {:host=>[[1,16,2], [33,8,4]],:cpu=>[1,8,8],:core=>[1,1,64]}
  oar_truncate_resources
  puts h_r
  h_ids = {:host=>[],:cpu=>[],:core=>[]}
  h_r.each do |k,v|
    i=1
    if v.first.is_a?(Array)
      v.each do |a|
        a[2].times do #nb_blocks
          a[1].times do #block_size
            h_ids[k] << i
          end
          i += 1
        end
      end
    else
      v[2].times do #nb_blocks
        v[1].times do #block_size
          h_ids[k] << i
        end
        i += 1
      end
    end
  end
  h_ids[:core].each_with_index do |c_id,i|
    host = h_ids[:host][i]
    cpu  =  h_ids[:cpu][i]
    core = c_id
    $dbh.execute("insert into resources (state, host, cpu, core) values ('Alive', #{host},#{cpu},#{core})").finish
  end
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

#simple_scheduler_test(100,100,SCHED_PERL_TS)
#simple_scheduler_test(100,100,SCHED_OCAML_A)
def simple_scheduler_test(nb_resources=100, nb_jobs=100, sched="sudo /usr/local/lib/oar/schedulers/simple_cbf_mb_h_ct_oar_mysql")
  #oar_truncate_jobs is called on oar_bulk_job_insert
  oar_truncate_resources; oar_truncate_gantt;
  puts "Create Ressources 1h (only resource_id)"
  oar_resource_insert(:nb_resources=>nb_resources)
  oar_conf_modify_hierarchy_1h(nb_resources)
  puts "Create Jobs w/ oar_bulk_job_insert(#{nb_jobs}) {|i| [(i % #{nb_resources})+1,300]}"
  #oar_bulk_job_insert(nb_jobs) {|i| [(i % nb_resources) +1,300]}
  oar_bulk_job_insert(nb_jobs) {|i| [2,300]}
  print "Launch Scheduler: "
  sched_cmd = "sudo sh -c '#{OARCONFFILE}; #{sched} default #{Time.now.to_i}'"
  puts sched_cmd
  tps, ok = timed_exec sched_cmd
  pp [tps, ok]
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




