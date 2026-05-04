FROM golang:1.24

ARG CODEX_NPM_PACKAGE=@openai/codex
ARG CODEX_NPM_VERSION=0.128.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates nodejs npm \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "${CODEX_NPM_PACKAGE}@${CODEX_NPM_VERSION}" \
    && codex --version

RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'if [ ! -d /workspace/bus-dev ]; then' \
    '  printf "%s\n" "bus-dev wrapper requires /workspace/bus-dev" >&2' \
    '  exit 127' \
    'fi' \
    'cd /workspace/bus-dev' \
    'exec go run ./cmd/bus-dev "$@"' \
    > /usr/local/bin/bus-dev \
    && chmod +x /usr/local/bin/bus-dev
