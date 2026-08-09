(* server.ml
   Mini serveur HTTP autour de Marina.sat_str, en OCaml pur.
   Utilise uniquement le module Unix (fourni avec le compilateur OCaml,
   pas besoin d'opam ni d'aucune autre dependance ou langage). *)

let read_line_opt ic =
  try Some (input_line ic) with End_of_file -> None

let url_decode s =
  let buf = Buffer.create (String.length s) in
  let n = String.length s in
  let i = ref 0 in
  while !i < n do
    (match s.[!i] with
     | '+' -> Buffer.add_char buf ' '; incr i
     | '%' when !i + 2 < n ->
       let hex = String.sub s (!i + 1) 2 in
       (try
          Buffer.add_char buf (Char.chr (int_of_string ("0x" ^ hex)));
          i := !i + 3
        with _ -> Buffer.add_char buf '%'; incr i)
     | c -> Buffer.add_char buf c; incr i)
  done;
  Buffer.contents buf

let parse_query query =
  String.split_on_char '&' query
  |> List.filter_map (fun kv ->
      if kv = "" then None
      else match String.index_opt kv '=' with
        | Some idx ->
          let k = String.sub kv 0 idx in
          let v = String.sub kv (idx + 1) (String.length kv - idx - 1) in
          Some (url_decode k, url_decode v)
        | None -> Some (url_decode kv, ""))

let http_response status body =
  let len = String.length body in
  Printf.sprintf
    "HTTP/1.1 %s\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
    status len body

let read_headers ic =
  let content_length = ref 0 in
  let rec loop () =
    match read_line_opt ic with
    | None -> ()
    | Some raw_line ->
      let line = String.trim raw_line in
      if line = "" then ()
      else begin
        let lower = String.lowercase_ascii line in
        let prefix = "content-length:" in
        let plen = String.length prefix in
        (if String.length lower >= plen && String.sub lower 0 plen = prefix then
           try
             content_length := int_of_string (String.trim (String.sub line plen (String.length line - plen)))
           with _ -> ());
        loop ()
      end
  in
  loop ();
  !content_length

let handle_client ic oc =
  match read_line_opt ic with
  | None -> ()
  | Some request_line ->
    let request_line = String.trim request_line in
    let content_length = read_headers ic in
    (match String.split_on_char ' ' request_line with
     | meth :: target :: _ ->
       let path, query =
         match String.index_opt target '?' with
         | Some idx ->
           String.sub target 0 idx,
           String.sub target (idx + 1) (String.length target - idx - 1)
         | None -> target, ""
       in
       let respond status body =
         output_string oc (http_response status body);
         flush oc
       in
       (match path with
        | "/healthz" -> respond "200 OK" "ok"
        | "/" ->
          respond "200 OK"
            "marina SAT solver.\nGET  /solve?prop=<expr>\nPOST /solve  (body = expr)\n"
        | "/solve" ->
          let prop =
            if meth = "POST" && content_length > 0 then begin
              let buf = Bytes.create content_length in
              really_input ic buf 0 content_length;
              Bytes.to_string buf
            end else
              (try List.assoc "prop" (parse_query query) with Not_found -> "")
          in
          if String.trim prop = "" then
            respond "400 Bad Request" "Erreur: parametre 'prop' manquant"
          else begin
            try respond "200 OK" (Marina.sat_str prop)
            with e -> respond "400 Bad Request" ("Erreur: " ^ Printexc.to_string e)
          end
        | _ -> respond "404 Not Found" "Not found")
     | _ -> ())

let () =
  let port = try int_of_string (Sys.getenv "PORT") with Not_found -> 8080 in
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt sock Unix.SO_REUSEADDR true;
  Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_any, port));
  Unix.listen sock 32;
  Printf.printf "marina HTTP server listening on 0.0.0.0:%d\n%!" port;
  while true do
    let client_sock, _ = Unix.accept sock in
    (try
       let ic = Unix.in_channel_of_descr client_sock in
       let oc = Unix.out_channel_of_descr client_sock in
       handle_client ic oc;
       (try flush oc with _ -> ())
     with e -> Printf.eprintf "Erreur client: %s\n%!" (Printexc.to_string e));
    (try Unix.close client_sock with _ -> ())
  done