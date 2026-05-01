.DEFAULT_GOAL := help

SHELL ?= sh
GO ?= go
GOFLAGS ?=
GOCACHE ?= $(abspath .cache/go-build)
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
TEST_SCOPE ?= changed
CHANGED_MODULES ?=
ROOT_SELFTEST ?= 1
ROOT_E2E_SELFTEST ?= 0
QUALITY_BUS_DEV ?= $(abspath bus-dev/bin/bus-dev)
QUALITY_SCOPE ?= changed
QUALITY_PROFILE ?= cli
QUALITY_HTTP_MODULES ?=
QUALITY_LIBRARY_MODULES ?=
QUALITY_TARGETS ?= lint security
QUALITY_DEEP ?= 0
QUALITY_DEEP_TARGETS ?=
QUALITY_ALLOW_TEST_TARGETS ?= 0
QUALITY_EFFECTIVE_TARGETS := $(strip $(QUALITY_TARGETS) $(if $(filter 1,$(QUALITY_DEEP)),$(QUALITY_DEEP_TARGETS)))
QUALITY_KEEP_GOING ?= 0
QUALITY_PROGRESS ?= 0
QUALITY_COMPLETE_SCOPE ?= all
QUALITY_COMPLETE_SOURCE ?= 1
QUALITY_COMPLETE_BUILD ?= 1
QUALITY_COMPLETE_KEEP_GOING ?= $(QUALITY_KEEP_GOING)
QUALITY_COMPLETE_PROGRESS ?= $(QUALITY_PROGRESS)
QUALITY_BUS ?= $(abspath bus/bin/bus)
QUALITY_BUS_LINT ?= $(abspath bus-lint/bin/bus-lint)
QUALITY_DOCS_MODULE_DIR ?= docs/docs/modules
COMMA := ,
SKIP_PATTERNS := $(strip $(subst $(COMMA), ,$(SKIP_MODULES)))
MODULE_MAKE_VARS := BIN_DIR="$(abspath $(BIN_DIR))" PREFIX="$(PREFIX)" BINDIR="$(BINDIR)" GO="$(GO)" GOFLAGS="$(GOFLAGS)" GOCACHE="$(GOCACHE)" CGO_ENABLED="$(CGO_ENABLED)" BUILD_STATIC="$(BUILD_STATIC)"

.PHONY: help init update upgrade status bootstrap test e2e quality quality-complete build install clean distclean audit-cli-reachability audit-cli-reachability-full tidy tidy-mods superproject-selftest print-test-modules print-e2e-modules print-quality-modules

