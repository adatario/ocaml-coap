(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

module Message : sig
  type t

  val pp : t Fmt.t

  (** {1 Parsers} *)

  val parser : int -> t Eio.Buf_read.parser
  val parser_framed : t Eio.Buf_read.parser
end
