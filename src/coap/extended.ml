(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

(* Helpers to deal with extended lenghts.

   This is used for encoding Option delta and Option length (Section
   3.1 of RFC 7252) and length in a framed CoAP message (Section 3.2
   of RFC 8323).
*)

open Eio

(** [extended_length l] reads the extended length if indicated by
     [l] and returns a parser to read the extended length and number of
     bytes that will be read. *)
let read l =
  let open Buf_read in
  if l <= 12 then (return l, 0)
  else if l = 13 then (map (fun l -> l + 13) Uint.Read.uint8, 1)
  else if l = 14 then (map (fun l -> l + 269) BE.uint16, 2)
  else if l = 15 then
    (* int handling on 32 bit machines where Int is 31 bit. *)
    (map (fun l -> l + 65805) (map Int32.to_int BE.uint32), 4)
  else
    failwith
      "internal error: extended_length expects an uint8 but was passed a \
       larger integer"

(** [writer value] returns the number of bytes to be written and a
    writer that writes [value]. *)
let writer value =
  let open Buf_write in
  if value < 13 then (value, fun _ -> ())
  else if value < 269 then (13, fun writer -> uint8 writer (value - 13))
  else if value < 65805 then (14, fun writer -> BE.uint16 writer (value - 269))
  else if value < 4295033101 then
    (15, fun writer -> BE.uint32 writer @@ Int32.of_int (value - 65805))
  else failwith "invalid extended value (too large)"
