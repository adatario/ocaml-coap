(*
 * SPDX-FileCopyrightText: 2023 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

module Message = struct
  module Code = struct
    let gen =
      QCheck.Gen.(
        oneofl
          Coap.Message.Code.
            [
              (* Request *)
              get;
              post;
              put;
              delete;
              (* Response *)
              created;
              deleted;
              valid;
              changed;
              content;
              (* Bad Request *)
              bad_request;
              unauthorized;
              bad_option;
              forbidden;
              not_found;
              method_not_allowed;
              not_acceptable;
              precondition_failed;
              request_entity_too_large;
              unsupported_content_format;
              (* Server Error *)
              internal_server_error;
              not_implemented;
              bad_gateway;
              service_unavailable;
              gateway_timeout;
              proxying_not_supported;
            ])

    let arbitrary =
      QCheck.make ~print:(Fmt.to_to_string Coap.Message.Code.pp) gen
  end

  module Option = struct
    (* let print = Fmt.to_to_string Coap.Message.Option.pp *)
    let print_list = Fmt.(to_to_string @@ list Coap.Message.Options.pp)

    let arbitrary_uri_path =
      QCheck.make ~print:print_list ~shrink:QCheck.Shrink.list
        QCheck.Gen.(
          map Coap.Message.Options.uri_path @@ small_list string_small)

    let arbitrary_uri_query =
      QCheck.make ~print:print_list ~shrink:QCheck.Shrink.list
        QCheck.Gen.(
          map Coap.Message.Options.uri_query @@ small_list string_small)

    let arbitrary =
      ignore arbitrary_uri_path;
      ignore arbitrary_uri_query;

      QCheck.(
        map List.concat @@ small_list
        @@ choose
             [
               (* no options *)
               always [];
               arbitrary_uri_path;
               arbitrary_uri_query;
             ])
  end

  let arbitrary_payload = QCheck.(option string_printable)
  let arbitrary_token = QCheck.(option (map Int64.abs int64))

  let arbitrary =
    QCheck.(
      map
        ~rev:(fun msg ->
          Coap.Message.(code msg, token msg, options msg, payload msg))
        (fun (code, token, options, payload) ->
          Coap.Message.make ~code ?token ~options payload)
      @@ tup4 Code.arbitrary arbitrary_token Option.arbitrary arbitrary_payload)

  let testable = Alcotest.testable Coap.Message.pp Coap.Message.equal
end

let write_to_string ~buffer_size f =
  let open Buf_write in
  let buffer = Buffer.create buffer_size in
  with_flow (Flow.buffer_sink buffer) (fun writer -> f writer);
  Buffer.to_bytes buffer |> Bytes.to_string

let test_framed =
  QCheck.Test.make ~name:"write_framed = parser_framed" ~count:200
    Message.arbitrary (fun msg ->
      let msg_s =
        write_to_string ~buffer_size:64 (fun writer ->
            Coap.Message.write_framed writer msg)
      in

      let reader =
        Buf_read.of_flow ~max_size:1000000 @@ Flow.string_source msg_s
      in

      let msg_roundtrip = Coap.Message.parser_framed reader in

      Alcotest.check Message.testable "parsed message is equal to original" msg
        msg_roundtrip;

      true)

let main () =
  Alcotest.run "Coap.Message"
    [
      ("framed messages", List.map QCheck_alcotest.to_alcotest [ test_framed ]);
    ]

let () = Eio_main.run (fun _env -> main ())
