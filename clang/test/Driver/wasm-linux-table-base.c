// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck --check-prefix=LINUX %s
// RUN: %clang -### --target=wasm32-wasi --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck --check-prefix=NON-LINUX %s
// RUN: %clang -### --target=wasm32-unknown-unknown --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck --check-prefix=NON-LINUX %s
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo \
// RUN:   -Wl,--table-base=7 %s 2>&1 | FileCheck --check-prefix=EXPLICIT %s
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo \
// RUN:   -shared %s 2>&1 | FileCheck --check-prefix=SHARED --implicit-check-not=--table-base %s
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo \
// RUN:   -pie %s 2>&1 | FileCheck --check-prefix=PIE --implicit-check-not=--table-base %s
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo \
// RUN:   -static-pie %s 2>&1 | FileCheck --check-prefix=STATIC-PIE --implicit-check-not=--table-base %s
// RUN: %clang -### --target=wasm64-unknown-linux-musl --sysroot=/foo \
// RUN:   -shared %s 2>&1 | FileCheck --check-prefix=WASM64-SHARED --implicit-check-not=--table-base %s

// LINUX: wasm-ld{{.*}}" "--table-base=3"
// NON-LINUX: wasm-ld
// NON-LINUX-NOT: --table-base
// EXPLICIT: wasm-ld{{.*}}" "--table-base=3" "--table-base=7"
// SHARED: wasm-ld{{.*}}" "-shared"
// PIE: wasm-ld
// STATIC-PIE: wasm-ld
// WASM64-SHARED: wasm-ld{{.*}}" "-m" "wasm64"
// WASM64-SHARED-SAME: "-shared"
