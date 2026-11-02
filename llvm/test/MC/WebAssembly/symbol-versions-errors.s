# SPDX-License-Identifier: MIT
# RUN: split-file %s %t
# RUN: not llvm-mc -triple=wasm32 -filetype=obj %t/empty.s 2>&1 | FileCheck %s --check-prefix=EMPTY
# RUN: not llvm-mc -triple=wasm32 -filetype=obj %t/undefined.s 2>&1 | FileCheck %s --check-prefix=UNDEF
# RUN: not llvm-mc -triple=wasm64 -filetype=obj %t/multiple.s 2>&1 | FileCheck %s --check-prefix=MULTIPLE
# RUN: not llvm-mc -triple=wasm32 -filetype=obj %t/incompatible.s 2>&1 | FileCheck %s --check-prefix=INCOMPATIBLE
# RUN: not llvm-mc -triple=wasm64 -filetype=obj %t/incompatible.s 2>&1 | FileCheck %s --check-prefix=INCOMPATIBLE

#--- empty.s
.symver x, api@
# EMPTY: error: expected symbol@version

#--- undefined.s
.functype x () -> (i32)
.symver x, api@@VERSION
# UNDEF: error: default version symbol api@@VERSION must be defined

#--- multiple.s
.functype x () -> (i32)
.symver x, api@ONE
.symver x, api@TWO
# MULTIPLE: error: multiple versions for x

#--- incompatible.s
.functype x () -> (i32)
.functype y () -> (i64)
.symver x, api@ONE
.symver y, api@ONE
# INCOMPATIBLE: error: incompatible versioned symbol api@ONE
