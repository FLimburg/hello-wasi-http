FROM rust:1-slim-buster

RUN apt update && apt install -y curl pkg-config libssl-dev git
RUN rustup component add rustfmt

ENTRYPOINT ["/bin/bash"]
