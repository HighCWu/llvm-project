# SPDX-License-Identifier: MIT
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown -o %t32.o %s
# RUN: wasm-ld %t32.o -o %t32.raw
# RUN: wasm-ld --experimental-elf-container %t32.o -o %t32.elf
# RUN: llvm-readobj --file-headers --program-headers %t32.elf > /dev/null
# RUN: %python %S/Inputs/elf-container-check.py %t32.raw %t32.elf 32
# RUN: not wasm-ld --experimental-elf-container -shared %t32.o -o %t.shared 2>&1 | FileCheck %s --check-prefix=MODE
# RUN: test ! -e %t.shared
# RUN: not wasm-ld --experimental-elf-container -pie %t32.o -o %t.pie 2>&1 | FileCheck %s --check-prefix=MODE
# RUN: test ! -e %t.pie
# RUN: not wasm-ld --experimental-elf-container -r %t32.o -o %t.reloc 2>&1 | FileCheck %s --check-prefix=MODE
# RUN: test ! -e %t.reloc
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown -o %t64.o %s
# RUN: wasm-ld -mwasm64 %t64.o -o %t64.raw
# RUN: wasm-ld -mwasm64 --experimental-elf-container %t64.o -o %t64.elf
# RUN: llvm-readobj --file-headers --program-headers %t64.elf > /dev/null
# RUN: %python %S/Inputs/elf-container-check.py %t64.raw %t64.elf 64

# MODE: error: --experimental-elf-container is only supported for final static executables

  .globl  _start
_start:
  .functype _start () -> ()
  end_function
