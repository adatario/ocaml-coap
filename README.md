# ocaml-coap

A OCaml implementation of the the Constrained Application Protocol (CoAP) as defined by [RFC 7252](https://www.rfc-editor.org/rfc/rfc7252) using [eio](https://github.com/ocaml-multicore/eio).

CoAP is a network transport protocol specialized for use with constrained nodes and constrained networks (e.g. low-power, lousy). CoAP provides a request/response interaction model similar to HTTP. However, CoAP can also be used for observing resources (see module [RFC 7641](https://www.rfc-editor.org/rfc/rfc7641)) and allows bi-directional requests.

Being optimized for small and constrained devices, CoAP is designed to have small implementations. This makes it suitable for usage in embedded OCaml applications (e.g. [MirageOS](https://mirage.io)) and other places where code size matters.

See also [the library interface](./src/coap/coap.mli).

## Status

Work-in-progress.

Currently only CoAP over TCP is supported (see [RFC 8323](https://www.rfc-editor.org/rfc/rfc8323)).

### TODOs

- [ ] CoAP over UDP
- [ ] Find nice abstraction for handling various transport layers
- [ ] Block-wise transport ([RFC 7959](https://www.rfc-editor.org/rfc/rfc7959))
- [ ] Observing resources ([RFC 7641](https://www.rfc-editor.org/rfc/rfc7641))
- [ ] Resource and Service discovery ([Section 7 of RFC 7252](https://www.rfc-editor.org/rfc/rfc7252#section-7))
- [ ] TLS/dTLS
- [ ] CoAP over WebSocket
- [ ] Tests

## See also

- [hyper-systems/ocaml-coap](https://github.com/hyper-systems/ocaml-coap): Another work-in-progress OCaml implementation.

## Development environment

```
guix time-machine -C channels.scm --disable-authentication -- shell -f -D guix.scm
```

## License

[ISC](./LICENSES/ISC.txt)
