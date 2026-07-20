// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck --check-prefix=LINUX %s
// RUN: %clang -### --target=wasm32-wasi --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck --check-prefix=NON-LINUX %s
// RUN: %clang -### --target=wasm32-unknown-unknown --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck --check-prefix=NON-LINUX %s
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo \
// RUN:   -Wl,--table-base=7 %s 2>&1 | FileCheck --check-prefix=EXPLICIT %s

// LINUX: wasm-ld{{.*}}" "--table-base=3"
// NON-LINUX: wasm-ld
// NON-LINUX-NOT: --table-base
// EXPLICIT: wasm-ld{{.*}}" "--table-base=3" "--table-base=7"
