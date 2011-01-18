#!/usr/bin/env ruby

$LOAD_PATH.unshift '/usr/lib/oar/desktop_computing'

require 'client'
require 'singleton'
require 'config'

class Agent
  def run
    client = Client.new
    while true do
      client.get_jobs_to_run
      client.get_jobs_to_kill
      sleep 30
    end
  end
end


Configuration.instance.check
agent = Agent.new
agent.run
