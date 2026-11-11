// RUN: %clang -target wasm64-unknown-linux-musl -mabi=linux64 -std=c11 -fsyntax-only -DLINUX64_ABI %s
// RUN: %clang -target wasm64-unknown-unknown -std=c11 -fsyntax-only %s
// RUN: %clang -target wasm64-unknown-linux-musl -mabi=mvp -std=c11 -fsyntax-only %s
// RUN: %clang -E -dM -target wasm64-unknown-linux-musl -mabi=linux64 -DLINUX64_ABI %s | FileCheck %s --check-prefix=LINUX64

#if defined(LINUX64_ABI)
#if !defined(__wasm_linux64__) || __wasm_linux64__ != 1
#error "linux64 ABI must define its libc-selection marker"
#endif
_Static_assert(__builtin_types_compatible_p(__INT64_TYPE__, long),
               "linux64 int64_t must use long");
_Static_assert(__builtin_types_compatible_p(__INT64_TYPE__, __INTPTR_TYPE__),
               "linux64 int64_t must match intptr_t");
_Static_assert(__builtin_types_compatible_p(__UINT64_TYPE__, unsigned long),
               "linux64 uint64_t must use unsigned long");
_Static_assert(__builtin_types_compatible_p(__UINT64_TYPE__, __UINTPTR_TYPE__),
               "linux64 uint64_t must match uintptr_t");
_Static_assert(__builtin_types_compatible_p(__INTMAX_TYPE__, long),
               "linux64 intmax_t must use long");
_Static_assert(__builtin_types_compatible_p(__UINTMAX_TYPE__, unsigned long),
               "linux64 uintmax_t must use unsigned long");
#else
#ifdef __wasm_linux64__
#error "non-linux64 WebAssembly ABI must not define the linux64 marker"
#endif
_Static_assert(__builtin_types_compatible_p(__INT64_TYPE__, long long),
               "non-linux64 int64_t must retain long long");
_Static_assert(__builtin_types_compatible_p(__INTPTR_TYPE__, long),
               "non-linux64 intptr_t must retain long");
_Static_assert(__builtin_types_compatible_p(__INTMAX_TYPE__, long long),
               "non-linux64 intmax_t must retain long long");
#endif

// LINUX64-DAG: #define __INT64_TYPE__ long{{( int)?}}
// LINUX64-DAG: #define __INTMAX_TYPE__ long{{( int)?}}
// LINUX64-DAG: #define __wasm_linux64__ 1
