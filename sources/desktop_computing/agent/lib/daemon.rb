#!/usr/bin/env ruby

require 'daemons'

Daemons.run('/usr/bin/oar-agent')
