#!/bin/sh

set -eo

if [ "$1" = format ]; then
    go fmt ./...
fi

fmt_out="$(gofmt -l .)"
echo "$fmt_out"
test -z "$fmt_out"

go vet ./...
