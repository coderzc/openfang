# syntax=docker/dockerfile:1

FROM buildpack-deps:noble AS builder

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /build

# 先 COPY 依赖文件（利用层缓存）
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY xtask ./xtask
COPY agents ./agents
COPY packages ./packages

# 编译
RUN cargo build --release --bin openfang

FROM buildpack-deps:noble AS runtime

# 安装额外工具（buildpack-deps 已有 curl, git, gcc, python3 基础）
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # Java
        default-jdk \
        # 系统工具
        vim nano htop tree jq \
        net-tools iputils-ping telnet dnsutils \
        zip unzip \
        # Docker
        docker.io \
    # 安装 Node.js
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    # 安装 Go
    && curl -fsSL https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | tar -C /usr/local -xzf - \
    && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    # 清理
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 环境变量
ENV PATH="/usr/local/go/bin:${PATH}"
ENV OPENFANG_HOME=/data

# COPY 编译产物
COPY --from=builder /build/target/release/openfang /usr/local/bin/
COPY --from=builder /build/agents /opt/openfang/agents

EXPOSE 4200
VOLUME /data

ENTRYPOINT ["openfang"]
CMD ["start"]
