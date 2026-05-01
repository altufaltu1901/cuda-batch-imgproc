// include/pipeline.h
// Declares the NPP-based image processing pipeline

#pragma once

#include <vector>

// RunPipeline applies:
//   1. RGB -> Grayscale (NPP)
//   2. Gaussian Blur    (NPP)
//   3. Sobel Edge Det.  (NPP)
// Returns single-channel result as host byte vector.
std::vector<unsigned char> RunPipeline(
    const unsigned char* host_rgb,  // #we take raw RGB host pointer
    int width,
    int height,
    int blur_size  // #we kernel size: 3, 5, or 7
);
