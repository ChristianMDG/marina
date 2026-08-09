# ---- Stage 1 : build ----

    FROM ubuntu:22.04 AS builder
    
    RUN apt-get update && \
        apt-get install -y --no-install-recommends ocaml-nox make && \
        rm -rf /var/lib/apt/lists/*
    
    WORKDIR /build
    COPY . .
    
    RUN make server
    
    FROM ubuntu:22.04
    
    RUN useradd --create-home --shell /usr/sbin/nologin marina
    COPY --from=builder /build/marina-server /usr/local/bin/marina-server
    
    USER marina
    WORKDIR /home/marina
    
    ENV PORT=8080
    EXPOSE 8080
    
    CMD ["marina-server"]