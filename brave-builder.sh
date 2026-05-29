#!/usr/bin/env bash
set -e

APP=brave

mkdir -p tmp
cd tmp

# Download appimagetool
if ! test -f ./appimagetool; then
    wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
    chmod a+x ./appimagetool
fi

# Load desktop file from repo
LAUNCHER=$(cat ../brave.desktop)

# Fetch latest stable Brave release info once
API=$(curl -Ls https://api.github.com/repos/brave/brave-browser/releases/latest)
VERSION=$(echo "$API" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
echo "Building Brave $VERSION"

_build() {
    local ARCH="$1"
    local ARCHREF="$2"
    local APPDIR="$APP-$ARCH.AppDir"
    local ZIPFILE="brave-$ARCHREF.zip"

    DOWNLOAD_URL=$(echo "$API" | sed 's/[()\",{} ]/\n/g' \
        | grep -i "https.*download.*${ARCHREF}.*zip$" \
        | grep -v symbol | head -1)

    [ -z "$DOWNLOAD_URL" ] && { echo "No URL found for $ARCH"; return 1; }

    echo "Downloading $ARCH build..."
    wget -q --show-progress "$DOWNLOAD_URL" -O "$ZIPFILE"

    mkdir -p "$APPDIR"
    unzip -qq "$ZIPFILE" -d "$APPDIR/"
    rm "$ZIPFILE"

    # Icon (use the 128px one included in Brave's package)
    cp "$APPDIR"/*128*.png "$APPDIR/brave.png"

    # Desktop file
    echo "$LAUNCHER" > "$APPDIR/brave.desktop"
    sed -i "s#Icon=.*#Icon=brave#g" "$APPDIR/brave.desktop"

    # AppRun entry point
    cat <<'APPRUN' > "$APPDIR/AppRun"
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export UNION_PRELOAD="${HERE}"
exec "${HERE}/brave" "$@"
APPRUN
    chmod a+x "$APPDIR/AppRun"

    ARCH="$ARCH" ./appimagetool --comp zstd \
        -u "gh-releases-zsync|thisisarnabdas|Brave-appimage|latest|*$ARCH.AppImage.zsync" \
        "./$APPDIR" "Brave-Web-Browser-$VERSION-$ARCH.AppImage"

    rm -rf "$APPDIR"
    echo "Done: Brave-Web-Browser-$VERSION-$ARCH.AppImage"
}

_build "x86_64" "amd64"
_build "aarch64" "arm64"

cd ..
mv tmp/*.AppImage* ./
