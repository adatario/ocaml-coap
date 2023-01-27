(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

let listen_addr = `Tcp (Net.Ipaddr.V4.loopback, 5683)

let handler session message =
  traceln "RECV: %a" Coap.Message.pp message;

  let path = Coap.Message.(Options.get_uri_path @@ options message) in
  traceln "Uri-Path: %a" Fmt.(list ~sep:(any "/") string) path;

  if Coap.Message.(Code.equal Code.empty @@ code message) then traceln "empty"
  else
    let response =
      Coap.Message.(
        make ~code:Code.content ?token:(token message) ~options:[]
          (Some "Hi coap-client!"))
    in
    traceln "SEND: %a" Coap.Message.pp response;

    Coap.Tcp.send session response

let listen ~net ~sw () =
  let listen_socket =
    Net.listen ~backlog:4 ~reuse_addr:true ~reuse_port:true ~sw net listen_addr
  in
  let rec loop () =
    Net.accept_fork ~sw listen_socket ~on_error:raise (fun socket addr ->
        traceln "New connection from: %a" Net.Sockaddr.pp addr;
        (* Initiate a CoAP session *)
        let session = Coap.Tcp.init socket in
        Coap.Tcp.handle ~sw (handler session) session);
    loop ()
  in
  loop ()

let main ~net () = Switch.run @@ fun sw -> listen ~net ~sw ()
let () = Eio_main.run @@ fun env -> main ~net:(Eio.Stdenv.net env) ()
