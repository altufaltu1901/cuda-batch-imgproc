// main.cu
// Batch image processing pipeline using CUDA NPP:
//   Grayscale -> Gaussian Blur -> Sobel Edge Detection
// Author: CUDA at Scale Independent Project

#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <filesystem>
#include <chrono>
#include <stdexcept>
#include <cstring>

#include <cuda_runtime.h>
#include <npp.h>
#include <nppi.h>

#define STB_IMAGE_IMPLEMENTATION
#include "../include/stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "../include/stb_image_write.h"

#include "../include/pipeline.h"
#include "../include/utils.h"

namespace fs = std::filesystem;

// #we print usage help
void PrintUsage(const char* prog) {
    std::cout << "Usage: " << prog
              << " --input <dir> --output <dir> [--log <file>] [--blur-size <3|5|7>]\n"
              << "  --input    : directory containing input images (jpg/png)\n"
              << "  --output   : directory to write processed images\n"
              << "  --log      : path to log file (default: logs/run.log)\n"
              << "  --blur-size: Gaussian blur kernel size (default: 5)\n";
}

// #we parse cli args into a simple config struct
struct Config {
    std::string input_dir;
    std::string output_dir;
    std::string log_file = "logs/run.log";
    int blur_size = 5;
};

Config ParseArgs(int argc, char** argv) {
    Config cfg;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--input" && i + 1 < argc)        cfg.input_dir  = argv[++i];
        else if (arg == "--output" && i + 1 < argc)  cfg.output_dir = argv[++i];
        else if (arg == "--log" && i + 1 < argc)     cfg.log_file   = argv[++i];
        else if (arg == "--blur-size" && i + 1 < argc) cfg.blur_size = std::stoi(argv[++i]);
        else { std::cerr << "Unknown arg: " << arg << "\n"; PrintUsage(argv[0]); exit(1); }
    }
    if (cfg.input_dir.empty() || cfg.output_dir.empty()) {
        PrintUsage(argv[0]);
        exit(1);
    }
    return cfg;
}

int main(int argc, char** argv) {
    Config cfg = ParseArgs(argc, argv);

    // #we make sure output dir exists
    fs::create_directories(cfg.output_dir);
    fs::create_directories(fs::path(cfg.log_file).parent_path());

    std::ofstream log(cfg.log_file, std::ios::out | std::ios::trunc);
    if (!log.is_open()) throw std::runtime_error("Cannot open log file: " + cfg.log_file);

    // #we log device info
    int device_id = 0;
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device_id));
    log << "[INFO] GPU: " << prop.name << "\n";
    log << "[INFO] CUDA Compute: " << prop.major << "." << prop.minor << "\n";
    std::cout << "[INFO] GPU: " << prop.name << "\n";

    // #we collect image paths
    std::vector<fs::path> image_paths;
    for (const auto& entry : fs::directory_iterator(cfg.input_dir)) {
        std::string ext = entry.path().extension().string();
        if (ext == ".jpg" || ext == ".jpeg" || ext == ".png") {
            image_paths.push_back(entry.path());
        }
    }

    if (image_paths.empty()) {
        std::cerr << "[ERROR] No images found in: " << cfg.input_dir << "\n";
        return 1;
    }

    std::cout << "[INFO] Found " << image_paths.size() << " images\n";
    log << "[INFO] Found " << image_paths.size() << " images\n";
    log << "[INFO] Blur kernel size: " << cfg.blur_size << "\n";

    int processed = 0, failed = 0;
    auto total_start = std::chrono::high_resolution_clock::now();

    for (const auto& img_path : image_paths) {
        auto t0 = std::chrono::high_resolution_clock::now();

        // #we load image with stb
        int width, height, channels;
        unsigned char* host_img = stbi_load(img_path.c_str(), &width, &height, &channels, 3);
        if (!host_img) {
            log << "[WARN] Failed to load: " << img_path.filename() << "\n";
            ++failed;
            continue;
        }

        try {
            // #we run the full NPP pipeline
            std::vector<unsigned char> result = RunPipeline(
                host_img, width, height, cfg.blur_size
            );

            // #we write output as png
            std::string out_name = cfg.output_dir + "/" +
                                   img_path.stem().string() + "_processed.png";
            stbi_write_png(out_name.c_str(), width, height, 1, result.data(), width);

            auto t1 = std::chrono::high_resolution_clock::now();
            double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
            log << "[OK] " << img_path.filename().string()
                << " (" << width << "x" << height << ") -> "
                << fs::path(out_name).filename().string()
                << " | " << ms << " ms\n";
            ++processed;
        } catch (const std::exception& e) {
            log << "[ERROR] " << img_path.filename() << ": " << e.what() << "\n";
            ++failed;
        }

        stbi_image_free(host_img);
    }

    auto total_end = std::chrono::high_resolution_clock::now();
    double total_ms = std::chrono::duration<double, std::milli>(total_end - total_start).count();

    log << "[SUMMARY] Processed: " << processed
        << " | Failed: " << failed
        << " | Total time: " << total_ms << " ms"
        << " | Avg: " << (processed > 0 ? total_ms / processed : 0) << " ms/image\n";

    std::cout << "[DONE] Processed: " << processed << " | Failed: " << failed
              << " | Total: " << total_ms << " ms\n";
    std::cout << "[DONE] Log written to: " << cfg.log_file << "\n";

    return 0;
}
