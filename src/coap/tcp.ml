(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

type t = {
  flow : Flow.two_way;
  read_buffer : Buf_read.t;
  mutable local_max_message_size : int option;
  mutable remote_max_message_size : int option;
}

type handler = Message.t -> unit

module Signaling = struct
  (* Handle signaling messages (see
     https://www.rfc-editor.org/rfc/rfc8323#section-5.3) *)

  module Code = struct
    let csm = Message.Code.make 7 1
    let ping = Message.Code.make 7 2
  end

  let is_signaling (msg : Message.t) =
    Message.Code.class' msg.code = 7 && Message.Code.detail msg.code < 32

  (* Handler *)

  let handler t msg =
    ignore t;
    traceln "Signaling.handler: %a" Message.pp msg;
    if Message.Code.equal (Message.code msg) Code.csm then (
      (* Set max_message_size *)
      Message.Options.filter_map_values ~number:2 Message.Options.get_uint
        msg.options
      |> List.iter (fun max_message_size ->
             t.remote_max_message_size <- Some max_message_size);
      ())
    else ()
end

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

let init ?max_message_size flow =
  let flow = (flow :> Flow.two_way) in
  (* init a read buffer *)
  let read_buffer = Buf_read.of_flow flow ~max_size:(2 lsl 16) in

  let t =
    {
      flow;
      read_buffer;
      local_max_message_size = max_message_size;
      remote_max_message_size = None;
    }
  in

  (* At the start of transport connection a CSM message must be sent
     and is expected (see https://www.rfc-editor.org/rfc/rfc8323#section-5.3) *)
  let my_csm = Message.make ~code:Signaling.Code.csm ~options:[] None in
  send t my_csm;

  t

let handle ~sw handler t =
  let rec read_loop () =
    match read_msg t with
    | Some msg ->
        if Signaling.is_signaling msg then (
          Signaling.handler t msg;
          read_loop ())
        else Fiber.fork ~sw (fun () -> handler msg);
        read_loop ()
    | None -> ()
  in

  read_loop ()
