#!/usr/bin/env ruby

puts Process.fork { exec "pwd && sleep 60" }
