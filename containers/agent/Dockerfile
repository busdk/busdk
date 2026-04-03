FROM node:24-bookworm

ARG GO_VERSION=1.26.1
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
      amd64) go_arch='amd64'; go_sha256='031f088e5d955bab8657ede27ad4e3bc5b7c1ba281f05f245bcc304f327c987a' ;; \
      arm64) go_arch='arm64'; go_sha256='a290581cfe4fe28ddd737dde3095f3dbeb7f2e4065cab4eae44dfc53b760c2f7' ;; \
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
