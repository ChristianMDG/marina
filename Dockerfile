# ---- Stage 1 : build ----
FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends ocaml-nox make && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN make

# ---- Stage 2 : image finale ----
FROM ubuntu:22.04

RUN useradd --create-home --shell /usr/sbin/nologin marina
COPY --from=builder /build/marina /usr/local/bin/marina

USER marina
WORKDIR /home/marina

ENTRYPOINT ["marina"]
