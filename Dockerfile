# Build environment for bolt package builds.
# Ubuntu 22.04 is required for Yocto Kirkstone compatibility.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      gawk wget git diffstat unzip texinfo \
      gcc build-essential chrpath socat cpio \
      python3 python3-pip python3-pexpect \
      xz-utils debianutils iputils-ping \
      python3-git python3-jinja2 python3-subunit \
      libegl1-mesa libsdl1.2-dev mesa-common-dev \
      zstd liblz4-tool file locales libacl1 xterm \
      curl ca-certificates gnupg \
      clang libclang-dev pkg-config \
      automake autoconf libtool libssl-dev \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# tomllib is stdlib in Python 3.11+; Ubuntu 22.04 ships Python 3.10 so we
# install the tomli backport.
RUN pip3 install --no-cache-dir tomli

RUN curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
      -o /usr/local/bin/repo \
    && chmod +x /usr/local/bin/repo

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --no-modify-path && \
    export PATH="/root/.cargo/bin:${PATH}" && \
    git clone --depth 1 https://github.com/rdkcentral/ralfpack /tmp/ralfpack && \
    cd /tmp/ralfpack && \
    cargo build --release && \
    install -m 0755 target/release/ralfpack /usr/bin/ralfpack && \
    rm -rf /tmp/ralfpack /root/.cargo /root/.rustup

ARG UID=1000
ARG GID=1000
RUN groupadd -g "${GID}" builder && \
    useradd -m -u "${UID}" -g "${GID}" -s /bin/bash builder

USER builder
WORKDIR /build

ENTRYPOINT ["bash",  "./entrypoint.sh"]
