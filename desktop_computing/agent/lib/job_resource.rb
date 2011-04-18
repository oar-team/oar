class JobResource

  attr_accessor :id
  def initialize(id)
    @id = id
    @remotehost = Configuration.instance.host
    @user = Configuration.instance.user
    @pass = Configuration.instance.pass
    @resource = RestClient::Resource.new "http://#@user:#@pass@#{@remotehost}/oarapi-priv/jobs/#{id}"
  end
  def get_command
    response = RestClient.get "http://#@user:#@pass@#{@remotehost}/oarapi-priv/jobs/#@id.json"
    job_hash = JSON.parse(response.body)['command']
  end

  def has_stagein
    begin
      resp = RestClient.head "#{@resource.url}/stagein.tgz"
      return resp.code == 200
    rescue
      return false
    end
  end
  def get_stagein
    system "wget -P #@id #{@resource.url}/stagein.tgz 1>/dev/null 2>/dev/null"
  end
  def send_stageout
    @resource['stageout.tgz'].post :myfile => File.new("#@id.tgz", 'rb')
  end
  def run
    @resource['state.json'].post({ 'state' => 'running' }.to_json, :content_type => :json)
  end
  def terminate
    @resource['state.json'].post({'state'=>'terminated'}.to_json, :content_type => :json)
  end
  def error
    @resource['state.json'].post({'state'=>'error'}.to_json, :content_type => :json)
  end
end
