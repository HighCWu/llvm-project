# SPDX-License-Identifier: MIT
# RUN: llvm-mc -triple=wasm32 -filetype=obj %s | llvm-readobj --symbols - | FileCheck %s
# RUN: llvm-mc -triple=wasm64 -filetype=obj %s | llvm-readobj --symbols - | FileCheck %s

# Directives precede the definitions, like C file-level inline assembly.
.symver old_impl, api@VERSION_1
.symver new_impl, api@@VERSION_2
.symver data_impl, data_api@@VERSION_2
.symver old_ref, api@VERSION_1
.symver old_again, api@VERSION_1
.functype old_ref () -> (i32)
.functype old_again () -> (i32)

.section .text.old_impl,"",@
.globl old_impl
old_impl:
  .functype old_impl () -> (i32)
  i32.const 1
  end_function

.section .text.new_impl,"",@
.globl new_impl
new_impl:
  .functype new_impl () -> (i32)
  i32.const 2
  end_function

.section .text.same_unit,"",@
.globl same_unit
same_unit:
  .functype same_unit () -> (i32)
  call old_ref
  call old_again
  i32.add
  end_function

.section .data.data_impl,"",@
.globl data_impl
data_impl:
  .int32 3
  .size data_impl, 4

# CHECK-DAG: Name: api@VERSION_1
# CHECK-DAG: Name: api@VERSION_2
# CHECK-DAG: Name: api
# CHECK-DAG: Name: data_api@VERSION_2
# CHECK-DAG: Name: data_api
