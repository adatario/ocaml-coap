(*
 * SPDX-FileCopyrightText: 2022 Tarides <contact@tarides.com>
 *
 * SPDX-License-Identifier: ISC
 *)

open Eio

(** An OCaml implementation of The Constrained Application Protocol
(CoAP) as defined by RFC 7252.

CoAP is a network transport protocol specialized for use with
constrained nodes and constrained networks (e.g. low-power,
lousy). CoAP provides a request/response interaction model similar to
HTTP. However, CoAP can also be used for observing resources (see
module {!Observe}) and allows bi-directional requests.

Being optimized for small and constrained devices, CoAP is designed to
have small implementations. This makes it suitable for usage in
embedded OCaml applications (e.g. MirageOS or js_of_ocaml).

@see <https://www.rfc-editor.org/rfc/rfc7252> RFC 7252: The
Constrained Application Protocol (CoAP)

 *)

module Message : sig
  module Code : sig
    type t

    val class' : t -> int
    val detail : t -> int

    (** {1 Constructors} *)

    val make : int -> int -> t
    (** [make class' detail] returns the code with class [class'] and
        detail [detail]. *)

    (** {2 Request} *)

    val get : t
    val post : t
    val put : t
    val delete : t

    (** {2 Response} *)

    val created : t

    (** {3 Success} *)

    val deleted : t
    val valid : t
    val changed : t
    val content : t

    (** {3 Bad Request} *)

    val bad_request : t
    val unauthorized : t
    val bad_option : t
    val forbidden : t
    val not_found : t
    val method_not_allowed : t
    val not_acceptable : t
    val precondition_failed : t
    val request_entity_too_large : t
    val unsupported_content_format : t

    (** {3 Server Error} *)

    val internal_server_error : t
    val not_implemented : t
    val bad_gateway : t
    val service_unavailable : t
    val gateway_timeout : t
    val proxying_not_supported : t

    (** {1 Debug} *)

    val pp : t Fmt.t
  end

  module Option : sig
    type t

    val number : t -> int
    val value : t -> string option

    (** {1 Constructors} *)

    val make : int -> string option -> t
    (** [make number value] returns a new option with number [number]
  and value [value]. *)

    (** {1 Properties} *)

    (** {2 Critical/Elective} *)

    (** @see <https://www.rfc-editor.org/rfc/rfc7252#section-5.4.1>
    Section 5.4.1 of RFC 7252 *)

    val is_critical : t -> bool
    val is_elective : t -> bool

    (** {2 Proxy Unsafe} *)

    (** @see <https://www.rfc-editor.org/rfc/rfc7252#section-5.4.2>
    Section 5.4.2 of RFC 7252 *)

    val is_proxy_unsafe : t -> bool
    val is_safe_to_forward : t -> bool

    (** {1 CoAP Options} *)

    (** Helpers for constructing and accessing pre-defined CoAP
    numbers *)

    (** {2 Uri-Host, Uri-Port, Uri-Path, and Uri-Query} *)

    (** @see <https://www.rfc-editor.org/rfc/rfc7252#section-5.10.1>
  Section 5.10.1 of RFC 7252 *)

    val uri_host : string -> t
    val get_uri_host : t list -> string option
    val uri_port : int -> t
    val get_uri_port : t list -> int option
    val uri_path : string list -> t list
    val get_uri_path : t list -> string list
    val uri_query : string list -> t list
    val get_uri_query : t list -> string list
  end

  type t

  val code : t -> Code.t
  val token : t -> int option
  val options : t -> Option.t list
  val payload : t -> string option
  val pp : t Fmt.t

  (** {1 Constructor} *)

  val make :
    code:Code.t -> ?token:int -> options:Option.t list -> string option -> t

  (** {1 Parsers} *)

  val parser : int -> t Buf_read.parser
  val parser_framed : t Buf_read.parser

  (** {1 Writing} *)

  val write_framed : Buf_write.t -> t -> unit
end

(** {1 Transport Layers} *)

module Tcp : sig
  (** CoAP (Constrained Application Protocol) over TCP

      @see <https://www.rfc-editor.org/rfc/rfc8323> RFC 8323: CoAP
        (Constrained Application Protocol) over TCP, TLS, and WebSockets
   *)

  type t
  type handler = Message.t -> unit

  val init : Flow.two_way -> t
  val handle : sw:Switch.t -> handler -> t -> unit
  val send : t -> Message.t -> unit
end
