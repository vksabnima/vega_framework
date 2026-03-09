# VEGA Framework — Companion Repository

This repository accompanies the book:
**Cognitive Verification Architecture: A Structured Approach to Modern Hardware Verification — The VEGA Framework**
by Vikash Kumar

All examples use the **AHB2APB protocol bridge** as the worked example.
The same workflow applies to any design.

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| Questa Intel FPGA Starter Edition (or any UVM-capable simulator) | Compile and simulate |
| Git Bash (Windows) or Bash (Linux/Mac) | Run shell scripts |
| Access to an LLM (Claude, ChatGPT, or similar) | Generate test plans, testbench code |
| Basic familiarity with UVM testbench structure | Understand generated code |

**Questa FSE path used in this repo:** `C:\intelFPGA\22.1std\questa_fse`
Update paths in `compile.bat`, `sim.bat`, and `run_all_tests.sh` if your installation differs.

---

## Repository Structure

```
vega_framework/
├── ch01_vega_tools/              ← Chapter 1: Tool setup & inputs
├── ch02_testplan/                ← Chapter 2: XTP generation
├── ch03_testbench/               ← Chapter 3: UVM testbench infrastructure
│   └── ahb2apb_bridge_uvmtb/
├── ch04_tests/                   ← Chapter 4: Test scenarios
│   ├── sequences/
│   └── tests/
├── ch05_debug_regression/        ← Chapter 5: Debug & regression
├── ch07_coverage_signoff/        ← Chapter 7: Coverage analysis & sign-off
└── rtl_Design/                   ← RTL source (reference design)
```

---

## Chapter 1 — VEGA Tool Setup & Verification Intent

**Goal:** Set up the VEGA framework inputs — the verification intent file and manifest that tell the LLM what to build.

### Folder Contents

| File | Purpose |
|------|---------|
| `manifest.json` | Project configuration — design name, simulator paths, interfaces, verification goals |
| `verification_intent.txt` | Plain-English description of what to drive, observe, and check |
| `vega_xtp_gen.py` | Script to generate XTP from spec + prompts (used in Chapter 2) |
| `vega_llm_tbgen.py` | Script to generate UVM testbench from XTP + manifest (used in Chapter 3) |

### What to Do

1. Read `verification_intent.txt` — this is the **only file the engineer writes per project**
2. Read `manifest.json` — defines design, interfaces, clocks, resets, and verification goals
3. Place your design spec PDF in this folder (e.g., `AHB2APB_Bridge_Spec.pdf`)
4. Place your IP-XACT XML in this folder (e.g., `ahb2apb_bridge.xml`)

### Key Concept

The verification intent uses **no signal names, no SystemVerilog, no UVM knowledge**. It has four sections:
- **DRIVE** — what stimulus to generate
- **OBSERVE** — what to monitor
- **CHECK** — verification goals (VG1–VG6)
- **OUT OF SCOPE** — what this phase does NOT cover

### How to Verify

```bash
# Check files are in place
ls ch01_vega_tools/
# Expected: manifest.json  vega_llm_tbgen.py  vega_xtp_gen.py  verification_intent.txt
```

---

## Chapter 2 — Test Plan Synthesis (XTP)

**Goal:** Generate an Executable Test Plan (XTP) from the design specification using LLM prompts.

### Folder Contents

| Folder/File | Purpose |
|-------------|---------|
| `prompts/` | VEGA prompts — feature extraction, review |
| `outputs/AHB2APB_Bridge_Spec_testplan.xtp` | Generated XTP (reference output) |
| `outputs/AHB2APB_Bridge_Spec_summary.csv` | Feature summary table |
| `outputs/AHB2APB_Bridge_Spec_summary.txt` | Human-readable summary |

### Steps to Follow

1. Open `prompts/step1_feature_extraction.txt`
2. Paste the prompt into your LLM along with your design spec PDF
3. Save the LLM output
4. Repeat with `step1a_feature_extraction.txt` (adds summary tables)
5. Repeat with `step1b_review.txt` (review and refine)
6. Compare your output to `outputs/AHB2APB_Bridge_Spec_testplan.xtp`

