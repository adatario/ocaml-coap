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
  let none = return None

  (** [extended_length l] reads the extended length if indicated by
  [l] and returns the length and number of bytes read. *)
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

  let option_length l =
    (* also returns the number of bytes consumed *)
    if l <= 12 then return (Some (l, 0))
    else if l = 13 then map (fun l -> Some (l - 13, 1)) uint8
    else if l = 14 then map (fun l -> Some (l - 269, 2)) uint16_le
    else if l = 15 then return None
    else failwith "invalid length"
end

module Message = struct
  (* type type' = Confirmable | Nonconfirmable | Acknowledgement | Reset *)

  module Code = struct
    type t = int

    let class' t = t lsr 5
    let detail t = t land 0x1f
    let pp f t = Fmt.pf f "%d.%02d" (class' t) (detail t)
  end

  module Option = struct
    type t = { number : int; value : string }

    let number t = t.number
    let value t = t.value

    let parser_1 current_number =
      let open Buf_read in
      let open Buf_read.Syntax in
      let open Parser in
      (* Initial byte *)
      let* initial_byte = uint8 in
      let ib_delta = (initial_byte land 0b11110000) lsr 4 in
      let ib_value_len = initial_byte land 0b00001111 in

      (* Delta (possibly extended) *)
      let* delta_opt = option_length ib_delta in

      match delta_opt with
      | Some (delta, delta_xlen) -> (
          (* Value length (possibly extended) *)
          let* value_len_opt = option_length ib_value_len in

          match value_len_opt with
          | Some (value_len, value_xlen) ->
              let* value = take value_len in
              return
              @@ Some
                   ( { number = current_number + delta; value },
                     1 + delta_xlen + value_xlen + value_len )
          | None -> failwith "message format error: invalid option length")
      | None ->
          (* delta value is 0xF, ib_len must also be 0xf - the payload marker *)
          if ib_value_len = 0xf then none
          else
            failwith
              "message format error: option delta value is 0xf\n\
              \           but option lenght is not 0xf"

    let parser_many len =
      let open Buf_read in
      let open Buf_read.Syntax in
      let rec loop prev current_number total_consumed =
        let* option_opt = parser_1 current_number in
        match option_opt with
        | Some (option, consumed) ->
            let total_consumed = total_consumed + consumed in
            if total_consumed >= len then return (option :: prev, total_consumed)
            else loop (option :: prev) option.number total_consumed
        | None -> return (prev, total_consumed)
      in

      let* options_rev, consumed = loop [] 0 0 in

      return @@ (List.rev options_rev, consumed)

    let pp =
      Fmt.(
        braces
        @@ record ~sep:semi
             [
               field "number" (fun o -> o.number) int;
               field "value" (fun o -> o.value) (on_string @@ octets ());
             ])
  end

  type t = {
    (* TCP CoAP does not have a type. TODO add for UDP *)
    (* type' : int; *)
    code : Code.t;
    token : int option;
    options : Option.t list;
    payload : string;
  }

  let code t = t.code
  let token t = t.token
  let options t = t.options
  let payload t = t.payload

  let pp =
    Fmt.(
      record
        [
          (* field "type" (fun m -> m.type') int; *)
          field "code" (fun m -> m.code) Code.pp;
          field "token" (fun m -> m.token) (option int);
          field "options"
            (fun m -> m.options)
            (brackets @@ list ~sep:semi Option.pp);
          field "payload" (fun o -> o.payload) (on_string @@ hex ());
        ])

  let parser_framed =
    let open Buf_read in
    let open Buf_read.Syntax in
    let open Parser in
    (* Initial byte *)
    let* initial_byte = uint8 in
    let ib_len = initial_byte lsr 4 in
    let tkl = initial_byte land 0xf in

    Eio.traceln "initial_byte: %X" initial_byte;
    Eio.traceln "ib_len: %X" ib_len;
    Eio.traceln "tkl: %X" tkl;

    (* Extended length (if any) *)
    let* length = extended_length ib_len in

    (* Code *)
    let* code = uint8 in
    Eio.traceln "code: %X" code;

    (* Token (if any) *)
    let* token = token tkl in

    (* Options *)
    let* options, consumed = Option.parser_many length in

    (* Payload *)
    let* payload = take (length - consumed) in

    return { code; token; options; payload }

  let parser _len = failwith "TODO"
end
