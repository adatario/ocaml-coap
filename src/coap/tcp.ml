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
    traceln "Tcp.Signaling.handler: %a" Message.pp msg;
    if Message.Code.equal (Message.code msg) Code.csm then (
      (* Set max_message_size *)
      Message.Options.filter_map_values ~number:2 Message.Options.get_uint
        msg.options
      |> List.iter (fun max_message_size ->
             traceln "Tcp.Signaling.handler - setting max_message_size to %d"
               max_message_size;
             t.remote_max_message_size <- Some max_message_size);
      ())
    else ()
end

(* Parsers *)

let parser =
  let open Buf_read in
  let open Buf_read.Syntax in
  (* Initial byte *)
  let* initial_byte = Uint.Read.uint8 in
  traceln "Message.parser_framed - initial_byte: %d" initial_byte;

  let ib_len = initial_byte lsr 4 in
  traceln "Message.parser_framed - ib_len: %d" ib_len;

  let tkl = initial_byte land 0xf in
  traceln "Message.parser_framed - tkl: %d" tkl;

  (* Extended length (if any) *)
  let length_parser, bytes_consumed = Message.read_extended_length ib_len in
  let* length = length_parser in
  traceln "Message.parser_framed - length: %d, bytes_consumed: %d" length
    bytes_consumed;

  (* Code *)
  let* code = Uint.Read.uint8 in
  traceln "Message.parser_framed - code: %d" code;

  (* Token (if any) *)
  let* token = take tkl in
  traceln "Message.parser_framed - token: %a" Message.token_pp token;

  (* Options *)
  let* options, consumed = Message.Options.parser_many length in
  traceln "Message.parser_framed - options: %a"
    Fmt.(list Message.Options.pp)
    options;
  traceln "Message.parser_framed - consumed: %d" consumed;

  (* Payload *)
  let payload_length = length - consumed - 1 in
  traceln "Message.parser_framed - payload_length: %d" payload_length;

  let* payload =
    if payload_length > 0 then map Stdlib.Option.some (take payload_length)
    else return None
  in

  return ({ code; token; options; payload } : Message.t)

(* Writers *)

let write writer (msg : Message.t) =
  let open Buf_write in
  let options_s = Message.Options.to_string msg.options in

  let payload_length =
    Stdlib.Option.(
      map
        (fun s ->
          (* 1 byte for the payload marker *)
          1 + String.length s)
        msg.payload
      |> value ~default:0)
  in

  let length = String.length options_s + payload_length in

  (* initial byte *)
  let length_ib, length_extended = Message.write_extended length in
  let token_ib = String.length msg.token in

  let initial_byte = (length_ib lsl 4) lor token_ib in
  uint8 writer initial_byte;

  length_extended writer;
  uint8 writer msg.code;
  string writer msg.token;

  string writer options_s;

  match msg.payload with
  | Some payload ->
      uint8 writer 0xff;
      string writer payload
  | None -> ()

let send t msg = Buf_write.with_flow t.flow (fun writer -> write writer msg)

let read_msg t =
  (* ignore @@ Buf_read.peek_char t.read_buffer; *)
  (* traceln "Tcp.read_msg - buffer: %a" Cstruct.hexdump_pp *)
  (* @@ Buf_read.peek t.read_buffer; *)
  match parser t.read_buffer with
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
  traceln "Tcp.init - sent CSM";
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
