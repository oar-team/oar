#!/usr/bin/env ruby

if system "ps -o pid,state -p #{ARGV[0]} 1>/dev/null 2>/dev/null"
  puts "sim"
else
  puts "nao"
end
