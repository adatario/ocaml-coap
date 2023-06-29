(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

let parser length =
  let open Buf_read in
  let open Buf_read.Syntax in
  (* Initial byte *)
  let* initial_byte = Uint.Read.uint8 in

  (* traceln "Message.parser_framed - initial_byte: %d" initial_byte; *)
  let ib_len = initial_byte lsr 4 in

  (* traceln "Message.parser_framed - ib_len: %d" ib_len; *)
  let tkl = initial_byte land 0xf in

  (* traceln "Message.parser_framed - tkl: %d" tkl; *)

  (* Length field MUST be set to 0 (length is encoded in WebSocket frame) *)
  assert (ib_len = 0);

  (* Code *)
  let* code = Uint.Read.uint8 in

  (* Token (if any) *)
  let* token = take tkl in

  (* set length to length of options + payload *)
  let length =
    length
    - (* initial byte plus code *)
    2
    - (* token length *)
    tkl
  in

  (* traceln "Message.parser_framed - token: %a" Message.token_pp token; *)

  (* Options *)
  let* options, consumed = Message.Options.parser_many length in

  (* traceln "Message.parser_framed - options: %a" *)
  (*   Fmt.(list Message.Options.pp) *)
  (*   options; *)
  (* traceln "Message.parser_framed - consumed: %d" consumed; *)

  (* Payload *)
  let payload_length = length - consumed - 1 in

  (* traceln "Message.parser_framed - payload_length: %d" payload_length; *)
  let* payload =
    if payload_length > 0 then map Stdlib.Option.some (take payload_length)
    else return None
  in

  return ({ code; token; options; payload } : Message.t)

let write writer (msg : Message.t) =
  let open Buf_write in
  let options_s = Message.Options.to_string msg.options in

  (* initial byte *)
  (* length is set to 0 *)
  let length_ib = 0 in
  let token_ib = String.length msg.token in

  let initial_byte = (length_ib lsl 4) lor token_ib in
  uint8 writer initial_byte;

  uint8 writer msg.code;
  string writer msg.token;

  string writer options_s;

  match msg.payload with
  | Some payload ->
      uint8 writer 0xff;
      string writer payload
  | None -> ()
