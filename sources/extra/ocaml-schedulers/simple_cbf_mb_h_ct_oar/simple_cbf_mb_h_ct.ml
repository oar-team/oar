(*                                                                         *)
(*   A of Conservative Backfilling scheduler with some additional features *)
(*                                                                         *)
(* Features: *)
(* - conservative backfilling :-) *)
(* - resource matching*)
(* - insertion of previously scheduled jobs *)
(* - multiple resource requests *) (* NOT TESTED *)
(* - multiple resource types *) (* NOT TESTED *)
(* - job container *) (* NOT TESTED *)
(* - dependencies *) (* NOT TESTED *)
(* - security_time_overhead *) 
(* *)
(* Not supported features: *)
(* - moldable jobs (use only first request set*)
(* - timesharing *)
(* - job array *)
(* - fairesharing *)
(* - suspend/resume, desktop compting feature do we need do address them in main scheduler ??? *)
(* - no errors catching/namming *)
(* - ordering in resources selection *)

(* TODO need   can't scheduled job ->  to error state ??? *)

open Int64
open Interval
open Types
open Hierarchy

type slot = {
	time_s : time_t;
	time_e : time_t;
	set_of_res : set_of_resources;
}

let slot_to_string slot = let itv2str itv = Printf.sprintf "[%d,%d]" itv.b itv.e in 
  (Printf.sprintf "slot: time_s %s, time_e: %s itv:={ " 
    (to_string slot.time_s) (to_string slot.time_e) ) ^
  (String.concat ", " (List.map itv2str slot.set_of_res)) ^ "}\n"

let slot_max nb_res = {time_s = zero; time_e = max_int; set_of_res = [{b = 1; e = nb_res}]}

(*******************************************************)
(* find_first_contiguous_slots_time *)
(* where job can fit in time        *)

(* provides contiguous_slots which fit job_walltime and retrieve slots list *)

let find_contiguous_slots_time slot_l job =
  (*  take into account time_b *)

	let rec find_ctg_slots slots ctg_slots prev_slots = match slots with
		| s::n when (s.time_e >= (add (add job.time_b job.walltime) minus_one)) -> (ctg_slots @ [s], prev_slots , n)
		| s::n when ((add s.time_e one) <> (List.hd n).time_s) -> 
			 job.time_b <- (List.hd n).time_s;
			 find_ctg_slots n [] (prev_slots @ ctg_slots @ [s])
		| s::n -> find_ctg_slots n (ctg_slots @ [s]) prev_slots
 		| _ -> failwith "Not contiguous job is too long (BUG??)";

		in let next_slot_time_s = (List.hd slot_l).time_s in
			if job.time_b < next_slot_time_s then job.time_b <- next_slot_time_s;
	  	find_ctg_slots slot_l [] [];;

(* No exclusive hierarchy assignement *)
let find_resource_hierarchies_job itv_slot job hy_levels =
  let rec requests_iter result hys r_rqts cts = match (hys, r_rqts, cts) with
    | ([],[],[]) -> List.flatten (List.rev result) (* TODO to optimze ??? *)
    | (x::n,y::m,z::o) -> 
      begin 
        let h = List.map (fun k -> try List.assoc k hy_levels with  Not_found -> failwith ("Can't find corresponding hierarchy level, HIERARCHY_LABELS configuration variable must be completed: "^k)) x in
        let itv_cts_slot = inter_intervals itv_slot z in
        let sub_result = find_resource_hierarchies_scattered itv_cts_slot h y in (* TODO: to adapt*)
        match sub_result with
          | [] -> []
          | res -> requests_iter (res::result) n m o
      end
    | (_,_,_) -> failwith "Not possible to be here"
  in requests_iter [] job.hy_level_rqt job.hy_nb_rqt job.constraints;;

let inter_slots slots =
  let rec iter_slots sls itv = match sls with
    | x::n -> let itv1 = inter_intervals itv x.set_of_res in iter_slots n itv1 
    | [] -> itv
  in  iter_slots (List.tl slots) (List.hd slots).set_of_res;; 

(* find_first_suitable_contiguous_slots for job *) 

let find_first_suitable_contiguous_slots slots j hy_levels =

	let rec find_suitable_contiguous_slots slot_l pre_slots job =
 
	   	let (next_ctg_time_slot, prev_slots, remain_slots) = find_contiguous_slots_time slot_l job in
      let itv_inter_slots = inter_slots next_ctg_time_slot in
      let itv_res_assignement = find_resource_hierarchies_job itv_inter_slots job hy_levels in

      match  itv_res_assignement with

        | [] -> find_suitable_contiguous_slots (List.tl next_ctg_time_slot @ remain_slots) 
                                               (pre_slots @ prev_slots @ [List.hd next_ctg_time_slot]) job
        | itv -> (itv, next_ctg_time_slot, (pre_slots @ prev_slots), remain_slots)
		in
			find_suitable_contiguous_slots slots [] j ;;


(*******************************************************)
(* split slot accordingly with job resource assignment *)
(* new slot A + B + C (A, B and C can be null)         *)

(*
 ------
|A|B|C|
|A|J|C|
|A|B|C|
 ------
*)

(* TODO ??? *)

(* generate A slot *) (* slot before job's begin *)
let slot_before_job_begin slot job = {
	time_s = slot.time_s;
	time_e = add job.time_b minus_one;
	(* nb_free_res = slot.nb_free_res; TOREMOVE*)
	set_of_res = slot.set_of_res;
};;

(* generate B slot *) 
let slot_during_job slot job = {
		time_s = max job.time_b slot.time_s;
		time_e = min (add (add job.time_b  job.walltime) minus_one) slot.time_e ;
		set_of_res = sub_intervals slot.set_of_res job.set_of_rs;
	}
;;

(* generate C slot *) (* slot after job's end *)

let slot_after_job_end slot job = {
	time_s = add job.time_b job.walltime ;
	time_e = slot.time_e  ;

	set_of_res = slot.set_of_res;
};;


let split_slots slots job = 
	let split_slot slt = 
		if job.time_b > slt.time_s then (* AAA *)
			if  (add (add job.time_b job.walltime) minus_one) > slt.time_e then
(*
					if slt.nb_free_res > job.nb_res then
  TOREMOVE
*)
					 (* A+B *)
						(slot_before_job_begin slt job) :: [(slot_during_job slt job)]
(*
 TOREMOVE
					else
					 (* A *)
						[slot_before_job_begin slt job]
*)
			else
(* TOREMOVE					if slt.nb_free_res > job.nb_res then *)

				 		(* A+B+C *)
						(slot_before_job_begin slt job) :: (slot_during_job slt job) :: [(slot_after_job_end slt job)]

(* TOREMOVE
					else
						(slot_before_job_begin slt job) :: [(slot_after_job_end slt job)]
*)
		else
			if (add (add job.time_b  job.walltime) minus_one) >= slt.time_e then
(* TOREMOVE
				if slt.nb_free_res > job.nb_res then
*)
				 (* B *)
					[slot_during_job slt job]
(* TOREMOVE
				else
					[]
*)
			else
(*	TOREMOVE
				if slt.nb_free_res > job.nb_res then
*)
				 	(* B+C *) 
					( slot_during_job slt job) :: [(slot_after_job_end slt job )]
(*	TOREMOVE
				else
					[slot_after_job_end slt job]
*)
	in List.flatten (List.map (fun slot -> split_slot slot ) slots) ;;


let resources_assign_job nb_res itv_l = 
	let rec res_assign_job r itv_l res_itv_l = match itv_l with
	| x::n -> if (x.e-x.b+1) >= r then 
		 	List.rev ({b = x.b; e = x.b + r-1}::res_itv_l)
		else
			res_assign_job (r -x.e + x.b - 1) n (x::res_itv_l)
	| _ -> failwith "Not enougth resources (BUG!)"
	in
		res_assign_job nb_res itv_l [];;

let assign_resources_job_split_slots job slots hy_levels = 
	let (resource_assigned, ctg_slots, prev_slots, remain_slots) = find_first_suitable_contiguous_slots slots job hy_levels in
	  job.set_of_rs <- resource_assigned;
		(job, prev_slots @ (split_slots ctg_slots job) @ remain_slots);;

(* previous schedule function, it's not use for ct support *)
let schedule_jobs jobs slots hy_levels = 
	let rec assign_res_jobs jobs scheduled_jobs slot_list = match jobs with
		| [] -> List.rev scheduled_jobs
		| j::n -> let (job, updated_slots ) = assign_resources_job_split_slots j slot_list hy_levels in assign_res_jobs n  (job::scheduled_jobs) updated_slots
	in assign_res_jobs jobs [] slots;;

(* TODO: rm, no more used ??? *)
(* is it use ? *)
let schedule_id_jobs jids h_jobs slots hy_levels = 
	let rec assign_res_jobs j_ids scheduled_jobs slot_list = match j_ids with
		| [] -> List.rev scheduled_jobs
		| j_id::n -> let j = try Hashtbl.find h_jobs j_id with  Not_found -> failwith "Can't Hashtbl.find job" in 
                (* Printf.printf "Job:\n%s\n" (job_to_string j); *)
                 let (job, updated_slots ) = assign_resources_job_split_slots j slot_list hy_levels in assign_res_jobs n  (job::scheduled_jobs) updated_slots
	in assign_res_jobs jids [] slots;;


(*                                                                                                  *)
(* Schedule loop with support for jobs container - can be recursive (recursivity has not be tested) *)
(*                                                                                                  *)
(* let schedule_id_jobs_ct jids h_jobs h_slots = *)
(* TODO: rm, no more used ? *)
 let schedule_id_jobs_ct h_slots h_jobs hy_levels jids security_time_overhead =

  let find_slots s_id =  try Hashtbl.find h_slots s_id with Not_found -> failwith "Can't Hashtbl.find slots (schedule_id_jobs_ct)" in
  let find_job j_id = try Hashtbl.find h_jobs j_id with Not_found -> failwith "Can't Hashtbl.find job (schedule_id_jobs_ct)" in 
  let test_type job job_type = try (true, (List.assoc job_type job.types)) with Not_found -> (false,"") in

  let rec assign_res_jobs j_ids scheduled_jobs = match j_ids with
		| [] -> List.rev scheduled_jobs
		| jid::n -> let j = find_job jid in
                let (test_inner, value_in) = test_type j "inner" in
                  let num_set_slots = if test_inner then (int_of_string value_in) else 0 in
(*                let num_set_slots = if test_inner then (try int_of_string value with _ -> 0) else 0 in *)(* job_error *)
                  begin
                    let (test_container, value) = test_type j "container" in
                      let (job, updated_slots ) = assign_resources_job_split_slots j (find_slots num_set_slots) hy_levels in 
                        Hashtbl.replace h_slots num_set_slots updated_slots;
                      if test_container then
                        (* create new slot / container *) (* substract j.walltime security_time_overhead *)
                        Hashtbl.add h_slots jid [{
                              time_s = job.time_b; 
                              time_e =  add job.time_b (sub job.walltime security_time_overhead) ; 
                              set_of_res = job.set_of_rs}]; 
                      assign_res_jobs n  (job::scheduled_jobs)
                  end 
  in
    assign_res_jobs jids []

(*                                                                                                  *)
(* Schedule loop with support for jobs container - can be recursive (recursivity has not be tested) *)
(* plus dependencies support                                                                        *)
(* * actual schedule function used *                                                                *)

 let schedule_id_jobs_ct_dep h_slots h_jobs hy_levels h_jobs_dependencies h_req_jobs_status jids security_time_overhead =

  let find_slots s_id =  try Hashtbl.find h_slots s_id with Not_found -> failwith "Can't Hashtbl.find slots (schedule_id_jobs_ct)" in
  let find_job j_id = try Hashtbl.find h_jobs j_id with Not_found -> failwith "Can't Hashtbl.find job (schedule_id_jobs_ct)" in 
  let test_type job job_type = try (true, (List.assoc job_type job.types)) with Not_found -> (false,"") in

  (* dependencies evaluation *)
  let test_no_dep jid =  try (false, (Hashtbl.find h_jobs_dependencies jid)) with Not_found -> (true,[]) in

(*
  let test_job_scheduled = try (Hashtbl.find h_jobs j)  with Not_found -> failwith "Can't Hashtbl.find h_jobs (test_job_scheduled )" in
*)
    
  let dependencies_evaluation j_id job_init =
    (* are there denpendencies*)
    let (tst_no_dep, deps) = test_no_dep j_id in
    if tst_no_dep then
      (false, job_init) (* don't skip, no dep *)
    else
      let rec jobs_required_iter dependencies = match dependencies with
        | [] -> (false, job_init)
        | jr_id::n -> let jrs =  try (Hashtbl.find h_req_jobs_status jr_id) with Not_found -> failwith "Can't Hashtbl.find jr in h_req_jobs_status" in
                      if (jrs.jr_state != "Terminated") then
                        let jsched = find_job jr_id in
                          (* test is job scheduled*)
                          if (jsched.set_of_rs != []) then
                            begin
                              if (add jsched.time_b jsched.walltime) > job_init.time_b then job_init.time_b <- (add jsched.time_b jsched.walltime);
                              jobs_required_iter n
                            end
                          else
                            (* job message: "Cannot determine scheduling time due to dependency with the job $d"; *)
                            (* oar_debug("[oar_sched_gantt_with_timesharing] [$j->{job_id}] $message\n"); *)
                            (true, job_init) (* skip *)
                      else (* job is Terminated *)
                        if (jrs.jr_jtype = "PASSIVE") && (jrs.jr_exit_code != 0) then
                          (* my $message = "Cannot determine scheduling time due to dependency with the job $d (exit code != 0)";
                             OAR::IO::set_job_message($base,$j->{job_id},$message);
                             OAR::IO::set_job_scheduler_info($base,$j->{job_id},$message);
                             oar_debug("[oar_sched_gantt_with_timesharing] [$j->{job_id}] $message\n");
                          *)
                          (true, job_init) (* skip *)
                        else
                          jobs_required_iter n
      in
        jobs_required_iter deps
 
  in
  (* assign ressource for all waiting jobs *)
  let rec assign_res_jobs j_ids scheduled_jobs nosched_jids = match j_ids with
		| [] -> (List.rev scheduled_jobs, List.rev nosched_jids)
		| jid::n -> let j_init = find_job jid in
                let (test_skip, j) = dependencies_evaluation jid j_init in
                let (test_inner, value_in) = test_type j "inner" in
                  let num_set_slots = if test_inner then (int_of_string value_in) else 0 in
(*                let num_set_slots = if test_inner then (try int_of_string value with _ -> 0) else 0 in *)(* job_error *)
                  begin
                    let (test_container, value) = test_type j "container" in
                      let current_slots = find_slots num_set_slots in
                      let (ok, ns_jids, (job, updated_slots) ) = try (true, nosched_jids, assign_resources_job_split_slots j current_slots hy_levels) 
                                                        with _ -> (false, (jid::nosched_jids), (j_init, current_slots)) 

                      in
                        if ok then
                          begin 
                            Hashtbl.replace h_slots num_set_slots updated_slots;
                            if test_container then
                              (* create new slot / container *) (* substract j.walltime security_time_overhead *)
                              Hashtbl.add h_slots jid [{
                                time_s = job.time_b; 
                                time_e = add job.time_b (sub job.walltime security_time_overhead); 
                                set_of_res=job.set_of_rs}];
                              (* replace updated/assgined job in job hashtable *) 
                              Hashtbl.replace h_jobs jid job; 

                            assign_res_jobs n  (job::scheduled_jobs) ns_jids
                          end
                       else 
                        assign_res_jobs n scheduled_jobs ns_jids
                  end 
  in
    assign_res_jobs jids [] []

(* function insert previously occupied slots in slots *)
(* job must be sorted by start_time *)

let split_slots_prev_scheduled_jobs slots jobs =

  let rec find_first_slot left_slots right_slots job = match right_slots with
    | x::n  when ((x.time_s > job.time_b) || ((x.time_s <= job.time_b) && (job.time_b <= x.time_e))) -> (left_slots,x,n) 
    | x::n -> find_first_slot (left_slots @ [x]) n job 
    | [] -> failwith "Argl cannot failed here"

  in

  let rec find_slots_aux encompass_slots r_slots job = match r_slots with
    (* find timed slots *)
    | x::n when (x.time_e >  (add job.time_b job.walltime)) -> (encompass_slots @ [x],n) 
    | x::n -> find_slots_aux (encompass_slots @ [x]) n job
    | [] -> failwith "Argl cannot failed here"
   in

  let find_slots_encompass first_slot right_slots job =
    if (first_slot.time_e >  (add job.time_b job.walltime)) then
      ([first_slot],right_slots)
    else find_slots_aux [first_slot] right_slots job

    in

      let rec split_slots_next_job prev_slots remain_slots job_l = match job_l with
        | [] -> prev_slots @ remain_slots
        | x::n -> let (l_slots, first_slot, r_slots) = find_first_slot prev_slots remain_slots x in
                  let (encompass_slots, ri_slots) =  find_slots_encompass first_slot r_slots x in
                  let splitted_slots =  split_slots encompass_slots x in 
                    split_slots_next_job l_slots (splitted_slots @ ri_slots) n 
     in 
        split_slots_next_job [] slots jobs


(* function insert previously one scheduled job in slots *)
(* job must be sorted by start_time *)

let split_slots_prev_scheduled_one_job slots job =

  let rec find_first_slot left_slots right_slots job = match right_slots with
    | x::n  when ((x.time_s > job.time_b) || ((x.time_s <= job.time_b) && (job.time_b <= x.time_e))) -> (left_slots,x,n) 
    | x::n -> find_first_slot (left_slots @ [x]) n job 
    | [] -> failwith "Argl cannot failed here"

  in

  let rec find_slots_aux encompass_slots r_slots job = match r_slots with
    (* find timed slots *)
    | x::n when (x.time_e >  (add job.time_b job.walltime)) -> (encompass_slots @ [x],n) 
    | x::n -> find_slots_aux (encompass_slots @ [x]) n job
    | [] -> failwith "Argl cannot failed here"
   in

  let find_slots_encompass first_slot right_slots job =
    if (first_slot.time_e >  (add job.time_b job.walltime)) then
      ([first_slot],right_slots)
    else find_slots_aux [first_slot] right_slots job

    in

      let (l_slots, first_slot, r_slots) = find_first_slot [] slots job in
        let (encompass_slots, ri_slots) =  find_slots_encompass first_slot r_slots job in
          let splitted_slots =  split_slots encompass_slots job in 
            splitted_slots @ ri_slots 

(* function insert previously scheduled job in slots with containers consideration *)
(* job must be sorted by start_time *)

(* loop across ordered jobs' id by start_time and create new set_slots or split slots when needed *) 

let set_slots_with_prev_scheduled_jobs h_slots h_jobs ordered_id_jobs security_time_overhead =
  let find_slots s_id =  try Hashtbl.find h_slots s_id with Not_found -> failwith "Can't Hashtbl.find slots (set_slots_with_prev_scheduled_jobs)" in 
  let find_job j_id = try Hashtbl.find h_jobs j_id with Not_found -> failwith "Can't Hashtbl.find job (set_slots_with_prev_scheduled_jobs)" in 
  let test_type job job_type = try (true, (List.assoc job_type job.types)) with Not_found -> (false,"0") in
  let rec loop_jobs od_id_jobs = match od_id_jobs with
    | [] -> () (* terminated *)
    | jid::m -> let j = find_job jid in
                let (test_inner, value_in) = test_type j "inner" in
                let num_set_slots = if test_inner then (int_of_string value_in) else 0 in
                begin
                  let (test_container, value) = test_type j "container" in
                  if test_container then
                    (* create new slot / container *) (* substract j.walltime security_time_overhead *)
                    Hashtbl.add h_slots jid [{
                      time_s = j.time_b; 
                      time_e = add j.time_b (sub j.walltime security_time_overhead); 
                      set_of_res = j.set_of_rs}];
                  (* TODO perhaps we'll need to optimize split_slots_prev_scheduled_jobs...made for jobs list *) 
                  Hashtbl.replace h_slots num_set_slots (split_slots_prev_scheduled_one_job (find_slots num_set_slots) j); 
                  loop_jobs m
                end  
  in
    loop_jobs ordered_id_jobs 
