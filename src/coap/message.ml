(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

exception FormatError of string

let read_option_length l =
  match Extended.read l with
  | _, byte_count when byte_count = 4 -> None
  | parser, byte_count -> Some (parser, byte_count)

let write_to_string ~buffer_size f =
  let buffer = Buffer.create buffer_size in
  Buf_write.with_flow (Flow.buffer_sink buffer) (fun writer -> f writer);
  Buffer.to_bytes buffer |> Bytes.to_string

(* type type' = Confirmable | Nonconfirmable | Acknowledgement | Reset *)

module Code = struct
  type t = int

  let equal = Int.equal
  let class' t = t lsr 5
  let detail t = t land 0b00011111

  (* Constructors *)

  let make class' detail =
    if class' < 8 && detail < 32 then (class' lsl 5) lor detail
    else raise (Invalid_argument "invalid class or detail")

  let empty = make 0 0
  let get = make 0 1
  let post = make 0 2
  let put = make 0 3
  let delete = make 0 4
  let created = make 2 1
  let deleted = make 2 2
  let valid = make 2 3
  let changed = make 2 4
  let content = make 2 5
  let bad_request = make 4 0
  let unauthorized = make 4 1
  let bad_option = make 4 2
  let forbidden = make 4 3
  let not_found = make 4 4
  let method_not_allowed = make 4 5
  let not_acceptable = make 4 6
  let precondition_failed = make 4 12
  let request_entity_too_large = make 4 13
  let unsupported_content_format = make 4 15
  let internal_server_error = make 5 0
  let not_implemented = make 5 1
  let bad_gateway = make 5 2
  let service_unavailable = make 5 3
  let gateway_timeout = make 5 4
  let proxying_not_supported = make 5 5
  let pp f t = Fmt.pf f "%d.%02d" (class' t) (detail t)
end

module Options = struct
  type t = { number : int; value : string option }

  let equal a b =
    Int.equal a.number b.number && Option.equal String.equal a.value b.value

  let number t = t.number
  let value t = t.value

  (** Constructors *)

  let make number value =
    match value with
    | Some v when String.length v = 0 -> { number; value = None }
    | _ -> { number; value }

  (** Properties *)

  let is_critical t = t.number land 1 > 0
  let is_elective t = not @@ is_critical t
  let is_proxy_unsafe t = t.number land 2 > 0
  let is_safe_to_forward t = not @@ is_proxy_unsafe t

  (** Utilities *)

  let filter_map ?number f =
    List.filter_map (fun option ->
        match number with
        | Some number -> if option.number = number then f option else None
        | None -> f option)

  let filter_map_values ?number f =
    filter_map ?number (fun option -> Option.bind option.value f)

  let rec get_uint value =
    let len = String.length value in
    let reader = Buf_read.of_flow ~max_size:len @@ Flow.string_source value in

    (* handle odd uint lenghts by padding a 0 at the most significant position. *)
    let pad_zero s =
      Seq.append (String.to_seq s) (Seq.return @@ Char.chr 0) |> String.of_seq
    in
    if len = 1 then Option.some @@ Uint.Read.uint8 reader
    else if len = 2 then Option.some @@ Buf_read.BE.uint16 reader
    else if len = 3 then get_uint @@ pad_zero value
    else if len = 4 then
      Option.some @@ Int32.to_int @@ Buf_read.BE.uint32 reader
    else if len = 5 then get_uint @@ pad_zero value
    else if len = 6 then
      Option.some @@ Int64.to_int @@ Buf_read.BE.uint48 reader
    else if len = 7 then get_uint @@ pad_zero value
    else if len = 8 then
      Option.some @@ Int64.to_int @@ Buf_read.BE.uint64 reader
    else None

  (* CoAP Options *)

  let uri_host host = make 3 (Some host)

  let get_uri_host options =
    filter_map_values ~number:3 Option.some options
    |> List.find_opt (Fun.const true)

  let uri_port port =
    let value =
      write_to_string ~buffer_size:2
        Buf_write.(
          fun writer ->
            if port < 256 then uint8 writer port else BE.uint16 writer port)
    in
    make 7 (Some value)

  let get_uri_port options =
    filter_map_values ~number:7
      (fun value ->
        if String.length value = 1 then
          Some Buf_read.(parse_string_exn Uint.Read.uint8 value)
        else if String.length value = 2 then
          Some Buf_read.(parse_string_exn Buf_read.BE.uint16 value)
        else None)
      options
    |> List.find_opt (Fun.const true)

  let uri_path = List.map (fun segment -> make 11 (Some segment))
  let get_uri_path = filter_map_values ~number:11 Option.some
  let uri_query = List.map (fun part -> make 15 (Some part))
  let get_uri_query = filter_map_values ~number:15 Option.some

  (** Pretty Printing *)

  let pp =
    Fmt.(
      hbox @@ braces
      @@ record ~sep:semi
           [
             field "number" (fun o -> o.number) int;
             field "value"
               (fun o -> o.value)
               (option
                  ~none:(styled `Faint @@ any "None")
                  (on_string @@ octets ()));
           ])

  (** Parser *)

  let parser_1 current_number =
    let open Buf_read in
    let open Buf_read.Syntax in
    (* Initial byte *)
    let* initial_byte = Uint.Read.uint8 in
    let ib_delta = (initial_byte land 0b11110000) lsr 4 in
    let ib_value_len = initial_byte land 0b00001111 in

    let delta_parser_opt = read_option_length ib_delta in
    let value_len_parser_opt = read_option_length ib_value_len in

    match (delta_parser_opt, value_len_parser_opt) with
    | Some (delta_parser, delta_xlen), Some (value_len_parser, value_xlen) ->
        let* delta = delta_parser in
        let* value_len = value_len_parser in

        let consumed = 1 + delta_xlen + value_xlen + value_len in

        let number = current_number + delta in
        let* value =
          if value_len = 0 then return None
          else take value_len |> map Option.some
        in

        let option = { number; value } in

        return @@ Some (option, consumed)
    | Some _, None | None, Some _ ->
        failwith
          "message format error: option delta value is 0xf\n\
          \           but option lenght is not 0xf"
    | None, None -> return @@ None

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

    if len > 0 then
      let* options_rev, consumed = loop [] 0 0 in
      return @@ (List.rev options_rev, consumed)
    else return ([], 0)

  (* Writer *)

  let stable_sort_by_number =
    List.stable_sort (fun a b -> Int.compare a.number b.number)

  let write_1 writer current_number t =
    let open Buf_write in
    let delta = t.number - current_number in
    let delta_ib, delta_extended = Extended.writer delta in
    let length_ib, length_extended =
      Extended.writer
        Stdlib.Option.(map String.length t.value |> value ~default:0)
    in

    (* initial byte *)
    let initial_byte = (delta_ib lsl 4) lor length_ib in
    uint8 writer initial_byte;

    delta_extended writer;
    length_extended writer;

    match t.value with Some value -> string writer value | None -> ()

  let write writer options =
    let sorted_options = stable_sort_by_number options in
    ignore
    @@ List.fold_left
         (fun current_number option ->
           write_1 writer current_number option;
           option.number)
         0 sorted_options

  let to_string options =
    (* TODO: heuristics on how large the options will be *)
    write_to_string ~buffer_size:8 (fun writer -> write writer options)
end

type t = {
  (* TCP CoAP does not have a type. TODO add for UDP *)
  (* type' : int; *)
  code : Code.t;
  token : string;
  options : Options.t list;
  payload : string option;
}

let equal a b =
  Code.equal a.code b.code
  && String.equal a.token b.token
  && List.equal Options.equal
       (Options.stable_sort_by_number a.options)
       (Options.stable_sort_by_number b.options)
  && Option.equal String.equal a.payload b.payload

let code t = t.code
let token t = t.token
let options t = t.options
let payload t = t.payload
let token_pp = Fmt.(on_string @@ octets ())

let pp ppf =
  Fmt.(
    pf ppf "@[<6><CoAP %a>@]"
    @@ record
         [
           (* field "type" (fun m -> m.type') int; *)
           field "code" (fun m -> m.code) Code.pp;
           field "token" (fun m -> m.token) token_pp;
           field "options"
             (fun m -> m.options)
             (brackets @@ vbox @@ list ~sep:semi Options.pp);
           field "payload"
             (fun o -> o.payload)
             (option
                ~none:(styled `Faint @@ any "None")
                (on_string @@ octets ()));
         ])

(* Constructor *)

let make ~code ?(token = "") ~options payload =
  (* empty string payload is not allowed *)
  let payload =
    match payload with Some p when String.length p = 0 -> None | _ -> payload
  in
  { code; token; options; payload }
