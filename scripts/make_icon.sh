#!/bin/bash
# Renders Resources/AppIcon.icon and Resources/AppIcon-1024.png. The mark is drawn by Sources/Tomato/Glyph.swift and
# Tomato.swift, the same files that draw the glyph in the menu bar, so make_icon.swift is compiled together with them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$(mktemp -d)/make_icon"
trap 'rm -rf "$(dirname "$TOOL")"' EXIT
swiftc -O -o "$TOOL" "$ROOT/scripts/make_icon.swift" "$ROOT/Sources/Tomato/Glyph.swift" "$ROOT/Sources/Tomato/Tomato.swift"
"$TOOL"
