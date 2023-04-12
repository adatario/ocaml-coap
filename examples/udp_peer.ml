(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio.Std

let run_dgram addr ~net sw =
  let client_addr = `Udp (addr, 0) in
  let listening_addr = `Udp (addr, 5683) in

  (* let listening_socket = Eio.Net.datagram_socket ~sw net listening_addr in *)

  (*   (fun () -> *)
  (*     let buf = Cstruct.create 20 in *)
  (*     traceln "Waiting to receive data on %a" Eio.Net.Sockaddr.pp listening_addr; *)
  (*     let addr, recv = Eio.Net.recv listening_socket buf in *)
  (*     traceln "Received message from %a: %a" Eio.Net.Sockaddr.pp addr *)
  (*       Fmt.(on_string @@ hex ()) *)
  (*       Cstruct.(to_string (sub buf 0 recv))) *)
  (*   (fun () -> *)
  let socket = Eio.Net.datagram_socket ~sw net client_addr in
  traceln "Sending data from %a to %a" Eio.Net.Sockaddr.pp client_addr
    Eio.Net.Sockaddr.pp listening_addr;

  let msg = Coap.Message.(make ~code:Code.get ~options:[] None) in

  Coap.Udp.send socket listening_addr Coap.Udp.NonConfirmable 42 msg
(* ) *)

let () =
  Eio_main.run (fun env ->
      let net = Eio.Stdenv.net env in
      Switch.run (fun sw -> run_dgram Eio.Net.Ipaddr.V4.loopback ~net sw))
