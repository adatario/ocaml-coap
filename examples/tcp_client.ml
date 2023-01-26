(*
 * SPDX-FileCopyrightText: 2022 iarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

let server_addr = `Tcp (Net.Ipaddr.V4.loopback, 5683)
let handler _connection message = traceln "RECV: %a" Coap.Message.pp message

let client ~net ~sw () =
  let socket = Net.connect ~sw net server_addr in
  let connection = Coap.Tcp.init socket in

  let msg =
    Coap.Message.(
      make ~code:Code.get ~options:(Option.uri_path [ "hi"; "ocaml-coap" ]) None)
  in
  Coap.Tcp.send connection msg;

  Coap.Tcp.handle ~sw (handler connection) connection;

  Eio_unix.sleep 1.0

let main ~net () = Switch.run @@ fun sw -> client ~net ~sw ()
let () = Eio_main.run @@ fun env -> main ~net:(Eio.Stdenv.net env) ()
