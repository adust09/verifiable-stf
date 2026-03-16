---
title: Peregrine Toolchain Versions
last_updated: 2026-03-17
tags:
  - peregrine
  - toolchain
---

# Peregrine Toolchain Versions

## peregrine-tool

- **Repository**: <https://github.com/peregrine-project/peregrine-tool>
- **SHA**: `840930f399d722dd890fc836a8e9a025db0b035a`
- **Branch**: master (Merge pull request #58 from peregrine-project/metarocq-1.5.1)

### Build instructions

```bash
cd tools/peregrine-tool

# Requires opam switch at /home/shouki/peregrine-tool with deps installed.
# Key packages: rocq-core 9.1.1, rocq-metarocq-* 1.5.1+9.1, malfunction 0.7
# rocq-verified-extraction and rocq-certirocq built from source (see notes below).

# Build Coq theories (skip WasmBackend — patched out):
opam exec --switch /home/shouki/peregrine-tool -- make -k

# Build OCaml binary:
opam exec --switch /home/shouki/peregrine-tool -- dune build

# Run:
opam exec --switch /home/shouki/peregrine-tool -- dune exec peregrine -- <LANG> <FILE> -o <OUT>
```

### Build notes

- `rocq-verified-extraction` v1.0.0+9.1 requires `malfunction >= 0.7.1` but only `0.7` is available. Built from source at `/tmp/rocq-verified-extraction` and `.vo` files installed manually.
- `rocq-certirocq` requires `coq-wasm` which has dune build conflicts. Built from source with `CodegenWasm` commented out. `Compiler/pipeline.v` patched to remove Wasm imports.
- `WasmBackend.v` in peregrine-tool cannot compile without `coq-wasm`. Patched `ConfigUtils.v` and `Pipeline.v` to stub out Wasm references.

### Key opam packages (opam switch: `/home/shouki/peregrine-tool`)

| Package | Version |
|---------|---------|
| ocaml-base-compiler | 4.14.2 |
| rocq-core | 9.1.1 |
| rocq-metarocq-common | 1.5.1+9.1 |
| rocq-metarocq-erasure | 1.5.1+9.1 |
| rocq-metarocq-erasure-plugin | 1.5.1+9.1 |
| rocq-rust-extraction | 0.2.1 |
| rocq-typed-extraction-common | 0.2.1 |
| malfunction | 0.7 (pinned from git) |
| coq-compcert | 3.17 |
| rocq-equations | 1.3.1+9.1 |

## lean-to-lambdabox

- **Repository**: <https://github.com/peregrine-project/lean-to-lambdabox>
- **SHA**: `f54d17d04402459effb35851cbba3bbe8e4ffbef`
- **lean-toolchain**: `leanprover/lean4:v4.22.0`

### Build instructions

```bash
cd tools/lean-to-lambdabox
lake build
```

## Dependency versions (for generated code)

No Rust code was generated (see FINDINGS.md for details).
The C backend generates code depending on CertiRocq's GC runtime (`gc_stack.h`).
