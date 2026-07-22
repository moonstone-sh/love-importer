#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
LUA_BIN="${LUA_BIN:-$ROOT/.moonstone/env/bin/lua}"
MAIN="${MAIN:-$ROOT/build/src/main.lua}"
LUA_PATH="$ROOT/.moonstone/env/share/lua/5.1/?.lua;$ROOT/.moonstone/env/share/lua/5.1/?/init.lua;${LUA_PATH:-};;"
LUA_CPATH="$ROOT/.moonstone/env/lib/lua/5.1/?.so;$ROOT/.moonstone/env/lib/lua/5.1/?/init.so;${LUA_CPATH:-};;"
export LUA_PATH LUA_CPATH
TMP="${TMPDIR:-/tmp}/love-importer-smoke.$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/root/bin" "$TMP/app/love.app/Contents/MacOS"
test -f "$MAIN" || { echo "missing compiled entrypoint: $MAIN" >&2; exit 1; }
export MOONSTONE_HOME="$TMP/moonstone-home"
cat > "$TMP/root/bin/love" <<'LOVE'
#!/usr/bin/env sh
echo love-root
LOVE
chmod +x "$TMP/root/bin/love"
cat > "$TMP/app/love.app/Contents/MacOS/love" <<'LOVE'
#!/usr/bin/env sh
echo love-app
LOVE
chmod +x "$TMP/app/love.app/Contents/MacOS/love"

"$LUA_BIN" "$MAIN" inspect "$TMP/root" | grep -q "kind:       normalized_root"

"$LUA_BIN" "$MAIN" import "$TMP/root" --version 11.5 --target linux-x86_64-gnu --out "$TMP/out-root"
test -x "$TMP/out-root/files/bin/love"
test -f "$TMP/out-root/package.toml"
grep -q 'name = "moonstone/love"' "$TMP/out-root/package.toml"
grep -q 'lua_api = "love-11"' "$TMP/out-root/package.toml"
test -d "$MOONSTONE_HOME/store/v0/b3"

"$LUA_BIN" "$MAIN" import "$TMP/app/love.app" --version 11.5 --target darwin-aarch64 --out "$TMP/out-app" --skip-run-check
test -L "$TMP/out-app/files/bin/love" -o -x "$TMP/out-app/files/bin/love"
test -d "$TMP/out-app/files/libexec/love.app"

(cd "$TMP/app" && zip -qr "$TMP/love-11.5-macos.zip" love.app)
"$LUA_BIN" "$MAIN" import "$TMP/love-11.5-macos.zip" --version 11.5 --target darwin-aarch64 --out "$TMP/out-zip" --skip-run-check --clear-quarantine
test -L "$TMP/out-zip/files/bin/love" -o -x "$TMP/out-zip/files/bin/love"
test -d "$TMP/out-zip/files/libexec/love.app"
grep -q 'quarantine_cleared = true' "$TMP/out-zip/import.toml"

"$LUA_BIN" "$MAIN" import-system "$TMP/root/bin/love" --version 11.5 --target linux-x86_64-gnu --out "$TMP/out-system" --local-only --skip-run-check
test -x "$TMP/out-system/files/bin/love"
grep -q 'local_only = true' "$TMP/out-system/import.toml"
grep -q 'publish_allowed = false' "$TMP/out-system/package.toml"

touch "$TMP/love.AppImage"
if "$LUA_BIN" "$MAIN" import "$TMP/love.AppImage" --version 11.5 --target linux-x86_64-gnu --out "$TMP/out-bad" >/tmp/love-importer-bad.out 2>&1; then
  echo "expected AppImage import to fail" >&2
  exit 1
fi
grep -q "AppImage input is not accepted" /tmp/love-importer-bad.out
