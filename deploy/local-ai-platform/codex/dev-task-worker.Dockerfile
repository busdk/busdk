ARG GO_VERSION=1.26
FROM golang:${GO_VERSION}

ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=0.133.0
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
RUN chmod 0755 /usr/local/bin/busdk-dev-task-entrypoint

WORKDIR /workspace
ENTRYPOINT ["busdk-dev-task-entrypoint"]
CMD []
