(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

(* An example of how to use the CoAP request and response semantics.

   Some notes:

   - Respones may be out-of-order: To handle this the client maintains
     a mapping of pending responses.
   - In CoAP the entity that makes requests can be both the TCP connection
     initiating entity or the receiving entity. The client logic below
     can be used by a TCP server and/or client.
*)

open Eio.Std

let server_addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, 5683)

module Client : sig
  type t

  val init : sw:Switch.t -> Coap.Tcp.t -> t

  val request :
    code:Coap.Message.Code.t ->
    options:Coap.Message.Options.t list ->
    ?payload:string ->
    t ->
    Coap.Message.t

  val stop : t -> unit
end = struct
  type request = {
    code : Coap.Message.Code.t;
    options : Coap.Message.Options.t list;
    payload : string option;
  }

  type resolver = (Coap.Message.t, exn) Result.t Promise.u

  (* Messages *)
  type msg =
    | Request of (request * resolver)
    | Message of Coap.Message.t
    | Stop

  type t = msg Eio.Stream.t

  (* Tokens *)

  let string_of_token token =
    let buf = Buffer.create 4 in
    Buffer.add_int32_ne buf token;
    Buffer.to_bytes buf |> Bytes.to_string

  module TokenMap = Map.Make (String)

  (* State *)

  type state = { token : Int32.t; pending : resolver TokenMap.t }

  let init ~sw connection =
    let mbox = Eio.Stream.create 100 in

    (* Listen for CoAP messages *)
    let rec receive_loop () =
      let msg = Coap.Tcp.receive connection in
      Eio.Stream.add mbox (Message msg);
      receive_loop ()
    in

    (* Handle messages in mbox *)
    let rec handler state =
      match Eio.Stream.take mbox with
      | Request (request, resolver) ->
          let token' = state.token |> string_of_token in
          let msg =
            Coap.Message.(
              make ~code:request.code ~token:token' ~options:request.options
                request.payload)
          in

          traceln "Sending Request message: %a" Coap.Message.pp msg;

          Coap.Tcp.send connection msg;

          (* Add the resolver to pending resolvers *)
          let pending = state.pending |> TokenMap.add token' resolver in

          (* loop *)
          handler { token = Int32.succ state.token; pending }
      | Message msg ->
          (match TokenMap.find_opt (Coap.Message.token msg) state.pending with
          | Some resolver -> Promise.resolve resolver (Result.ok msg)
          | None -> traceln "unhandled msg: %a" Coap.Message.pp msg);

          handler state
      | Stop ->
          traceln "Stop";
          ()
    in

    let init_state = { token = Int32.zero; pending = TokenMap.empty } in

    Fiber.fork_daemon ~sw (fun () ->
        Fiber.first receive_loop (fun () -> handler init_state);
        `Stop_daemon);

    (* Return the mbox *)
    mbox

  let request ~code ~options ?payload mbox =
    let promise, resolver = Promise.create () in
    Eio.Stream.add mbox (Request ({ code; options; payload }, resolver));
    match Promise.await promise with Ok v -> v | Error exn -> raise exn

  let stop mbox = Eio.Stream.add mbox Stop
end

let main ~net () =
  Switch.run (fun sw ->
      let socket = Eio.Net.connect ~sw net server_addr in
      let connection = Coap.Tcp.init socket in

      let client = Client.init ~sw connection in

      let response =
        Client.request ~code:Coap.Message.Code.get ~options:[] ~payload:"Hello"
          client
      in

      traceln "Response: %a" Coap.Message.pp response;

      ignore Client.stop)

let () = Eio_main.run @@ fun env -> main ~net:(Eio.Stdenv.net env) ()
