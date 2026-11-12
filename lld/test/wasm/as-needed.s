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
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/root-data-lib.s -o %t/root-data-lib32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/root-data-user.s -o %t/root-data-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/dep-data-provider.s -o %t/dep-data-provider32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/alias-root.s -o %t/alias-root32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/alias-user.s -o %t/alias-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/alias-provider.s -o %t/alias-provider32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/env-global-lib.s -o %t/env-global-lib32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/env-global-user.s -o %t/env-global-user32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/env-global-provider.s -o %t/env-global-provider32.o
# RUN: wasm-ld --experimental-pic -shared %t/dep-stub32.o -o %t/stub/libdep.so
# RUN: wasm-ld --experimental-pic -shared %t/dep-provider32.o -o %t/provider/libdep.so
# RUN: wasm-ld --experimental-pic -shared %t/dep-data-provider32.o -o %t/provider/libdata-dep.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib32.o %t/stub/libdep.so -o %t/libroot32.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib32.o -o %t/libroot-alone32.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-data-lib32.o -o %t/libroot-data-alone32.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/alias-root32.o -o %t/libalias-root32.so
# RUN: wasm-ld --experimental-pic -shared %t/alias-provider32.o -o %t/libalias-provider.so
# RUN: wasm-ld --experimental-pic --unresolved-symbols=import-dynamic -shared %t/env-global-lib32.o -o %t/libenv-global32.so
# RUN: wasm-ld --experimental-pic -shared %t/env-global-provider32.o -o %t/libenv-global-provider.so
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user32.o %t/libroot32.so %t/provider/libdep.so -o %t/transitive32.wasm
# RUN: obj2yaml %t/transitive32.wasm | FileCheck %s --check-prefix=TRANSITIVE
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user32.o %t/libroot-alone32.so %t/provider/libdep.so -o %t/transitive-direct-needed32.wasm
# RUN: obj2yaml %t/transitive-direct-needed32.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT-NEEDED
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-and-dep-user32.o %t/libroot32.so %t/provider/libdep.so -o %t/transitive-direct32.wasm
# RUN: obj2yaml %t/transitive-direct32.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-data-user32.o %t/libroot-data-alone32.so %t/provider/libdata-dep.so -o %t/transitive-got-data32.wasm
# RUN: obj2yaml %t/transitive-got-data32.wasm | FileCheck %s --check-prefix=TRANSITIVE-GOT-DATA
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/alias-user32.o %t/libalias-root32.so %t/libalias-provider.so -o %t/transitive-alias32.wasm
# RUN: obj2yaml %t/transitive-alias32.wasm | FileCheck %s --check-prefix=TRANSITIVE-ALIAS
# RUN: wasm-ld --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/env-global-user32.o %t/libenv-global32.so %t/libenv-global-provider.so -o %t/env-global32.wasm
# RUN: obj2yaml %t/env-global32.wasm | FileCheck %s --check-prefix=ENV-GLOBAL

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
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/root-data-lib.s -o %t/root-data-lib64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/root-data-user.s -o %t/root-data-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/dep-data-provider.s -o %t/dep-data-provider64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/alias-root.s -o %t/alias-root64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/alias-user.s -o %t/alias-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/alias-provider.s -o %t/alias-provider64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/env-global-lib.s -o %t/env-global-lib64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/env-global-user.s -o %t/env-global-user64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/env-global-provider.s -o %t/env-global-provider64.o
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/dep-stub64.o -o %t/stub64/libdep.so
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/dep-provider64.o -o %t/provider64/libdep.so
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/dep-data-provider64.o -o %t/provider64/libdata-dep.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib64.o %t/stub64/libdep.so -o %t/libroot64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-lib64.o -o %t/libroot-alone64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/root-data-lib64.o -o %t/libroot-data-alone64.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/alias-root64.o -o %t/libalias-root64.so
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/alias-provider64.o -o %t/libalias-provider.so
# RUN: wasm-ld -mwasm64 --experimental-pic --unresolved-symbols=import-dynamic -shared %t/env-global-lib64.o -o %t/libenv-global64.so
# RUN: wasm-ld -mwasm64 --experimental-pic -shared %t/env-global-provider64.o -o %t/libenv-global-provider.so
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user64.o %t/libroot64.so %t/provider64/libdep.so -o %t/transitive64.wasm
# RUN: obj2yaml %t/transitive64.wasm | FileCheck %s --check-prefix=TRANSITIVE
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-user64.o %t/libroot-alone64.so %t/provider64/libdep.so -o %t/transitive-direct-needed64.wasm
# RUN: obj2yaml %t/transitive-direct-needed64.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT-NEEDED
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-and-dep-user64.o %t/libroot64.so %t/provider64/libdep.so -o %t/transitive-direct64.wasm
# RUN: obj2yaml %t/transitive-direct64.wasm | FileCheck %s --check-prefix=TRANSITIVE-DIRECT
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/root-data-user64.o %t/libroot-data-alone64.so %t/provider64/libdata-dep.so -o %t/transitive-got-data64.wasm
# RUN: obj2yaml %t/transitive-got-data64.wasm | FileCheck %s --check-prefix=TRANSITIVE-GOT-DATA
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/alias-user64.o %t/libalias-root64.so %t/libalias-provider.so -o %t/transitive-alias64.wasm
# RUN: obj2yaml %t/transitive-alias64.wasm | FileCheck %s --check-prefix=TRANSITIVE-ALIAS
# RUN: wasm-ld -mwasm64 --experimental-pic --as-needed --unresolved-symbols=import-dynamic -shared %t/env-global-user64.o %t/libenv-global64.so %t/libenv-global-provider.so -o %t/env-global64.wasm
# RUN: obj2yaml %t/env-global64.wasm | FileCheck %s --check-prefix=ENV-GLOBAL

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
# TRANSITIVE-GOT-DATA: Needed:
# TRANSITIVE-GOT-DATA-NEXT: - libroot-data-alone{{32|64}}.so
# TRANSITIVE-GOT-DATA-NEXT: - libdata-dep.so
# TRANSITIVE-ALIAS: Needed:
# TRANSITIVE-ALIAS-NEXT: - libalias-root{{32|64}}.so
# TRANSITIVE-ALIAS-NEXT: - libalias-provider.so
# ENV-GLOBAL: Needed:
# ENV-GLOBAL-NEXT: - libenv-global{{32|64}}.so
# ENV-GLOBAL-NOT: - libenv-global-provider.so

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
target datalayout = "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-i128:128-n32:64-S128-ni:1:10:20"
target triple = "wasm32-unknown-unknown"
declare void @provided_fn()
define void @_start() {
  call void @provided_fn()
  ret void
}

