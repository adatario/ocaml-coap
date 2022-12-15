(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

type t = { flow : Flow.two_way }
type handler = Message.t -> unit

let send t msg =
  Buf_write.with_flow t.flow (fun writer -> Message.write_framed writer msg)

let init flow = { flow }

let handle ~sw handler t =
  let reader = Buf_read.of_flow t.flow ~max_size:64 in

  let rec recv () =
    match Buf_read.format_errors Message.parser_framed reader with
    | Ok msg ->
        Fiber.fork ~sw (fun () -> handler msg);
        recv ()
    | Error (`Msg msg) -> failwith msg
  in

  recv ()
