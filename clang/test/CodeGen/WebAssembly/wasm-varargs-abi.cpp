// RUN: %clang -target wasm64-unknown-linux -mabi=linux64 -std=c++11 -S -emit-llvm -o - %s | FileCheck %s --check-prefix=IR
// RUN: %clang -target wasm64-unknown-linux -mabi=linux64 -std=c++11 -S -emit-llvm -o - %s | llc -mtriple=wasm64-unknown-unknown -asm-verbose=false -wasm-disable-explicit-locals -wasm-keep-registers | FileCheck %s --check-prefix=LOWER

extern "C" void consume(const char *, ...);

extern "C" void linux64_caller(int value) {
  consume("%d", value);
}

struct Global {
  Global();
};

Global::Global() {}
Global initialized;

// IR-LABEL: define internal void @__cxx_global_var_init{{.*}} #[[INIT:[0-9]+]]
// IR: attributes #[[INIT]] = { {{.*}}"wasm-varargs-abi"="linux64"{{.*}} }

// LOWER-LABEL: linux64_caller:
// LOWER: i64.extend_i32_u
// LOWER: i64.store 0
