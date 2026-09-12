#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DATA="$ROOT/server-data"
RESOURCES="$SERVER_DATA/resources"
TMP="$(mktemp -d)"

echo "tsivtools base server setup"
mkdir -p "$SERVER_DATA"

if [ -d "$RESOURCES/[system]" ]; then
    echo "cfx-server-data already present, skipping download"
else
    echo "downloading cfx-server-data"
    curl -fsSL -o "$TMP/data.zip" \
        https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip
    unzip -q "$TMP/data.zip" -d "$TMP"
    cp -r "$TMP"/cfx-server-data-master/. "$SERVER_DATA/"
    echo "cfx-server-data installed"
fi

if [ -d "$ROOT/../tsivtools" ]; then
    rm -rf "$RESOURCES/tsivtools"
    cp -r "$ROOT/../tsivtools" "$RESOURCES/tsivtools"
    echo "tsivtools copied into resources"
fi

if [ ! -f "$SERVER_DATA/server.cfg" ]; then
    cp "$ROOT/server.cfg" "$SERVER_DATA/server.cfg"
    echo "server.cfg written"
fi

rm -rf "$TMP"

echo
echo "next steps:"
echo "  1. put your licence key from https://portal.cfx.re into server-data/server.cfg"
echo "  2. extract the FXServer artifacts somewhere"
echo "  3. run:  bash <artifacts>/run.sh +exec server.cfg   from inside server-data"
echo "  4. join with  connect 127.0.0.1  in the FiveM F8 console"
