# RUN: split-file %s %t
# RUN: mkdir -p %t/stub %t/provider %t/stub64 %t/provider64

# wasm32 inputs.
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/unused.s -o %t/unused32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/function-user.s -o %t/function-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/data-user.s -o %t/data-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/weak-user.s -o %t/weak-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/local-user.s -o %t/local-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/provider.s -o %t/provider32.o
# RUN: wasm-ld --experimental-pic -shared %t/provider32.o -o %t/libprovider32.so
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/data-provider.s -o %t/data-provider32.o
# RUN: wasm-ld --experimental-pic -shared %t/data-provider32.o -o %t/libdata-provider32.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/unused32.o %t/libprovider32.so -o %t/default32.wasm
# RUN: obj2yaml %t/default32.wasm | FileCheck %s --check-prefix=DEFAULT
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/unused32.o %t/libprovider32.so -o %t/unused32.wasm
# RUN: obj2yaml %t/unused32.wasm | FileCheck %s --check-prefix=UNUSED
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/function-user32.o %t/libprovider32.so -o %t/function32.wasm
# RUN: obj2yaml %t/function32.wasm | FileCheck %s --check-prefix=USED
# RUN: not wasm-ld --experimental-pic --as-needed -shared %t/function-user32.o %t/libdata-provider32.so -o %t/type-mismatch32.wasm 2>&1 | FileCheck %s --check-prefix=TYPE-MISMATCH
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/data-user32.o %t/libprovider32.so -o %t/data32.wasm
# RUN: obj2yaml %t/data32.wasm | FileCheck %s --check-prefix=USED
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/weak-user32.o %t/libprovider32.so -o %t/weak32.wasm
# RUN: obj2yaml %t/weak32.wasm | FileCheck %s --check-prefix=UNUSED
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/local-user32.o %t/libprovider32.so -o %t/local32.wasm
# RUN: obj2yaml %t/local32.wasm | FileCheck %s --check-prefix=UNUSED
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/duplicate-provider.s -o %t/duplicate-provider32.o
# RUN: wasm-ld --experimental-pic -shared %t/duplicate-provider32.o -o %t/libduplicate32.so
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/function-user32.o %t/libprovider32.so %t/libduplicate32.so -o %t/shared-binding32.wasm
# RUN: obj2yaml %t/shared-binding32.wasm | FileCheck %s --check-prefix=SHARED-BINDING
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/unused32.o --no-as-needed %t/libprovider32.so -o %t/toggle32.wasm
# RUN: obj2yaml %t/toggle32.wasm | FileCheck %s --check-prefix=DEFAULT

# A strong undefined reference from bitcode is a regular-input reason too.
# RUN: llvm-as %t/lto32.ll -o %t/lto32.bc
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic --lto-O0 -shared %t/lto32.bc %t/libprovider32.so -o %t/lto32.wasm
# RUN: obj2yaml %t/lto32.wasm | FileCheck %s --check-prefix=USED

# The first DSO has a strong import satisfied by the second DSO. When that
# dependency is already in the first DSO's Needed list, it is not repeated as
# a direct dependency of the final output. A regular-object reference still
# emits a direct Needed entry.
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/root-lib.s -o %t/root-lib32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/dep-stub.s -o %t/dep-stub32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/dep-provider.s -o %t/dep-provider32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/root-user.s -o %t/root-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/root-and-dep-user.s -o %t/root-and-dep-user32.o
# RUN: wasm-ld --experimental-pic -shared %t/dep-stub32.o -o %t/stub/libdep.so
# RUN: wasm-ld --experimental-pic -shared %t/dep-provider32.o -o %t/provider/libdep.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib32.o %t/stub/libdep.so -o %t/libroot32.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib32.o -o %t/libroot-alone32.so
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user32.o %t/libroot32.so %t/provider/libdep.so -o %t/transitive32.wasm
# RUN: obj2yaml %t/transitive32.wasm | FileCheck %s --check-prefix=TRANSITIVE
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user32.o %t/libroot-alone32.so %t/provider/libdep.so -o %t/transitive-direct-needed32.wasm
# RUN: obj2yaml %t/transitive-direct-needed32.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT-NEEDED
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-and-dep-user32.o %t/libroot32.so %t/provider/libdep.so -o %t/transitive-direct32.wasm
# RUN: obj2yaml %t/transitive-direct32.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT

