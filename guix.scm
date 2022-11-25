(use-modules
 (guix packages)
 (guix git)
 (guix download)
 (guix git-download)
 (guix build-system gnu)
 (guix build-system dune)
 (guix build-system ocaml)
 ((guix licenses) #:prefix license:)
 (gnu packages ocaml)
 (gnu packages libevent)
 (gnu packages autotools)
 (gnu packages admin)
 (gnu packages base)
 (gnu packages check)
 (gnu packages pkg-config)
 (gnu packages tls))

(define-public libcoap
  (package
    (name "libcoap")
    (version "4.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
	     (url "https://github.com/obgm/libcoap")
	     (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1ywrbj4nr36g89cfj6j5vw3b612183g7sd93w6gmhfx9xjl5w1xi"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags '("--disable-documentation"
			   "--with-gnutls"
			   "--enable-tests"
			   "--enable-shared")))
    (native-inputs
     (list autoconf
           automake
           libtool
           pkg-config
	   which
	   cunit))
    (propagated-inputs
     (list gnutls))
    (synopsis "A C implementation of the Constrained Application
Protocol (RFC 7252)")
    (description "libcoap is a C implementation of a lightweight
application-protocol for devices that are constrained their resources
such as computing power, RF range, memory, bandwidth, or network
packet sizes.  This protocol, CoAP, is standardized by the IETF as RFC
7252. For further information related to CoAP, see
@uref{http://coap.technology}.")
    (home-page "https://libcoap.net/")
    (license license:bsd-2)))

(define-public ocaml5.0-eio-coap
  (package-with-ocaml5.0
   (package
    (name "ocaml-eio-coap")
    (version "0.0.0")
    (home-page "https://github.com/adatario/ocaml-eio-coap")
    (source (git-checkout (url (dirname (current-filename)))))
    (build-system dune-build-system)
    (propagated-inputs
     (list ocaml5.0-eio
	   ocaml5.0-eio-main
	   libuv))
    (native-inputs
     (list ocaml-merlin
	   ocaml-dot-merlin-reader
	   libcoap
	   netcat))
    (synopsis #f)
    (description #f)
    (license license:isc))))

ocaml5.0-eio-coap
