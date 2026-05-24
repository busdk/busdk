FROM node:24-bookworm

ARG GO_VERSION=1.26.3
ARG TARGETARCH

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

RUN npm install -g @openai/codex@latest

RUN go install golang.org/x/tools/gopls@latest \
 && go install golang.org/x/tools/cmd/goimports@latest \
 && go install golang.org/x/vuln/cmd/govulncheck@latest \
 && go install github.com/go-delve/delve/cmd/dlv@latest \
 && go install honnef.co/go/tools/cmd/staticcheck@latest

WORKDIR /workspace
CMD ["/bin/bash"]