#--- lto64.ll
target datalayout = "e-m:e-p:64:64-p10:8:8-p20:8:8-i64:64-i128:128-n32:64-S128-ni:1:10:20"
target triple = "wasm64-unknown-unknown"
declare void @provided_fn()
define void @_start() {
  call void @provided_fn()
  ret void
}

#--- root-lib.s
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

#--- dep-data-provider.s
.section .data.dep_data,"",@
.globl dep_data
dep_data:
  .int32 7
.size dep_data, 4

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

#--- root-data-lib.s
.globl root_data_fn
.functype root_data_fn () -> ()
root_data_fn:
  .functype root_data_fn () -> ()
  end_function
.section .data.ref,"",@
.globl root_data_ref
root_data_ref:
  .int32 dep_data
.size root_data_ref, 4

#--- root-data-user.s
.globl _start
.functype root_data_fn () -> ()
_start:
  .functype _start () -> ()
  call root_data_fn
  end_function

#--- alias-root.s
.weak weak_alias
.import_module weak_alias, env
.import_name weak_alias, weak_import
.functype weak_alias () -> ()
.globl strong_alias
.import_module strong_alias, env
.import_name strong_alias, shared_import
.functype strong_alias () -> ()
.globl alias_root_fn
.functype alias_root_fn () -> ()
alias_root_fn:
  .functype alias_root_fn () -> ()
  call weak_alias
  call strong_alias
  end_function

#--- alias-user.s
.globl _start
.functype alias_root_fn () -> ()
_start:
  .functype _start () -> ()
  call alias_root_fn
  end_function

#--- alias-provider.s
# The linked DSO retains import fields, not source-level aliases. Keep the
# weak and strong imports distinct so their bindings remain representable.
.globl shared_import
.functype shared_import () -> ()
shared_import:
  .functype shared_import () -> ()
  end_function

#--- env-global-lib.s
.globl host_config
.globaltype host_config, i32, immutable
.globl env_global_fn
.functype env_global_fn () -> (i32)
env_global_fn:
  .functype env_global_fn () -> (i32)
  global.get host_config
  end_function

#--- env-global-user.s
.globl _start
.functype env_global_fn () -> (i32)
_start:
  .functype _start () -> ()
  call env_global_fn
  drop
  end_function

#--- env-global-provider.s
.section .data.host_config,"",@
.globl host_config
host_config:
  .int32 7
.size host_config, 4
