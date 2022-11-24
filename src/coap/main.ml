(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

let main ~stdout = Eio.Flow.copy_string "Hello, world!\n" stdout
let () = Eio_main.run @@ fun env -> main ~stdout:(Eio.Stdenv.stdout env)
