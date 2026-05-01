#!/bin/bash
# download_stb.sh — fetch stb_image headers if not already present
set -e
INCLUDE_DIR="$(dirname "$0")/../include"
STB_IMG="$INCLUDE_DIR/stb_image.h"
STB_WRT="$INCLUDE_DIR/stb_image_write.h"

if [ ! -f "$STB_IMG" ]; then
    echo "[INFO] Downloading stb_image.h..."
    curl -sL https://raw.githubusercontent.com/nothings/stb/master/stb_image.h -o "$STB_IMG"
fi
if [ ! -f "$STB_WRT" ]; then
    echo "[INFO] Downloading stb_image_write.h..."
    curl -sL https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h -o "$STB_WRT"
fi
echo "[INFO] stb headers ready."
