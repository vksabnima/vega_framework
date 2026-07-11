# Chapter 4 — Test Scenario Generation

> **The generated artifacts do not live in this folder — by design.** Per the
> Chapter 4 flow, AI-generated test scenarios land directly in the Chapter 3
> testbench's own folders, compiled and run as part of that environment, not in
> a separate Chapter 4 tree. This README documents the chapter and points to
> where its generator and outputs actually live, so every chapter has a matching
> folder without duplicating files.

## What Chapter 4 does

Chapter 4 turns the **XTP test plan** (Chapter 2) into directed UVM test
scenarios: one stimulus sequence and one test class per plan row, each tracing
back to the XTP feature it verifies and each self-checking real DUT behaviour
(sticky STATUS bits, `ERROR_ADDR`/`ERROR_INFO` capture, `HRESP`, reset
semantics). The categories span datapath, connectivity, protocol, register
access, error handling, reset, and cross-feature interactions.

## Where everything lives

| Artifact | Location |
|---|---|
| **Generator** (the Chapter 4 tool) | `ch01_vega_tools/vega_test_generator.py` |
| **Input plan** | `ch02_testplan/ahb2apb_testplan.xtp` |
| **Generated stimulus sequences** | `ch03_testbench/ahb2apb_bridge_uvmtb/sequences/ahb_mst_test_*_seq.sv` |
| **Generated test classes** | `ch03_testbench/ahb2apb_bridge_uvmtb/tests/test_*.sv` |
| **Regression runner / results** | `ch05_debug_regression/` (Chapter 5) |

The current suite is **96 generated test classes** plus the bring-up and sanity
tests — **98 total, all passing**. Each generated test pairs a
`ahb_mst_test_<category>_NNN_seq.sv` stimulus sequence with a
`test_<category>_NNN_test.sv` UVM test. One directed
`test_coverage_closure_001` was later added during coverage sign-off
(Chapter 8) to close the remaining functional-coverage bins.

## Why the outputs are folded into Chapter 3

A generated test is only meaningful inside the environment it was written for:
it instantiates the Chapter 3 env, drives the Chapter 3 agents, and is compiled
by the same `compile.bat` / package include list. Splitting the tests into a
standalone `ch04_*` tree would break those includes and the regression flow.
Keeping them alongside the infrastructure (`sequences/`, `tests/`) is the
correct structure; this folder records that decision rather than fighting it.

## Reproduce

```
# regenerate scenarios from the XTP (writes into the ch03 testbench)
python ch01_vega_tools/vega_test_generator.py   # see Chapter 4 for arguments

# run the full suite (from Chapter 5)
# -> 98/98 PASS; see ch05_debug_regression/ and ch08_coverage_signoff/
```

## Status

Documentation pointer. The runnable artifacts are the generated sequences and
tests under `ch03_testbench/ahb2apb_bridge_uvmtb/`; see Chapter 4 in the book
for the generation flow and the per-category breakdown.
