#!/usr/bin/ruby
require 'rss/1.0'
require 'rss/2.0'
require 'open-uri'
require 'yaml'

source = "http://wiki-oar.imag.fr/news/?feed=rss2" # url or local file
content = "" # raw content of rss feed will be loaded here
open(source) do |s| content = s.read end
rss = RSS::Parser.parse(content, false)

news = {}
rss.items.each do |item| 
   news[item.date.to_s] = "h3. \"#{item.title}\":#{item.link}"
end

File.open( 'news.yaml', 'w' ) do |out|
  YAML.dump( news, out )
end


