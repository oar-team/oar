require "oar"
require "copas"

oar.conf_load()
oar.connect()

if not oar.conf["BKM_SYNC_PORT"] then 
  bkm_sync_port = 2220
else
  bkm_sync_port = oar.conf["BKM_SYNC_PORT"]
end

-- 
-- Transform a compact node list as use in Slurm to list of individual nodes
-- ex: nodes[23,45,50-52] -> {nodes23, node45, node50, node51, node52} 
-- TODO: this funcion must be move to an helper library
-- TODO: support different named nodes
function flatten_nodelist(nodelist_compact)
  x,y,node,desc =  nodelist_compact:find("^(%S+)%[(%S+)%]")
  if not x then -- only one node
    return {nodelist_compact}
  end
  d = oar.tsplit(desc:gsub(","," "))

  local nodelist = {}
  for i,n in ipairs(d) do
    x,y, b,e = n:find("(%d+)-(%d+)")
    if x then
      for i=b,e,1 do
        nodelist[#nodelist+1]=node..i
      end
    else
      nodelist[#nodelist+1]=node..n
    end
  end
  return nodelist
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
  
  print(job_info.node_list)

  -- read RJMS' node file and build resource id list
  -- TODO:  SLURM_JOB_NODELIST= lx[15,18,32-33] -> use flatten_nodelist

  resource_ids = {}
  k = 1

-- convert node_list or node_file allocated and given by foreign RJMS to OAR's resource id list
-- TODO need to uniq the node_file  
  if job_info.node_list=='' then
    local f = assert(io.open(job_info.node_file, "r")) 
    for line in f:lines() do 
      print(line)
      for i,r_id in ipairs(nodes_resources_ids[line]) do
        resource_ids[k]=r_id
        k = k + 1
      end 
    end
  else

    print("BKM-sync: dump flatten_nodellist")
    dumptable(flatten_nodelist(job_info.node_list))

    for i, node in ipairs(flatten_nodelist(job_info.node_list)) do
      print("BKM-sync: allocated node:"..node)
      for i,r_id in ipairs(nodes_resources_ids[node]) do
        resource_ids[k]=r_id
        k = k + 1
      end 
    end
  end

  print("BKM-sync: dump resource_ids")
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
