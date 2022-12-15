(*
 * SPDX-FileCopyrightText: 2022 iarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

let listen_addr = `Tcp (Net.Ipaddr.V4.loopback, 5683)

let handler ~stdout session message =
  Flow.copy_string (Fmt.str "RECV: %a\n" Coap.Message.pp message) stdout;
  Coap.Tcp.send session message

let listen ~net ~sw ~stdout () =
  let listen_socket =
    Net.listen ~backlog:4 ~reuse_addr:true ~reuse_port:true ~sw net listen_addr
  in
  let rec loop () =
    Net.accept_fork ~sw listen_socket
      ~on_error:(fun _exn -> Flow.copy_string "ERROR\n" stdout)
      (fun socket addr ->
        Flow.copy_string
          (Fmt.str "Connection from: %a\n" Net.Sockaddr.pp addr)
          stdout;
        let session = Coap.Tcp.init socket in
        Coap.Tcp.handle ~sw (handler ~stdout session) session);

    loop ()
  in
  loop ()

let main ~net ~stdout () = Switch.run @@ fun sw -> listen ~net ~sw ~stdout ()

let () =
  Eio_main.run @@ fun env ->
  main ~net:(Eio.Stdenv.net env) ~stdout:(Eio.Stdenv.stdout env) ()