help:
	@printf "BusDK superproject\n\n"
	@printf "Targets:\n"
	@printf "  init        Initialize and fetch all submodules\n"
	@printf "  update      Sync submodules to pinned commits\n"
	@printf "  upgrade     (maintainers) Advance pins to latest remotes\n"
	@printf "  status      Show pinned submodule SHAs\n"
	@printf "  test        Run module test suites\n"
	@printf "  e2e         Run module end-to-end suites (when target exists)\n"
	@printf "  quality     Run reusable Go source/static quality checks\n"
	@printf "  quality-complete  Run source quality plus slow bus lint checks for help/docs\n"
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
	@printf "  ROOT_E2E_SELFTEST=%s\n\n" "$(ROOT_E2E_SELFTEST)"
	@printf "  QUALITY_SCOPE=%s\n" "$(QUALITY_SCOPE)"
	@printf "  QUALITY_TARGETS=%s\n" "$(QUALITY_TARGETS)"
	@printf "  QUALITY_DEEP=%s\n" "$(QUALITY_DEEP)"
	@printf "  QUALITY_DEEP_TARGETS=%s\n" "$(QUALITY_DEEP_TARGETS)"
	@printf "  QUALITY_ALLOW_TEST_TARGETS=%s\n" "$(QUALITY_ALLOW_TEST_TARGETS)"
	@printf "  QUALITY_PROFILE=%s\n" "$(QUALITY_PROFILE)"
	@printf "  QUALITY_HTTP_MODULES=%s\n" "$(QUALITY_HTTP_MODULES)"
	@printf "  QUALITY_LIBRARY_MODULES=%s\n" "$(QUALITY_LIBRARY_MODULES)"
	@printf "  QUALITY_KEEP_GOING=%s\n" "$(QUALITY_KEEP_GOING)"
	@printf "  QUALITY_PROGRESS=%s\n\n" "$(QUALITY_PROGRESS)"
	@printf "  QUALITY_COMPLETE_SCOPE=%s\n" "$(QUALITY_COMPLETE_SCOPE)"
	@printf "  QUALITY_COMPLETE_SOURCE=%s\n" "$(QUALITY_COMPLETE_SOURCE)"
	@printf "  QUALITY_COMPLETE_BUILD=%s\n" "$(QUALITY_COMPLETE_BUILD)"
	@printf "  QUALITY_COMPLETE_KEEP_GOING=%s\n" "$(QUALITY_COMPLETE_KEEP_GOING)"
	@printf "  QUALITY_COMPLETE_PROGRESS=%s\n" "$(QUALITY_COMPLETE_PROGRESS)"
	@printf "  QUALITY_DOCS_MODULE_DIR=%s\n\n" "$(QUALITY_DOCS_MODULE_DIR)"
	@printf "Example:\n"
	@printf "  make bootstrap\n"
	@printf "  make bootstrap PREFIX=/opt/busdk\n"
	@printf "  make bootstrap PREFIX=/c/busdk BINDIR=/c/busdk/bin\n"
	@printf "  make test TEST_SCOPE=all\n"
	@printf "  make e2e CHANGED_MODULES='bus-reports bus-bank'\n"
	@printf "  make quality QUALITY_KEEP_GOING=1\n"
	@printf "  make quality CHANGED_MODULES='bus-reports bus-bank'\n"
	@printf "  make quality QUALITY_SCOPE=all\n"
	@printf "  make quality-complete\n"

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
	@MAKEFLAGS= MFLAGS= MAKELEVEL= bash ./tests/superproject/test_changed_scope.sh
	@MAKEFLAGS= MFLAGS= MAKELEVEL= bash ./tests/superproject/test_quality_quiet.sh
	@MAKEFLAGS= MFLAGS= MAKELEVEL= bash ./tests/superproject/test_quality_complete.sh
	@MAKEFLAGS= MFLAGS= MAKELEVEL= sh ./tests/superproject/test_pricing_costs.sh
	@MAKEFLAGS= MFLAGS= MAKELEVEL= bash ./tests/superproject/test_agent_container.sh

print-test-modules:
	@set -eu; \
	scope="$(TEST_SCOPE)"; \
	case "$$scope" in \
		all|changed) ;; \
		*) printf "invalid TEST_SCOPE: %s\n" "$$scope" >&2; exit 2;; \
	esac; \
	changed_modules="$(CHANGED_MODULES)"; \
	if [ "$$scope" = "changed" ] && [ -z "$$changed_modules" ]; then \
		changed_modules="$$( \
			{ \
				git status --porcelain --ignore-submodules=none | awk '\
					{ \
						path = substr($$0, 4); \
						sub(/^[[:space:]]+/, "", path); \
						if (index(path, " -> ") > 0) path = substr(path, index(path, " -> ") + 4); \
						if (path ~ /^aiz(\/|$$)/) print "aiz"; \
						else if (path ~ /^bus(\/|$$)/) print "bus"; \
						else if (index(path, "bus-") == 1) { split(path, parts, "/"); print parts[1]; } \
					} \
				'; \
				for mod in $(MODULE_DIRS); do \
					if git -C "$$mod" rev-parse --git-dir >/dev/null 2>&1 && [ -n "$$(git -C "$$mod" status --porcelain 2>/dev/null)" ]; then \
						printf "%s\n" "$$mod"; \
					fi; \
				done; \
			} | awk '!seen[$$0]++' \
		)"; \
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

