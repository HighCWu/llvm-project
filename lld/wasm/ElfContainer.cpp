// SPDX-License-Identifier: MIT

#include "ElfContainer.h"

#include <cstring>
#include <limits>

namespace lld::wasm {
namespace {

constexpr uint32_t elfTypeExecutable = 2;
constexpr uint32_t elfVersionCurrent = 1;
constexpr uint32_t elfOsAbiLinux = 3;
constexpr uint32_t elfProgramHeaderType = 0x60005741;
constexpr uint32_t elfProgramHeaderRead = 4;
constexpr uint32_t carrierVersion = 1;
constexpr uint32_t payloadHeaderSize = 32;
constexpr uint64_t maxCompileStreamSize = std::numeric_limits<uint32_t>::max();

void write16le(unsigned char *buffer, size_t offset, uint16_t value) {
  buffer[offset] = static_cast<unsigned char>(value);
  buffer[offset + 1] = static_cast<unsigned char>(value >> 8);
}

void write32le(unsigned char *buffer, size_t offset, uint32_t value) {
  for (unsigned i = 0; i < 4; ++i)
    buffer[offset + i] = static_cast<unsigned char>(value >> (i * 8));
}

void write64le(unsigned char *buffer, size_t offset, uint64_t value) {
  for (unsigned i = 0; i < 8; ++i)
    buffer[offset + i] = static_cast<unsigned char>(value >> (i * 8));
}

} // namespace

size_t elfContainerPrefixSize(bool is64) { return is64 ? 152 : 116; }

uint64_t elfContainerFileSize(uint64_t wasmSize, bool is64) {
  if (wasmSize < 8 || wasmSize > maxCompileStreamSize)
    return 0;
  uint64_t prefixSize = elfContainerPrefixSize(is64);
  if (wasmSize > maxCompileStreamSize - prefixSize)
    return 0;
  return prefixSize + wasmSize;
}

bool writeElfContainerPrefix(unsigned char *buffer, size_t capacity,
                             uint64_t wasmSize, bool is64) {
  const size_t prefixSize = elfContainerPrefixSize(is64);
  if (!buffer || capacity < prefixSize ||
      !elfContainerFileSize(wasmSize, is64))
    return false;

  std::memset(buffer, 0, prefixSize);
  buffer[0] = 0x7f;
  buffer[1] = 'E';
  buffer[2] = 'L';
  buffer[3] = 'F';
  buffer[4] = static_cast<unsigned char>(is64 ? 2 : 1);
  buffer[5] = 1;
  buffer[6] = static_cast<unsigned char>(elfVersionCurrent);
  buffer[7] = static_cast<unsigned char>(elfOsAbiLinux);

  const size_t elfHeaderSize = is64 ? 64 : 52;
  const size_t programHeaderSize = is64 ? 56 : 32;
  const size_t payloadOffset = elfHeaderSize + programHeaderSize;
  const size_t programHeaderOffset = elfHeaderSize;
  const uint64_t segmentFileSize = payloadHeaderSize + wasmSize;

  write16le(buffer, 16, static_cast<uint16_t>(elfTypeExecutable));
  write16le(buffer, 18, 0); // EM_NONE
  write32le(buffer, 20, elfVersionCurrent);
  if (is64) {
    write64le(buffer, 32, elfHeaderSize);
    write16le(buffer, 52, static_cast<uint16_t>(elfHeaderSize));
    write16le(buffer, 54, static_cast<uint16_t>(programHeaderSize));
    write16le(buffer, 56, 1);

    write32le(buffer, programHeaderOffset, elfProgramHeaderType);
    write32le(buffer, programHeaderOffset + 4, elfProgramHeaderRead);
    write64le(buffer, programHeaderOffset + 8, payloadOffset);
    write64le(buffer, programHeaderOffset + 32, segmentFileSize);
    write64le(buffer, programHeaderOffset + 48, 4);
  } else {
    write32le(buffer, 28, static_cast<uint32_t>(elfHeaderSize));
    write16le(buffer, 40, static_cast<uint16_t>(elfHeaderSize));
    write16le(buffer, 42, static_cast<uint16_t>(programHeaderSize));
    write16le(buffer, 44, 1);

    write32le(buffer, programHeaderOffset, elfProgramHeaderType);
    write32le(buffer, programHeaderOffset + 4,
              static_cast<uint32_t>(payloadOffset));
    write32le(buffer, programHeaderOffset + 16,
              static_cast<uint32_t>(segmentFileSize));
    write32le(buffer, programHeaderOffset + 24, elfProgramHeaderRead);
    write32le(buffer, programHeaderOffset + 28, 4);
  }

  constexpr unsigned char payloadName[12] = {
      'L', 'I', 'N', 'U', 'X', '.', 'W', 'A', 'S', 'M', 0, 0};
  std::memcpy(buffer + payloadOffset, payloadName, sizeof(payloadName));
  write32le(buffer, payloadOffset + 12, carrierVersion);
  write32le(buffer, payloadOffset + 16, is64 ? 64 : 32);
  write64le(buffer, payloadOffset + 24, wasmSize);
  return true;
}

} // namespace lld::wasm
