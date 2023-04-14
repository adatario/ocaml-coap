(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

type typ = Confirmable | NonConfirmable | Acknowledgement | Reset
type id = int

let parser length =
  let open Eio.Buf_read in
  let open Eio.Buf_read.Syntax in
  (* Initial byte *)
  let* initial_byte = Uint.Read.uint8 in
  let _version = initial_byte lsr 6 in
  let typ_ib = (initial_byte lsr 4) land 0b11 in
  let typ =
    if typ_ib = 0 then Confirmable
    else if typ_ib = 1 then NonConfirmable
    else if typ_ib = 2 then Acknowledgement
    else if typ_ib = 3 then Reset
    else failwith "invalid type while parsing initial byte"
  in
  let tkl = initial_byte land 0xf in

  (* code *)
  let* code = uint8 in

  (* message id *)
  let* id = BE.uint16 in

  let* token = take tkl in
  let token = if String.length token = 0 then None else Some token in

  let length =
    length
    (* initial byte, code and message id *)
    - 4
    (* token length *)
    - tkl
  in

  (* Options *)
  let* options, consumed = Message.Options.parser_many length in

  (* Payload *)
  let payload_length = length - consumed - 1 in
  let* payload =
    if payload_length > 0 then map Stdlib.Option.some (take payload_length)
    else return None
  in

  return (typ, id, Message.make ~code ?token ~options payload)

let write writer typ id (msg : Message.t) =
  let open Eio.Buf_write in
  let token_ib = String.length msg.token in

  let type_ib =
    match typ with
    | Confirmable -> 0
    | NonConfirmable -> 1
    | Acknowledgement -> 2
    | Reset -> 3
  in

  (* initial byte *)
  let initial_byte =
    (* Version *)
    (0b01 lsl 6) lor (type_ib lsl 4) lor (0xff land token_ib)
  in
  uint8 writer initial_byte;

  (* code *)
  uint8 writer msg.code;

  (* message id *)
  BE.uint16 writer id;

  (* token *)
  string writer msg.token;

  (* options *)
  Message.Options.write writer msg.options;

  (* payload *)
  match msg.payload with
  | Some payload ->
      uint8 writer 0xff;
      string writer payload
  | None -> ()

let send ?(buffer = Buffer.create 1024) socket addr typ id msg =
  Eio.Buf_write.with_flow (Eio.Flow.buffer_sink buffer) (fun writer ->
      write writer typ id msg);
  Eio.Net.send socket addr (Cstruct.of_bytes (Buffer.to_bytes buffer))

let receive ?(buffer = Cstruct.create 1024) socket =
  let addr, recv = Eio.Net.recv socket buffer in

  let reader = Eio.Buf_read.of_buffer buffer.buffer in
  let typ, id, msg = parser recv reader in

  (addr, typ, id, msg)
