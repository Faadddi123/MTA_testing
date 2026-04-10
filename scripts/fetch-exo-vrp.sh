#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/eXo-OpenSource/mta-gamemode.git}"
TARGET_DIR="${1:-mods/deathmatch/resources/[vrp]}"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

LATEST_TAG="$(curl -fsSL https://api.github.com/repos/eXo-OpenSource/mta-gamemode/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
if [[ -z "$LATEST_TAG" ]]; then
    echo "Unable to determine latest eXo release tag" >&2
    exit 1
fi

git clone --depth 1 --branch "$LATEST_TAG" "$REPO_URL" "$WORK_DIR/src"
( cd "$WORK_DIR/src" && python3 build/buildscript.py --branch "$LATEST_TAG" )

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -a "$WORK_DIR/src/." "$TARGET_DIR/"
rm -rf "$TARGET_DIR/.git"

printf 'Installed eXo release %s into %s\n' "$LATEST_TAG" "$TARGET_DIR"
