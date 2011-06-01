#!/usr/bin/ruby
require 'oar_db_setting.rb'

def oar_conf_add_hierarchy nb_resources

  hierarchy_conf = "HIERARCHY_LABELS=\"resource_id\"\nresource_id=\"(1,1,#{nb_resources})\""
  system "cat oar_base.conf > oar.conf;
          echo '#{hierarchy_conf}' >> oar.conf"
  
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
    k.times do |i| oar_job_insert(:res=>"resource_id=#{i}",:walltime=> 300) end
    t,e = timed_exec sched  
    if e 
      puts "bench_stairway (nb,tps) #{k} #{t}"
    else
      puts "bench_stairway ERROR system result = FASLE (nb) #{k}"
    end
  end
end
