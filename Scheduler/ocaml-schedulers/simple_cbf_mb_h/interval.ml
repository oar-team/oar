
(* todo *)
(* suppress the result list in inter_interval list argument !!! *) 
(* need to propage in all directory !!! *)

(*  interval  type and some operations on them         *)

(* interval is the basic unit to construct set of resources *)
type interval = {b : int; e : int}

type set_of_resources = interval list


(* generate list of intervals for list of unordered ints with greedy approach *)
(* must be quicker with a dichotomic approach in most cases *)
let ints2intervals ints =
   
	let ordered_ints = List.sort Pervasives.compare ints in 
		let rec aux list_int itv_b prev itvs = match list_int with
      | [] ->  [{b=itv_b; e=itv_b}]
			| x::[] ->  if x > (prev+1) then
										List.rev ({b=x; e=x}::{b=itv_b; e=prev}::itvs)
									else
										List.rev ({b=itv_b; e=x}::itvs)
			| x::n -> if x > (prev+1) then
								  aux n x x ({b=itv_b; e=prev}::itvs)
					 			else
									aux n itv_b x itvs
			in
		aux (List.tl ordered_ints) (List.hd ordered_ints) (List.hd ordered_ints) [];;
(*
# ints2intervals [];;  WARNING TO MODIFY ????
Exception: Failure "hd".
#  ints2intervals [2];;
- : interval list = [{b = 2; e = 2}]
# ints2intervals [2;4;1;3];;
- : interval list = [{b = 1; e = 4}]
# ints2intervals [2;4;1;];;
- : interval list = [{b = 1; e = 2}; {b = 4; e = 4}]
#  ints2intervals [2;4];;
- : interval list = [{b = 2; e = 2}; {b = 4; e = 4}]
# ints2intervals [4;5;7;1;2;3;6;9;8];;
- : interval list = [{b = 1; e = 9}]
*)

(* generate list of ints from list of intervals *)

let intervals2ints itv_l =
  let rec aux itvs ints = match itvs with
    | [] -> ints
    | x::n -> let r = ref [] in 
                for i = x.b to x.e do r := i::!r done;
                aux n (ints @ !r)
  in                
  aux itv_l [];;
(*
# intervals2ints  [{b = 1; e = 4}];;
- : int list = [4; 3; 2; 1]
# intervals2ints [{b = 2; e = 2}; {b = 4; e = 4}]
  ;;
- : int list = [2; 4]
# intervals2ints [{b = 1; e = 2}; {b = 4; e = 4}]
  ;;
- : int list = [2; 1; 4]
*)

(* compute intersection of 2 resource intervals *)
let rec inter_intervals itv_l_1 itv_l_2 itv_l_inter = 
	match (itv_l_1,itv_l_2) with
	| (x::n,y::m) ->
			if (y.e < x.b) then inter_intervals (x::n) m itv_l_inter else (* y before x w/ no overlap *)
			if (y.b > x.e) then inter_intervals n (y::m) itv_l_inter else (* x before y w/ no overlap *)
			if (y.b >= x.b) then 
				if (y.e <=  x.e) then  (* y before y w/ no overlap *)
					inter_intervals ({b=y.e+1;e=x.e}::n) m ({b=y.b;e=y.e}::itv_l_inter)
				else 
					inter_intervals n ({b=x.e+1;e=y.e}::m) ({b=y.b;e=x.e}::itv_l_inter)
			else
				if (y.e <=  x.e) then
					inter_intervals ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.e}::itv_l_inter)
				else
					inter_intervals n ({b=x.e+1;e=y.e}::m) ({b=x.b;e=x.e}::itv_l_inter)
	| (_,_) -> List.rev itv_l_inter;;


