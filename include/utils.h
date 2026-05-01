// include/utils.h
// CUDA and NPP error checking utilities

#pragma once

#include <iostream>
#include <stdexcept>
#include <string>
#include <cuda_runtime.h>
#include <npp.h>

// #we throw on any cuda error
#define CUDA_CHECK(call)                                                     \
    do {                                                                     \
        cudaError_t _err = (call);                                           \
        if (_err != cudaSuccess) {                                           \
            throw std::runtime_error(                                        \
                std::string("CUDA error at ") + __FILE__ + ":" +            \
                std::to_string(__LINE__) + " -> " +                         \
                cudaGetErrorString(_err));                                   \
        }                                                                    \
    } while (0)

// #we throw on any npp error
#define NPP_CHECK(call)                                                      \
    do {                                                                     \
        NppStatus _st = (call);                                              \
        if (_st != NPP_SUCCESS) {                                            \
            throw std::runtime_error(                                        \
                std::string("NPP error ") + std::to_string(_st) +           \
                " at " + __FILE__ + ":" + std::to_string(__LINE__));        \
        }                                                                    \
    } while (0)

// #we scoped device buffer that auto-frees
struct DeviceBuffer {
    Npp8u* ptr = nullptr;

    explicit DeviceBuffer(size_t bytes) {
        CUDA_CHECK(cudaMalloc(&ptr, bytes));
    }

    ~DeviceBuffer() {
        if (ptr) cudaFree(ptr);
    }

    // #we disable copy
    DeviceBuffer(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;
};