# Repeat the option behavior for wasm64.
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/unused.s -o %t/unused64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/function-user.s -o %t/function-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/data-user.s -o %t/data-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/weak-user.s -o %t/weak-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/local-user.s -o %t/local-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/provider.s -o %t/provider64.o
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/provider64.o -o %t/libprovider64.so
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/data-provider.s -o %t/data-provider64.o
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/data-provider64.o -o %t/libdata-provider64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/unused64.o %t/libprovider64.so -o %t/default64.wasm
# RUN: obj2yaml %t/default64.wasm | FileCheck %s --check-prefix=DEFAULT
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/unused64.o %t/libprovider64.so -o %t/unused64.wasm
# RUN: obj2yaml %t/unused64.wasm | FileCheck %s --check-prefix=UNUSED
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/function-user64.o %t/libprovider64.so -o %t/function64.wasm
# RUN: obj2yaml %t/function64.wasm | FileCheck %s --check-prefix=USED
# RUN: not wasm-ld -mwasm64 --experimental-pic --as-needed -shared %t/function-user64.o %t/libdata-provider64.so -o %t/type-mismatch64.wasm 2>&1 | FileCheck %s --check-prefix=TYPE-MISMATCH
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/data-user64.o %t/libprovider64.so -o %t/data64.wasm
# RUN: obj2yaml %t/data64.wasm | FileCheck %s --check-prefix=USED
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/weak-user64.o %t/libprovider64.so -o %t/weak64.wasm
# RUN: obj2yaml %t/weak64.wasm | FileCheck %s --check-prefix=UNUSED
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/local-user64.o %t/libprovider64.so -o %t/local64.wasm
# RUN: obj2yaml %t/local64.wasm | FileCheck %s --check-prefix=UNUSED
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/duplicate-provider.s -o %t/duplicate-provider64.o
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/duplicate-provider64.o -o %t/libduplicate64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/function-user64.o %t/libprovider64.so %t/libduplicate64.so -o %t/shared-binding64.wasm
# RUN: obj2yaml %t/shared-binding64.wasm | FileCheck %s --check-prefix=SHARED-BINDING
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/unused64.o --no-as-needed %t/libprovider64.so -o %t/toggle64.wasm
# RUN: obj2yaml %t/toggle64.wasm | FileCheck %s --check-prefix=DEFAULT
# RUN: llvm-as %t/lto64.ll -o %t/lto64.bc
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic --lto-O0 -shared %t/lto64.bc %t/libprovider64.so -o %t/lto64.wasm
# RUN: obj2yaml %t/lto64.wasm | FileCheck %s --check-prefix=USED
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/root-lib.s -o %t/root-lib64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/dep-stub.s -o %t/dep-stub64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/dep-provider.s -o %t/dep-provider64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/root-user.s -o %t/root-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/root-and-dep-user.s -o %t/root-and-dep-user64.o
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/dep-stub64.o -o %t/stub64/libdep.so
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/dep-provider64.o -o %t/provider64/libdep.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib64.o %t/stub64/libdep.so -o %t/libroot64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib64.o -o %t/libroot-alone64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user64.o %t/libroot64.so %t/provider64/libdep.so -o %t/transitive64.wasm
# RUN: obj2yaml %t/transitive64.wasm | FileCheck %s --check-prefix=TRANSITIVE
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user64.o %t/libroot-alone64.so %t/provider64/libdep.so -o %t/transitive-direct-needed64.wasm
# RUN: obj2yaml %t/transitive-direct-needed64.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT-NEEDED
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-and-dep-user64.o %t/libroot64.so %t/provider64/libdep.so -o %t/transitive-direct64.wasm
# RUN: obj2yaml %t/transitive-direct64.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT

