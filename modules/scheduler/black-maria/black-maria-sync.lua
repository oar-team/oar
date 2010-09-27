require "oar"
require "pp"
require "copas"

function handler(c, host, port)
  local peer = host .. ":" .. port
  print("BKM-sync: connection from", peer)
 -- c:send("Hello\r\n")

  -- get data 
  data = (c:receive"*l")
  print("data from", peer, data)
  assert(loadstring("job_infos =" .. data))()

  dumptable(job_infos)
  
  print(job_infos.yop)
 
  -- read JRMS' node file

  -- update oar's DB
  -- save assignement
  -- set job's stat to running 
--  oar

  

  -- notify almighy

end

-- retreive resource_ids by node 
nodes_resources_ids = oar.get_nodes_resources_black_maria

-- add tcp server
copas.addserver(assert(socket.bind("*",2220)),
                function(c) return handler(copas.wrap(c), c:getpeername()) end
)

-- launch server
copas.loop()
