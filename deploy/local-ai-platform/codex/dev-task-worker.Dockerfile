ARG GO_VERSION=1.26
FROM golang:${GO_VERSION}

ARG TARGETARCH
ARG CODEX_VERSION=0.134.0
ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=
ARG CODEX_LINUX_AMD64_SHA256=e54b983c3ab5ca992da8edde83bb29a545761a72c4fa39f18a165d9e792e1c71
ARG CODEX_LINUX_ARM64_SHA256=8e066f998111eb8b44250ac11df004daa07fadf276c5942a7183cb8e421091a3
ARG GOPLS_VERSION=v0.20.0
ARG DELVE_VERSION=v1.25.2

LABEL org.opencontainers.image.title="BusDK dev-task worker"
LABEL org.opencontainers.image.description="Image-backed bus-integration-dev-task worker runtime without a mounted BusDK source checkout"
LABEL org.opencontainers.image.source="https://github.com/busdk/busdk"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates chromium curl fonts-liberation git make nodejs npm openssh-client ripgrep xz-utils \
    && (apt-get install -y --no-install-recommends docker-cli docker-compose || apt-get install -y --no-install-recommends docker.io docker-compose) \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium
ENV BUSDK_WORKSPACE_ROOT=/workspace

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

RUN ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

RUN GOBIN=/usr/local/bin go install "golang.org/x/tools/gopls@${GOPLS_VERSION}" \
    && gopls version | grep -q "${GOPLS_VERSION}" \
    && gopls mcp -instructions >/usr/local/share/gopls-mcp-instructions.md \
    && test -s /usr/local/share/gopls-mcp-instructions.md

RUN GOBIN=/usr/local/bin go install "github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION}" \
    && dlv version | grep -q "Version: ${DELVE_VERSION#v}" \
    && dlv dap --help >/usr/local/share/dlv-dap-help.txt \
    && grep -qi "dap" /usr/local/share/dlv-dap-help.txt

COPY dist-bin/ /usr/local/bin/

RUN set -eu; \
    for bin in curl git make ssh docker go gofmt rg codex gopls dlv; do \
      command -v "$bin" >/dev/null; \
    done; \
    for bin in /usr/local/bin/bus* /usr/local/bin/aiz* /usr/local/bin/unaiz; do \
      [ -e "$bin" ] || continue; \
      chmod 0755 "$bin"; \
    done; \
    for bin in bus bus-dev bus-integration-dev-task bus-lint bus-notes bus-operator-token; do \
      command -v "$bin" >/dev/null; \
    done; \
    bus-integration-dev-task --help >/usr/local/share/bus-integration-dev-task-help.txt; \
    test -s /usr/local/share/bus-integration-dev-task-help.txt

COPY deploy/local-ai-platform/codex/dev-task-worker-entrypoint.sh /usr/local/bin/busdk-dev-task-entrypoint
COPY deploy/local-ai-platform/codex/codex-appserver-stdio.sh /usr/local/bin/codex-appserver-stdio
RUN chmod 0755 /usr/local/bin/busdk-dev-task-entrypoint /usr/local/bin/codex-appserver-stdio

WORKDIR /workspace
ENTRYPOINT ["busdk-dev-task-entrypoint"]
CMD []
