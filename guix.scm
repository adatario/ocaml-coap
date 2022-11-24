(use-modules
 (guix packages)
 (guix git)
 (guix build-system dune)
 (guix build-system ocaml)
 ((guix licenses) #:prefix license:)
 (gnu packages ocaml)
 (gnu packages libevent))

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
	   ocaml-dot-merlin-reader))
    (synopsis #f)
    (description #f)
    (license license:isc))))

ocaml5.0-eio-coap
