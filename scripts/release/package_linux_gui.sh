#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
umask 022

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
RELEASE_ROOT_DIR="$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd -P)"

usage() {
  cat <<'EOF'
Usage: package_linux_gui.sh BIN_DIR OUTPUT_DIR VERSION PLATFORM

Build a Debian GUI-wallet package from one native release bin directory.
PLATFORM must be linux-x86_64 or linux-aarch64.
EOF
}

if (( $# != 4 )); then
  usage >&2
  exit 2
fi

BIN_DIR=$1
OUTPUT_DIR=$2
VERSION=$3
PLATFORM=$4
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || {
  echo "invalid semantic version: $VERSION" >&2
  exit 1
}
case "$PLATFORM" in
  linux-x86_64) DEBIAN_ARCHITECTURE=amd64 ;;
  linux-aarch64) DEBIAN_ARCHITECTURE=arm64 ;;
  *)
    echo "unsupported Linux GUI platform: $PLATFORM" >&2
    exit 1
    ;;
esac

for command in appstreamcli date dpkg-deb install mktemp sed; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "required command is missing: $command" >&2
    exit 1
  }
done

BIN_DIR="$(CDPATH='' cd -- "$BIN_DIR" && pwd -P)"
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(CDPATH='' cd -- "$OUTPUT_DIR" && pwd -P)"
for binary in lostecho-gui lostecho; do
  [[ -f $BIN_DIR/$binary && -x $BIN_DIR/$binary ]] || {
    echo "release binary is missing or not executable: $BIN_DIR/$binary" >&2
    exit 1
  }
done

TEMPORARY=$(mktemp -d "${TMPDIR:-/tmp}/lostecho-linux-gui.XXXXXX")
cleanup() {
  local status=$?
  if [[ -d $TEMPORARY && $TEMPORARY == "${TMPDIR:-/tmp}"/lostecho-linux-gui.* ]]; then
    rm -r -- "$TEMPORARY" || true
  fi
  exit "$status"
}
trap cleanup EXIT

PACKAGE_ROOT="$TEMPORARY/lostecho-gui_${VERSION}_${DEBIAN_ARCHITECTURE}"
install -d \
  "$PACKAGE_ROOT/DEBIAN" \
  "$PACKAGE_ROOT/usr/bin" \
  "$PACKAGE_ROOT/usr/lib/lostecho" \
  "$PACKAGE_ROOT/usr/share/applications" \
  "$PACKAGE_ROOT/usr/share/doc/lostecho-gui" \
  "$PACKAGE_ROOT/usr/share/metainfo"
for size in 16 32 48 64 128 256 512; do
  install -d "$PACKAGE_ROOT/usr/share/icons/hicolor/${size}x${size}/apps"
done

install -m 0755 "$BIN_DIR/lostecho-gui" "$PACKAGE_ROOT/usr/lib/lostecho/lostecho-gui"
install -m 0755 "$BIN_DIR/lostecho" "$PACKAGE_ROOT/usr/lib/lostecho/lostecho"
ln -s ../lib/lostecho/lostecho-gui "$PACKAGE_ROOT/usr/bin/lostecho-gui"
install -m 0644 "$RELEASE_ROOT_DIR/LICENSE" \
  "$PACKAGE_ROOT/usr/share/doc/lostecho-gui/LICENSE"
install -m 0644 "$RELEASE_ROOT_DIR/NOTICE" \
  "$PACKAGE_ROOT/usr/share/doc/lostecho-gui/NOTICE"

install -m 0644 \
  "$SCRIPT_DIR/gui/linux/org.lostecho.wallet.desktop" \
  "$PACKAGE_ROOT/usr/share/applications/org.lostecho.wallet.desktop"
RELEASE_DATE=$(date -u +%F)
sed \
  -e "s/@VERSION@/$VERSION/g" \
  -e "s/@RELEASE_DATE@/$RELEASE_DATE/g" \
  "$SCRIPT_DIR/gui/linux/org.lostecho.wallet.metainfo.xml.in" \
  > "$PACKAGE_ROOT/usr/share/metainfo/org.lostecho.wallet.metainfo.xml"
chmod 0644 "$PACKAGE_ROOT/usr/share/metainfo/org.lostecho.wallet.metainfo.xml"
appstreamcli validate --no-net \
  "$PACKAGE_ROOT/usr/share/metainfo/org.lostecho.wallet.metainfo.xml"
for size in 16 32 48 64 128 256 512; do
  install -m 0644 \
    "$RELEASE_ROOT_DIR/echo_gui/assets/app-icons/Lostecho-${size}.png" \
    "$PACKAGE_ROOT/usr/share/icons/hicolor/${size}x${size}/apps/org.lostecho.wallet.png"
done

sed \
  -e "s/@VERSION@/$VERSION/g" \
  -e "s/@ARCHITECTURE@/$DEBIAN_ARCHITECTURE/g" \
  "$SCRIPT_DIR/gui/linux/control.in" \
  > "$PACKAGE_ROOT/DEBIAN/control"
chmod 0644 "$PACKAGE_ROOT/DEBIAN/control"

ARTIFACT="$OUTPUT_DIR/lostecho-gui-v${VERSION}-${PLATFORM}.deb"
dpkg-deb --root-owner-group --build "$PACKAGE_ROOT" "$ARTIFACT" >/dev/null
dpkg-deb --info "$ARTIFACT" >/dev/null
dpkg-deb --contents "$ARTIFACT" >/dev/null
EXTRACTED="$TEMPORARY/extracted"
dpkg-deb --extract "$ARTIFACT" "$EXTRACTED"
[[ -L $EXTRACTED/usr/bin/lostecho-gui ]]
[[ -s $EXTRACTED/usr/share/doc/lostecho-gui/LICENSE ]]
[[ -s $EXTRACTED/usr/share/doc/lostecho-gui/NOTICE ]]
[[ -s $EXTRACTED/usr/share/metainfo/org.lostecho.wallet.metainfo.xml ]]
[[ ! -e $EXTRACTED/usr/lib/lostecho/lostecho-cli ]]
[[ ! -e $EXTRACTED/usr/lib/lostecho/lostecho-miner ]]
"$EXTRACTED/usr/lib/lostecho/lostecho-gui" --release-self-check >/dev/null
printf '%s\n' "$ARTIFACT"
