ARG GO_VERSION=1.26
FROM golang:${GO_VERSION}

ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=0.133.0
ARG GOPLS_VERSION=v0.20.0
ARG DELVE_VERSION=v1.25.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git make nodejs npm ripgrep xz-utils \
    && (apt-get install -y --no-install-recommends docker-cli docker-compose || apt-get install -y --no-install-recommends docker.io docker-compose) \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "${CODEX_NPM_PACKAGE}@${CODEX_NPM_VERSION}" \
    && codex --version

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
