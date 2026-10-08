#!/usr/bin/env bash
# Installs the pinned Linux toolchain that tools/check.sh and tests/run.sh expect:
#   ~/bin/{rojo,stylua,luau-lsp,luau} and ~/luau-defs/globalTypes.d.luau
# Safe to re-run; already-installed tools are skipped. Used by CI and cloud sessions.
# On Windows/macOS install the same versions with aftman/rokit instead.
set -euo pipefail

ROJO_VERSION=7.4.4
STYLUA_VERSION=2.0.2
LUAU_LSP_VERSION=1.45.0 # also pins the Roblox type definitions the test mock is built from
LUAU_VERSION=0.640

BIN="$HOME/bin"
DEFS_DIR="$HOME/luau-defs"
mkdir -p "$BIN" "$DEFS_DIR"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch_zip() { # name url binary
	if [ -x "$BIN/$3" ]; then
		echo "$1: already installed"
		return
	fi
	echo "$1: downloading"
	curl -sSfL -o "$tmp/$1.zip" "$2"
	unzip -o -q "$tmp/$1.zip" -d "$tmp/$1"
	cp "$tmp/$1/$3" "$BIN/$3"
	chmod +x "$BIN/$3"
}

fetch_zip rojo "https://github.com/rojo-rbx/rojo/releases/download/v$ROJO_VERSION/rojo-$ROJO_VERSION-linux-x86_64.zip" rojo
fetch_zip stylua "https://github.com/JohnnyMorganz/StyLua/releases/download/v$STYLUA_VERSION/stylua-linux-x86_64.zip" stylua
fetch_zip luau-lsp "https://github.com/JohnnyMorganz/luau-lsp/releases/download/$LUAU_LSP_VERSION/luau-lsp-linux.zip" luau-lsp
fetch_zip luau "https://github.com/luau-lang/luau/releases/download/$LUAU_VERSION/luau-ubuntu.zip" luau

if [ ! -s "$DEFS_DIR/globalTypes.d.luau" ]; then
	echo "defs: downloading luau-lsp $LUAU_LSP_VERSION globalTypes.d.luau"
	curl -sSfL -o "$DEFS_DIR/globalTypes.d.luau" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP_VERSION/scripts/globalTypes.d.luau"
else
	echo "defs: already installed"
fi
echo "Toolchain ready in $BIN (add it to PATH)."
