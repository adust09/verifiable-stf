# Extract lambda-RC IR to ir_program.json
dump-ir:
    cd guest && lake env lean --run IrDump.lean && mv ir_program.json ../ir_program.json

# Filter IR to only reachable declarations
filter-ir ENTRY="risc0_main_eth2":
    cargo run --release -p ir-trace --bin filter-ir -- ir_program.json ir_program_filtered.json {{ENTRY}}

# Run host-side IR interpreter, generate trace.bin
run-ir-trace INPUT ENTRY="risc0_main_eth2":
    cargo run -p ir-trace -- --ir ir_program.json --input {{INPUT}} --output trace.bin --entry {{ENTRY}}

# Execute mode (cycle count, no proving)
verify-ir-trace INPUT ENTRY="risc0_main_eth2":
    RISC0_DEV_MODE=1 cargo run --release --bin host -- --ir ir_program.json --input {{INPUT}} --entry {{ENTRY}}

# Prove mode (full zk proof)
verify-ir-trace-prove INPUT ENTRY="risc0_main_eth2":
    cargo run --release --bin host -- --ir ir_program.json --input {{INPUT}} --entry {{ENTRY}}

# Benchmark interpreter on multiple validator counts
bench-ir-trace VALIDATORS="10,100":
    #!/usr/bin/env bash
    set -euo pipefail
    for n in $(echo {{VALIDATORS}} | tr ',' ' '); do
        echo "=== N=$n validators ==="
        cargo run --release -p ir-trace --bin gen-eth2-input -- $n /tmp/eth2_input_${n}.bin
        cargo run --release -p ir-trace -- \
          --ir ir_program_filtered.json \
          --input /tmp/eth2_input_${n}.bin \
          --entry risc0_main_eth2 --bench --runs 3
        echo
    done

# Measure zkVM cycle count for IR trace verification
bench-ir-trace-cycles VALIDATORS="10":
    #!/usr/bin/env bash
    set -euo pipefail
    for n in $(echo {{VALIDATORS}} | tr ',' ' '); do
        echo "=== N=$n validators ==="
        cargo run --release -p ir-trace --bin gen-eth2-input -- $n /tmp/eth2_input_${n}.bin
        cargo run --release -p ir-trace --bin ir-trace -- \
          --ir ir_program_filtered.json \
          --input /tmp/eth2_input_${n}.bin \
          --entry risc0_main_eth2 --output /tmp/trace_${n}.bin
        cargo run --release --bin host -- \
          --ir ir_program_filtered.json \
          --input /tmp/eth2_input_${n}.bin \
          --trace /tmp/trace_${n}.bin --mode execute
        echo
    done

# Clean all artifacts
clean:
    cargo clean
    rm -f ir_program.json ir_program_sum.json ir_program_filtered.json
    rm -f trace.bin
    rm -f *.pb
