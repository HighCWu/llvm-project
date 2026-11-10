; RUN: llc < %s -mtriple=wasm32-unknown-unknown -asm-verbose=false | FileCheck %s --check-prefixes=CHECK,CHK32
; RUN: llc < %s -mtriple=wasm64-unknown-unknown -asm-verbose=false | FileCheck %s --check-prefixes=CHECK,CHK64

target triple = "wasm32-unknown-unknown"

; CHECK-LABEL: clear_cache:
; CHK32-NEXT: .functype clear_cache (i32, i32, i32, i32) -> ()
; CHK64-NEXT: .functype clear_cache (i64, i64, i64, i64) -> ()
; CHECK: i32.store
; CHECK-NOT: call
; CHECK: i32.store
; CHECK-NOT: call
define void @clear_cache(ptr %before, ptr %begin, ptr %end, ptr %after) {
entry:
  store volatile i32 1, ptr %before, align 4
  call void @llvm.clear_cache(ptr %begin, ptr %end)
  store volatile i32 2, ptr %after, align 4
  ret void
}

declare void @llvm.clear_cache(ptr, ptr)
