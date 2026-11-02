# SPDX-License-Identifier: MIT
# RUN: split-file %s %t
# RUN: llvm-mc -triple=wasm64 -mattr=+reference-types,+tail-call -filetype=obj %t/good.s -o %t/good.o
# RUN: not llvm-mc -triple=wasm64 -mattr=+reference-types -filetype=obj %t/bad.s -o %t/bad.o 2>&1 | FileCheck %s
# RUN: not llvm-mc -triple=wasm32 -mattr=+reference-types,+tail-call -filetype=obj %t/good.s -o %t/bad32.o 2>&1 | FileCheck %s --check-prefix=TABLE32

#--- good.s
.tabletype __indirect_function_table, funcref
.text
.section .text.call64,"",@
call64:
  .functype call64 (i64) -> (i32)
  local.get 0
  call_indirect __indirect_function_table, () -> (i32)
  end_function
.section .text.tail64,"",@
tail64:
  .functype tail64 (i64) -> (i32)
  local.get 0
  return_call_indirect __indirect_function_table, () -> (i32)
  end_function

#--- bad.s
.tabletype __indirect_function_table, funcref
.text
bad64:
  .functype bad64 (i32) -> (i32)
  local.get 0
  call_indirect __indirect_function_table, () -> (i32)
  end_function
# CHECK: error: type mismatch, expected [i64] but got [i32]
# TABLE32: error: type mismatch, expected [i32] but got [i64]
