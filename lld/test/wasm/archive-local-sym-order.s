## Test that a local symbol in an earlier archive member does not hide a global
## definition in a later member.  The archive precedes the caller so both
## members are registered before foo becomes undefined.
# RUN: split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown -o %t/local.o %t/local.s
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown -o %t/global.o %t/global.s
# RUN: llvm-mc -filetype=obj -triple=wasm32-unknown-unknown -o %t/main.o %t/main.s
# RUN: rm -f %t/libfoo.a
# RUN: llvm-ar rcs %t/libfoo.a %t/local.o %t/global.o
# RUN: wasm-ld --no-entry --export=_start %t/libfoo.a %t/main.o -o %t/out.wasm
# RUN: llvm-objdump --disassemble-symbols=_start,foo --no-show-raw-insn \
# RUN:   --no-leading-addr %t/out.wasm | FileCheck %s

#--- main.s

.functype foo () -> ()

.globl _start
_start:
  .functype _start () -> ()
  call foo
  end_function

# CHECK-LABEL: <foo>:
# CHECK:         nop
# CHECK-NEXT:    end
# CHECK-LABEL: <_start>:
# CHECK:         call 0

#--- local.s

foo:
  .functype foo () -> ()
  end_function

#--- global.s

.globl foo
foo:
  .functype foo () -> ()
  nop
  end_function
