require 'rack/reverse_proxy'

OAR_API_URL = 'http://192.168.1.10/oarapi'

use Rack::ReverseProxy do
  reverse_proxy_options :preserve_host => true
  reverse_proxy '/oarapi', OAR_API_URL
end

use Rack::Static, 
  :urls => ["/img", "/js", "/css", "font"],
  :root => "public"

run Rack::URLMap.new( {
  "/"    => Rack::Directory.new( "public" ), # Serve our static content
#  "/app" => App.new                          # Sinatra app
} )
