// RUN: %clang_cc1 -emit-llvm %s -o - -triple=wasm32-unknown-linux-musl | FileCheck %s

int main(int argc, char **argv, char **envp) {
  return argc + (argv != 0) + (envp != 0);
}

// CHECK-NOT: @environ
// CHECK-NOT: define i32 @main
// CHECK-LABEL: define i32 @__main_argc_argv_envp(i32 noundef %argc, ptr noundef %argv, ptr noundef %envp)
// CHECK-NOT: define i32 @__main_argc_argv(