### How to Verify

```bash
# Check XTP was generated
cat ch02_testplan/outputs/AHB2APB_Bridge_Spec_testplan.xtp | head -50

# Check feature count — should list features across categories:
# AHB protocol, APB protocol, conversion, burst, error, reset, register
grep "FEATURE" ch02_testplan/outputs/AHB2APB_Bridge_Spec_testplan.xtp | wc -l
```

### Key Output

`outputs/AHB2APB_Bridge_Spec_testplan.xtp` — the complete Executable Test Plan, input for Chapter 3.

---

## Chapter 3 — UVM Testbench Generation

**Goal:** Generate the UVM testbench infrastructure and verify it compiles and runs with bringup + sanity tests.

### Folder Contents

```
ch03_testbench/ahb2apb_bridge_uvmtb/
├── env/
│   ├── ahb_mst_agent/        ← AHB master driver, monitor, sequencer, agent
│   ├── apb_slv_agent/        ← APB slave driver, monitor, sequencer, agent
│   ├── ahb2apb_bridge_env.sv ← Top environment
│   ├── ahb2apb_bridge_scoreboard.sv ← Scoreboard (VG1–VG6)
│   └── ahb2apb_bridge_coverage.sv   ← Functional coverage collector
├── config/
│   └── ahb2apb_bridge_dut_config.sv  ← DUT configuration object
├── top/
│   └── tb_top.sv             ← Testbench top module
├── sequences/
│   ├── ahb_mst_base_seq.sv   ← Base sequence with helper tasks
│   ├── ahb_mst_bringup_seq.sv ← Bringup stimulus
│   └── apb_slv_bringup_seq.sv ← APB slave responder
├── tests/
│   ├── ahb2apb_bridge_bringup_test.sv ← 1 txn, no scoreboard — proves TB alive
│   └── ahb2apb_bridge_sanity_test.sv  ← N txns, full scoreboard — proves DUT works
├── ahb2apb_bridge_pkg.sv     ← Package (include order)
├── ahb_mst_if.sv             ← AHB interface
├── apb_slv_if.sv             ← APB interface
├── reset_ctrl_if.sv          ← Reset control interface
├── tb_list.f                 ← Compile file list
├── compile.bat               ← Compile + elaborate (Windows)
└── sim.bat                   ← Run simulation (Windows)
```

### Steps to Follow

**Step 1: Compile**
```bash
cd ch03_testbench/ahb2apb_bridge_uvmtb
compile.bat
```
Or manually:
```bash
cd ch03_testbench/ahb2apb_bridge_uvmtb
rm -rf work
/c/intelFPGA/22.1std/questa_fse/win64/vlib work
/c/intelFPGA/22.1std/questa_fse/win64/vlog -sv -timescale 1ns/1ps \
    +define+UVM_NO_DPI \
    "+incdir+/c/intelFPGA/22.1std/questa_fse/verilog_src/uvm-1.1d/src" \
    "+incdir+." \
    -f tb_list.f \
    /c/intelFPGA/22.1std/questa_fse/verilog_src/uvm-1.1d/src/uvm_pkg.sv
/c/intelFPGA/22.1std/questa_fse/win64/vopt tb_top -o tb_top_opt +acc
```

**Expected:** `Errors: 0, Warnings: 0`

**Step 2: Run bringup test**
```bash
sim.bat
# or:
/c/intelFPGA/22.1std/questa_fse/win64/vsim -c tb_top_opt \
    +UVM_TESTNAME=ahb2apb_bridge_bringup_test \
    -do "run -all; quit -f"
```

**Expected:** `TEST PASSED`, `UVM_ERROR: 0`, `UVM_FATAL: 0`

**Step 3: Run sanity test**
```bash
sim.bat ahb2apb_bridge_sanity_test
```

**Expected:** `TEST PASSED` — scoreboard checks all 6 verification goals (VG1–VG6)

