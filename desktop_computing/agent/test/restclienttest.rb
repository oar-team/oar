#!/usr/bin/env ruby

require 'rubygems'
require 'rest_client'

    response = RestClient.get "http://192.168.56.101/oarapi/jobs/4/stagein.tgz"
    File.open("4.tgz", 'w') {|f| f.write(response) }
