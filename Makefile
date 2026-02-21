.DEFAULT_GOAL := help

SHELL ?= sh
GO ?= go
GOFLAGS ?=
CGO_ENABLED ?= 0
BUILD_STATIC ?= 1

BIN_DIR ?= bin

ifeq ($(strip $(HOME)),)
HOME_DIR := $(subst \,/,$(USERPROFILE))
else
HOME_DIR := $(HOME)
endif

PREFIX ?= $(HOME_DIR)/.local
BINDIR ?= $(PREFIX)/bin
INSTALL ?= install

MODULE_DIRS := $(sort $(foreach d,$(wildcard bus bus-*),$(if $(wildcard $(d)/Makefile),$(d),)))
SKIP_MODULES ?=
COMMA := ,
SKIP_PATTERNS := $(strip $(subst $(COMMA), ,$(SKIP_MODULES)))
MODULE_MAKE_VARS := BIN_DIR="$(abspath $(BIN_DIR))" PREFIX="$(PREFIX)" BINDIR="$(BINDIR)" GO="$(GO)" GOFLAGS="$(GOFLAGS)" CGO_ENABLED="$(CGO_ENABLED)" BUILD_STATIC="$(BUILD_STATIC)"

.PHONY: help init update upgrade status bootstrap test e2e build install clean distclean audit-cli-reachability audit-cli-reachability-full tidy-mods

help:
	@printf "BusDK superproject\n\n"
	@printf "Targets:\n"
	@printf "  init        Initialize and fetch all submodules\n"
	@printf "  update      Sync submodules to pinned commits\n"
	@printf "  upgrade     (maintainers) Advance pins to latest remotes\n"
	@printf "  status      Show pinned submodule SHAs\n"
	@printf "  test        Run module test suites\n"
	@printf "  e2e         Run module end-to-end suites (when target exists)\n"
	@printf "  build       Build all tools into ./%s\n" "$(BIN_DIR)"
	@printf "  install     Install tools into %s\n" "$(BINDIR)"
	@printf "  clean       Remove local build artifacts\n"
	@printf "  distclean   clean + deinitialize submodules\n"
	@printf "  audit-cli-reachability  Report module packages unreachable from current CLI mains\n"
	@printf "  audit-cli-reachability-full  Same audit + classify if unused packages are imported by other module CLIs\n"
	@printf "  tidy-mods   Run go mod tidy across all bus/bus-* modules\n"
	@printf "  bootstrap   init + build + install\n\n"
	@printf "Variables:\n"
	@printf "  GO=%s\n" "$(GO)"
	@printf "  GOFLAGS=%s\n" "$(GOFLAGS)"
	@printf "  CGO_ENABLED=%s\n" "$(CGO_ENABLED)"
	@printf "  BUILD_STATIC=%s\n" "$(BUILD_STATIC)"
	@printf "  BIN_DIR=%s\n" "$(BIN_DIR)"
	@printf "  PREFIX=%s\n" "$(PREFIX)"
	@printf "  BINDIR=%s\n\n" "$(BINDIR)"
	@printf "  SKIP_MODULES=%s\n\n" "$(SKIP_MODULES)"
	@printf "Example:\n"
	@printf "  make bootstrap\n"
	@printf "  make bootstrap PREFIX=/opt/busdk\n"
	@printf "  make bootstrap PREFIX=/c/busdk BINDIR=/c/busdk/bin\n"

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

test:
	@set -eu; \
	for mod in $(MODULE_DIRS); do \
		skip=0; \
		for pat in $(SKIP_PATTERNS); do \
			case "$$mod" in $$pat) skip=1;; esac; \
		done; \
		if [ "$$skip" -eq 1 ]; then \
			printf "==> %s (skipped)\n" "$$mod"; \
			continue; \
		fi; \
		if [ -f "$$mod/Makefile" ]; then \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" test $(MODULE_MAKE_VARS); \
		fi; \
		done

e2e:
	@set -eu; \
	ran=0; \
	for mod in $(MODULE_DIRS); do \
		skip=0; \
		for pat in $(SKIP_PATTERNS); do \
			case "$$mod" in $$pat) skip=1;; esac; \
		done; \
		if [ "$$skip" -eq 1 ]; then \
			printf "==> %s (skipped)\n" "$$mod"; \
			continue; \
		fi; \
		if [ ! -f "$$mod/Makefile" ]; then \
			printf "==> %s (skipped: no Makefile)\n" "$$mod"; \
			continue; \
		fi; \
		if ! "$(MAKE)" -C "$$mod" -n e2e >/dev/null 2>&1; then \
			printf "==> %s (skipped: no e2e target)\n" "$$mod"; \
			continue; \
		fi; \
		printf "==> %s\n" "$$mod"; \
		"$(MAKE)" -C "$$mod" e2e $(MODULE_MAKE_VARS); \
		ran=$$((ran + 1)); \
	done; \
	printf "e2e: ran %d module(s)\n" "$$ran"

build:
	@set -eu; \
	for mod in $(MODULE_DIRS); do \
		skip=0; \
		for pat in $(SKIP_PATTERNS); do \
			case "$$mod" in $$pat) skip=1;; esac; \
		done; \
		if [ "$$skip" -eq 1 ]; then \
			printf "==> %s (skipped)\n" "$$mod"; \
			continue; \
		fi; \
		if [ -f "$$mod/Makefile" ]; then \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" build $(MODULE_MAKE_VARS); \
		fi; \
	done

install:
	@set -eu; \
	for mod in $(MODULE_DIRS); do \
		skip=0; \
		for pat in $(SKIP_PATTERNS); do \
			case "$$mod" in $$pat) skip=1;; esac; \
		done; \
		if [ "$$skip" -eq 1 ]; then \
			printf "==> %s (skipped)\n" "$$mod"; \
			continue; \
		fi; \
		if [ -f "$$mod/Makefile" ]; then \
			bin_name=$${mod##*/}; \
			src="$$mod/bin/$$bin_name"; \
			dst="$(DESTDIR)$(BINDIR)/$$bin_name"; \
			if [ -f "$$src" ] && [ -f "$$dst" ] && [ "$$dst" -nt "$$src" ]; then \
				printf "==> %s (up-to-date)\n" "$$mod"; \
				continue; \
			fi; \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" install $(MODULE_MAKE_VARS); \
		fi; \
	done

clean:
	@set -eu; \
	for mod in $(MODULE_DIRS); do \
		skip=0; \
		for pat in $(SKIP_PATTERNS); do \
			case "$$mod" in $$pat) skip=1;; esac; \
		done; \
		if [ "$$skip" -eq 1 ]; then \
			printf "==> %s (skipped)\n" "$$mod"; \
			continue; \
		fi; \
		if [ -f "$$mod/Makefile" ]; then \
			printf "==> %s\n" "$$mod"; \
			"$(MAKE)" -C "$$mod" clean $(MODULE_MAKE_VARS); \
		fi; \
	done
	rm -rf "$(BIN_DIR)"

distclean: clean
	git submodule deinit -f --all

audit-cli-reachability:
	./scripts/find-unreachable-cli-packages.sh

audit-cli-reachability-full:
	./scripts/find-unreachable-cli-packages.sh --classify-outside

tidy-mods:
	./scripts/tidy-all-mods.sh
