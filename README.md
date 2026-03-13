# verifiable-stf

Verifiable State Transition Function — Lean 4 IR trace interpreter + RISC Zero zkVM verifier.

Interprets Lean 4 lambda-RC IR on the host side and generates an execution trace. The zkVM guest verifies each trace step, proving correctness of the Lean-written STF.

## Architecture

```
guest/IrDump.lean          → Dump Lean IR to JSON
    ↓
tools/ir-trace (host)      → Interpret IR JSON, generate execution trace (bincode)
    ↓
host/src/main.rs           → Pass trace to zkVM, run execute/prove
    ↓
methods/guest-ir-trace     → zkVM guest: re-verify each trace step
```

## Quick Start

```bash
# Build
cargo build --release

# Extract Lean IR (requires Lean 4 toolchain)
just dump-ir

# Filter to reachable declarations only
just filter-ir

# Run interpreter benchmark
just bench-ir-trace 10

# zkVM execution (dev mode)
just verify-ir-trace /tmp/eth2_input_10.bin

# zkVM proving
just verify-ir-trace-prove /tmp/eth2_input_10.bin
```

## Benchmark Results

### 3-Approach Comparison (ETH2 STF)

| Approach | N=10 cycles | N=10 segments | N=100 cycles | N=100 segments |
|----------|-------------|---------------|--------------|----------------|
| Lean (compiled, init) | 26,148,291 | 29 | 35,281,299 | 38 |
| Rust (compiled) | 12,491,509 | 13 | 14,446,747 | 15 |
| IR Trace (host interp) | 238,049 steps / 7.71s | - | 324,741 steps / 11.19s | - |

### Host-side Interpreter (N=10, 3 runs median)

```
Timing:     7.71s (median), 7.62s (min), 11.89s (max)

Trace Steps:  238,049
  Call:          51,128 (21.5%)
  Branch:        27,111 (11.4%)
  PrimResult:   100,490 (42.2%)
  CtorCreate:    10,865 (4.6%)
  ProjResult:    39,701 (16.7%)
  SetResult:      8,754 (3.7%)

Value table:  639,836 entries
Output:       78,522 bytes (Success)
```

### Host-side Interpreter (N=100, 3 runs median)

```
Timing:     11.19s (median), 11.18s (min), 16.44s (max)

Trace Steps:  324,741
  Call:          62,832 (19.3%)
  Branch:        33,685 (10.4%)
  PrimResult:   157,376 (48.5%)
  CtorCreate:    13,835 (4.3%)
  ProjResult:    46,905 (14.4%)
  SetResult:     10,108 (3.1%)

Value table:  867,320 entries
Output:       91,752 bytes (Success)
```

### Scaling Characteristics

| Metric | N=10 | N=100 | Ratio |
|--------|------|-------|-------|
| Total steps | 238,049 | 324,741 | 1.36x |
| Wall time (median) | 7.71s | 11.19s | 1.45x |
| Value table entries | 639,836 | 867,320 | 1.36x |
| PrimResult steps | 100,490 | 157,376 | 1.57x |
| Output size | 78,522 B | 91,752 B | 1.17x |

### zkVM Verification (Sum Example, E2E)

```
Mode:        execute
Trace:       3,843 bytes (bincode)
User Cycles: 653,173
Segments:    1
Wall Time:   76.18ms
Output:      8 bytes (Success)
```

### ETH2 zkVM Status

| Format | Trace size | Status |
|--------|-----------|--------|
| JSON | ~15 GB | Too large |
| bincode | 8.14 GB | Exceeds zkVM ~4 GB input limit |

Root cause: the value_table stores 639,837 entries including large ByteArray/Object values. See [docs/problem.md](docs/problem.md) for detailed analysis and proposed solutions.

## Project Structure

```
├── ir-trace-common/          # Shared types (Value, TraceStep, PrimOp)
├── tools/ir-trace/           # Host-side IR interpreter
│   ├── src/interpreter/      # Core VM (eval_expr, exec_body, stack)
│   └── src/bin/              # gen-eth2-input, filter-ir
├── methods/guest-ir-trace/   # zkVM guest verifier
├── host/                     # Host driver (execute/prove modes)
├── guest/                    # Lean 4 ETH2 STF + IrDump.lean
└── docs/                     # Benchmark results, trace size analysis
```

## Requirements

- **Rust**: stable (via `rust-toolchain.toml`)
- **Lean**: 4.22.0 (for IR extraction only)
- **just**: command runner
