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

MODULE_DIRS := $(sort $(foreach d,$(wildcard bus aiz bus-*),$(if $(wildcard $(d)/Makefile),$(d),)))
SKIP_MODULES ?=
TEST_SCOPE ?= changed
CHANGED_MODULES ?=
ROOT_SELFTEST ?= 1
COMMA := ,
SKIP_PATTERNS := $(strip $(subst $(COMMA), ,$(SKIP_MODULES)))
MODULE_MAKE_VARS := BIN_DIR="$(abspath $(BIN_DIR))" PREFIX="$(PREFIX)" BINDIR="$(BINDIR)" GO="$(GO)" GOFLAGS="$(GOFLAGS)" CGO_ENABLED="$(CGO_ENABLED)" BUILD_STATIC="$(BUILD_STATIC)"

.PHONY: help init update upgrade status bootstrap test e2e build install clean distclean audit-cli-reachability audit-cli-reachability-full tidy tidy-mods superproject-selftest print-test-modules print-e2e-modules

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
	@printf "  tidy        Run make tidy across all bus/bus-* modules\n"
	@printf "  tidy-mods   Alias for tidy\n"
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
	@printf "  TEST_SCOPE=%s\n" "$(TEST_SCOPE)"
	@printf "  CHANGED_MODULES=%s\n\n" "$(CHANGED_MODULES)"
	@printf "Example:\n"
	@printf "  make bootstrap\n"
	@printf "  make bootstrap PREFIX=/opt/busdk\n"
	@printf "  make bootstrap PREFIX=/c/busdk BINDIR=/c/busdk/bin\n"
	@printf "  make test TEST_SCOPE=all\n"
	@printf "  make e2e CHANGED_MODULES='bus-reports bus-bank'\n"

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

superproject-selftest:
	@bash ./tests/superproject/test_changed_scope.sh

print-test-modules:
	@set -eu; \
	scope="$(TEST_SCOPE)"; \
	case "$$scope" in \
		all|changed) ;; \
		*) printf "invalid TEST_SCOPE: %s\n" "$$scope" >&2; exit 2;; \
	esac; \
	changed_modules="$(CHANGED_MODULES)"; \
	if [ "$$scope" = "changed" ] && [ -z "$$changed_modules" ]; then \
		changed_modules="$$(git status --porcelain --ignore-submodules=none | awk '\
			{ \
				path = substr($$0, 4); \
				sub(/^[[:space:]]+/, "", path); \
				if (index(path, " -> ") > 0) path = substr(path, index(path, " -> ") + 4); \
				if (path ~ /^aiz(\/|$$)/) print "aiz"; \
				else if (path ~ /^bus(\/|$$)/) print "bus"; \
				else if (index(path, "bus-") == 1) { split(path, parts, "/"); print parts[1]; } \
			} \
		' | awk '!seen[$$0]++')"; \
	fi; \
	for mod in $(MODULE_DIRS); do \
		selected=1; \
		if [ "$$scope" = "changed" ]; then \
			selected=0; \
			for chosen in $$changed_modules; do \
				if [ "$$mod" = "$$chosen" ]; then selected=1; break; fi; \
			done; \
		fi; \
		if [ "$$selected" -ne 1 ]; then \
			continue; \
		fi; \
		skip=0; \
		for pat in $(SKIP_PATTERNS); do \
			case "$$mod" in $$pat) skip=1;; esac; \
		done; \
		if [ "$$skip" -eq 1 ]; then \
			continue; \
		fi; \
		if [ -f "$$mod/Makefile" ]; then \
			printf "%s\n" "$$mod"; \
		fi; \
	done

print-e2e-modules:
	@set -eu; \
	for mod in $$("$(MAKE)" -s print-test-modules TEST_SCOPE="$(TEST_SCOPE)" CHANGED_MODULES="$(CHANGED_MODULES)" SKIP_MODULES="$(SKIP_MODULES)"); do \
		if ! "$(MAKE)" -C "$$mod" -n e2e >/dev/null 2>&1; then \
			continue; \
		fi; \
		printf "%s\n" "$$mod"; \
	done

