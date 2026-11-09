# SPDX-License-Identifier: MIT
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %s -o %t32.o
# RUN: wasm-ld --soname=gnu-warn-common --export=ordinary_data %t32.o -o %t32.base.wasm
# RUN: wasm-ld --soname=gnu-warn-common --export=ordinary_data --warn-common %t32.o -o %t32.warn.wasm
# RUN: cmp %t32.base.wasm %t32.warn.wasm
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %s -o %t64.o
# RUN: wasm-ld -mwasm64 --soname=gnu-warn-common --export=ordinary_data %t64.o -o %t64.base.wasm
# RUN: wasm-ld -mwasm64 --soname=gnu-warn-common --export=ordinary_data -warn-common %t64.o -o %t64.warn.wasm
# RUN: cmp %t64.base.wasm %t64.warn.wasm
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %p/allow-multiple-definition.s -o %t.dup1.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %p/Inputs/allow-multiple-definition.s -o %t.dup2.o
# RUN: not wasm-ld --warn-common %t.dup1.o %t.dup2.o -o /dev/null 2>&1 | FileCheck %s --check-prefix=DUP

# DUP: error: duplicate symbol: foo

.functype test_function () -> ()
.globl _start
_start:
  .functype _start () -> ()
  call test_function
  end_function

.globl test_function
test_function:
  .functype test_function () -> ()
  end_function

.section .data.ordinary_data,"",@
.globl ordinary_data
ordinary_data:
  .int32 42
  .size ordinary_data, 4
