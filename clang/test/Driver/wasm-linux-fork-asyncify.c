// SPDX-License-Identifier: MIT
// RUN: mkdir -p %t/tools %t/empty
// RUN: touch %t/tools/wasm-opt
// RUN: chmod +x %t/tools/wasm-opt
// RUN: %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib -Wl,--no-entry -O2 --wasm-fork-asyncify -### %s -o %t/o2.wasm 2>&1 | FileCheck %s --check-prefix=O2
// RUN: %clang --target=wasm64-unknown-linux-musl -B%t/tools -nostdlib -Wl,--no-entry -O0 --wasm-fork-asyncify -### %s -o %t/wasm64.wasm 2>&1 | grep wasm-opt | FileCheck %s --check-prefix=O0 --implicit-check-not='"-O'
// RUN: %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib -Wl,--no-entry --wasm-fork-asyncify -### %s -o %t/no-o.wasm 2>&1 | grep wasm-opt | FileCheck %s --check-prefix=NO-O --implicit-check-not='"-O'
// RUN: %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib -Wl,--no-entry -O2 --no-wasm-opt --wasm-fork-asyncify -### %s -o %t/no-opt.wasm 2>&1 | grep wasm-opt | FileCheck %s --check-prefix=NO-OPT --implicit-check-not='"-O2'
// RUN: %clang --target=wasm32-unknown-linux-musl --wasm-fork-asyncify -Werror -E %s -o /dev/null
// RUN: %clang --target=wasm32-unknown-linux-musl --wasm-fork-asyncify -Werror -S %s -o %t/compile.s
// RUN: %clang --target=wasm32-unknown-linux-musl --wasm-fork-asyncify -Werror -c %s -o %t/compile.o
// RUN: %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib --wasm-fork-asyncify -r -### %t/compile.o -o %t/partial.o 2>&1 | FileCheck %s --check-prefix=RELOC --implicit-check-not=wasm-opt
// RUN: not %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib --wasm-fork-asyncify -shared -### %s -o %t/shared.wasm 2>&1 | FileCheck %s --check-prefix=SHARED
// RUN: not %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib --wasm-fork-asyncify -pie -### %s -o %t/pie.wasm 2>&1 | FileCheck %s --check-prefix=PIE
// RUN: not %clang --target=wasm32-unknown-linux-musl -B%t/tools -nostdlib --wasm-fork-asyncify -static-pie -### %s -o %t/static-pie.wasm 2>&1 | FileCheck %s --check-prefix=STATIC-PIE
// RUN: not %clang --target=wasm32-unknown-unknown -B%t/tools -nostdlib --wasm-fork-asyncify -### %s -o %t/unknown.wasm 2>&1 | FileCheck %s --check-prefix=NON-LINUX
// RUN: not env PATH=%t/empty %clang -B%t/empty --target=wasm32-unknown-linux-musl -nostdlib --wasm-fork-asyncify -### %s -o %t/missing.wasm 2>&1 | FileCheck %s --check-prefix=MISSING

// O2: "{{.*}}wasm-ld"
// O2-SAME: "--keep-section=target_features"
// O2-SAME: "-o" "{{.*}}fork-asyncify-{{.*}}.wasm"
// O2-NOT: "{{.*}}o2.wasm"
// O2: "{{.*}}wasm-opt"
// O2-SAME: "-O2" "{{.*}}fork-asyncify-{{.*}}.wasm"
// O2-SAME: "--enable-threads" "--enable-bulk-memory" "--enable-mutable-globals"
// O2-SAME: "--enable-sign-ext" "--enable-nontrapping-float-to-int"
// O2-SAME: "--enable-memory64" "--enable-exception-handling" "--asyncify"
// O2-SAME: "--pass-arg=asyncify-imports@linux_fork_v1.checkpoint,linux.syscall,linux.syscall_v2,linux_user_poll_v1.checkpoint,linux_user_poll_v2.checkpoint"
// O2-SAME: "--pass-arg=asyncify-asserts" "-o" "{{.*}}o2.wasm"

// O0: "{{.*}}wasm-opt"
// O0-SAME: "--enable-memory64" "--enable-exception-handling" "--asyncify"
// O0-SAME: "--pass-arg=asyncify-imports@linux_fork_v1.checkpoint,linux.syscall,linux.syscall_v2,linux_user_poll_v1.checkpoint,linux_user_poll_v2.checkpoint"
// O0-SAME: "--pass-arg=asyncify-asserts"
// NO-O: "{{.*}}wasm-opt"
// NO-O-SAME: "--asyncify" "--pass-arg=asyncify-imports@linux_fork_v1.checkpoint,linux.syscall,linux.syscall_v2,linux_user_poll_v1.checkpoint,linux_user_poll_v2.checkpoint"
// NO-O-SAME: "--pass-arg=asyncify-asserts"
// NO-OPT: "{{.*}}wasm-opt"
// NO-OPT-SAME: "--asyncify" "--pass-arg=asyncify-imports@linux_fork_v1.checkpoint,linux.syscall,linux.syscall_v2,linux_user_poll_v1.checkpoint,linux_user_poll_v2.checkpoint"
// NO-OPT-SAME: "--pass-arg=asyncify-asserts"
// RELOC: "{{.*}}wasm-ld"
// SHARED: error: invalid argument '--wasm-fork-asyncify' not allowed with '-shared'
// PIE: error: invalid argument '--wasm-fork-asyncify' not allowed with '-pie'
// STATIC-PIE: error: invalid argument '--wasm-fork-asyncify' not allowed with '-static-pie'
// NON-LINUX: error: unsupported option '--wasm-fork-asyncify' for target 'wasm32-unknown-unknown'
// MISSING: error: unable to execute command: wasm-opt is required for --wasm-fork-asyncify

int main(void) { return 0; }
