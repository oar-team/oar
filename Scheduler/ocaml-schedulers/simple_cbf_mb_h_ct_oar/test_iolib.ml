open Iolib
let _= 
(*  let conn = let r = Iolib_pg.connect () in at_exit (fun () -> Iolib_pg.disconnect r); r in *)
 (* let r = Iolib_pg.connect () in let g = get_resource_list r in test_db r ;; *)
 let r = Iolib.connect () in get_resource_list r  ;;  
