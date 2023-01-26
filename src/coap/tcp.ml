(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

module Signaling = struct
  open Message.Code

  let csm = make 7 1
  let ping = make 7 2
  let is_signaling code = class' code = 7 && detail code < 32
end

type t = { flow : Flow.two_way; read_buffer : Buf_read.t }
type handler = Message.t -> unit

let send t msg =
  (* let msg_s = *)
  (*   Message.Common.Write.to_string ~buffer_size:32 (fun writer -> *)
  (*       Message.write_framed writer msg) *)
  (* in *)

  (* traceln "SEND bytes: %a" Fmt.(on_string @@ hex ()) msg_s; *)
  Buf_write.with_flow t.flow (fun writer -> Message.write_framed writer msg)

let read_msg t =
  match Message.parser_framed t.read_buffer with
  | msg -> Some msg
  | exception End_of_file -> None

let init flow =
  let flow = (flow :> Flow.two_way) in
  (* init a read buffer *)
  let read_buffer = Buf_read.of_flow flow ~max_size:(2 lsl 16) in

  let t = { flow; read_buffer } in

  (* At the start of transport connection a CSM message must be sent
     and is expected (see https://www.rfc-editor.org/rfc/rfc8323#section-5.3) *)
  let my_csm = Message.make ~code:Signaling.csm ~options:[] None in
  send t my_csm;

  t

let handle ~sw handler t =
  let rec read_loop () =
    match read_msg t with
    | Some msg ->
        if Signaling.is_signaling msg.code then (
          (* TODO handle CSM messages *)
          traceln "TODO: handle CSM message";
          read_loop ())
        else Fiber.fork ~sw (fun () -> handler msg);
        read_loop ()
    | None -> ()
  in

  read_loop ()