test:
	@set -eu; \
	if [ "$(ROOT_SELFTEST)" = "1" ]; then \
		"$(MAKE)" superproject-selftest; \
	fi; \
	scope="$(TEST_SCOPE)"; \
	case "$$scope" in \
		all|changed) ;; \
		*) printf "invalid TEST_SCOPE: %s\n" "$$scope" >&2; exit 2;; \
	esac; \
	changed_modules="$(CHANGED_MODULES)"; \
	if [ "$$scope" = "changed" ] && [ -z "$$changed_modules" ]; then \
		changed_modules="$$(git status --porcelain --ignore-submodules=none | awk '\
			{ \
				path = substr($$0, 4); \
				sub(/^[[:space:]]+/, "", path); \
				if (index(path, " -> ") > 0) path = substr(path, index(path, " -> ") + 4); \
				if (path ~ /^aiz(\/|$$)/) print "aiz"; \
				else if (path ~ /^bus(\/|$$)/) print "bus"; \
				else if (index(path, "bus-") == 1) { split(path, parts, "/"); print parts[1]; } \
			} \
		' | awk '!seen[$$0]++')"; \
	fi; \
	ran=0; \
	for mod in $(MODULE_DIRS); do \
		selected=1; \
		if [ "$$scope" = "changed" ]; then \
			selected=0; \
			for chosen in $$changed_modules; do \
				if [ "$$mod" = "$$chosen" ]; then selected=1; break; fi; \
			done; \
		fi; \
		if [ "$$selected" -ne 1 ]; then \
			continue; \
		fi; \
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
			ran=$$((ran + 1)); \
		fi; \
	done; \
	if [ "$$ran" -eq 0 ]; then \
		printf "test: no selected modules\n"; \
	else \
		printf "test: ran %d module(s)\n" "$$ran"; \
	fi

e2e:
	@set -eu; \
	scope="$(TEST_SCOPE)"; \
	case "$$scope" in \
		all|changed) ;; \
		*) printf "invalid TEST_SCOPE: %s\n" "$$scope" >&2; exit 2;; \
	esac; \
	changed_modules="$(CHANGED_MODULES)"; \
	if [ "$$scope" = "changed" ] && [ -z "$$changed_modules" ]; then \
		changed_modules="$$(git status --porcelain --ignore-submodules=none | awk '\
			{ \
				path = substr($$0, 4); \
				sub(/^[[:space:]]+/, "", path); \
				if (index(path, " -> ") > 0) path = substr(path, index(path, " -> ") + 4); \
				if (path ~ /^aiz(\/|$$)/) print "aiz"; \
				else if (path ~ /^bus(\/|$$)/) print "bus"; \
				else if (index(path, "bus-") == 1) { split(path, parts, "/"); print parts[1]; } \
			} \
		' | awk '!seen[$$0]++')"; \
	fi; \
	ran=0; \
	for mod in $(MODULE_DIRS); do \
		selected=1; \
		if [ "$$scope" = "changed" ]; then \
			selected=0; \
			for chosen in $$changed_modules; do \
				if [ "$$mod" = "$$chosen" ]; then selected=1; break; fi; \
			done; \
		fi; \
		if [ "$$selected" -ne 1 ]; then \
			continue; \
		fi; \
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
	if [ "$$ran" -eq 0 ]; then \
		printf "e2e: no selected modules\n"; \
	else \
		printf "e2e: ran %d module(s)\n" "$$ran"; \
	fi

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

tidy:
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
		if [ ! -f "$$mod/Makefile" ]; then \
			printf "==> %s (skipped: no Makefile)\n" "$$mod"; \
			continue; \
		fi; \
		if ! "$(MAKE)" -C "$$mod" -n tidy >/dev/null 2>&1; then \
			printf "==> %s (skipped: no tidy target)\n" "$$mod"; \
			continue; \
		fi; \
		printf "==> %s\n" "$$mod"; \
		"$(MAKE)" -C "$$mod" tidy $(MODULE_MAKE_VARS); \
	done

tidy-mods:
	@$(MAKE) tidy
