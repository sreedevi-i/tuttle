PROJECT_ROOT := $(shell cd .. && pwd)
BINARY := .build/debug/TuttleMac

.PHONY: build run clean

build:
	swift build

run: build
	cd $(PROJECT_ROOT) && TuttleMac/$(BINARY)

clean:
	swift package clean