(* compute intersection of 2 intervals resources*)
(* with resources counter nb_res *)
let rec inter_intervals itv_l_1 itv_l_2 itv_l_inter nb_res = 
	match (itv_l_1,itv_l_2) with
	| (x::n,y::m) ->
			if (y.e < x.b) then inter_intervals (x::n) m itv_l_inter nb_res else (* y before x w/ no overlap *)
			if (y.b > x.e) then inter_intervals n (y::m) itv_l_inter nb_res else (* x before y w/ no overlap *)
			if (y.b >= x.b) then
				if (y.e <=  x.e) then  (* y before y w/ no overlap *)
					inter_intervals ({b=y.e+1;e=x.e}::n) m ({b=y.b;e=y.e}::itv_l_inter) (nb_res + y.e - y.b + 1)
				else 
					inter_intervals n ({b=x.e+1;e=y.e}::m) ({b=y.b;e=x.e}::itv_l_inter) (nb_res + x.e - y.b + 1)
			else
				if (y.e <=  x.e) then
					inter_intervals ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.e}::itv_l_inter) (nb_res + y.e - x.b + 1)
				else
					inter_intervals n ({b=x.e+1;e=y.e}::m) ({b=x.b;e=x.e}::itv_l_inter) (nb_res + x.e - x.b + 1)
	| (_,_) -> (List.rev itv_l_inter,nb_res);;

(*
let x1 = {b = 11; e = 20};; 
let y1 =  {b = 1; e = 5};; 
let y2 =  {b = 26; e = 30};;

let y3 =  {b = 12; e = 15};; 
let y4 =  {b = 12; e = 25};; 
let y5 =  {b = 5; e = 15};; 
let y6 =  {b = 5; e = 25};; 

let yl1 = [{b = 5; e = 13};{b = 15; e = 16 };{b = 19; e = 19}];;


inter_intervals [x1] [y1] [];; (* [] *)
inter_intervals [x1] [y2] [];; (* [] *)
inter_intervals [x1] [y3] [];; (* [{b = 12; e = 15}] *)
inter_intervals [x1] [y4] [];; (* [{b = 12; e = 20}] *)
inter_intervals [x1] [y5] [];; (* [{b = 11; e = 15}] *)
inter_intervals [x1] [y6] [];; (* [{b = 11; e = 20}] *)
inter_intervals [x1] [y7] [];; (* [{b = 11; e = 20}] *)

inter_intervals_0 [x1] yl1 [];;(* *)

inter_intervals [x1] [y1] [] 0;; (* [] *)
inter_intervals [x1] [y2] [] 0;; (* [] *)
inter_intervals [x1] [y3] [] 0;; (* [{b = 12; e = 15}] *)
inter_intervals [x1] [y4] [] 0;; (* [{b = 12; e = 20}] *)
inter_intervals [x1] [y5] [] 0;; (* [{b = 11; e = 15}] *)
inter_intervals [x1] [y6] [] 0;; (* [{b = 11; e = 20}] *)
inter_intervals [x1] [y7] [] 0;; (* [{b = 11; e = 20}] *)

inter_intervals [x1] yl1 [] 0;;(* ([{b = 11; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}], 6) *)
*)

(* some converter to string *)
let itv2str itv = Printf.sprintf "{%d,%d}" itv.b itv.e ;; 
let itvs2str itvs = "["^(String.concat ", " (List.map itv2str itvs))^"]" ;;
let itva2str itva = "[|"^(String.concat ", " (List.map itv2str (Array.to_list itva)))^"|]" ;;


(* compute substraction of 2 resource intervals *)
let sub_intervals x_l y_l = 
	let rec sub_interval_l itv_l_1 itv_l_2 sub_itv_l = 
		match (itv_l_1,itv_l_2) with
		| (x::n,y::m) ->
				if (y.e < x.b) then sub_interval_l (x::n) m sub_itv_l else (* y before x w/ no overlap *)
				if (y.b > x.e) then sub_interval_l n (y::m) (sub_itv_l @ [x]) else (* x before y w/ no overlap *)
				if (y.b > x.b) then 
					if (y.e <  x.e) then  (* y before y w/ no overlap *)
						sub_interval_l ({b=y.e+1;e=x.e}::n) m ({b=x.b;e=y.b-1}::sub_itv_l)
					else 
						sub_interval_l n (y::m) ({b=x.b;e=y.b-1}::sub_itv_l)
				else
					if (y.e <  x.e) then
						sub_interval_l ({b=y.e+1;e=x.e}::n) m sub_itv_l
					else
						sub_interval_l n (y::m) sub_itv_l
		| (x_l,[]) ->  (List.rev sub_itv_l) @ x_l
		| (_,_) -> List.rev sub_itv_l

	in  sub_interval_l x_l y_l [];;
