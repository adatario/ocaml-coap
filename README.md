# ocaml-coap

A OCaml implementation of the the Constrained Application Protocol (CoAP) as defined by [RFC 7252](https://www.rfc-editor.org/rfc/rfc7252) using [eio](https://github.com/ocaml-multicore/eio).

CoAP is a network transport protocol specialized for use with constrained nodes and constrained networks (e.g. low-power, lousy). CoAP provides a request/response interaction model similar to HTTP. However, CoAP can also be used for observing resources (see module [RFC 7641](https://www.rfc-editor.org/rfc/rfc7641)) and allows bi-directional requests.

Being optimized for small and constrained devices, CoAP is designed to have small implementations. This makes it suitable for usage in embedded OCaml applications (e.g. [MirageOS](https://mirage.io)) and other places where code size matters.

See also [the library interface](./src/coap/coap.mli).

## Examples

A simple CoAP server and client is provided in the [examples](./examples) folder.

Start a server:

```
$ dune exec examples/tcp_server.exe
+New connection from: tcp:127.0.0.1:49220
+RECV: <CoAP code: 0.01
+            token: None
+            options:
+             [{number: 3;
+               value: 6c6f 6361 6c68 6f73 74};
+              {number: 11;
+               value: 6869};
+              {number: 11;
+               value: 6f63 616d 6c2d 636f 6170}]
+            payload: 4865 6c6c 6f20 436f 4150 2120 3132 3332 3133 2031 3233
+             3132 3320 3132 3331 3233>
+Uri-Path: hi/ocaml-coap
+SEND: <CoAP code: 2.05
+            token: None
+            options: []
+            payload: 4869 2063 6f61 702d 636c 6965 6e74 21>
```

Use the [libcoap](https://libcoap.net/) `coap-client` tool (provided in the Guix development environment) to make a request:

```
 $ coap-client -m get -e "Hello ocaml-coap!" coap+tcp://localhost:5683/hi/ocaml-coap
Hi coap-client!
```

## Status

Work-in-progress.

Currently only CoAP over TCP is supported (see [RFC 8323](https://www.rfc-editor.org/rfc/rfc8323)).

### TODOs

- [ ] CoAP over UDP
- [ ] TCP connection signaling messages (ping, pong, etc.)
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
guix time-machine -C channels.scm --disable-authentication -- shell -Df guix.scm
```

## License

[ISC](./LICENSES/ISC.txt)
