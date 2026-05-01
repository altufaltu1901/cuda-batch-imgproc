# Makefile — CUDA Batch Image Processing Pipeline
# Targets: all, clean, run

NVCC        := nvcc
CXX         := g++
TARGET      := bin/cuda_imgproc
SRC_DIR     := src
INC_DIR     := include

SRCS        := $(SRC_DIR)/main.cu $(SRC_DIR)/pipeline.cu
INCLUDES    := -I$(INC_DIR)

# #we link against NPP image processing and core libs
LDFLAGS     := -lnppif -lnppig -lnppicc -lnppidei -lnppc -lstdc++fs

# #we compile for sm_75 (T4/Turing) and sm_86 (A100), adjust as needed
NVCCFLAGS   := -std=c++17 -O2 -arch=sm_75 \
               -gencode arch=compute_75,code=sm_75 \
               -gencode arch=compute_86,code=sm_86 \
               $(INCLUDES)

INPUT_DIR   := data/input
OUTPUT_DIR  := data/output
LOG_FILE    := logs/run.log
BLUR_SIZE   := 5

.PHONY: all clean run setup

all: $(TARGET)

$(TARGET): $(SRCS) $(INC_DIR)/pipeline.h $(INC_DIR)/utils.h \
           $(INC_DIR)/stb_image.h $(INC_DIR)/stb_image_write.h
	@mkdir -p bin
	$(NVCC) $(NVCCFLAGS) $(SRCS) -o $@ $(LDFLAGS)
	@echo "[BUILD] Done -> $@"

# #we fetch stb headers then build
setup:
	@bash scripts/download_stb.sh
	@mkdir -p data/input data/output logs bin

run: all
	@mkdir -p $(OUTPUT_DIR) logs
	./$(TARGET) \
		--input  $(INPUT_DIR) \
		--output $(OUTPUT_DIR) \
		--log    $(LOG_FILE) \
		--blur-size $(BLUR_SIZE)

clean:
	rm -rf bin $(OUTPUT_DIR) logs
	@echo "[CLEAN] Done"
