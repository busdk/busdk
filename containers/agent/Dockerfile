FROM node:24-bookworm

ARG GO_VERSION=1.26.3
ARG TARGETARCH
ARG CODEX_VERSION=0.135.0
ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=
ARG CODEX_LINUX_AMD64_SHA256=a15e7dad657da4a0e120eede29556fee6d50e8c919759cc2ecba3c99099363e2
ARG CODEX_LINUX_ARM64_SHA256=568bce1d593ef25ffdf5549369a8606085652294646a5c4961547a894ea2f76d

ENV DEBIAN_FRONTEND=noninteractive \
    GOBIN=/usr/local/bin \
    PATH=/usr/local/go/bin:/usr/local/bin:${PATH}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      make \
      openssh-client \
      procps \
      ripgrep \
      unzip \
 && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
      amd64) go_arch='amd64'; go_sha256='2b2cfc7148493da5e73981bffbf3353af381d5f93e789c82c79aff64962eb556' ;; \
      arm64) go_arch='arm64'; go_sha256='9d89a3ea57d141c2b22d70083f2c8459ba3890f2d9e818e7e933b75614936565' ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tgz \
 && echo "${go_sha256}  /tmp/go.tgz" | sha256sum -c - \
 && rm -rf /usr/local/go \
 && tar -C /usr/local -xzf /tmp/go.tgz \
 && rm -f /tmp/go.tgz

RUN set -eu; \
    if [ -n "$CODEX_NPM_VERSION" ]; then \
      npm install -g "${CODEX_NPM_PACKAGE}@${CODEX_NPM_VERSION}"; \
      expected_version="$CODEX_NPM_VERSION"; \
    else \
      case "${TARGETARCH:-amd64}" in \
        amd64|x86_64) codex_arch=x86_64; codex_sha="$CODEX_LINUX_AMD64_SHA256" ;; \
        arm64|aarch64) codex_arch=aarch64; codex_sha="$CODEX_LINUX_ARM64_SHA256" ;; \
        *) echo "unsupported TARGETARCH for Codex: ${TARGETARCH:-unset}" >&2; exit 1 ;; \
      esac; \
      codex_archive="/tmp/codex-${CODEX_VERSION}-${codex_arch}.tar.gz"; \
      curl -fsSL "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${codex_arch}-unknown-linux-musl.tar.gz" -o "$codex_archive"; \
      echo "${codex_sha}  ${codex_archive}" | sha256sum -c -; \
      tar -C /usr/local/bin -xzf "$codex_archive"; \
      mv "/usr/local/bin/codex-${codex_arch}-unknown-linux-musl" /usr/local/bin/codex; \
      chmod 0755 /usr/local/bin/codex; \
      rm -f "$codex_archive"; \
      expected_version="$CODEX_VERSION"; \
    fi; \
    codex --version | grep -q "$expected_version"

RUN go install golang.org/x/tools/gopls@latest \
 && go install golang.org/x/tools/cmd/goimports@latest \
 && go install golang.org/x/vuln/cmd/govulncheck@latest \
 && go install github.com/go-delve/delve/cmd/dlv@latest \
 && go install honnef.co/go/tools/cmd/staticcheck@latest

WORKDIR /workspace
CMD ["/bin/bash"]
