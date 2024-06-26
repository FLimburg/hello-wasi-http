# 👋 Hello `wasmtime`

This section of the tutorial introduces [wasmtime][wasmtime], a WebAssembly (Wasm) runtime and one of the [Bytecode Alliance][bca]'s reference implementations for the WebAssembly System Interface ([WASI](https://wasi.dev/)) standards[^1].

In this workshop, we're going to:
- Clone an example repository,
- Build a WebAssembly component
- Serve web traffic with our component using `wasmtime`.

[wasmtime]: https://wasmtime.dev
[bca]: https://bytecodealliance.org

## 0. TL/DR

This Readme originates from https://github.com/cosmonic-labs/kubecon2024-eu-wasm-workshop and has been implemented as a gitpod.
Just open in gitpod.io and everything will setup and run on it's own

## 📦 1. Setup

> [!NOTE]
> This first example is Rust-focused, but we'll move onto working with other languages (Go, TypeScript, Python) in a later tutorial stage.

### 1.1 🐳 Set up docker container

To get started quickly, if you have `docker` installed, you can start a container:

```console
docker run --rm -it rust:1-slim-buster
```

Once your container has loaded up, install the basic dependencies for the demo:

```console
apt update && apt install -y curl pkg-config libssl-dev git
```

If you'd like to use our `setup.Dockerfile`, run the following (once you've checked out this repository):

```console
docker build --tag wasm-workshop --file setup.Dockerfile .
docker run --rm -it wasm-workshop
```

### 1.1 (optional) 🦀 Install Rust toolchain natively

**This step is only necessary if you're *not* using `docker`**

As this demo will be working primarily in [Rust][rust], you'll need to install the Rust language toolchain.

You can find out [how to install Rust from rust-lang.org][rust-install].

[rust]: https://rust-lang.org
[rust-install]: https://www.rust-lang.org/tools/install

### 1.2 ⬇️ Clone Dan Gohman's [`sunfishcode/hello-wasi-http`][github-sunfishcode/hello-wasi-http] Repository

You can clone the repository with `git`:

```console
git clone https://github.com/sunfishcode/hello-wasi-http.git
```

[github-sunfishcode/hello-wasi-http]: https://github.com/sunfishcode/hello-wasi-http/

### 1.3 🏗️ Install `wasmtime` and related tools

Before we can build WebAssembly components in Rust, we'll need to install some Rust ecosystem tooling:

Here is some information on the tools we'll be installing

| Tool                                 | Purpose                                                                                                                                                   |
|--------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`wasmtime`][wasmtime]               | Leading WebAssembly runtime implementation, developed by the [Bytecode Alliance][bca], which supports basic WebAssembly and many more advanced standards. |
| [`wasm-tools`][wasm-tools]           | Tooling for manipulating and modifying WebAssembly binaries and more.                                                                                     |
| [`cargo-component`][cargo-component] | Rust CLI for building WebAssembly components with Rust                                                                                                    |

We can install all the tooling we'll need with [`cargo`][cargo], the package ("crate") manager of the Rust toolchain:

```console
cargo install wasmtime-cli wasm-tools cargo-component
```

[cargo]: https://doc.rust-lang.org/book/ch01-03-hello-cargo.html
[wasm-tools]: https://github.com/bytecodealliance/wasm-tools
[cargo-component]: https://github.com/bytecodealliance/cargo-component

## 2. ⁉️What the WIT

Here we'll learn about the [WebAssembly Interface Types specification][wit-spec], which helps us build and connect components with declarative, high level types.

<details>
<summary> 🗺️ A brief introduction to WIT</summary>

A brief introduction to WIT:

```wit
package local:demo; # <namespace>:<package>

interface host {
  log: func(msg: string);
}
```

This is a WIT interface that defines a namespace (`local`), and a package (`demo`) which contains *one* interface (`host`).

The `host` interface consists of *one* function (`log`) which accepts a single argument (`msg`, of type `string`) and does not return anything.

</details>

### 2.1 Define the WIT

