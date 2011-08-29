class Configuration
  include Singleton
  attr_reader :host, :user, :pass
  def initialize
    file = File.open('/etc/oar/oar.conf')

    server_hostname = nil

    file.each_line do |line|
      if line =~ /OAR_REST_SERVER=(.*)/
        @host = $1
      elsif line =~ /DESKTOP_COMPUTING_AGENT_USERNAME=(.*)/
        @user = $1
      elsif line =~ /DESKTOP_COMPUTING_AGENT_PASSWORD=(.*)/
        @pass = $1
      end
    end

    file.close

  end

  def check
    raise "Please set the OAR_REST_SERVER, DESKTOP_COMPUTING_AGENT_USERNAME and DESKTOP_COMPUTING_AGENT_PASSWORD properties on /etc/oar/oar.conf" unless (@host && @user && @pass)
  end
end


