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
  
  print(job_infos.nodes_file)
 

  -- read JRMS' node file and build resource id list
  resource_ids = {}
  k = 1
  local f = assert(io.open(job_infos.nodes_file, "r"))
  for line in f:lines() do 
    print(line)
    for i,r_id in ipairs(nodes_resources_ids[line]) do
      resource_ids[k]=r_id
      k = k + 1
    end 
  end

  dumptable(resource_ids)

  -- update oar's DB / save assignement
  --  iolib::set_assigned_moldable_job(
  -- add_resource_job_pair
-- TODO
  oar.set_assigned_moldable_job(job_id,moldable_job_id)
  oar.save_assignements_black_maria(moldable_job_id,resource_ids) 

--TODO
  -- set job's stat to running 
--TODO
  -- notify almighy (schedule cycle ? will update Gantt Diagram ??)

  -- notifiy for external tools ?

  -- gantt visu ??? 

end

oar.conf_load()
oar.connect()
-- retreive resource_ids by node 
nodes_resources_ids = oar.get_nodes_resources_black_maria()
dumptable(nodes_resources_ids)

-- add tcp server
copas.addserver(assert(socket.bind("*",2220)),
                function(c) return handler(copas.wrap(c), c:getpeername()) end
)

-- launch server
copas.loop()