From the [**`hello-wasi-http`**][github-sunfishcode/hello-wasi-http] repository you cloned locally, take a look at the WebAssembly Interface Types in [`wit/world.wit`](https://github.com/sunfishcode/hello-wasi-http/blob/main/wit/world.wit):

```wit
package sunfishcode:hello-wasi-http;

world target-world {
  include wasi:http/proxy@0.2.0;
}
```

This WIT definition defines a `world` called `target-world` which sets all of the interfaces (and functions) that the component we're about to build will import and export.

To enable our component to handle incoming HTTP requests, we're `include`ing the `wasi:http/proxy` interface (`<namespace>:<package>/<interface>`), at version `0.2.0`. This interface includes a shareable implementation for handling HTTP requests.

WIT information (the `world`, `interface`s, etc) is embedded into every WebAssembly component you build; you can inspect Wasm components to see exactly what interfaces they implement are before running them.

> [!TIP]
> **🔐 Gamechanger for security**
>
> Interfaces are like the concept of [capabilities][wiki-capabilities], whch we can use with fine-grained security controls to make our execution environments safe.
>
> By inspecting interfaces, we can understand a component *without* seeing or executing the code.
> Think of the tools we have to inspect containers, their contents, and what they do, it's very difficult to inspect binaries and containers for what they'll do at runtime before running them.

Feel free to take a look in [`src/lib.rs`](https://github.com/sunfishcode/hello-wasi-http/blob/main/src/lib.rs#L12) as well, where you can find the implementation code for this component directly using the WASI interface.

```rust
// ...imports

impl bindings::exports::wasi::http::incoming_handler::Guest for Component {
    fn handle(_request: IncomingRequest, outparam: ResponseOutparam) {
        let hdrs = Fields::new();
        let resp = OutgoingResponse::new(hdrs);
        let body = resp.body().expect("outgoing response");

        ResponseOutparam::set(outparam, Ok(resp));

        let out = body.write().expect("outgoing stream");
        out.blocking_write_and_flush(b"Hello, wasi:http/proxy worldddd!\n")
            .expect("writing response");

        drop(out);
        OutgoingBody::finish(body, None).unwrap();
    }
}
```

This looks pretty similar in each language, and the use of the interface directly here is a good learning exercise.[^2]

[wit-spec]: https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md
[wiki-capabilities]: https://en.wikipedia.org/wiki/Capability-based_security

## 🛠️Build your component

Building your component is similar to building a Rust binary, simply run:

```console
cargo component build
```

This will create a component in `target/wasm32-wasi/debug`, you can use the **wasm-tools** CLI to inspect its wit:

```console
wasm-tools component wit target/wasm32-wasi/debug/hello_wasi_http.wasm
```

You should see output like the following (without syntax highlighting):

```wit
package root:component;

world root {
  import wasi:io/error@0.2.0;
  import wasi:io/streams@0.2.0;
  import wasi:cli/stdout@0.2.0;
  import wasi:cli/stderr@0.2.0;
  import wasi:cli/stdin@0.2.0;
  import wasi:http/types@0.2.0;

  export wasi:http/incoming-handler@0.2.0;
}
```

As you can see, this component **`import`**s standard libraries for IO and standard output/error/in, and **`export`**s the HTTP incoming handler.

Based on only this information we know that this component will _never_ be able to access files, make web requests of its own, run arbitrary commands, etc without ever looking at the source code.

## 👟 Run your component

You can run your component using **`wasmtime serve`**, which provides the implementation for `wasi:http`, `wasi:io`, `wasi:cli` and others to the WebAssembly component:

```console
wasmtime serve -Scommon ./target/wasm32-wasi/debug/hello_wasi_http.wasm
```

In another terminal, you can run `curl` and see the hello statement we've written:

```console
curl localhost:8080
```

#### Footnotes

[^1]: [jco](https://github.com/bytecodealliance/jco), a NodeJS runtime and JavaScript tooling project, is another reference implementation for WASI.
[^2]: There are multiple tools that abstract this interface usage, like [wasm-http-tools](https://github.com/yoshuawuyts/wasm-http-tools) which supports generating a component from OpenAPI / Swagger specifications.
