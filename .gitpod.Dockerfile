FROM rust:1-slim-buster

RUN apt update && \
    apt install -y curl pkg-config libssl-dev git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 
RUN rustup component add rustfmt && \
    cargo install wasmtime-cli wasm-tools cargo-component

ENTRYPOINT ["/bin/bash"]
