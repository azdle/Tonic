Tonic is an [Elixir](http://elixir-lang.org)
[CoAP](https://tools.ietf.org/html/draft-ietf-core-coap) library.

# Status
This library is far from complete and so far it's purpose it more as a learning
tool for myself. I do hope to flesh this out into a full framework as I learn
more about Elixir and functional programming in general.

# Use
Below is the (modified) output of an interactive session that shows the use of
this library.

```
$ iex coap.ex 

iex(1)> Coap.Message.from_binary <<64,0,0,0>>
%Coap.Message{code: 0, id: 0, options: [], payload: "", token: "", type: 0,
 version: 1}
iex(2)> Coap.Message.from_binary <<97,69,188,144,112,68>> <> "abcd" <> <<255>> <> "temp = 22.5 C"

%Coap.Message{code: 69, id: 48272,
 options: [%Coap.Option{number: 4, value: "abcd"}], payload: "temp = 22.5 C",
 token: "p", type: 2, version: 1}

iex(3)> Coap.Message.from_binary <<97,69,188,144,112,68>> <> "abcd" <> <<255>> <> "temp = 22.5 C"
%Coap.Message{code: 69, id: 48272,
 options: [%Coap.Option{number: 4, value: "abcd"}], payload: "temp = 22.5 C",
 token: "p", type: 2, version: 1}
```