(*
sub_intervals [x1] [y1] ;; [x1]
sub_intervals [x1] [y2] ;; [x1]
sub_intervals [x1] [y3] ;; [{b = 11; e = 11}; {b = 16; e = 20}]
sub_intervals [x1] [y4] ;; [{b = 11; e = 11}]
sub_intervals [x1] [y5] ;; [{b = 16; e = 20}]
sub_intervals [x1] [y6] ;; []
sub_intervals [x1] [x1] ;; []
sub_intervals [x1] [];; [x1]
sub_intervals [x1] yl1 ;;  [{b = 14; e = 14}; {b = 17; e = 18}; {b = 20; e = 20}]
sub_intervals [y5] [x1];;  [{b = 5; e = 10}]
*)

(* return [] *)
(* itv_l_a itv_l_reference  MUST BE ORDERED by ascending resource id *)

(* Is it use ?*)

let extract_n_block_itv itv_l_a itv_l_reference n =
  let itv_l_seg = (fst (inter_intervals itv_l_a itv_l_reference [] 0)) in
  let rec extract_n_itv itv_l_1 itv_l_ref itv_l_result nb_itv = match (itv_l_1,itv_l_ref) with
    | ([],_) | (_,[]) -> [] 
    | (x::n,y::m) -> if x=y then
                       if nb_itv=1 then
                         List.rev (x::itv_l_result) 
                       else
                         extract_n_itv n m (x::itv_l_result) (nb_itv -1)  
                     else
                       if y.e < x.b then
                         extract_n_itv (x::n) m itv_l_result nb_itv
                       else 
                         if x.e < y.e then 
                           extract_n_itv n (y::m) itv_l_result nb_itv
                         else
                           extract_n_itv n m itv_l_result nb_itv
  in extract_n_itv itv_l_seg itv_l_reference [] n;;

(*
let y = [{b = 5; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}]
#  extract_n_block_itv y y 1 ;;
- : interval list = [{b = 5; e = 13}]
#  extract_n_block_itv y y 2 ;;
- : interval list = [{b = 5; e = 13}; {b = 15; e = 16}]
#  extract_n_block_itv y y 3 ;;
- : interval list = [{b = 5; e = 13}; {b = 15; e = 16}; {b = 19; e = 19}]
#  extract_n_block_itv [{b = 15; e = 16}; {b = 19; e = 19}] y 3 ;;
- : interval list = []
#  extract_n_block_itv [{b = 15; e = 16}; {b = 19; e = 19}] y 2 ;;
- : interval list = [{b = 15; e = 16}; {b = 19; e = 19}]
#  extract_n_block_itv [{b = 15; e = 16}; {b = 19; e = 19}] y 2 ;;
- : interval list = [{b = 15; e = 16}; {b = 19; e = 19}]

*)


(* Is it use ?*)

let extract_block_itv itv_l_a itv_l_reference =
  let itv_l_seg = (fst (inter_intervals itv_l_a itv_l_reference [] 0)) in
  let rec extract_itv itv_l_1 itv_l_ref itv_l_result = match (itv_l_1,itv_l_ref) with
    | (x::n,y::m) -> if x=y then
                       extract_itv n m (x::itv_l_result)
                     else
                       if y.e < x.b then
                         extract_itv (x::n) m itv_l_result
                       else 
                         if x.e < y.e then 
                           extract_itv n (y::m) itv_l_result
                         else
                           extract_itv n m itv_l_result
    |(_,_) -> List.rev itv_l_result
  in extract_itv itv_l_seg itv_l_reference [];;

