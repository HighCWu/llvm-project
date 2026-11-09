# SPDX-License-Identifier: MIT

import pathlib
import struct
import sys

raw = pathlib.Path(sys.argv[1]).read_bytes()
elf = pathlib.Path(sys.argv[2]).read_bytes()
is64 = int(sys.argv[3]) == 64
prefix_size = 152 if is64 else 116
elf_header_size = 64 if is64 else 52
program_header_size = 56 if is64 else 32
program_header_offset = elf_header_size
payload_offset = elf_header_size + program_header_size
elf_class = 2 if is64 else 1
width = 64 if is64 else 32

assert raw[:8] == b"\0asm\1\0\0\0"
assert elf[:16] == b"\x7fELF" + bytes([elf_class, 1, 1, 3]) + bytes(8)
assert len(elf) == prefix_size + len(raw)
assert elf[prefix_size:] == raw

header_format = "<HHIQQQIHHHHHH" if is64 else "<HHIIIIIHHHHHH"
expected_header = (2, 0, 1, 0, elf_header_size, 0, 0, elf_header_size,
                   program_header_size, 1, 0, 0, 0)
assert struct.unpack_from(header_format, elf, 16) == expected_header

program_header_format = "<IIQQQQQQ" if is64 else "<IIIIIIII"
if is64:
    expected_program_header = (0x60005741, 4, payload_offset, 0, 0,
                               32 + len(raw), 0, 4)
else:
    expected_program_header = (0x60005741, payload_offset, 0, 0,
                               32 + len(raw), 0, 4, 4)
assert struct.unpack_from(program_header_format, elf,
                           program_header_offset) == expected_program_header

assert elf[payload_offset:payload_offset + 12] == b"LINUX.WASM\0\0"
assert struct.unpack_from("<IIIQ", elf, payload_offset + 12) == (
    1, width, 0, len(raw))
