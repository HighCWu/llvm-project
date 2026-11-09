# SPDX-License-Identifier: MIT
# RUN: rm -rf %t && split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/main.s -o %t/main32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/a-entry.s -o %t/a-entry32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/a-backref.s -o %t/a-backref32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/b-func.s -o %t/b-func32.o
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown %t/b-unused.s -o %t/b-unused32.o
# RUN: llvm-ar rcs %t/liba32.a %t/a-entry32.o %t/a-backref32.o
# RUN: llvm-ar rcs %t/libb32.a %t/b-func32.o %t/b-unused32.o
# RUN: cd %t && wasm-ld --soname=gnu-groups main32.o liba32.a libb32.a -o plain32.wasm
# RUN: cd %t && wasm-ld --soname=gnu-groups --start-group main32.o liba32.a libb32.a --end-group -o group32.wasm
# RUN: cmp %t/plain32.wasm %t/group32.wasm
# RUN: cd %t && wasm-ld --soname=gnu-groups -start-group main32.o liba32.a libb32.a -end-group -o group-single-dash32.wasm
# RUN: cmp %t/plain32.wasm %t/group-single-dash32.wasm
# RUN: cd %t && wasm-ld --soname=gnu-groups '-(' main32.o liba32.a libb32.a '-)' -o group-alias32.wasm
# RUN: cmp %t/plain32.wasm %t/group-alias32.wasm
# RUN: cd %t && wasm-ld --soname=gnu-groups --start-group main32.o liba32.a libb32.a --end-group -o why32.wasm --why-extract=why32.txt
# RUN: cmp %t/group32.wasm %t/why32.wasm
# RUN: FileCheck %s --input-file=%t/why32.txt --check-prefix=WHY --implicit-check-not=b-unused32.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/main.s -o %t/main64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/a-entry.s -o %t/a-entry64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/a-backref.s -o %t/a-backref64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/b-func.s -o %t/b-func64.o
# RUN: llvm-mc -filetype=obj -triple=wasm64-unknown-unknown %t/b-unused.s -o %t/b-unused64.o
# RUN: llvm-ar rcs %t/liba64.a %t/a-entry64.o %t/a-backref64.o
# RUN: llvm-ar rcs %t/libb64.a %t/b-func64.o %t/b-unused64.o
# RUN: cd %t && wasm-ld -mwasm64 --soname=gnu-groups main64.o liba64.a libb64.a -o plain64.wasm
# RUN: cd %t && wasm-ld -mwasm64 --soname=gnu-groups --start-group main64.o liba64.a libb64.a --end-group -o group64.wasm
# RUN: cmp %t/plain64.wasm %t/group64.wasm

# WHY: reference{{.*}}extracted{{.*}}symbol
# WHY: main32.o{{.*}}liba32.a(a-entry32.o){{.*}}a_entry
# WHY-NEXT: libb32.a(b-func32.o){{.*}}liba32.a(a-backref32.o){{.*}}a_func
# WHY-NEXT: liba32.a(a-entry32.o){{.*}}libb32.a(b-func32.o){{.*}}b_func

#--- main.s
.functype a_entry () -> ()
.globl _start
_start:
  .functype _start () -> ()
  call a_entry
  end_function

#--- a-entry.s
.functype b_func () -> ()
.globl a_entry
a_entry:
  .functype a_entry () -> ()
  call b_func
  end_function

#--- a-backref.s
.globl a_func
a_func:
  .functype a_func () -> ()
  end_function

#--- b-func.s
.functype a_func () -> ()
.globl b_func
b_func:
  .functype b_func () -> ()
  call a_func
  end_function

#--- b-unused.s
.globl unused_member
unused_member:
  .functype unused_member () -> ()
  end_function
