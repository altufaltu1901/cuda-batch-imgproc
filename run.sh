#!/bin/bash
# run.sh — build and execute the batch image processing pipeline
# Usage: ./run.sh [--input DIR] [--output DIR] [--blur-size N] [--log FILE]
set -e

INPUT_DIR="data/input"
OUTPUT_DIR="data/output"
LOG_FILE="logs/run.log"
BLUR_SIZE=5

# #we parse optional overrides
while [[ $# -gt 0 ]]; do
    case $1 in
        --input)      INPUT_DIR="$2";  shift 2 ;;
        --output)     OUTPUT_DIR="$2"; shift 2 ;;
        --log)        LOG_FILE="$2";   shift 2 ;;
        --blur-size)  BLUR_SIZE="$2";  shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

echo "=== CUDA Batch Image Processing Pipeline ==="
echo "[1/4] Setting up directories and headers..."
make setup

echo "[2/4] Downloading sample images..."
bash scripts/download_images.sh

echo "[3/4] Building..."
make all

echo "[4/4] Running pipeline..."
mkdir -p "$OUTPUT_DIR" logs
./bin/cuda_imgproc \
    --input     "$INPUT_DIR" \
    --output    "$OUTPUT_DIR" \
    --log       "$LOG_FILE" \
    --blur-size "$BLUR_SIZE"

echo ""
echo "=== Results ==="
echo "Output images: $(ls "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l) files in $OUTPUT_DIR/"
echo "Log:           $LOG_FILE"
tail -5 "$LOG_FILE"
