open Iolib;;
let r = Iolib.connect ();;
let (res,  =  get_resource_list_w_hierarchy r ["core";"cpu";"network_address"] "scheduler_priority ASC, state_num ASC, available_upto DESC, suspended_jobs ASC, network_address DESC, resource_id ASC";;
