// src/pipeline.cu
// NPP-based image processing pipeline implementation

#include "../include/pipeline.h"
#include "../include/utils.h"

#include <cuda_runtime.h>
#include <npp.h>
#include <nppi.h>
#include <vector>
#include <stdexcept>

// #we saturating add: clamp(a+b, 0, 255) per pixel, replaces nppiAdd dep
__global__ void SaturatingAdd(const Npp8u* a, const Npp8u* b, Npp8u* out, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        unsigned int sum = (unsigned int)a[i] + (unsigned int)b[i];
        out[i] = (Npp8u)(sum > 255u ? 255u : sum);
    }
}

// #we validate blur size and return NppiMaskSize enum
static NppiMaskSize GetMaskSize(int blur_size) {
    switch (blur_size) {
        case 3: return NPP_MASK_SIZE_3_X_3;
        case 5: return NPP_MASK_SIZE_5_X_5;
        case 7: return NPP_MASK_SIZE_7_X_7;
        default:
            throw std::invalid_argument("blur_size must be 3, 5, or 7");
    }
}

std::vector<unsigned char> RunPipeline(
    const unsigned char* host_rgb,
    int width,
    int height,
    int blur_size)
{
    // #we compute byte sizes for each stage
    const size_t rgb_bytes  = width * height * 3 * sizeof(Npp8u);
    const size_t gray_bytes = width * height * 1 * sizeof(Npp8u);

    NppiSize roi = {width, height};
    int rgb_step  = width * 3;
    int gray_step = width * 1;

    NppiMaskSize mask = GetMaskSize(blur_size);

    // --- Stage 0: upload RGB to device ---
    DeviceBuffer d_rgb(rgb_bytes);
    CUDA_CHECK(cudaMemcpy(d_rgb.ptr, host_rgb, rgb_bytes, cudaMemcpyHostToDevice));

    // --- Stage 1: RGB -> Grayscale via NPP ---
    // #we use nppiRGBToGray_8u_C3C1R
    DeviceBuffer d_gray(gray_bytes);
    NPP_CHECK(nppiRGBToGray_8u_C3C1R(
        d_rgb.ptr, rgb_step,
        d_gray.ptr, gray_step,
        roi
    ));

    // --- Stage 2: Gaussian Blur ---
    // #we blur in-place using temp buffer
    DeviceBuffer d_blurred(gray_bytes);
    NPP_CHECK(nppiFilterGauss_8u_C1R(
        d_gray.ptr, gray_step,
        d_blurred.ptr, gray_step,
        roi,
        mask
    ));

    // --- Stage 3: Sobel Edge Detection ---
    // #we sobel needs border: use nppiFilterSobelHorizBorder + VertBorder and combine
    // For simplicity and full NPP support we use nppiFilterSobel_8u16s_C1R then convert
    // Actually we use nppiFilter calls: horizontal + vertical magnitude approx via
    // nppiFilterSobelHorizMaskBorder_8u_C1R for a clean single-pass approach.
    // We use nppiFilterSobelHorizBorder_8u_C1R + nppiFilterSobelVertBorder_8u_C1R
    // then nppiAdd to get combined edges (absolute values approximation).
    DeviceBuffer d_sobel_h(gray_bytes);
    DeviceBuffer d_sobel_v(gray_bytes);
    DeviceBuffer d_edges(gray_bytes);

    NPP_CHECK(nppiFilterSobelHorizBorder_8u_C1R(
        d_blurred.ptr, gray_step,
        roi,
        {0, 0},
        d_sobel_h.ptr, gray_step,
        roi,
        NPP_BORDER_REPLICATE
    ));

    NPP_CHECK(nppiFilterSobelVertBorder_8u_C1R(
        d_blurred.ptr, gray_step,
        roi,
        {0, 0},
        d_sobel_v.ptr, gray_step,
        roi,
        NPP_BORDER_REPLICATE
    ));

    // #we combine H+V sobel with a simple saturating-add kernel (avoids nppiAdd lib dep)
    int n_pixels = width * height;
    int threads  = 256;
    int blocks   = (n_pixels + threads - 1) / threads;
    SaturatingAdd<<<blocks, threads>>>(d_sobel_h.ptr, d_sobel_v.ptr, d_edges.ptr, n_pixels);
    CUDA_CHECK(cudaGetLastError());

    // --- Download result to host ---
    std::vector<unsigned char> result(width * height);
    CUDA_CHECK(cudaMemcpy(result.data(), d_edges.ptr, gray_bytes, cudaMemcpyDeviceToHost));

    // #we sync to ensure all GPU ops done before returning
    CUDA_CHECK(cudaDeviceSynchronize());

    return result;
}
