(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

type typ = Confirmable | NonConfirmable | Acknowledgement | Reset
type id = int

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
