#                  ((( |||_| ///\ [[[_ (((
#                   ))) || |  \\/  [[_  )))
# 
#                      #################
#                 ###########################
#              #################################
#            #####################################
#          ################,_####_##################
#         ###############_,) \__/ )##################
#         ##########__.\\\\    ,_ |#_################
#        ########/`,         _,) \__/ )###############
#        ########\,'    __.\\\\,   ,_ |###_###########
#        ###########`-/`,         _,) \__/ )##########
#        #############\,'    __.\\\\',    /|##########
#        ###############`-/`,       \ \__/ |##########
#         ################\,'   ,=== \____/|#########
#         #################`--'--'--'--'--'##########
#          #########################################
#            ######################################
#              ##################################
#                 ############################
#                      ##################
# 
# 
#                        And a shotgun!
# 
#  ,______________________________________
# |_________________,----------._ [____]  ""-,__  __....-----=====
#                (_(||||||||||||)___________/   ""                |
#                   `----------'        [ ))"-,                   |
#                                        ""    `,  _,--....___    |
#                                                `/           """"
# 
# 
# Shoes - _why ( http://github.com/why/shoes/tree/master )
# Shotgun - Ryan Tomayko ( http://github.com/rtomayko/shotgun/tree/master )
#
# AscII Artists: _why, 7-(ans, Krogg
# 

Shoes.setup do
	# Put whatever gems you want in here.
	# 
	# If you're using a different framework remove sinatra from the list.
	{
		'http://gems.rubyforge.org' => %w( daemons rack eventmachine ),
		'http://gems.github.com' => %w( macournoyer-thin sinatra-sinatra )
	}.each do | url, gems |
		source url
		gems.each { | g | gem g }
	end
end

require 'rack'

class Shotgun
  attr_reader :rackup_file

  def initialize(rackup_file, wrapper=nil)
    @rackup_file = rackup_file
    @wrapper = wrapper || lambda { |inner_app| inner_app }
  end

  def call(env)
    dup.call!(env)
  end

  def call!(env)
    @env = env
    @reader, @writer = IO.pipe

    # Disable GC before forking in an attempt to get some advantage
    # out of COW.
    GC.disable

    if fork
      proceed_as_parent
    else
      proceed_as_child
    end

  ensure
    GC.enable
  end

  # ==== Stuff that happens in the parent process

  def proceed_as_parent
    @writer.close
    status, headers, body = Marshal.load(@reader)
    @reader.close
    Process.wait
    [status, headers, body]
  end

  # ==== Stuff that happens in the forked child process.

  def proceed_as_child
    @reader.close
    app = assemble_app
    status, headers, body = app.call(@env)
    Marshal.dump([status, headers.to_hash, slurp(body)], @writer)
    @writer.close
	ensure
    exit! 0
  end

  def assemble_app
    @wrapper.call(inner_app)
  end

  def inner_app
    if rackup_file =~ /\.ru$/
      config = File.read(rackup_file)
      eval "Rack::Builder.new {( #{config}\n )}.to_app", nil, rackup_file
    else
      require rackup_file
      if defined? Sinatra::Application
        Sinatra::Application.set :reload, false
        Sinatra::Application.set :logging, false
        Sinatra::Application.set :raise_errors, true
        Sinatra::Application
      else
        Object.const_get(File.basename(rackup_file, '.rb').capitalize)
      end
    end
  end

  def slurp(body)
    return body    if body.respond_to? :to_ary
    return [body]  if body.respond_to? :to_str

    buf = []
    body.each { |part| buf << part }
    buf
  end
end


class ShoesAndAShotgun < Shoes
	url '/', :index
	
	def index
		fileName = ( @fileName ) ? @fileName.text : 'app.rb'
		portNum = ( @portNum ) ? @portNum.text : '3000'
	
		clear
		background red
	
		stack :margin => 10 do
			para 'Filename', :stroke => white
			@fileName = edit_line :width => 270, :text => fileName
		end
		stack :margin => 10 do
			para 'Port', :stroke => white
			@portNum = edit_line :width => 80, :text => portNum
		end
		button 'Start', :margin => 10 do
			running
		end
	end

	def running
		index unless @fileName.text =~ /^[^\.]+\.[^\.]+$/
		index unless @portNum.text =~ /^[0-9]*[0-9]{2}[0-9]*$/
		index unless File.exists?( @fileName.text )
		
		server = Rack::Handler::Thin
	 	app = Shotgun.new( @fileName.text )
		@thread = Thread.new { server.run( app, { :Host =>'127.0.0.1', :Port => @portNum.text } ) }
		
		clear
		background green
		
		stack :margin => 10 do
			title 'Running on port: '+@portNum.text, :weight => 'bold', :stroke => white
			
			stack do
        background white, :curve => 4
        caption(
					link('Open the app...', :click => "http://localhost:#{@portNum.text}"),
					:stroke => "#CD9",
					:align => 'center',
					:margin => 4
				)
      end
	
			button 'stop' do
				@thread.exit
				index
			end
		end
	end
end

Shoes.app( :width => 300, :height => 250, :resizable => false, :title => 'Shoes and a Shotgun' )
