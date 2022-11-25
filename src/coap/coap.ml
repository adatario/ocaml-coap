(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

module Parser = struct
  open Buf_read

  let uint8 = map Char.code any_char
  let uint16_le = map (fun s -> Bytes.(get_uint16_le (of_string s) 0)) (take 2)

  let uint32_le =
    map (fun s -> Bytes.(Int32.to_int @@ get_int32_le (of_string s) 0)) (take 4)

  let some = map Option.some

  let extended_length l =
    if l <= 12 then return l
    else if l = 13 then map (fun l -> l - 13) uint8
    else if l = 14 then map (fun l -> l - 269) uint16_le
    else if l = 15 then map (fun l -> l - 65805) uint32_le
    else failwith "invalid length"

  let token tkl =
    if tkl = 0 then return None
    else if tkl = 1 then some uint16_le
    else if tkl = 2 then some uint32_le
    else if tkl = 3 then some uint32_le
    else failwith "invalid token length"
end

module Message = struct
  (* type type' = Confirmable | Nonconfirmable | Acknowledgement | Reset *)
  type t = { type' : int; token : int option }

  let pp =
    Fmt.(
      record
        [
          field "type" (fun m -> m.type') int;
          field "token_length" (fun m -> m.token) (option int);
        ])

  let parser_framed =
    let open Buf_read in
    let open Buf_read.Syntax in
    let open Parser in
    let* initial_byte = map Char.code any_char in
    let len = initial_byte lsr 4 in
    let tkl = initial_byte land 0xf in
    let* xlen = extended_length len in
    let* token = token tkl in
    ignore xlen;

    return { type' = 2; token }

  let parser _len = failwith "TODO"
end