# DEFAULT:      Needed:
# DEFAULT-NEXT:   - libprovider{{32|64}}.so
# UNUSED:       Needed:          []
# USED:         Needed:
# USED-NEXT:      - libprovider{{32|64}}.so
# TYPE-MISMATCH: error: symbol type mismatch: provided_fn
# SHARED-BINDING: Needed:
# SHARED-BINDING-NEXT: - libprovider{{32|64}}.so
# SHARED-BINDING-NOT: libduplicate{{32|64}}.so
# TRANSITIVE:   Needed:
# TRANSITIVE-NEXT: - libroot{{32|64}}.so
# TRANSITIVE-NOT:  libdep.so
# TRANSITIVE-DIRECT-NEEDED: Needed:
# TRANSITIVE-DIRECT-NEEDED-NEXT: - libroot-alone{{32|64}}.so
# TRANSITIVE-DIRECT-NEEDED-NEXT: - libdep.so
# TRANSITIVE-DIRECT: Needed:
# TRANSITIVE-DIRECT-NEXT: - libroot{{32|64}}.so
# TRANSITIVE-DIRECT-NEXT: - libdep.so

#--- unused.s
.globl _start
_start:
  .functype _start () -> ()
  end_function

#--- function-user.s
.globl _start
.functype provided_fn () -> ()
_start:
  .functype _start () -> ()
  call provided_fn
  end_function

#--- data-user.s
.section .data.ref,"",@
.globl data_ref
data_ref:
  .int32 provided_data
.size data_ref, 4

#--- weak-user.s
.weak provided_fn
.functype provided_fn () -> ()
.globl _start
_start:
  .functype _start () -> ()
  call provided_fn
  end_function

#--- local-user.s
.globl provided_fn
.functype provided_fn () -> ()
provided_fn:
  .functype provided_fn () -> ()
  end_function
.globl _start
_start:
  .functype _start () -> ()
  call provided_fn
  end_function

#--- provider.s
.globl provided_fn
.functype provided_fn () -> ()
provided_fn:
  .functype provided_fn () -> ()
  end_function
.section .data.provided_data,"",@
.globl provided_data
provided_data:
  .int32 7
.size provided_data, 4

#--- data-provider.s
.section .data.provided_fn,"",@
.globl provided_fn
provided_fn:
  .int32 7
.size provided_fn, 4

#--- duplicate-provider.s
.globl provided_fn
.functype provided_fn () -> ()
provided_fn:
  .functype provided_fn () -> ()
  end_function

#--- lto32.ll
target triple = "wasm32-unknown-unknown"
declare void @provided_fn()
define void @_start() {
  call void @provided_fn()
  ret void
}

#--- lto64.ll
target triple = "wasm64-unknown-unknown"
declare void @provided_fn()
define void @_start() {
  call void @provided_fn()
  ret void
}

.globl dep_fn
.functype dep_fn () -> ()
.globl root_fn
.functype root_fn () -> ()
root_fn:
  .functype root_fn () -> ()
  call dep_fn
  end_function

#--- dep-stub.s
.globl unrelated_fn
.functype unrelated_fn () -> ()
unrelated_fn:
  .functype unrelated_fn () -> ()
  end_function

#--- dep-provider.s
.globl dep_fn
.functype dep_fn () -> ()
dep_fn:
  .functype dep_fn () -> ()
  end_function

#--- root-user.s
.globl _start
.functype root_fn () -> ()
_start:
  .functype _start () -> ()
  call root_fn
  end_function

#--- root-and-dep-user.s
.globl _start
.functype root_fn () -> ()
.functype dep_fn () -> ()
_start:
  .functype _start () -> ()
  call root_fn
  call dep_fn
  end_function
