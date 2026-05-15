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
    'tool="$(basename "$0")"' \
    'module="/workspace/$tool"' \
    'cmd="./cmd/$tool"' \
    'if [ ! -d "$module" ]; then' \
    '  printf "%s\n" "$tool wrapper requires $module" >&2' \
    '  exit 127' \
    'fi' \
    'bin_dir="${BUSDK_TOOL_BIN_DIR:-/tmp/busdk-tools}"' \
    'bin="$bin_dir/$tool"' \
    'mkdir -p "$bin_dir"' \
    'if [ ! -x "$bin" ] || [ "${BUSDK_TOOL_REBUILD:-0}" = "1" ]; then' \
    '  (cd "$module" && go build -o "$bin" "$cmd")' \
    'fi' \
    'exec "$bin" "$@"' \
    > /usr/local/bin/busdk-go-tool \
    && chmod +x /usr/local/bin/busdk-go-tool \
    && cp /usr/local/bin/busdk-go-tool /usr/local/bin/bus \
    && cp /usr/local/bin/busdk-go-tool /usr/local/bin/bus-dev \
    && cp /usr/local/bin/busdk-go-tool /usr/local/bin/bus-gx \
    && cp /usr/local/bin/busdk-go-tool /usr/local/bin/bus-lint \
    && cp /usr/local/bin/busdk-go-tool /usr/local/bin/bus-notes
