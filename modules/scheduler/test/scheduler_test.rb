require 'oar_db_setting'
require 'oar_test_scheduler_helpers'
require 'test/unit'
require 'getoptlong'

$db_state = 'unready'

opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--scheduler', '-s', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--db_type', '-d', GetoptLong::REQUIRED_ARGUMENT ]
    )

# process the parsed options
opts.each do |opt, arg|
  puts "Option: #{opt}, arg #{arg.inspect}"
end
puts "Remaining args: #{ARGV.join(', ')}"


class TestBase < Test::Unit::TestCase
  @@db_up = false
  def setup
    if (!@@db_up)  
      oar_db_clean #clean jobs and resources
      oar_db_resource("core=16")
      oar_conf_create
      $db_up = true 
    else
      oar_db_truncate_jobs
    end


  # test 1 simple job
  def test_one_job
    jid = oar_job_insert
    assert(oar_job(:fisrt
  end

  # test backfilling
  def test_backfilling
  end

end


class TestNormal < Test::Unit::TestCase
  def setup
   end

   def test_previous_job
   end

   def test_ressource_matching
   end

   def test_hierarchy
   end

  def test_multiple_resource_requests
  end


  def test_multiple_resource_types
  end

  def job_container
  end

  def test_besteffort
  end

  def test_job_depencies
  end

end

class TestBasicError < Test::Unit::TestCase
  def setup
  end

  def test_notenought_resources
  end

end

class TestAdvanced < Test::Unit::TestCase
  def setup
  end

  def test_all_ressources
  end

  def test_best_ressources
  end
end
