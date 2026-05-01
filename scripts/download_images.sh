#!/bin/bash
# download_images.sh — populate data/input with sample images for testing
# Uses USC SIPI misc images (public domain) and generates synthetic test images
set -e
INPUT_DIR="$(dirname "$0")/../data/input"
mkdir -p "$INPUT_DIR"

echo "[INFO] Downloading sample images from USC SIPI..."

# #we grab a set of classic public-domain test images from USC SIPI
BASE="https://sipi.usc.edu/database/misc"
IMAGES=(
    "4.1.01.tiff"
    "4.1.02.tiff"
    "4.1.03.tiff"
    "4.1.04.tiff"
    "4.1.05.tiff"
    "4.1.06.tiff"
    "4.1.07.tiff"
    "4.1.08.tiff"
    "4.2.01.tiff"
    "4.2.02.tiff"
    "4.2.03.tiff"
    "4.2.04.tiff"
    "4.2.05.tiff"
    "4.2.06.tiff"
    "4.2.07.tiff"
)

for img in "${IMAGES[@]}"; do
    out="$INPUT_DIR/${img%.tiff}.png"
    if [ ! -f "$out" ]; then
        echo "[INFO] Downloading $img..."
        curl -sL "$BASE/$img" -o "/tmp/$img" && \
        convert "/tmp/$img" "$out" 2>/dev/null || \
        curl -sL "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg" -o "$out"
    fi
done

# #we also generate 100 synthetic PNG images using Python if we have < 50
COUNT=$(ls "$INPUT_DIR"/*.png 2>/dev/null | wc -l)
if [ "$COUNT" -lt 50 ]; then
    echo "[INFO] Generating synthetic images to reach 100..."
    python3 - <<PYEOF
import os, random
from PIL import Image, ImageDraw
import numpy as np

out_dir = "$INPUT_DIR"
existing = len([f for f in os.listdir(out_dir) if f.endswith('.png')])
target = 100

for i in range(existing, target):
    w, h = random.choice([(256,256),(512,512),(320,240),(640,480)])
    img = Image.fromarray(np.random.randint(0, 256, (h, w, 3), dtype=np.uint8))
    draw = ImageDraw.Draw(img)
    # #we add some geometric shapes so edges are meaningful
    for _ in range(random.randint(3, 10)):
        x0,y0 = random.randint(0,w-50), random.randint(0,h-50)
        x1,y1 = x0+random.randint(20,80), y0+random.randint(20,80)
        color = tuple(random.randint(0,255) for _ in range(3))
        draw.rectangle([x0,y0,x1,y1], outline=color, width=3)
        draw.ellipse([x0,y0,x1,y1], outline=tuple(random.randint(0,255) for _ in range(3)), width=2)
    img.save(os.path.join(out_dir, f"synthetic_{i:04d}.png"))

print(f"[INFO] Generated {target - existing} synthetic images.")
PYEOF
fi

echo "[INFO] Input directory has $(ls "$INPUT_DIR"/*.png 2>/dev/null | wc -l) images."
