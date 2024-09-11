.PHONY: install build test format set-version doc-images

all: build

format:
	git describe --tags --abbrev=0 | sed 's/v//' > pkg/account/version.txt
	go fmt ./...

test: format
	go test ./...
	go vet ./...

dev-build: test
	go build ./...

install: test
	go install ./cmd/...

build: 
	./bin/build.sh

set-version:
	if TAG=$$(git describe --tags --abbrev=0); then echo "$${TAG}" | sed 's/v//' > pkg/account/version.txt; fi
