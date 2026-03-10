# Chapter 3 — UVM Testbench Generation

This chapter builds the UVM testbench infrastructure for the AHB2APB bridge.

## Folder Contents

- `ahb2apb_bridge_uvmtb/` — Complete UVM testbench (env, agents, interfaces, bringup/sanity tests)

## Quick Start

```bash
cd ahb2apb_bridge_uvmtb
compile.bat          # Compile + elaborate
sim.bat              # Run bringup test (1 txn, no scoreboard)
sim.bat ahb2apb_bridge_sanity_test   # Run sanity test (full scoreboard)
```

## Expected Results

- Compile: `Errors: 0, Warnings: 0`
- Bringup: `TEST PASSED`, `UVM_ERROR: 0`
- Sanity: `TEST PASSED` — all verification goals (VG1–VG6) checked
