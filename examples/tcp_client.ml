(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

let server_addr = `Tcp (Net.Ipaddr.V4.loopback, 5683)

let client ~net ~sw () =
  let socket = Net.connect ~sw net server_addr in
  let connection = Coap.Tcp.init socket in

  let read connection =
    let message = Coap.Tcp.receive connection in
    traceln "RECV: %a" Coap.Message.pp message
    (* Only handle a single message and then exit *)
  in

  (* Start receiving messages in a seperate fiber. *)
  Fiber.fork ~sw (fun () -> read connection);

  (* Send a message *)
  let msg =
    Coap.Message.(
      make ~code:Code.get
        ~options:(Options.uri_path [ "hi"; "ocaml-coap" ])
        None)
  in

  Coap.Tcp.send connection msg

let main ~net () =
  try Switch.run @@ fun sw -> client ~net ~sw () with
  | Exit -> ()
  | e -> raise e

let () = Eio_main.run @@ fun env -> main ~net:(Eio.Stdenv.net env) ()