**Step 4: View waveforms**

`sim.bat` automatically records all signals to `sim.wlf` (via `log -r /*`).
To open the waveform viewer after simulation:
```bash
# Open Questa GUI with saved waveform
/c/intelFPGA/22.1std/questa_fse/win64/vsim -view sim.wlf
```
In the GUI: **Add > Wave > Signals in Design** to browse, or drag signals from the object browser into the wave window.

Key signals to inspect:
- `tb_top/ahb_if/*` — AHB bus (HADDR, HWDATA, HRDATA, HWRITE, HREADY_OUT, HRESP)
- `tb_top/apb_if/*` — APB bus (PADDR, PWDATA, PRDATA, PWRITE, PSEL, PENABLE, PREADY, PSLVERR)
- `tb_top/dut/state` — Bridge FSM state

### How to Verify

| Check | What to look for |
|-------|-----------------|
| Compile | `Errors: 0, Warnings: 0` in vlog output |
| Elaborate | `Errors: 0, Warnings: 0` in vopt output |
| Bringup test | `TEST PASSED` in transcript — TB is alive |
| Sanity test | `TEST PASSED` — scoreboard VG1-VG6 all pass |
| Scoreboard | `AHB=N APB=N` — transaction counts match (VG6) |

### Troubleshooting

| Error | Fix |
|-------|-----|
| `Unable to checkout verification license` | Questa FSE lacks `svverification` — don't use `covergroup` or `.randomize()` |
| `config_db get failed` | Check virtual interface type has no modport suffix |
| `UVM_FATAL: No sequencer` | Check agent `is_active` matches config |

---

## Chapter 4 — Test Scenarios

**Goal:** Write 47 directed test scenarios derived from the XTP, covering datapath, protocol, register access, error handling, reset, stress, and cross-feature interactions.

### Folder Contents

```
ch04_tests/
├── sequences/    ← 47 sequence files (stimulus)
│   ├── ahb_mst_datapath_001_seq.sv ... ahb_mst_datapath_011_seq.sv
│   ├── ahb_mst_connectivity_001_seq.sv ... 004
│   ├── ahb_mst_protocol_001_seq.sv ... 004
│   ├── ahb_mst_reg_access_001_seq.sv ... 006
│   ├── ahb_mst_error_001_seq.sv ... 012
│   ├── ahb_mst_reset_001_seq.sv ... 005
│   ├── ahb_mst_stress_001_seq.sv
│   └── ahb_mst_cross_feature_001_seq.sv ... 004
└── tests/        ← 47 test files (test classes)
    └── (mirrors sequences — one test per sequence)
```

### Test Categories

| Category | Tests | What They Cover |
|----------|-------|-----------------|
| Datapath | 001–011 | Write/read forwarding, address, data, burst types, boundary, enable gating |
| Connectivity | 001–004 | HREADY_OUT, signal stability, PSEL/PENABLE timing |
| Protocol | 001–004 | Wait states, min 2-cycle APB, two-cycle AHB error, APB stability |
| Register Access | 001–006 | CTRL, STATUS, ERROR_ADDR, ERROR_INFO — R/W, W1C, reset values |
| Error | 001–012 | Address error, timeout, PSLVERR, error recovery, interrupt, first-capture |
| Reset | 001–005 | Soft reset, active-transfer abort, async reset, safe state, ready timing |
| Stress | 001 | 200+ back-to-back transfers, all burst types, all sizes |
| Cross-Feature | 001–004 | Reset+transfer, timeout+register, soft-reset+error, wait+timeout |

### Steps to Follow

**Step 1: Compile** (from ch03, includes ch04 files via pkg.sv)
```bash
cd ch03_testbench/ahb2apb_bridge_uvmtb
compile.bat
```

**Step 2: Run a single test**
```bash
sim.bat ahb2apb_bridge_datapath_001_test
```

**Step 3: Run another**
```bash
sim.bat ahb2apb_bridge_error_006_test
```

### How to Verify

