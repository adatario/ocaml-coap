(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

module Message : sig
  module Code : sig
    type t

    val class' : t -> int
    val detail : t -> int
    val pp : t Fmt.t
  end

  module Option : sig
    type t

    val number : t -> int
    val value : t -> string
  end

  type t

  val code : t -> Code.t
  val token : t -> int option
  val options : t -> Option.t list
  val payload : t -> string
  val pp : t Fmt.t

  (** {1 Parsers} *)

  val parser : int -> t Eio.Buf_read.parser
  val parser_framed : t Eio.Buf_read.parser
end
