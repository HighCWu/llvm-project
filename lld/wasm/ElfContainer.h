// SPDX-License-Identifier: MIT

#ifndef LLD_WASM_ELF_CONTAINER_H
#define LLD_WASM_ELF_CONTAINER_H

#include <cstddef>
#include <cstdint>

namespace lld::wasm {

size_t elfContainerPrefixSize(bool is64);
uint64_t elfContainerFileSize(uint64_t wasmSize, bool is64);
bool writeElfContainerPrefix(unsigned char *buffer, size_t capacity,
                             uint64_t wasmSize, bool is64);

} // namespace lld::wasm

#endif
