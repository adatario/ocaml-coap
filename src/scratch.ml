(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

let listen_addr = `Tcp (Net.Ipaddr.V4.loopback, 5683)

let handle_connection ~stdout socket addr =
  Flow.copy_string (Fmt.str "Connection from: %a\n" Net.Sockaddr.pp addr) stdout;

  match Buf_read.parse ~max_size:4000 Coap.Message.parser_framed socket with
  | Ok msg ->
      Flow.copy_string (Fmt.str "message: %a\n" Coap.Message.pp msg) stdout
  | Error (`Msg msg) ->
      Flow.copy_string (Fmt.str "Parser error: %s\n" msg) stdout

let listen ~net ~sw ~stdout () =
  let listen_socket =
    Net.listen ~backlog:4 ~reuse_addr:true ~reuse_port:true ~sw net listen_addr
  in
  let rec loop () =
    Net.accept_fork ~sw listen_socket
      ~on_error:(fun _exn -> Flow.copy_string "ERROR\n" stdout)
      (handle_connection ~stdout);
    loop ()
  in
  loop ()

let main ~net ~stdout () = Switch.run @@ fun sw -> listen ~net ~sw ~stdout ()

let () =
  Eio_main.run @@ fun env ->
  main ~net:(Eio.Stdenv.net env) ~stdout:(Eio.Stdenv.stdout env) ()