print-quality-modules:
	@$(MAKE) -s print-test-modules TEST_SCOPE="$(QUALITY_SCOPE)" CHANGED_MODULES="$(CHANGED_MODULES)" SKIP_MODULES="$(SKIP_MODULES)"

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
		changed_modules="$$( \
			{ \
				git status --porcelain --ignore-submodules=none | awk '\
					{ \
						path = substr($$0, 4); \
						sub(/^[[:space:]]+/, "", path); \
						if (index(path, " -> ") > 0) path = substr(path, index(path, " -> ") + 4); \
						if (path ~ /^aiz(\/|$$)/) print "aiz"; \
						else if (path ~ /^bus(\/|$$)/) print "bus"; \
						else if (index(path, "bus-") == 1) { split(path, parts, "/"); print parts[1]; } \
					} \
				'; \
				for mod in $(MODULE_DIRS); do \
					if git -C "$$mod" rev-parse --git-dir >/dev/null 2>&1 && [ -n "$$(git -C "$$mod" status --porcelain 2>/dev/null)" ]; then \
						printf "%s\n" "$$mod"; \
					fi; \
				done; \
			} | awk '!seen[$$0]++' \
		)"; \
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
	if [ "$(ROOT_E2E_SELFTEST)" = "1" ]; then \
		bash ./tests/superproject/e2e_agent_container.sh; \
	fi; \
	scope="$(TEST_SCOPE)"; \
	case "$$scope" in \
		all|changed) ;; \
		*) printf "invalid TEST_SCOPE: %s\n" "$$scope" >&2; exit 2;; \
	esac; \
	changed_modules="$(CHANGED_MODULES)"; \
	if [ "$$scope" = "changed" ] && [ -z "$$changed_modules" ]; then \
		changed_modules="$$( \
			{ \
				git status --porcelain --ignore-submodules=none | awk '\
					{ \
						path = substr($$0, 4); \
						sub(/^[[:space:]]+/, "", path); \
						if (index(path, " -> ") > 0) path = substr(path, index(path, " -> ") + 4); \
						if (path ~ /^aiz(\/|$$)/) print "aiz"; \
						else if (path ~ /^bus(\/|$$)/) print "bus"; \
						else if (index(path, "bus-") == 1) { split(path, parts, "/"); print parts[1]; } \
					} \
				'; \
				for mod in $(MODULE_DIRS); do \
					if git -C "$$mod" rev-parse --git-dir >/dev/null 2>&1 && [ -n "$$(git -C "$$mod" status --porcelain 2>/dev/null)" ]; then \
						printf "%s\n" "$$mod"; \
					fi; \
				done; \
			} | awk '!seen[$$0]++' \
		)"; \
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

