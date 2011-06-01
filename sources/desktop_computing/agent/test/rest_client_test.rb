#!/usr/bin/ruby

require 'rubygems'
require 'rest_client'

result = RestClient.get 'http://192.168.56.101/oarapi/resources/nodes/192.168.56.1/jobs.json'
puts result
