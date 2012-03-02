(*                                   *)
(* Main author: Lionel Eyraud-Dubois *)
(*                                   *)

(* function manipulations *)

let id x = x

let foldi n f start = 
  let rec aux i state = 
    if i < n then aux (i+1) (f i state) 
    else state in 
    aux 0 start

let (@@) f g = function x -> f (g x)

let rev f x y = f y x

let bicompose f g h x y = f (g x) (h y)
let cmp critere x y = Pervasives.compare (critere x) (critere y)			   

let curry f x y = f (x, y)
let uncurry f (x, y) = f x y

let agrege f transforme start = List.fold_left (bicompose f id transforme) start
let somme transforme = agrege (+) transforme 0
let sommefloat transforme = agrege (+.) transforme 0.

let concatene transforme = agrege (^) transforme ""
let concatene_sep sep transforme = 
  let rec aux buf = function 
      [] -> buf
    | [x] -> buf ^ (transforme x)
    | x::xs -> aux (buf ^ (transforme x) ^ sep) xs in 
    aux ""

(** [arrange p arr l] : examine dans l'ordre les éléments de [l],
  arrange les deux premiers entre eux par la fonction [arr], enlève le
  resultat s'il vérifie le prédicat [p]. Renvoie la liste des éléments
  arrangés. *)
let arrange p arr l = 
  let rec aux buffer = function
      [] -> buffer
    | [a] -> a::buffer
    | a::b::next -> let c = arr a b in 
	if p c then aux (c::buffer) next 
	else aux buffer (c::next) in 
    aux [] l 

let cut_string sep s = 
  let l = String.length s in
  let rec drop_sep p = 
    if p >= l then l else
    if s.[p] == sep then drop_sep (p+1) else p in
  let rec cut_aux p buf = 
    if p >= l then buf else
      let i = try (String.index_from s p sep) with Not_found -> l in
      let j = drop_sep (i+1) in
	cut_aux j ((String.sub s p (i-p))::buf) in

    List.rev (cut_aux (drop_sep 0) [])


(* list manipulations *)

let first_n l n = 
  let rec aux buf l n = match n, l with 
      0, _ | _, [] -> List.rev buf
    | n, x::xs -> aux (x::buf) xs (n-1) in
    aux [] l n 

let rec remove_first x = function 
    [] -> []
  | y::s when x = y -> s
  | a::s -> a::(remove_first x s)

let remove_list what from = 
  List.fold_left (fun l x -> remove_first x l) from what 

let cheap_min f l = 
  let aux (y, yv) x = let xv = f x in 
    if (compare xv yv) > 0 then (y, yv) else (x, xv) in
    match  l with
	[] -> raise (Failure "Outils.min")
      | x::xs -> List.fold_left aux (x, f x) xs
	 
let cheap_max f l = 
  let aux (y, yv) x = let xv = f x in 
    if (compare xv yv) < 0 then (y, yv) else (x, xv) in
    match  l with
	[] -> raise (Failure "Outils.min")
      | x::xs -> List.fold_left aux (x, f x) xs

let gen_min comp = function
    [] -> raise (Failure "Outils.gen_min")
  | x::xs -> List.fold_left (fun x y -> if (comp x y) > 0 then y else x) x xs

let gen_max comp = function
    [] -> raise (Failure "Outils.gen_min")
  | x::xs -> List.fold_left (fun x y -> if (comp x y) < 0 then y else x) x xs
	  
let min f l = fst (cheap_min f l)
let max f l = fst (cheap_max f l)
		
let rec revmap_concat f l = function
    [] -> l
  | x::xs -> revmap_concat f ( (f x)::l) xs

let for_int a b = 
  let rec aux p buf = 
    if p > b then List.rev buf
    else aux (p+1) (p::buf) in 
    
    if b < a then failwith "for"
    else aux a []
  
let for_float a b step = 
  if b = a then [ a ]
  else if step = 0. then failwith "for"
  else 
    let tmp = 
      let s = int_of_float ((b -. a) /. step) in for_int 0 s in
      List.map (fun x -> a +. (float x) *. step) tmp

type ('a, 'b) union = One of 'a | Two of 'b


let filter_map2 f l = 
  let rec aux buf1 buf2 = function
      [] -> (List.rev buf1, List.rev buf2)
    | x::xs -> 
	match f x with 
	    One u -> aux (u::buf1) buf2 xs
	  | Two v -> aux buf1 (v::buf2) xs in
    aux [] [] l


(* Be carefull: it's greedy and heavy *)

let rec cross = function
    [] -> []
  | [ l ] -> List.map (fun x -> [x]) l
  | l::ls -> let reste = cross ls in 
      List.flatten 
	(List.map (fun x -> List.map (fun a -> x::a) reste) l)


(* array manipulations *)

let swap tab a b = 
  let x = tab.(a) in tab.(a) <- tab.(b); tab.(b) <- x
    
let partial_sums ?(transform = id) t =
  let k = Array.length t in 
  let r = Array.make k 0
  and v = ref 0 in 
    for i = 0 to k - 1 do 
      r.(i) <- !v;
      v := !v + (transform t.(i)); 
    done; r


(* operations on float *)

let logb b = let l = log b in 
  function x -> (log x) /. l

let log2 = logb 2.

(* misc *)

let get_option = function
    Some x -> x
  | None -> failwith "get_option"

let time f arg = 
  let deb = Sys.time () in 
  let res = f arg in 
  let fin = Sys.time () in 
    (fin -. deb, res)

open Str
let replace input output = Str.global_replace (Str.regexp_string input) output
let replace_regexp input output = Str.global_replace (Str.regexp input) output
let split a = Str.split (Str.regexp_string a);;

let hash_iter f l h = List.iter (fun x-> let j = try Hashtbl.find h x with  Not_found -> failwith "Can't Hashtbl.find " in f j) l 

let couples2hash l = 
  let h = Hashtbl.create 10 in
  begin
    ignore ( List.iter (fun x -> Hashtbl.add h (fst x) (snd x) ) l);
    h
  end


let filter_map f_filter f_map =
  let rec find accu = function
      [] -> List.rev accu
    | x :: l -> if (f_filter x) then find ((f_map x) :: accu) l else find accu l in
    find []

(* remove quotes from string *)
let remove_quotes str = replace " " "" str
