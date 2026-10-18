#!/bin/sh
# Builds Reactio Draw for Linux (x64 and ARM) with Go 1.24 or newer; no C compiler and no GTK headers needed
# (GTK and WebKitGTK are loaded when the program starts). The libraries are in third_party/, so nothing is downloaded.
# Needs index.html (the program page) beside this file: the repository's index.html.
cd "$(dirname "$0")"
[ -f index.html ] || cp ../index.html index.html
for A in amd64 arm64; do
  O=ReactioDraw; [ $A = arm64 ] && O=ReactioDraw-ARM
  CGO_ENABLED=0 GOOS=linux GOARCH=$A GOFLAGS=-mod=mod go build -trimpath -o "$O" . && echo "Done: $O"
done