Each test prints `TEST PASSED` or `TEST FAILED` in the transcript.
Look for:
- `UVM_ERROR: 0`
- `UVM_FATAL: 0`
- Sequence `SUMMARY: N PASS, 0 FAIL`

### Sequence Helper Tasks

All sequences extend `ahb_mst_base_seq` (in ch03) which provides:

| Task | Purpose |
|------|---------|
| `drive_write(addr, data)` | Single AHB write |
| `drive_read(addr, rdata, resp)` | Single AHB read |
| `drive_write_ex(addr, data, hburst, hsize)` | Write with explicit burst/size |
| `drive_read_ex(addr, rdata, resp, hburst, hsize)` | Read with explicit burst/size |
| `check_read(tag, addr, expected)` | Read + compare |
| `write_and_verify(tag, addr, data)` | Write + readback + compare |
| `drive_reg_write(offset, data)` | Write to bridge register |
| `check_reg_read(tag, offset, expected)` | Read register + compare |

---

## Chapter 5 — Debug & Regression

**Goal:** Run the full 49-test regression, debug any failures, and confirm all tests pass.

### Folder Contents

| File | Purpose |
|------|---------|
| `run_all_tests.sh` | Regression runner — compiles, runs all 49 tests, reports results |
| `test_results_summary.txt` | Per-test pass/fail with descriptions |
| `logs/` | Per-test simulation logs (created by regression run) |

### Steps to Follow

**Step 1: Run full regression**
```bash
cd ch05_debug_regression
bash run_all_tests.sh
```
This will:
1. Compile the TB from `ch03_testbench/`
2. Run all 49 tests sequentially
3. Report PASS/FAIL for each test

**Expected output:**
```
TOTAL: 49  PASS: 49  FAIL: 0
```

**Step 2: Review test results**
```bash
cat ch05_debug_regression/test_results_summary.txt
```

### Debugging a Failed Test

```bash
# Check the log for a specific test
cat ch05_debug_regression/logs/ahb2apb_bridge_error_006_test.log | grep -E "ERROR|FAIL|FATAL"

# Run a single test with full verbosity for debugging
cd ch03_testbench/ahb2apb_bridge_uvmtb
sim.bat ahb2apb_bridge_error_006_test
# Add +UVM_VERBOSITY=UVM_HIGH for more detail

# Open waveform for visual debug
/c/intelFPGA/22.1std/questa_fse/win64/vsim -view sim.wlf
```

### How to Verify

| Check | Expected |
|-------|----------|
| Regression | `49/49 PASSED` |
| No test failures | `FAIL: 0` |
| Test summary | Matches `test_results_summary.txt` |

---

## Chapter 7 — Coverage Analysis & Sign-off

**Goal:** Analyze functional coverage across the full regression, identify and close coverage gaps, and build the sign-off argument.

### Folder Contents

| File | Purpose |
|------|---------|
| `coverage_report.txt` | Final coverage report — 128/128 bins, 100% regression coverage |
| `test_results_summary.txt` | Complete test pass/fail record (sign-off evidence) |

### Coverage Architecture

The coverage collector (`ch03_testbench/.../env/ahb2apb_bridge_coverage.sv`) uses manual bin tracking with associative arrays — a workaround for Questa FSE which lacks the `svverification` license required for `covergroup`. It subscribes to AHB and APB monitor analysis ports and samples protocol-level coverage every clock cycle via virtual interfaces.

### Coverage Groups

| Coverage Group | Bins | What It Covers |
|----------------|------|----------------|
| AHB_TXN | 57 | Address ranges, HWRITE, HSIZE, HBURST (all 8), HRESP, crosses |
| APB_TXN | 11 | Address ranges, PWRITE, PSLVERR, crosses |
| REGISTER_ACCESS | 12 | CTRL/STATUS/ERROR_ADDR/ERROR_INFO read/write |
| ERROR_SCENARIOS | 11 | Error direction x address range crosses |
| AHB_PROTOCOL | 13 | HREADY_OUT, HRESP, HTRANS, two-cycle error, trans x ready |
| APB_PROTOCOL | 24 | SETUP/ACCESS phases, transitions, PREADY wait, PSLVERR |
| **TOTAL** | **128** | **100% covered** |

