---
title: Peregrine Spike Findings
last_updated: 2026-03-17
tags:
  - peregrine
  - spike
---

# Peregrine Spike Findings (Issue #4)

## Summary

**Go/No-Go for Issue #5: NO-GO via Rust backend. C backend is a viable alternative path.**

The `.ast → Rust` gate **failed**: peregrine's Rust backend requires **typed** lambda box
input (`.tast` format), but lean-to-lambdabox only produces **untyped** output (`.ast` format).
The C and OCaml backends accept untyped input and work correctly.

## .ast vs .tast Gate Result

| Backend | Input type required | lean-to-lambdabox output | Result |
|---------|-------------------|-------------------------|--------|
| **Rust** | Typed (`.tast`) | Untyped (`.ast`) | **FAIL** |
| **Elm** | Typed (`.tast`) | Untyped (`.ast`) | **FAIL** |
| **C** | Untyped (`.ast`) | Untyped (`.ast`) | **PASS** |
| **OCaml** | Untyped (`.ast`) | Untyped (`.ast`) | **PASS** |
| **CakeML** | Untyped (`.ast`) | Untyped (`.ast`) | Expected PASS |
| **Wasm** | Untyped (`.ast`) | Untyped (`.ast`) | Not tested (deps unavailable) |

### Root cause

In `lean-to-lambdabox/LeanToLambdaBox/Erasure.lean` line 361:
```lean
return (.untyped s.gdecls (.some t), s.inlinings)
```
The erasure always produces `Program.untyped`. There is no `.typed` variant implemented.

In `peregrine-tool/theories/Pipeline.v` line 74:
```coq
| Rust _ => assert (is_typed_ast p) "Rust extraction requires typed lambda box input"
```

### Error message
```
Could not compile:
Rust extraction requires typed lambda box input
```

## Generated Rust Dependencies / Module Structure

**N/A** — no Rust code was generated due to the typed IR requirement.

## ByteArray Support (ABI Spike)

- Built-in `ByteArray` was **not tested** with `#erase` (expected to fail as it's an opaque type)
- Custom byte types (`Bit`, `Byte`, `ByteList`) work with `#erase`:
  - `byteIdentity.ast` — generated successfully
  - `byteLength.ast` — generated successfully (includes Nat operations)
  - `byteConcat.ast` — generated successfully
- All custom byte type `.ast` files compile to C via peregrine

## RISC-0 Guest Compile + Execution

**Not tested** — blocked by Rust backend gate failure. No generated Rust code to compile.

## Peregrine Toolchain Build Issues

1. `rocq-verified-extraction >= 1.0.0+9.1` requires `malfunction >= 0.7.1`, but opam only has `0.7`. Fixed by building from source.
2. `rocq-certirocq` requires `coq-wasm`, which has dune build conflicts when built inside the peregrine-tool directory. Fixed by building from source with Wasm backend removed.
3. Peregrine's `WasmBackend.v` cannot compile without `coq-wasm`. Patched `ConfigUtils.v` and `Pipeline.v` to stub out Wasm references.

## Recommendations for Issue #5

### Option A: Add typed IR support to lean-to-lambdabox
- Modify `Erasure.lean` to produce `Program.typed` output
- This requires implementing type preservation through the erasure process
- **Effort**: High — the typed format requires ExAst (extended AST with types), which is significantly more complex than the untyped format
- **Risk**: lean-to-lambdabox's architecture is fundamentally based on type erasure

### Option B: Use C backend instead of Rust
- The C backend works with untyped `.ast` and generates C code
- The generated C code depends on CertiRocq's GC runtime (`gc_stack.h`)
- Would need to compile C code for riscv32im target and link into RISC-0 guest
- **Effort**: Medium — need cross-compilation setup and GC runtime porting
- **Risk**: GC runtime may not work in `no_std` / zkVM environment

### Option C: Upstream enhancement request
- File an issue on lean-to-lambdabox requesting typed IR output
- File an issue on peregrine-tool requesting untyped Rust backend support
- **Effort**: Low (for us), but timeline uncertain

### Option D: Direct Lean4 → RISC-0 compilation
- Skip peregrine entirely and compile Lean4 natively to riscv32im
- Lean4 has C backend support built-in
- **Effort**: Medium — need Lean4 cross-compilation to riscv32im
