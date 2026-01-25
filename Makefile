.DEFAULT_GOAL := help

GO ?= go

MODULES_DIR := .
BIN_DIR ?= bin

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
INSTALL ?= install

TOOLS := \
	bus \
	bus-accounts \
	bus-assets \
	bus-attachments \
	bus-bank \
	bus-budget \
	bus-entities \
	bus-inventory \
	bus-invoices \
	bus-journal \
	bus-payroll \
	bus-period \
	bus-reconcile \
	bus-reports \
	bus-validate \
	bus-vat \
	bus-filing \
	bus-filing-prh \
	bus-filing-vero

.PHONY: help init update upgrade status bootstrap build install clean distclean

help:
	@printf "BusDK superproject\n\n"
	@printf "Targets:\n"
	@printf "  init        Initialize and fetch all submodules\n"
	@printf "  update      Sync submodules to pinned commits\n"
	@printf "  upgrade     (maintainers) Advance pins to latest remotes\n"
	@printf "  status      Show pinned submodule SHAs\n"
	@printf "  build       Build all tools into ./%s\n" "$(BIN_DIR)"
	@printf "  install     Install tools into %s\n" "$(BINDIR)"
	@printf "  clean       Remove local build artifacts\n"
	@printf "  distclean   clean + deinitialize submodules\n"
	@printf "  bootstrap   init + build + install\n\n"
	@printf "Variables:\n"
	@printf "  GO=%s\n" "$(GO)"
	@printf "  BIN_DIR=%s\n" "$(BIN_DIR)"
	@printf "  PREFIX=%s\n" "$(PREFIX)"
	@printf "  BINDIR=%s\n\n" "$(BINDIR)"
	@printf "Example:\n"
	@printf "  make bootstrap\n"
	@printf "  make bootstrap PREFIX=/opt/busdk\n"

init:
	git submodule update --init --recursive

update:
	git submodule sync --recursive
	git submodule update --recursive

upgrade:
	git submodule sync --recursive
	git submodule update --remote --recursive

status:
	git submodule status --recursive

bootstrap: init build install

build:
	@set -eu; \
	mkdir -p "$(BIN_DIR)"; \
	for tool in $(TOOLS); do \
		mod="$(MODULES_DIR)/$$tool"; \
		printf "==> %s\n" "$$tool"; \
		( cd "$$mod" && GOBIN="$(abspath $(BIN_DIR))" "$(GO)" install ./cmd/$$tool ); \
	done

install: build
	@set -eu; \
	mkdir -p "$(BINDIR)"; \
	for tool in $(TOOLS); do \
		"$(INSTALL)" -m 0755 "$(BIN_DIR)/$$tool" "$(BINDIR)/$$tool"; \
	done

clean:
	rm -rf "$(BIN_DIR)"

distclean: clean
	git submodule deinit -f --all
