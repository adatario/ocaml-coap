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

(define-public ocaml-thread-table
  (package
    (name "ocaml-thread-table")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri
               "https://github.com/ocaml-multicore/thread-table/releases/download/0.1.0/thread-table-0.1.0.tbz")
              (sha256
               (base32
                "0ywdjnyjpryfs2szvlm4mdvvcmq34q66jbh64rbfgrjn5z003kkp"))))
    (build-system dune-build-system)
    (propagated-inputs (list ocaml-odoc))
    (native-inputs (list ocaml-mdx ocaml-alcotest))
    (home-page "https://github.com/ocaml-multicore/thread-table")
    (synopsis "A lock-free thread-safe integer keyed hash table")
    (description #f)
    (license license:bsd-0)))

(define-public ocaml-domain-local-await
  (package
    (name "ocaml-domain-local-await")
    (version "0.2.1")
    (source (origin
              (method url-fetch)
              (uri
               "https://github.com/ocaml-multicore/domain-local-await/releases/download/0.2.1/domain-local-await-0.2.1.tbz")
              (sha256
               (base32
                "0viflr2252lcbdxk40sk4pqg1h8plqb5qim7v774kx34ba2nq31d"))))
    (build-system dune-build-system)
    (arguments `(#:tests? #f)) ; TODO
    (propagated-inputs (list ocaml-thread-table ocaml-odoc))
    (native-inputs (list ocaml-alcotest ocaml-mdx))
    (home-page "https://github.com/ocaml-multicore/domain-local-await")
    (synopsis "A scheduler independent blocking mechanism")
    (description #f)
    (license license:bsd-0)))

(define ocaml-eio
  (package
    (name "ocaml-eio")
    (version "0.10")
    (home-page "https://github.com/ocaml-multicore/eio")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url home-page)
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256 (base32
                "1dkbzdz6b6486pcnzwmisibgz2jr1mz15072yc8cfig0gxxh4y7p"))))
    (build-system dune-build-system)
    (arguments `(#:package "eio"))
    (propagated-inputs (list ocaml-bigstringaf
                             ocaml-cstruct
                             ocaml-lwt
                             ocaml-lwt-dllist
                             ocaml-logs
                             ocaml-optint
                             ocaml-psq
                             ocaml-fmt
                             ocaml-hmap
			     ocaml-domain-local-await
                             ocaml-mtime
                             ocaml-odoc))
    (native-inputs (list ocaml-astring
                         ocaml-crowbar
                         ocaml-alcotest
                         ocaml-mdx))
    (synopsis "Effect-based direct-style IO API for OCaml")
    (description "This package provides an effect-based IO API for multicore
OCaml with fibers.")
    (license license:isc)))

(define-public ocaml5.0-eio
  (package-with-ocaml5.0 ocaml-eio))

(define ocaml-eio-linux
  (package
    (inherit ocaml-eio)
    (name "ocaml-eio-linux")
    (arguments `(#:package "eio_linux"
		 ;; TODO
		 #:tests? #f))
    (propagated-inputs
     (list ocaml-eio
           ocaml-uring
           ocaml-logs
           ocaml-fmt))
    (native-inputs
     (list ocaml-mdx
           ocaml-alcotest
           ocaml-mdx))
    (synopsis "Linux backend for ocaml-eio")
    (description "@code{Eio_linux} provides a Linux io-uring backend for
@code{Ocaml Eio} APIs, plus a low-level API that can be used directly
(in non-portable code).")))

(define-public ocaml5.0-eio-linux
  (package-with-ocaml5.0 ocaml-eio-linux))

(define ocaml-eio-main
  (package
    (inherit ocaml-eio)
    (name "ocaml-eio-main")
    (arguments `(#:package "eio_main"
                 ;; tests require network
                 #:tests? #f))
    (propagated-inputs
     (list ocaml-eio
           ocaml-eio-linux))
    (native-inputs
     (list ocaml-mdx))
    (synopsis "Eio backend selector")
    (description "@code{Eio_main} selects an appropriate backend (e.g.
@samp{eio_linux} or @samp{eio_luv}), depending on your platform.")))

(define-public ocaml5.0-eio-main
  (package-with-ocaml5.0 ocaml-eio-main))

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


(define* (package-with-source p #:key source version (package-names '()))

  (define (transform p)
    (if (member (package-name p) package-names)

	(package
	  (inherit p)
	  (location (package-location p))
	  (version (if version version (package-version p)))
	  (source source))

	p))

  (define (cut? p)
    (not (or (eq? (package-build-system p) ocaml-build-system)
             (eq? (package-build-system p) dune-build-system))))

  ((package-mapping transform cut?) p))

(define-public ocaml-mtime-2.0.0
  (package
    (name "ocaml-mtime")
    (version "2.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://erratique.ch/software/mtime/releases/"
                                  "mtime-" version ".tbz"))
              (sha256
               (base32
                "1ss4w3qxsfp51d88r0j7dzqs05dbb1xdx11hn1jl9cvd03ma0g9z"))))
    (build-system ocaml-build-system)
    (native-inputs
     (list ocamlbuild opam))
    (propagated-inputs
     `(("topkg" ,ocaml-topkg)))
    (arguments
     `(#:tests? #f
       #:build-flags (list "build")
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))
    (home-page "https://erratique.ch/software/mtime")
    (synopsis "Monotonic wall-clock time for OCaml")
    (description "Access monotonic wall-clock time.  It measures time
spans without being subject to operating system calendar time adjustments.")
    (license license:isc)))

(define-public ocaml5.0-coap
  (package-with-ocaml5.0
   (package
     (name "ocaml-coap")
     (version "0.0.0")
     (home-page "https://github.com/adatario/ocaml-coap")
     (source (git-checkout (url (dirname (current-filename)))))
     (build-system dune-build-system)
     (propagated-inputs
      (list ocaml5.0-eio
	    ocaml5.0-eio-main))
     (native-inputs
      (list
       ;; Testing
       ocaml-alcotest
       ocaml-qcheck

       ;; CoAP dev tools
       libcoap
       netcat

       ;; OCaml dev tools
       ocaml-merlin
       ocaml-dot-merlin-reader))
     (synopsis #f)
     (description #f)
     (license license:isc))))

ocaml5.0-coap