quality:
	@set -eu; \
	tmp_files=""; \
	cleanup() { for f in $$tmp_files; do rm -f "$$f"; done; }; \
	trap cleanup EXIT; \
	trap 'cleanup; exit 130' HUP INT TERM; \
	step_log=$$(mktemp); \
	tmp_files="$$tmp_files $$step_log"; \
	if ! "$(MAKE)" -C bus-dev build $(MODULE_MAKE_VARS) >"$$step_log" 2>&1; then \
		if [ -s "$$step_log" ]; then cat "$$step_log" >&2; fi; \
		printf "Quality tool build failed, run this for more information: make -C bus-dev build\n" >&2; \
		exit 1; \
	fi; \
	if [ "$(QUALITY_ALLOW_TEST_TARGETS)" != "1" ]; then \
		for target in $(QUALITY_EFFECTIVE_TARGETS); do \
			case "$$target" in \
				test|test-*|*-test|e2e|test-e2e|bench|test-bench|docker-image|test-docker) \
					printf "invalid quality target %s: root make quality is source/static analysis only; run tests with make test, make e2e, or module-specific test targets\n" "$$target" >&2; \
					exit 2;; \
			esac; \
		done; \
	fi; \
	ran=0; \
	failed=0; \
	for mod in $$(MAKEFLAGS= "$(MAKE)" -s print-quality-modules QUALITY_SCOPE="$(QUALITY_SCOPE)" CHANGED_MODULES="$(CHANGED_MODULES)" SKIP_MODULES="$(SKIP_MODULES)"); do \
		has_go=0; \
		target_ran=0; \
		profile="$(QUALITY_PROFILE)"; \
		for pat in $(QUALITY_HTTP_MODULES); do \
			case "$$mod" in $$pat) profile="http-service";; esac; \
		done; \
		for pat in $(QUALITY_LIBRARY_MODULES); do \
			case "$$mod" in $$pat) profile="library";; esac; \
		done; \
		if [ -f "$$mod/go.mod" ]; then \
			has_go=1; \
			if [ "$(QUALITY_PROGRESS)" = "1" ]; then printf "==> %s (quality profile: %s)\n" "$$mod" "$$profile"; fi; \
			step_log=$$(mktemp); \
			tmp_files="$$tmp_files $$step_log"; \
			if ! "$(QUALITY_BUS_DEV)" quality lint --profile "$$profile" "$$mod" >"$$step_log" 2>&1; then \
				if [ -s "$$step_log" ]; then cat "$$step_log" >&2; fi; \
				printf "Quality lint for %s failed, run this for more information: %s quality lint --profile %s %s\n" "$$mod" "$(QUALITY_BUS_DEV)" "$$profile" "$$mod" >&2; \
				failed=$$((failed + 1)); \
				if [ "$(QUALITY_KEEP_GOING)" != "1" ]; then exit 1; fi; \
			fi; \
		elif [ "$(QUALITY_PROGRESS)" = "1" ]; then \
			printf "==> %s (no go.mod; delegated targets only)\n" "$$mod"; \
		fi; \
		for target in $(QUALITY_EFFECTIVE_TARGETS); do \
			if ! "$(MAKE)" -C "$$mod" -n "$$target" >/dev/null 2>&1; then \
				if [ "$(QUALITY_PROGRESS)" = "1" ]; then printf "==> %s:%s (skipped: no target)\n" "$$mod" "$$target"; fi; \
				continue; \
			fi; \
			target_ran=1; \
			if [ "$(QUALITY_PROGRESS)" = "1" ]; then printf "==> %s:%s\n" "$$mod" "$$target"; fi; \
			step_log=$$(mktemp); \
			tmp_files="$$tmp_files $$step_log"; \
			if ! "$(MAKE)" -C "$$mod" "$$target" $(MODULE_MAKE_VARS) BUS_DEV="$(QUALITY_BUS_DEV)" BUS_GO_QUALITY_PROFILE="$$profile" >"$$step_log" 2>&1; then \
				case "$$target" in \
					test|test-race) label="Unit tests"; show_log=0;; \
					test-fuzz) label="Fuzz tests"; show_log=0;; \
					test-bench) label="Benchmarks"; show_log=0;; \
					test-docker) label="Docker tests"; show_log=0;; \
					lint) label="Lint"; show_log=1;; \
					security) label="Security checks"; show_log=1;; \
					*) label="Quality target $$target"; show_log=1;; \
				esac; \
				if [ "$$show_log" -eq 1 ] && [ -s "$$step_log" ]; then cat "$$step_log" >&2; fi; \
				printf "%s for %s failed, run this for more information: make -C %s %s\n" "$$label" "$$mod" "$$mod" "$$target" >&2; \
				failed=$$((failed + 1)); \
				if [ "$(QUALITY_KEEP_GOING)" != "1" ]; then exit 1; fi; \
			fi; \
		done; \
		if [ "$$has_go" -eq 1 ] || [ "$$target_ran" -eq 1 ]; then \
			ran=$$((ran + 1)); \
		fi; \
	done; \
	if [ "$$ran" -eq 0 ]; then \
		printf "quality: no selected modules\n"; \
	elif [ "$$failed" -ne 0 ]; then \
		printf "quality: %d module step(s) failed across %d module(s)\n" "$$failed" "$$ran"; \
		exit 1; \
	else \
		printf "quality: ran %d module(s)\n" "$$ran"; \
	fi

