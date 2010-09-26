require "oar"
require "copas"

function handler(c, host, port)
  local peer = host .. ":" .. port
  print("BKM-sync: connection from", peer)
  c:send("Hello\r\n")

  -- get data
  print("data from", peer, (c:receive"*l"))

  -- read JRMS' node file

  -- update oar's DB

  -- notify almighy

end

-- retreive resource_ids by node 
nodes_resource_ids = oar.get_nodes_resources_black_maria

-- add tcp server
copas.addserver(assert(socket.bind("*",2220)),
                function(c) return handler(copas.wrap(c), c:getpeername()) end
)

-- launch server
copas.loop()
