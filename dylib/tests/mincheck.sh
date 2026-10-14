#!/bin/sh
set -eu

app="$1"
min="$2"
sdk="$3"

[ -d "$app" ] || { echo "mincheck: $app not found"; exit 1; }

newer() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 > y[i] + 0) exit 0
      if (x[i] + 0 < y[i] + 0) exit 1
    }
    exit 1
  }'
}

checked=0
bad=0
list=$(mktemp)
trap 'rm -f "$list"' EXIT
find "$app" -type f > "$list"
while IFS= read -r f; do
  case "$(file -b "$f")" in Mach-O*) ;; *) continue ;; esac
  checked=$((checked + 1))
  versions=$(xcrun vtool -show-build "$f" 2>/dev/null | awk '
    $1 == "cmd" { cmd = $2 }
    cmd == "LC_BUILD_VERSION" && $1 == "minos" { print $2 }
    cmd == "LC_VERSION_MIN_MACOSX" && $1 == "version" { print $2 }')
  if [ -z "$versions" ]; then
    echo "  no minimum version: ${f#"$app"/}"
    bad=1
    continue
  fi
  for v in $versions; do
    if newer "$v" "$min"; then
      echo "  needs macOS $v: ${f#"$app"/}"
      bad=1
    fi
  done
done < "$list"

main="$app/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")"
built=$(xcrun vtool -show-build "$main" 2>/dev/null | awk '$1 == "sdk" { print $2; exit }')
if [ -z "$built" ] || newer "$sdk" "$built"; then
  echo "  built against SDK ${built:-unknown}, below $sdk: ${main#"$app"/}"
  bad=1
fi

[ "$checked" -gt 0 ] || { echo "mincheck: no Mach-O files in $app"; exit 1; }
[ "$bad" -eq 0 ] || { echo "==> mincheck: failed"; exit 1; }
echo "==> mincheck: $checked binaries run on macOS $min"
