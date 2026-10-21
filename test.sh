#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/cache .build/modules
export CLANG_MODULE_CACHE_PATH="$PWD/.build/modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/modules"
swift test --disable-sandbox --cache-path "$PWD/.build/cache" "$@"