quality-complete:
	@set -eu; \
	failed=0; \
	if [ "$(QUALITY_COMPLETE_SOURCE)" = "1" ]; then \
		if ! "$(MAKE)" quality QUALITY_SCOPE="$(QUALITY_COMPLETE_SCOPE)" CHANGED_MODULES="$(CHANGED_MODULES)" SKIP_MODULES="$(SKIP_MODULES)" QUALITY_KEEP_GOING="$(QUALITY_COMPLETE_KEEP_GOING)" QUALITY_PROGRESS="$(QUALITY_COMPLETE_PROGRESS)"; then \
			failed=$$((failed + 1)); \
			if [ "$(QUALITY_COMPLETE_KEEP_GOING)" != "1" ]; then exit 1; fi; \
		fi; \
	fi; \
	if [ "$(QUALITY_COMPLETE_BUILD)" = "1" ]; then \
		if ! "$(MAKE)" -C bus build $(MODULE_MAKE_VARS); then \
			printf "quality-complete: failed to build bus dispatcher\n" >&2; \
			exit 1; \
		fi; \
		if ! "$(MAKE)" -C bus-lint build $(MODULE_MAKE_VARS); then \
			printf "quality-complete: failed to build bus-lint\n" >&2; \
			exit 1; \
		fi; \
	fi; \
	if [ ! -x "$(QUALITY_BUS)" ]; then \
		printf "quality-complete: bus dispatcher not executable: %s\n" "$(QUALITY_BUS)" >&2; \
		exit 1; \
	fi; \
	if [ ! -x "$(QUALITY_BUS_LINT)" ]; then \
		printf "quality-complete: bus-lint not executable: %s\n" "$(QUALITY_BUS_LINT)" >&2; \
		exit 1; \
	fi; \
	tmp_files=""; \
	cleanup() { for f in $$tmp_files; do rm -f "$$f"; done; }; \
	trap cleanup EXIT HUP INT TERM; \
	modules="$$(MAKEFLAGS= "$(MAKE)" -s print-quality-modules QUALITY_SCOPE="$(QUALITY_COMPLETE_SCOPE)" CHANGED_MODULES="$(CHANGED_MODULES)" SKIP_MODULES="$(SKIP_MODULES)")"; \
	lint_tool_dir=$$(dirname "$(QUALITY_BUS_LINT)"); \
	bus_tool_dir=$$(dirname "$(QUALITY_BUS)"); \
	lint_path="$$lint_tool_dir:$$bus_tool_dir:$$PATH"; \
	for mod in $$modules; do \
		lint_path="$$(pwd)/$$mod/bin:$$lint_path"; \
	done; \
	ran=0; \
	doc_ran=0; \
	help_ran=0; \
	for mod in $$modules; do \
		if [ "$(QUALITY_COMPLETE_PROGRESS)" = "1" ]; then printf "==> %s (complete quality)\n" "$$mod"; fi; \
		if [ "$(QUALITY_COMPLETE_BUILD)" = "1" ]; then \
			step_log=$$(mktemp); \
			tmp_files="$$tmp_files $$step_log"; \
			if ! "$(MAKE)" -C "$$mod" build $(MODULE_MAKE_VARS) >"$$step_log" 2>&1; then \
				if [ -s "$$step_log" ]; then cat "$$step_log" >&2; fi; \
				printf "Complete quality build for %s failed, run this for more information: make -C %s build\n" "$$mod" "$$mod" >&2; \
				failed=$$((failed + 1)); \
				if [ "$(QUALITY_COMPLETE_KEEP_GOING)" != "1" ]; then exit 1; fi; \
			fi; \
		fi; \
		doc_path="$(QUALITY_DOCS_MODULE_DIR)/$$mod.md"; \
		if [ ! -f "$$doc_path" ]; then \
			printf "Complete quality documentation lint for %s failed: missing %s\n" "$$mod" "$$doc_path" >&2; \
			failed=$$((failed + 1)); \
			if [ "$(QUALITY_COMPLETE_KEEP_GOING)" != "1" ]; then exit 1; fi; \
		else \
			if [ "$(QUALITY_COMPLETE_PROGRESS)" = "1" ]; then printf "==> %s:doc-lint\n" "$$mod"; fi; \
			step_log=$$(mktemp); \
			tmp_files="$$tmp_files $$step_log"; \
			if ! PATH="$$lint_path" "$(QUALITY_BUS)" lint --type documentation "$$doc_path" >"$$step_log" 2>&1; then \
				if [ -s "$$step_log" ]; then cat "$$step_log" >&2; fi; \
				printf "Complete quality documentation lint for %s failed; rerun: make quality-complete QUALITY_COMPLETE_SCOPE=changed CHANGED_MODULES='%s' QUALITY_COMPLETE_SOURCE=0 QUALITY_COMPLETE_PROGRESS=1\n" "$$mod" "$$mod" >&2; \
				failed=$$((failed + 1)); \
				if [ "$(QUALITY_COMPLETE_KEEP_GOING)" != "1" ]; then exit 1; fi; \
			fi; \
			doc_ran=$$((doc_ran + 1)); \
		fi; \
		bin_path="$$mod/bin/$$mod"; \
		if [ ! -x "$$bin_path" ]; then \
			if [ "$(QUALITY_COMPLETE_PROGRESS)" = "1" ]; then printf "==> %s:help-lint (skipped: no executable)\n" "$$mod"; fi; \
		else \
			if [ "$(QUALITY_COMPLETE_PROGRESS)" = "1" ]; then printf "==> %s:help-lint\n" "$$mod"; fi; \
			help_file=$$(mktemp "$${TMPDIR:-/tmp}/$$mod.help.XXXXXX"); \
			step_log=$$(mktemp); \
			tmp_files="$$tmp_files $$help_file $$step_log"; \
			if ! "$$bin_path" --help >"$$help_file" 2>&1; then \
				if [ -s "$$help_file" ]; then cat "$$help_file" >&2; fi; \
				printf "Complete quality help capture for %s failed, run this for more information: %s --help\n" "$$mod" "$$bin_path" >&2; \
				failed=$$((failed + 1)); \
				if [ "$(QUALITY_COMPLETE_KEEP_GOING)" != "1" ]; then exit 1; fi; \
			elif ! PATH="$$lint_path" "$(QUALITY_BUS)" lint --type cli-help "$$help_file" >"$$step_log" 2>&1; then \
				if [ -s "$$step_log" ]; then cat "$$step_log" >&2; fi; \
				printf "Complete quality help lint for %s failed; rerun: make quality-complete QUALITY_COMPLETE_SCOPE=changed CHANGED_MODULES='%s' QUALITY_COMPLETE_SOURCE=0 QUALITY_COMPLETE_PROGRESS=1\n" "$$mod" "$$mod" >&2; \
				failed=$$((failed + 1)); \
				if [ "$(QUALITY_COMPLETE_KEEP_GOING)" != "1" ]; then exit 1; fi; \
			fi; \
			help_ran=$$((help_ran + 1)); \
		fi; \
		ran=$$((ran + 1)); \
	done; \
	if [ "$$ran" -eq 0 ]; then \
		printf "quality-complete: no selected modules\n"; \
	elif [ "$$failed" -ne 0 ]; then \
		printf "quality-complete: %d step(s) failed across %d module(s) (doc lint %d, help lint %d)\n" "$$failed" "$$ran" "$$doc_ran" "$$help_ran"; \
		exit 1; \
	else \
		printf "quality-complete: ran %d module(s) (doc lint %d, help lint %d)\n" "$$ran" "$$doc_ran" "$$help_ran"; \
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