(* Is it use ?*)
let extract_n_min_block_itv itv_l_a itv_l_reference n =
  let itv_l_seg = (fst (inter_intervals itv_l_a itv_l_reference [] 0)) in
  let rec extract_n_min_itv itv_l_1 itv_l_ref itv_l_result nb_itv = match (itv_l_1,itv_l_ref) with
    | (x::n,y::m) -> if x=y then
                       extract_n_min_itv n m (x::itv_l_result) (nb_itv -1)  
                     else
                       if y.e < x.b then
                         extract_n_min_itv (x::n) m itv_l_result nb_itv
                       else 
                         if x.e < y.e then 
                           extract_n_min_itv n (y::m) itv_l_result nb_itv
                         else
                           extract_n_min_itv n m itv_l_result nb_itv
    | (_,_) -> if (nb_itv < 1) then List.rev itv_l_result else []
  in extract_n_min_itv itv_l_seg itv_l_reference [] n;;

(* extract_no_empty_bk : keep reference intervals where intersection with  itv_l *)
let extract_no_empty_bk itv_l_a itv_l_reference =
 let rec extract_itv itv_l_ref result  = match itv_l_ref with
  | [] -> List.rev result
  | (x::n) -> let inter_itvs = (fst (inter_intervals itv_l_a [x] [] 0)) in 
              match inter_itvs with 
                | [] -> extract_itv n result 
                | y -> extract_itv n (x::result)
  in extract_itv itv_l_reference [];;
(*
let a = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b2 = [{b = 1; e = 8}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b3 = [{b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b4 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}];;
let b5 = [{b = 10; e = 12}; {b = 13; e = 14};];;
let b6 = [{b = 3; e = 4}; {b = 19; e = 20};];;

*)



(* extract interval list intersect for each reference intervals, also give the nb of non empty intersection*)

let extract_itv_by_itv_nb_inter itv_l_a itv_l_reference =
  let rec extract_itv itv_l_ref result nb_inter = match itv_l_ref with
    | [] -> (List.rev result,nb_inter)
    | (x::n) -> let inter_itvs =  (fst (inter_intervals itv_l_a [x] [] 0)) in 
                match inter_itvs with 
                  | [] -> extract_itv n result nb_inter 
                  | y -> extract_itv n (y::result) (nb_inter + 1) 
  in extract_itv itv_l_reference [] 0;;

(*
let a = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b1 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b2 = [{b = 1; e = 8}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b3 = [{b = 9; e = 16}; {b = 17; e = 24}; {b = 25; e = 32}];;
let b4 = [{b = 1; e = 8}; {b = 9; e = 16}; {b = 17; e = 24}];;
let b5 = [{b = 10; e = 12}; {b = 13; e = 14};];;

# extract_itv_by_itv_nb_inter b1 a;;
- : interval list list * int =
([[{b = 1; e = 8}]; [{b = 9; e = 16}]; [{b = 17; e = 24}];
  [{b = 25; e = 32}]],
 4)
# extract_itv_by_itv_nb_inter b2 a;;
- : interval list list * int =
([[{b = 1; e = 8}]; [{b = 17; e = 24}]; [{b = 25; e = 32}]], 3)
# extract_itv_by_itv_nb_inter b3 a;;
- : interval list list * int =
([[{b = 9; e = 16}]; [{b = 17; e = 24}]; [{b = 25; e = 32}]], 3)
# extract_itv_by_itv_nb_inter b4 a;;
- : interval list list * int =
([[{b = 1; e = 8}]; [{b = 9; e = 16}]; [{b = 17; e = 24}]], 3)

# extract_itv_by_itv_nb_inter b5 a;;
- : interval list list * int = ([[{b = 10; e = 12}; {b = 13; e = 14}]], 1)
*)


