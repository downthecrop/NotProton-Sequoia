#!/bin/sh

set -eu

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)

SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1789160759}
export SOURCE_DATE_EPOCH

WORK=${WORK:-$repo/scratch/fonts}
OUT=${OUT:-$repo/build/fonts}
JOBS=${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}
case $WORK in /*) ;; *) WORK=$PWD/$WORK ;; esac
case $OUT in /*) ;; *) OUT=$PWD/$OUT ;; esac
case "$repo$WORK$OUT" in *[[:space:]]*)
	echo "==> the repo, WORK and OUT cannot contain spaces, make would split them" >&2
	exit 1 ;;
esac
dist=$WORK/dist
stamp=$OUT.stamp

if [ "${1:-}" = "--rebuild" ]; then
	rm -rf "$WORK" "$OUT" "$stamp"
elif [ $# -ne 0 ]; then
	echo "==> unknown argument $1" >&2
	exit 1
fi

key=$(cd "$here" && python3 -c '
import hashlib, os, pathlib
root = pathlib.Path(".")
h = hashlib.sha256(os.environ["SOURCE_DATE_EPOCH"].encode())
for p in sorted(q for q in root.rglob("*") if q.is_file()):
    h.update(hashlib.sha256(str(p).encode()).digest())
    h.update(hashlib.sha256(p.read_bytes()).digest())
print(h.hexdigest())
')
if [ -d "$OUT" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$key" ]; then
	echo "==> fonts are already built from fonts/"
	exit 0
fi

tools=$WORK/tools
mkdir -p "$tools"
gnu_patch=$(command -v gpatch || true)
if [ -z "$gnu_patch" ] && patch --version 2>/dev/null | grep -q GNU; then
	gnu_patch=$(command -v patch)
fi
missing=""
[ -n "$gnu_patch" ] || missing="$missing GNU-patch"
for tool in fontforge python3 makeotfexe tx sfntedit otf2ttf otf2otc ttx; do
	command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
python3 -c 'import fontTools' 2>/dev/null || missing="$missing python3-fontTools"
if [ -n "$missing" ]; then
	echo "==> missing tools:$missing" >&2
	exit 1
fi
ln -sf "$gnu_patch" "$tools/patch"
printf "#!/bin/sh\ntool=\$1\nshift\nexec \"%s/\$tool\" \"\$@\"\n" "$(dirname "$(command -v makeotfexe)")" > "$tools/afdko"
chmod +x "$tools/afdko"

obj=$WORK/obj
rm -rf "$obj" "$dist"
mkdir -p "$obj"
{
	echo ".SECONDEXPANSION:"
	echo "SRCDIR := $repo"
	echo "DST_DIR := $dist"
	echo "include $here/Makefile"
} > "$obj/Makefile"

echo "==> building fonts"
if ! (cd "$obj" && PATH="$tools:$PATH" make -j"$JOBS" "$dist/share/fonts" > build.log 2>&1); then
	tail -30 "$obj/build.log" >&2
	echo "==> font build failed, full log in $obj/build.log" >&2
	exit 1
fi

python3 - "$dist/share/fonts" <<'EOF'
import pathlib, struct, sys, os
epoch = int(os.environ["SOURCE_DATE_EPOCH"]) + 2082844800
def checksum(b):
    b = bytes(b) + b"\0" * (-len(b) % 4)
    return sum(struct.unpack(">%dI" % (len(b) // 4), b)) & 0xffffffff
for path in sorted(pathlib.Path(sys.argv[1]).rglob("*.tt[fc]")):
    d = bytearray(path.read_bytes())
    if d[:4] == b"ttcf":
        count = struct.unpack(">I", d[8:12])[0]
        fonts = [struct.unpack(">I", d[12 + 4 * i:16 + 4 * i])[0] for i in range(count)]
    else:
        fonts = [0]
    heads = {}
    for font in fonts:
        for i in range(struct.unpack(">H", d[font + 4:font + 6])[0]):
            rec = font + 12 + 16 * i
            if d[rec:rec + 4] == b"head":
                heads.setdefault(struct.unpack(">I", d[rec + 8:rec + 12])[0], []).append(rec)
    changed = False
    for head, records in heads.items():
        length = struct.unpack(">I", d[records[0] + 12:records[0] + 16])[0]
        zeroed = bytearray(d[head:head + length])
        zeroed[8:12] = bytes(4)
        before = checksum(zeroed)
        for at in (20, 28):
            if struct.unpack(">q", d[head + at:head + at + 8])[0] > epoch:
                d[head + at:head + at + 8] = struct.pack(">q", epoch)
        zeroed = bytearray(d[head:head + length])
        zeroed[8:12] = bytes(4)
        after = checksum(zeroed)
        if after == before:
            continue
        changed = True
        for rec in records:
            d[rec + 4:rec + 8] = struct.pack(">I", after)
        adjust = struct.unpack(">I", d[head + 8:head + 12])[0]
        d[head + 8:head + 12] = struct.pack(">I", (adjust - 2 * (after - before)) & 0xffffffff)
    if changed:
        path.write_bytes(d)
EOF
for license in liberation-fonts/LICENSE noto/LICENSE source-han-sans/LICENSE.txt ume/license.html; do
	mkdir -p "$dist/share/fonts/$(dirname "$license")"
	cp "$here/$license" "$dist/share/fonts/$license"
done
rm -rf "$OUT" "$stamp"
mkdir -p "$(dirname "$OUT")"
mv "$dist/share/fonts" "$OUT"
rm -rf "$dist"
echo "$key" > "$stamp"
count=$(find "$OUT" -name '*.tt[fc]' | wc -l | tr -d ' ')
echo "==> built $count fonts in $OUT"
