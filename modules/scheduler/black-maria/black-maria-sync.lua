require "oar"
require "copas"

oar.conf_load()
oar.connect()

if not oar.conf["BKM_SYNC_PORT"] then 
  bkm_sync_port = 2220
else
  bkm_sync_port = oar.conf["BKM_SYNC_PORT"]
end

function notify_almighty()
  local client = socket.connect(oar.conf["SERVER_HOSTNAME"],oar.conf["SERVER_PORT"])
  client:send("Scheduling\n")
  client:close()
end

function handler(c, host, port)
  local peer = host .. ":" .. port
  print("BKM-sync: connection from", peer)
 -- c:send("Hello\r\n")

  -- get data 
  local data = (c:receive"*l")
  print("data from", peer, data)
  assert(loadstring("job_info =" .. data))()

  dumptable(job_info)
  
  print(job_info.nodes_file)
 

  -- read JRMS' node file and build resource id list
  resource_ids = {}
  k = 1
  local f = assert(io.open(job_info.nodes_file, "r"))
  for line in f:lines() do 
    print(line)
    for i,r_id in ipairs(nodes_resources_ids[line]) do
      resource_ids[k]=r_id
      k = k + 1
    end 
  end

  dumptable(resource_ids)

  oar.save_assignements_black_maria(job_info.moldable_j_id,resource_ids) 
  
  -- update job's state to Running and set assigned_moldable_job field
  oar.sql("UPDATE jobs SET state = ".."'Running'"..
          ",assigned_moldable_job = ".. job_info.moldable_j_id..
          " WHERE job_id = ".. job_info.j_id)
  -- notify almighy (schedule cycle ? will update Gantt Diagram ??)
  notify_almighty()
  -- notifiy for external tools ?
end

--
-- main
--

-- retreive resource_ids by node 
nodes_resources_ids = oar.get_nodes_resources_black_maria()
dumptable(nodes_resources_ids)

-- add tcp server
copas.addserver(assert(socket.bind("*",bkm_sync_port)),
                function(c) return handler(copas.wrap(c), c:getpeername()) end
)

-- launch server
copas.loop()
