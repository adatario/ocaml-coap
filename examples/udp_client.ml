(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio.Std

let run_dgram addr ~net sw =
  let client_addr = `Udp (addr, 0) in
  let server_addr = `Udp (addr, 5683) in

  let socket = Eio.Net.datagram_socket ~sw net client_addr in

  (* Send a message *)
  let msg =
    Coap.Message.(
      make ~code:Code.get
        ~options:Coap.Message.Options.[ uri_host "test.example" ]
        (Some "Hello"))
  in

  traceln "SEND(%a to %a): %a" Eio.Net.Sockaddr.pp client_addr
    Eio.Net.Sockaddr.pp server_addr Coap.Message.pp msg;
  Coap.Udp.send socket server_addr Coap.Udp.NonConfirmable 42 msg;

  (* Receive response *)
  let addr, _typ, id, msg = Coap.Udp.receive socket in

  traceln "RECV(%a): id:%d; msg:%a" Eio.Net.Sockaddr.pp addr id Coap.Message.pp
    msg;

  match Coap.Message.payload msg with
  | Some payload -> traceln "%s" payload
  | None -> ()

let () =
  Eio_main.run (fun env ->
      let net = Eio.Stdenv.net env in
      Switch.run (fun sw -> run_dgram Eio.Net.Ipaddr.V4.loopback ~net sw))
