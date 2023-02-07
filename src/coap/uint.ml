(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

(* Helpers to deal with uints as used in CoAP *)

open Eio

module Read = struct
  open Buf_read

  let uint8 = map Char.code any_char

  let uint24 =
    let open Syntax in
    let* upper_16 = BE.uint16 in
    let* lower_8 = uint8 in
    return Int.(logor (shift_left upper_16 8) lower_8)

  let uint40 =
    let open Syntax in
    let* upper_32 = BE.uint32 in
    let* lower_8 = uint8 in
    return Int64.(logor (shift_left (of_int32 upper_32) 8) @@ of_int lower_8)

  let uint48 =
    let open Syntax in
    let* upper_32 = BE.uint32 in
    let* lower_16 = BE.uint16 in
    return Int64.(logor (shift_left (of_int32 upper_32) 16) (of_int lower_16))

  let uint56 =
    let open Syntax in
    let* upper_32 = BE.uint32 in
    let* lower_24 = uint24 in
    return Int64.(logor (shift_left (of_int32 upper_32) 24) (of_int lower_24))
end

(* module Write = struct *)
(*   open Buf_write *)

(*   let uint24 writer v = *)
(*     (\* write upper 16 bits *\) *)
(*     BE.uint16 writer  *)
(*     LE.uint16 writer Int64.(to_int v); *)
(*     (\* write upper 8 bits *\) *)
(*     uint8 writer Int64.(to_int @@ shift_right_logical v 16) *)

(*   let uint40 writer v = *)
(*     (\* write lower 32 bits *\) *)
(*     LE.uint32 writer Int64.(to_int32 v); *)
(*     (\* write upper 8 bits *\) *)
(*     uint8 writer Int64.(to_int @@ shift_right_logical v 32) *)

(*   let uint48 writer v = *)
(*     (\* write lower 32 bits *\) *)
(*     LE.uint32 writer Int64.(to_int32 v); *)
(*     (\* write upper 8 bits *\) *)
(*     LE.uint16 writer Int64.(to_int @@ shift_right_logical v 32) *)

(*   let uint56 writer v = *)
(*     (\* write lower 32 bits *\) *)
(*     LE.uint32 writer Int64.(to_int32 v); *)
(*     (\* write upper 8 bits *\) *)
(*     uint24 writer Int64.(shift_right_logical v 32) *)
(* end *)
