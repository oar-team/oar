require 'rubygems'
require 'sinatra'
require 'json'

enable :logging

get '/' do
	'Woot woot...'
end

get '/hello' do
  content_type 'text/json'
  {:id => 1, :foo => 'bar'}.to_json
end
