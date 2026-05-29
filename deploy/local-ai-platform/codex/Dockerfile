ARG GO_VERSION=1.26
FROM golang:${GO_VERSION}

ARG TARGETARCH
ARG CODEX_VERSION=0.135.0
ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=
ARG CODEX_LINUX_AMD64_SHA256=a15e7dad657da4a0e120eede29556fee6d50e8c919759cc2ecba3c99099363e2
ARG CODEX_LINUX_ARM64_SHA256=568bce1d593ef25ffdf5549369a8606085652294646a5c4961547a894ea2f76d
ARG GOPLS_VERSION=v0.20.0
ARG DELVE_VERSION=v1.25.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git make nodejs npm ripgrep xz-utils \
    && (apt-get install -y --no-install-recommends docker-cli docker-compose || apt-get install -y --no-install-recommends docker.io docker-compose) \
    && rm -rf /var/lib/apt/lists/*

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

COPY codex-appserver-stdio.sh /usr/local/bin/codex-appserver-stdio
RUN chmod 0755 /usr/local/bin/codex-appserver-stdio

RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'workspace_root=${BUSDK_WORKSPACE_ROOT:-/workspace}' \
    'refresh_script=$workspace_root/scripts/busdk-refresh-tools.sh' \
    'if [ -x "$refresh_script" ]; then' \
    '  "$refresh_script" --refresh-only' \
    'fi' \
    'if [ "$#" -eq 0 ]; then' \
    '  exec /bin/sh' \
    'fi' \
    'exec "$@"' \
    > /usr/local/bin/busdk-refresh-tools \
    && chmod +x /usr/local/bin/busdk-refresh-tools

ENTRYPOINT ["busdk-refresh-tools"]
