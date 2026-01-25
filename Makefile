.DEFAULT_GOAL := help

GO ?= go

BIN_DIR ?= bin

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
INSTALL ?= install

MODULE_DIRS := $(sort $(foreach d,$(wildcard bus bus-*),$(if $(wildcard $(d)/Makefile),$(d),)))

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
	for mod in $(MODULE_DIRS); do \
		if [ -f "$$mod/Makefile" ]; then \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" build \
			BIN_DIR="$(abspath $(BIN_DIR))" \
			PREFIX="$(PREFIX)" \
			BINDIR="$(BINDIR)" \
			GO="$(GO)" \
			GOFLAGS="$(GOFLAGS)" \
			CGO_ENABLED="$(CGO_ENABLED)"; \
		fi; \
	done

install:
	@set -eu; \
	for mod in $(MODULE_DIRS); do \
		if [ -f "$$mod/Makefile" ]; then \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" install \
			BIN_DIR="$(abspath $(BIN_DIR))" \
			PREFIX="$(PREFIX)" \
			BINDIR="$(BINDIR)" \
			GO="$(GO)" \
			GOFLAGS="$(GOFLAGS)" \
			CGO_ENABLED="$(CGO_ENABLED)"; \
		fi; \
	done

clean:
	@set -eu; \
	for mod in $(MODULE_DIRS); do \
		if [ -f "$$mod/Makefile" ]; then \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" clean \
			BIN_DIR="$(abspath $(BIN_DIR))" \
			PREFIX="$(PREFIX)" \
			BINDIR="$(BINDIR)" \
			GO="$(GO)" \
			GOFLAGS="$(GOFLAGS)" \
			CGO_ENABLED="$(CGO_ENABLED)"; \
		fi; \
	done
	rm -rf "$(BIN_DIR)"

distclean: clean
	git submodule deinit -f --all