### Excluded Bins (architectural limitations)

These bins are intentionally excluded — they are not coverage holes but require hardware features this bridge does not support:
- `REG.ERROR_ADDR.WRITE`, `REG.ERROR_INFO.WRITE` — read-only registers
- `APB_PROT.SETUP.WAIT` — PREADY is meaningless during SETUP phase
- `AHB_PROT.HTRANS BUSY/SEQ` — requires pipelined burst driver
- `AHB_PROT.NONSEQ.STALL` — requires pipelined back-to-back transfers
- `AHB_TXN.burst_x_resp ERROR` (7 bins) — requires mid-burst error injection

### Steps to Follow

**Step 1: Run regression** (if not already done in Chapter 5)
```bash
cd ch05_debug_regression
bash run_all_tests.sh
```

**Step 2: Review coverage report**
```bash
cat ch07_coverage_signoff/coverage_report.txt
```

**Step 3: Check per-test coverage in simulation logs**
```bash
# Each test log prints per-group and overall coverage at end of simulation
grep "OVERALL" ch05_debug_regression/logs/ahb2apb_bridge_stress_001_test.log
# Expected: OVERALL : 71.1%  (91/128 bins)

# Top coverage contributors:
#   stress_001  : 71.1% (91/128) — exercises all burst types, sizes, error paths
#   error_006   : 54.7% (70/128) — PSLVERR detection + read-with-error
#   error_012   : 53.9% (69/128) — timeout + APB deassert
```

**Step 4: Identify uncovered bins** (if coverage < 100%)
```bash
# Each test log lists uncovered bins at the end
grep -A 50 "UNCOVERED BINS" ch05_debug_regression/logs/ahb2apb_bridge_stress_001_test.log
```

**Step 5: Close coverage gaps**

Coverage closure techniques used in this project:
1. Added `drive_write_ex` / `drive_read_ex` helpers — set HBURST/HSIZE after `post_randomize()` to prevent overwrite
2. Exercised all 7 burst types (INCR, WRAP4, INCR4, WRAP8, INCR8, WRAP16, INCR16) in stress_001
3. Added BYTE and HALFWORD transfer exercises (HSIZE=000, 001)
4. Added read-error coverage at multiple address ranges
5. Added read-with-PSLVERR to error_006 sequence
6. Removed architecturally impossible bins from coverage goals

### How to Verify

| Check | Expected |
|-------|----------|
| Coverage report | `128/128 bins covered (100%)` |
| All groups | Each group shows 100% in regression union |
| Excluded bins | Documented with architectural justification |
| Test results | `49/49 PASSED` |

---

## RTL Design

The RTL source is in `rtl_Design/ahb2apb_bridge.sv`. This is the design under test.

Key features:
- AHB-Lite slave interface (32-bit address/data)
- APB master interface (32-bit address/data)
- 4 configuration registers at `0x0F00–0x0FFF` (CTRL, STATUS, ERROR_ADDR, ERROR_INFO)
- FSM-based protocol conversion (IDLE → SETUP → ACCESS)
- Configurable timeout with formula `2^(TIMEOUT_VAL+4)` cycles
- Error detection: address range, APB timeout, PSLVERR
- Soft reset (self-clearing) and async hard reset

---

## Quick Reference — Common Commands

```bash
# Compile TB (from ch03)
cd ch03_testbench/ahb2apb_bridge_uvmtb && compile.bat

# Run bringup test
sim.bat

# Run any specific test
sim.bat ahb2apb_bridge_datapath_005_test

# Run full regression (from ch05)
cd ch05_debug_regression && bash run_all_tests.sh

# Check a test log
cat ch05_debug_regression/logs/<test_name>.log | grep -E "PASSED|FAILED|ERROR"
```

---

## License

This repository is provided as a learning companion to the VEGA Framework book.
