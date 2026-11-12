// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo %s -rdynamic 2>&1 \
// RUN:   | FileCheck %s --check-prefix=LINUX32
// LINUX32: wasm-ld{{.*}} "-m" "wasm32" "--export-dynamic"

// RUN: %clang -### --target=wasm64-unknown-linux-musl --sysroot=/foo %s -rdynamic 2>&1 \
// RUN:   | FileCheck %s --check-prefix=LINUX64
// LINUX64: wasm-ld{{.*}} "-m" "wasm64" "--export-dynamic"

// Relocatable links claim -rdynamic but do not export symbols dynamically.
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo %s \
// RUN:   -r -rdynamic 2>&1 | FileCheck %s --check-prefix=RELOC32
// RELOC32-NOT: warning: argument unused during compilation: '-rdynamic'
// RELOC32: wasm-ld{{.*}} "-m" "wasm32" {{.*}} "-r"
// RELOC32-NOT: "--export-dynamic"

// RUN: %clang -### --target=wasm64-unknown-linux-musl --sysroot=/foo %s \
// RUN:   -r -rdynamic 2>&1 | FileCheck %s --check-prefix=RELOC64
// RELOC64-NOT: warning: argument unused during compilation: '-rdynamic'
// RELOC64: wasm-ld{{.*}} "-m" "wasm64" {{.*}} "-r"
// RELOC64-NOT: "--export-dynamic"

// WASI targets using wasm-ld support the same linker option.
// RUN: %clang -### --target=wasm32-wasi --sysroot=/foo %s -rdynamic 2>&1 \
// RUN:   | FileCheck %s --check-prefix=WASI
// WASI: wasm-ld{{.*}} "-m" "wasm32" "--export-dynamic"

// -Wl continues to pass an explicit linker option through unchanged.
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo %s \
// RUN:   -Wl,--export-dynamic 2>&1 | FileCheck %s --check-prefix=WL
// WL: wasm-ld{{.*}} "--export-dynamic"

// The driver does not enable dynamic exports by default.
// RUN: %clang -### --target=wasm32-unknown-linux-musl --sysroot=/foo %s 2>&1 \
// RUN:   | FileCheck %s --check-prefix=DEFAULT
// DEFAULT: wasm-ld
// DEFAULT-NOT: "--export-dynamic"

// Compile-only actions have no linker job to receive the option.
// RUN: %clang -### -c --target=wasm32-unknown-linux-musl --sysroot=/foo %s \
// RUN:   -rdynamic 2>&1 | FileCheck %s --check-prefix=COMPILE
// COMPILE: "-cc1"
// COMPILE-NOT: wasm-ld
// COMPILE-NOT: "--export-dynamic"

int main(void) { return 0; }
