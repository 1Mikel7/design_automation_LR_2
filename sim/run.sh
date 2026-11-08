#!/bin/sh
cd "$(dirname "$0")"
mkdir -p build
verilator --cc --exe --build --timing --coverage-line --trace -Wno-fatal -Wno-lint -Wno-style \
    --top-module top -Mdir build/obj -o sim \
    "$(pwd)/coverage.vlt" ../rtl/apb_traffic_light.sv ../tb/apb_master.sv ../tb/top.sv "$(pwd)/sim_main.cpp" \
    > build/verilator.log 2>&1 || { cat build/verilator.log; exit 1; }
cd build && ./obj/sim "$@"