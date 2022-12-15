(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

module Common = struct
  (* Helpers for reading and writing CoAP structures that appear in
     many places. *)

  module Read = struct
    open Buf_read

    let uint8 = map Char.code any_char

    let uint16_le =
      map (fun s -> Bytes.(get_uint16_le (of_string s) 0)) (take 2)

    let uint32_le =
      map
        (fun s -> Bytes.(Int32.to_int @@ get_int32_le (of_string s) 0))
        (take 4)

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
      else if tkl = 1 then some uint8
      else if tkl = 2 then some uint16_le
      else if tkl = 4 then some uint32_le
      else failwith "invalid token length"

    let option_length l =
      (* also returns the number of bytes consumed *)
      if l <= 12 then return (Some (l, 0))
      else if l = 13 then map (fun l -> Some (l - 13, 1)) uint8
      else if l = 14 then map (fun l -> Some (l - 269, 2)) uint16_le
      else if l = 15 then return None
      else failwith "invalid length"
  end

  module Write = struct
    open Buf_write

    let extended value =
      if value < 13 then (value, fun _ -> ())
      else if value < 269 then (13, fun writer -> uint8 writer (value - 13))
      else if value < 65805 then
        (14, fun writer -> LE.uint16 writer (value - 269))
      else if value < 4295033101 then
        (15, fun writer -> LE.uint32 writer @@ Int32.of_int (value - 65805))
      else failwith "invalid extended value (too large)"

    let token token =
      match token with
      | None -> (0, fun _ -> ())
      | Some token when token < 256 -> (1, fun writer -> uint8 writer token)
      | Some token when token < 65536 ->
          (2, fun writer -> LE.uint16 writer token)
      | Some token when token < 1 lsl 32 ->
          (4, fun writer -> LE.uint32 writer @@ Int32.of_int token)
      | _ -> failwith "invalid token (too large)"
  end
end

module Message = struct
  (* type type' = Confirmable | Nonconfirmable | Acknowledgement | Reset *)

  module Code = struct
    type t = int

    let class' t = t lsr 5
    let detail t = t land 0b00011111
    let pp f t = Fmt.pf f "%d.%02d" (class' t) (detail t)
  end

  module Option = struct
    type t = { number : int; value : string }

    let number t = t.number
    let value t = t.value

    let parser_1 current_number =
      let open Buf_read in
      let open Buf_read.Syntax in
      let open Common.Read in
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
        hbox @@ braces
        @@ record ~sep:semi
             [
               field "number" (fun o -> o.number) int;
               field "value" (fun o -> o.value) (on_string @@ octets ());
             ])

    (* Writer *)

    let write_1 writer current_number t =
      let open Buf_write in
      let open Common.Write in
      let delta = t.number - current_number in
      let delta_ib, delta_extended = extended delta in
      let length_ib, length_extended = extended (String.length t.value) in

      (* initial byte *)
      let initial_byte = (delta_ib lsl 4) lor length_ib in
      uint8 writer initial_byte;

      delta_extended writer;
      length_extended writer;

      string writer t.value

    let write writer options =
      let sorted_options =
        List.stable_sort (fun a b -> Int.compare a.number b.number) options
      in
      ignore
      @@ List.fold_left
           (fun current_number option ->
             write_1 writer current_number option;
             option.number)
           0 sorted_options

    let to_bytes options =
      (* TODO: heuristics on how large the options will be *)
      let options_buffer = Buffer.create 8 in
      Buf_write.with_flow (Flow.buffer_sink options_buffer) (fun writer ->
          write writer options;
          Buf_write.flush writer;
          Buffer.to_bytes options_buffer)
  end

  type t = {
    (* TCP CoAP does not have a type. TODO add for UDP *)
    (* type' : int; *)
    code : Code.t;
    token : int option;
    options : Option.t list;
    payload : string option;
  }

  let code t = t.code
  let token t = t.token
  let options t = t.options
  let payload t = t.payload

  let pp ppf =
    Fmt.(
      pf ppf "@[<6><CoAP %a>@]"
      @@ record
           [
             (* field "type" (fun m -> m.type') int; *)
             field "code" (fun m -> m.code) Code.pp;
             field "token"
               (fun m -> m.token)
               (option ~none:(styled `Faint @@ any "None") int);
             field "options"
               (fun m -> m.options)
               (brackets @@ vbox @@ list ~sep:semi Option.pp);
             field "payload"
               (fun o -> o.payload)
               (option
                  ~none:(styled `Faint @@ any "None")
                  (on_string @@ octets ()));
           ])

  (* Parsers *)

  let parser_framed =
    let open Buf_read in
    let open Buf_read.Syntax in
    let open Common.Read in
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
    let payload_length = length - consumed in
    let* payload =
      if payload_length > 0 then map Stdlib.Option.some (take payload_length)
      else return None
    in

    return { code; token; options; payload }

  let parser _len = failwith "TODO"

  (* Writers *)

  let write_framed writer message =
    let open Buf_write in
    let open Common.Write in
    let options_bytes = Option.to_bytes message.options in

    let payload_length =
      Stdlib.Option.(
        map
          (fun s ->
            (* 1 byte for the payload marker *)
            1 + String.length s)
          message.payload
        |> value ~default:0)
    in

    let length = Bytes.length options_bytes + payload_length in

    (* initial byte *)
    let length_ib, length_extended = extended length in
    let token_ib, token = token message.token in
    let initial_byte = (length_ib lsl 4) lor token_ib in
    uint8 writer initial_byte;

    length_extended writer;
    uint8 writer message.code;
    token writer;

    bytes writer options_bytes;

    match message.payload with
    | Some payload ->
        uint8 writer 0xff;
        string writer payload
    | None -> ()
end
