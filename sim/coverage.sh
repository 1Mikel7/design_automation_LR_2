#!/bin/sh
cd "$(dirname "$0")"
verilator_coverage --annotate build/annotated --annotate-min 1 build/coverage.dat