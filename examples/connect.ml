
open Cry

let c = create () 

let connection =
  let mount = "" in
  let content_type = mpeg in
  let channels = 2 in
  let samplerate = 44100 in
  let bitrate = 128 in
  let protocol = Icy in
  let icy = true in
  let audio_info = audio_info ~channels ~samplerate ~bitrate () in 
  {
    (connection ~audio_info ~icy ~protocol ~mount ~content_type ()) with
    port = 8005
  }

let () =
  try 
    connect c connection;
    if get_icy_cap c then Printf.printf "Icy enabled !\n%!";
    let meta = Hashtbl.create 10 in
    Hashtbl.add meta "artist" "testé";
    Hashtbl.add meta "title"  "testé";
    update_metadata c meta
  with
    | Error e -> Printf.printf "Error: %s\n%!" (string_of_error e)

