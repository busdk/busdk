ARG GO_VERSION=1.26
FROM golang:${GO_VERSION}

ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=0.128.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates chromium fonts-liberation nodejs npm xz-utils \
    && (apt-get install -y --no-install-recommends docker-cli docker-compose || apt-get install -y --no-install-recommends docker.io docker-compose) \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium

RUN npm install -g "${CODEX_NPM_PACKAGE}@${CODEX_NPM_VERSION}" \
    && codex --version

RUN ln -sf /usr/local/go/bin/go /usr/local/bin/go \
    && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt \
    && rg_bin="$(find /usr/local/lib/node_modules/@openai -path '*/vendor/*/path/rg' -type f | head -n 1)" \
    && test -n "$rg_bin" \
    && ln -sf "$rg_bin" /usr/local/bin/rg

RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'if [ ! -d /workspace/bus-dev ]; then' \
    '  printf "%s\n" "bus-dev wrapper requires /workspace/bus-dev" >&2' \
    '  exit 127' \
    'fi' \
    'caller_dir=$(pwd)' \
    'cd /workspace/bus-dev' \
    'exec go run ./cmd/bus-dev -C "$caller_dir" "$@"' \
    > /usr/local/bin/bus-dev \
    && chmod +x /usr/local/bin/bus-dev
