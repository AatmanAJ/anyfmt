# One target per job. See BUILD.md §2.
SHELL := /bin/bash
.DEFAULT_GOAL := build

DERIVED      ?= $(CURDIR)/build/DerivedData
CONFIG       ?= Debug
# Worktrees share the main checkout's built engines.
GIT_COMMON   := $(shell git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
ENGINES_DIST ?= $(if $(wildcard $(CURDIR)/Engines/dist/Helpers),$(CURDIR)/Engines/dist,$(dir $(GIT_COMMON))Engines/dist)
export HALO_ENGINES_DIR := $(ENGINES_DIST)
XCB          := xcodebuild -project Halo.xcodeproj -derivedDataPath $(DERIVED) ENGINES_DIST=$(ENGINES_DIST)
PRODUCTS     := $(DERIVED)/Build/Products/$(CONFIG)

.PHONY: bootstrap engines generate build test test-packages test-unit check uitest matrix fixtures dmg clean gallery perf

## Build-machine dependencies only. End users never install anything.
bootstrap:
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	brew install xcodegen meson ninja nasm pkg-config autoconf automake libtool
	@command -v cargo >/dev/null || { echo "Install Rust (rustup.rs) for the resvg engine"; exit 1; }
	@command -v node >/dev/null || { echo "Install Node.js 18+ for the cloud mock server tests"; exit 1; }
	@echo "bootstrap ok"

## Build pinned arm64 engines into Engines/dist (ffmpeg, ffprobe, resvg).
engines:
	./Engines/build-ffmpeg.sh
	./Engines/build-resvg.sh

generate:
	@xcodegen generate --quiet

build: generate
	$(XCB) -scheme Halo -configuration $(CONFIG) build | xcbeautify 2>/dev/null || $(XCB) -scheme Halo -configuration $(CONFIG) build -quiet

## Unit tests: packages + core + app-hosted, plus policy checks.
test: generate test-packages test-unit check

test-packages:
	cd Packages/DragSense && swift test
	cd Packages/RadialMenu && swift test

test-unit:
	$(XCB) -scheme Halo -configuration Debug test -quiet

check:
	./scripts/check-entitlements.sh

## UI tests need macOS Automation Mode enabled (see BLOCKERS.md).
uitest: generate
	$(XCB) -scheme HaloUI -configuration Debug test

fixtures:
	./Tests/Fixtures/make-fixtures.sh

## Runs every route on its fixture, validates outputs, writes docs/MATRIX.md.
matrix: generate fixtures
	$(XCB) -scheme Halo -configuration Release build -quiet
	$(DERIVED)/Build/Products/Release/halo-matrix --fixtures Tests/Fixtures/generated --out Tests/Matrix/out --report docs/MATRIX.md

## Wheel Gallery screenshots into docs/screens.
gallery: build
	$(PRODUCTS)/Halo.app/Contents/MacOS/Halo --render-gallery $(CURDIR)/docs/screens

perf: generate
	$(XCB) -scheme Halo -configuration Release build -quiet
	./scripts/perf.sh $(DERIVED)/Build/Products/Release

dmg: generate
	./packaging/make-dmg.sh

clean:
	rm -rf build Halo.xcodeproj
