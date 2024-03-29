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
embedded OCaml applications (e.g. MirageOS) and other places wher code
size matters.

@see <https://www.rfc-editor.org/rfc/rfc7252> RFC 7252: The
Constrained Application Protocol (CoAP)

 *)

module Message : sig
  module Code : sig
    type t

    val equal : t -> t -> bool
    val class' : t -> int
    val detail : t -> int

    (** {1 Constructors} *)

    val make : int -> int -> t
    (** [make class' detail] returns the code with class [class'] and
        detail [detail]. *)

    (** {2 Empty} *)

    val empty : t

    (** {2 Request} *)

    val get : t
    val post : t
    val put : t
    val delete : t

    (** {2 Response} *)

    (** {3 Success} *)

    val created : t
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

  module Options : sig
    type t

    val equal : t -> t -> bool
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

    (** {1 Utilties} *)

    val filter_map : ?number:int -> (t -> 'a option) -> t list -> 'a list

    val filter_map_values :
      ?number:int -> (string -> 'a option) -> t list -> 'a list

    (** {2 Option Value Formats} *)

    val get_uint : string -> int option

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

    (** {1 Pretty Printing} *)

    val pp : t Fmt.t
  end

  type t

  val equal : t -> t -> bool
  val code : t -> Code.t
  val token : t -> string
  val options : t -> Options.t list
  val payload : t -> string option
  val pp : t Fmt.t

  (** {1 Constructor} *)

  val make :
    code:Code.t -> ?token:string -> options:Options.t list -> string option -> t
end

(** {1 Transport Layers} *)

module Udp : sig
  (** CoAP (Constrained Application Protocol) over UDP

      @see <https://www.rfc-editor.org/rfc/rfc7252> The Constrained
      Application Protocol (CoAP)
   *)

  type typ =
    | Confirmable
    | NonConfirmable
    | Acknowledgement
    | Reset
        (** CoAP message type. This allows a lightweight reliability mechanism.

      @see <https://www.rfc-editor.org/rfc/rfc7252#section-4> Section on Message Transmission in RFC 7252.
   *)

  type id = int
  (** Type for CoAP message ID *)

  val send :
    ?buffer:Buffer.t ->
    #Eio.Net.datagram_socket ->
    Eio.Net.Sockaddr.datagram ->
    typ ->
    id ->
    Message.t ->
    unit
  (** [send ~buffer socket addr typ id msg] sends the CoAP msg [msg]
      with message type [typ] and message ID to [addr] over [socket].

      The buffer [buffer] is used to serialize the CoAP message. If
      [buffer] is not provided a buffer of size 1024 bytes is
      allocated.
   *)

  val receive :
    ?buffer:Cstruct.t ->
    #Eio.Net.datagram_socket ->
    Eio.Net.Sockaddr.datagram * typ * id * Message.t
  (** [receive ~buffer socket] reads a single CoAP message from the socket [socket].

      The buffer [buffer] is used when receiving the datagram from the
      socket. If [buffer] is not provided a buffer of size 1024 bytes
      is allocated.
   *)

  (** {1 Message Serialization} *)

  val parser : int -> (typ * id * Message.t) Buf_read.parser
  (** [parser length] returns a parser that reads a single CoAP
  message of total length [length]. *)

  val write : Buf_write.t -> typ -> id -> Message.t -> unit
end

module Tcp : sig
  (** CoAP (Constrained Application Protocol) over TCP

      @see <https://www.rfc-editor.org/rfc/rfc8323> RFC 8323: CoAP
        (Constrained Application Protocol) over TCP, TLS, and WebSockets
   *)

  type t
  (** CoAP connection *)

  val init : ?max_message_size:int -> #Flow.two_way -> t
  (** [init ~max_message_size flow] initiates a CoAP connection over
      the TCP flow [flow]. *)

  val receive : t -> Message.t
  (** [receive t] reads a single message from the connection. *)

  val send : t -> Message.t -> unit
  (** [send t msg] sends the message [msg] over the connection [t]. *)

  (** {1 Message Serialization} *)

  val parser : Message.t Buf_read.parser
  val write : Buf_write.t -> Message.t -> unit
end

module Websocket : sig
  (** CoAP (Constrained Application Protocol) over WebSockets.

      @see <https://www.rfc-editor.org/rfc/rfc8323> RFC 8323: CoAP
        (Constrained Application Protocol) over TCP, TLS, and WebSockets
   *)

  (** {1 Message Serialization} *)

  val parser : int -> Message.t Buf_read.parser
  (** [parser length] returns a parser that reads a single CoAP
  message of total length [length]. *)

  val write : Buf_write.t -> Message.t -> unit
end
