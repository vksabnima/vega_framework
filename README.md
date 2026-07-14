# VEGA Framework — Companion Repository

This repository accompanies the book:
**AI-Assisted Hardware Verification: Cognitive Verification Architecture with the VEGA Framework**
by Vikash Kumar

> 📖 **Get the book** — *AI-Assisted Hardware Verification* · Springer · ISBN 978-3-032-34545-5
> 👉 **[View on Springer Nature Link](https://link.springer.com/book/9783032345455)**

All examples are built on the **Educational Bus Bridge Model** — a carefully
curated AHB-to-APB bridge (specification, RTL, and IP-XACT) authored
specifically for this book. It is deliberately drafted to carry enough real
design context, a register file, error propagation, a configurable timeout,
and burst handling, to give the AI the substance it needs to perform genuine,
close-to-silicon hardware verification rather than a toy demonstration. The
same governed workflow applies to any design.

---

## Time per Verification Stage — VEGA vs. Manual

The table contrasts the **wall-clock time measured with VEGA** on this
repository's worked example (the Educational Bus Bridge Model, an AHB-to-APB
bridge) against **typical manual effort** reported in industry verification
studies. VEGA figures are *measured this run*; manual figures are *cited
industry ranges*, not measured for this design.

| Verification stage | Manual (typical, industry) | VEGA (measured) |
|---|:--:|:--:|
| Design-intent → TestPlan / XTP *(Ch. 2)* | days | **≈ 5 min** |
| UVM testbench bring-up *(Ch. 3)* | days – weeks | **≈ 4 min** |
| Debug to first passing test *(Ch. 3 / 5)* | hours – days | **≈ 7 min** |
| Test-scenario suite — 103 tests *(Ch. 4)* | weeks | **≈ 2.2 h** (78 s/test) |
| **End-to-end: spec → verified suite** | **weeks** | **≈ 2.5 h** |

<sub>**VEGA** = wall-clock measured on Questa Intel FPGA Starter Edition with
Claude Opus 4.8, under human Verification-Strategist governance. The Ch. 4 rate
is 77.7 s/test measured over 72 of 103 logged generations; all 103 tests were
generated and compile clean. **Manual** = typical ranges from the Wilson
Research Group functional-verification studies and Siemens Verification
Horizons — verification consumes ~70% of IC/ASIC project effort, and debug
alone ~44% of a verification engineer's time. Manual figures are industry
estimates, not measured for this design.</sub>

---

## Simulator Independence

VEGA is a **methodology, not a tool tied to one simulator.** The framework —
governed, intent-driven generation with full traceability from design intent
to verification evidence — applies to **any SystemVerilog/UVM simulator**
(Questa, VCS, Xcelium, Riviera-PRO, and others).

This repository uses **Questa Intel FPGA Starter Edition** as the reference
environment only because it is free and widely available. Everything
simulator-specific is confined to a thin outer layer:

- **The generated UVM testbench** (env, agents, scoreboard, sequences, tests)
  is standard SystemVerilog/UVM and runs on any UVM simulator as-is.
- **The `.bat` scripts** (`compile.bat`, `sim.bat`, `waves.bat`) just wrap one
  tool's invocation — swap them for your simulator's compile/run commands.
- **The Questa-FSE accommodations** (manual `.randomize()`, associative-array
  coverage instead of `covergroup`) exist only because the *free* edition
  omits the `svverification` license. On a fully licensed simulator you can
  drop them and use native `.randomize()`, `covergroup`, and `uvm_reg`.

The parts that *are* VEGA — the prompts, the XTP flow, the quality gates, and
the Verification Strategist governance model — are identical regardless of
which simulator runs the result.

---

## Prerequisites

> **Platform note:** The documented commands and `.bat` scripts target
> Windows + Questa Intel FPGA Starter Edition. Linux and macOS readers will
> need to adapt the scripts and Quartus paths.

The book's Chapter 3 §3.4 lists every tool you need. The list below is the same
in condensed form. Install in order; verify each step before moving on. Commands
are for Windows Command Prompt (the platform the book targets).

### 1. Python 3.10 or later

```cmd
winget install Python.Python.3.12
python --version
```
Expected: `Python 3.12.x` or higher.

### 2. Anthropic Python SDK

```cmd
python -m pip install anthropic
python -c "import anthropic; print(anthropic.__version__)"
```
Expected: a version number (0.40.0 or later).

### 3. PDF text extraction (optional, recommended)

```cmd
python -m pip install pdfplumber
```
Improves protocol-timing accuracy when `--spec` is provided. If skipped, the
generator falls back to the LLM's protocol knowledge.

### 4. Node.js v20 LTS

```cmd
winget install OpenJS.NodeJS.LTS
node --version
```
Expected: `v20.x.x` or later. (Claude Code requires Node 18.18+; v20 LTS is
recommended. Older Node will crash with `TypeError: Object not disposable`.)

### 5. Claude Code

```cmd
npm install -g @anthropic-ai/claude-code
claude --version
```
Then run `claude` once and complete the browser-based authentication.
Requires a Claude.ai Pro or Max subscription (covers all fix sessions, no
per-token billing).

### 6. Git

```cmd
winget install Git.Git
git --version
```

### 7. Questa Intel FPGA Starter Edition

Free, distributed with Quartus Prime Lite from Intel:
<https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/download.html>

Default install path used throughout this repo: `C:\intelFPGA\22.1std\questa_fse`.
If yours differs, update `questa_path` in `ch01_vega_tools/manifest.json` and
the `set QUESTA_HOME=…` lines at the top of `compile.bat`, `sim.bat`, and `waves.bat`.

> **Questa FSE constraint:** the `svverification` license is **not** included.
> `.randomize()` cannot be called on user-defined objects, and `covergroup`
> requires a workaround. Every prompt and rule in VEGA accounts for this.

### 8. Anthropic API key

The generator (`vega_llm_tbgen.py`) calls the Anthropic API directly. This is
**separate** from the Claude Code subscription. One full testbench costs ~$1–2
in API credits with Claude Opus.

Create a key at <https://console.anthropic.com/settings/keys>, then set it
permanently in Windows environment variables (System → Advanced → Environment
Variables → New User variable):

```
Name : ANTHROPIC_API_KEY
Value: sk-ant-api03-... (your key)
```

Verify in a new Command Prompt:

```cmd
echo %ANTHROPIC_API_KEY%
```
Expected output starts with `sk-ant-…`.

---

## Quick Start: Chapter 3 Worked Example

This is the exact command pair from book §3.7.5 — generating the AHB2APB
bridge UVM testbench end to end. All four required inputs are already in
`ch01_vega_tools/`; the spec PDF and IP-XACT XML ship with the repo.

### Step 1 — Preview the prompt (no API charge)

`--dry-run` validates every input, builds the master prompt, prints the first
4,000 characters, and reports token count without calling the API. Always run
this first.

```cmd
cd C:\path\to\vega_framework

python ch01_vega_tools\vega_llm_tbgen.py ^
   --ipxact   ch01_vega_tools\ahb2apb_bridge.xml ^
   --manifest ch01_vega_tools\manifest.json ^
   --intent   ch01_vega_tools\verification_intent.txt ^
   --dry-run
```

If the pre-flight check passes (no missing sections, design-name match,
interfaces defined), proceed to Step 2.

### Step 2 — Generate the testbench

```cmd
python ch01_vega_tools\vega_llm_tbgen.py ^
   --ipxact   ch01_vega_tools\ahb2apb_bridge.xml ^
   --manifest ch01_vega_tools\manifest.json ^
   --intent   ch01_vega_tools\verification_intent.txt ^
   --spec     ch01_vega_tools\ahb2apb_spec.pdf ^
   --rtl      rtl_Design\ahb2apb_bridge.sv ^
   --output   ch03_testbench\ahb2apb_bridge_uvmtb
```

Allow 3–5 minutes. The script streams each generated file as it lands.

> ⚠️ **Heads-up:** the repo already ships a fully generated reference
> testbench at `ch03_testbench/ahb2apb_bridge_uvmtb/` (committed so readers
> can inspect the output without spending API credits). Running Step 2 with
> the `--output` path above **will overwrite that committed reference**.
> If you want to keep both, point `--output` to a sibling directory
> (e.g. `ch03_testbench\ahb2apb_bridge_uvmtb_mine`).

### Expected Output (Step 2)

The first ~30 lines should look like this — use it to confirm your run is
on track:

```
VEGA LLM Testbench Generator v2.0
Model : claude-opus-4-8 | <date>

PARSING INPUTS
============================================================
  ✓  IP-XACT  : ahb2apb_bridge | 21 ports
  ✓  Manifest : 2 interface(s): ahb_mst, apb_slv
  ✓  Intent   : 1,847 chars
  ✓  Spec     : 12,340 chars from ahb2apb_spec.pdf
  ✓  RTL      : ahb2apb_bridge | 21 ports parsed

PRE-FLIGHT CHECK
============================================================
  ✓  All checks passed

CREATING DIRECTORY STRUCTURE
============================================================
  ✓  7 directories created

LLM GENERATION
============================================================
  →  Prompt   : ~8,304 tokens
  →  Files    : 21 to generate
  →  Model    : claude-opus-4-8
  →  Streaming response — files will appear as generated...

  [ 1/21] config/ahb2apb_bridge_dut_config.sv
  [ 2/21] ahb_mst_if.sv
  ...
  [21/21] top/ahb2apb_bridge_dut_bind.sv
```

After all 21 files stream, the script writes deterministic scaffolding
(`*_pkg.sv`, `tb_list.f`, `compile.bat`, `sim.bat`, `waves.bat`, `CLAUDE.md`), runs
`git init` + iteration-0 commit, and prints `DONE`.

### Step 3 — Fix iteratively with Claude Code

```cmd
cd ch03_testbench\ahb2apb_bridge_uvmtb
claude
```

Claude Code reads `CLAUDE.md` automatically. A typical first session:

```
> read the directory structure and prepare for compile/sim error fixes
> run compile.bat and fix any errors
> run sim.bat and fix any UVM_FATAL or UVM_ERROR
> run sim.bat ahb2apb_bridge_sanity_test and fix any errors
> commit as iteration-1
```

See book §3.7.7 for the full fix-session walkthrough.

---

## Repository Structure

```
vega_framework/
├── ch01_vega_tools/              ← Chapter 1: Tool setup & inputs
├── ch02_testplan/                ← Chapter 2: XTP generation
├── ch03_testbench/               ← Chapter 3: UVM testbench infrastructure
│   └── ahb2apb_bridge_uvmtb/
│       ├── sequences/            ← Chapter 4: generated test sequences
│       └── tests/                ← Chapter 4: generated test classes
├── ch04_test_scenarios/          ← Chapter 4: pointer README (tests live in ch03 above)
├── ch05_debug_regression/        ← Chapter 5: Debug & regression
├── ch06_subsystem/               ← Chapter 6: Subsystem verification (architecture & teaching)
├── ch07_quality_metrics/         ← Chapter 7: Quality metrics
├── ch08_coverage_signoff/        ← Chapter 8: Coverage analysis & sign-off
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
| `ahb2apb_bridge.xml` | IP-XACT (IEEE 1685) port description for the bridge |
| `ahb2apb_spec.pdf` | Specification for the **Educational Bus Bridge Model** (author-original AHB-to-APB bridge) — see PDF front-matter for the disclaimer and IP notice |
| `vega_xtp_gen.py` | Script to generate XTP from spec + prompts (used in Chapter 2) |
| `vega_llm_tbgen.py` | Script to generate UVM testbench from XTP + manifest (used in Chapter 3) |

### Setup Walkthrough

For the Educational Bus Bridge Model worked example shipped in this repo, all
four required inputs are already in place — no setup needed beyond completing the
[Prerequisites](#prerequisites). Skip directly to Chapter 2 or Chapter 3.

For your own design, follow these steps before running the generators:

**Step 1 — Confirm the toolchain.** From the [Prerequisites](#prerequisites)
section, you should already have Python 3.10+, the `anthropic` SDK, Node.js 20
LTS, Claude Code, Git, Questa FSE, and `ANTHROPIC_API_KEY` set. Verify:

```cmd
python --version
python -c "import anthropic; print(anthropic.__version__)"
node --version
claude --version
git --version
echo %ANTHROPIC_API_KEY%
```

**Step 2 — Place your inputs in `ch01_vega_tools/`.** Use the existing AHB2APB
files as templates:

```cmd
copy <your_design>.xml          ch01_vega_tools\
copy <your_design>_spec.pdf     ch01_vega_tools\
```

**Step 3 — Edit `manifest.json`** to match your DUT (top module name, RTL
file path relative to `ch03_testbench/<output_dir>/`, clock + reset port
names, interface roles, verification goals). The manifest is the only file
that requires deliberate engineering judgment.

**Step 4 — Write `verification_intent.txt`** in plain English. Four sections:

- **DRIVE** — what stimulus to generate (transaction types, addresses, data patterns)
- **OBSERVE** — what to monitor (when to capture, which signals mark capture point)
- **CHECK** — verification goals as `VGn — <condition that must hold true>`
- **OUT OF SCOPE** — what this testbench intentionally does NOT verify

Takes under ten minutes per design. The LLM implements this directly in the
driver, monitor, scoreboard, and sequences — vague intent produces a TB that
compiles but checks nothing meaningful.

**Step 5 — Verify your inputs are in place.**

```bash
ls ch01_vega_tools/
# Expected (minimum): manifest.json  verification_intent.txt
#                     vega_llm_tbgen.py  vega_xtp_gen.py
#                     <your_design>.xml  <your_design>_spec.pdf
```

You're now ready for Chapter 2 (test-plan generation) or skip directly to
Chapter 3 (testbench generation).

---

## Chapter 2 — Test Plan Synthesis (XTP)

**Goal:** Generate an Executable Test Plan (XTP) from the design specification.
Two paths produce the same artifact (book §2.2): an automated one-shot script
or a four-step manual flow with explicit review gates.

### Folder Contents

| Folder/File | Purpose |
|-------------|---------|
| `prompts/step1_feature_extraction.txt` | Step 1 prompt — extracts features + ambiguity register |
| `prompts/step1a_feature_extraction.txt` | Step 1a prompt — adds summary tables |
| `prompts/step1b_review.txt` | Step 1b prompt — feature-list review (PASS/FAIL per feature) |
| `outputs/AHB2APB_Bridge_Spec_testplan.xtp` | Reference XTP — the final Executable Test Plan |
| `outputs/AHB2APB_Bridge_Spec_summary.csv` | Reference feature summary table |
| `outputs/AHB2APB_Bridge_Spec_summary.txt` | Reference human-readable summary |

> The committed `AHB2APB_Bridge_Spec_*` outputs are reference artifacts from
> a past run. A fresh run with the renamed spec PDF will produce filenames
> derived from the new spec stem (e.g., `ahb2apb_spec_testplan.xtp`).

### Path A — Automated (one command, book §2.3)

`vega_xtp_gen.py` runs a staged, multi-call pipeline (the PDF is cached and
reused across stages): feature discovery (standard, misc, and cross-feature),
an audit pass, per-feature test generation in parallel, then assemble and lint.
It applies 12 quality checks (6 per-test + 6 global) against an 80% per-feature
bar, retries a weak feature up to 2× — writing a flagged stub rather than
dropping it — and runs a deterministic XML lint before the XTP is written.

```cmd
python -m pip install pymupdf anthropic

python ch01_vega_tools\vega_xtp_gen.py ^
   ch01_vega_tools\ahb2apb_spec.pdf ^
   --output ch02_testplan\outputs
```

Cost: typically a few cents per spec. Output: a single `*_testplan.xtp` plus
`*_summary.{csv,txt}` in the chosen output directory.

> **Book §2.8 note.** The book runs this step as
> `python ch01_vega_tools/vega_xtp_gen.py spec.pdf`. So that command works
> verbatim from a fresh clone, a copy of the specification named `spec.pdf`
> ships at the repository root — it is byte-identical to
> `ch01_vega_tools/ahb2apb_spec.pdf` (the same spec, two names).

When to use Path A: well-structured specs and protocols the model already
knows. When to skip it: specs that rely heavily on tables, timing diagrams,
or cross-references the model may misread (book §2.3.2).

### Path B — Manual, four steps with explicit gates (book §2.4)

For specs that need architect-in-the-loop review, run the four prompts in
`prompts/` sequentially, with a Verification Strategist gate between each:

| Step | Prompt | Output | Gate |
|------|--------|--------|------|
| 1a | `prompts/step1a_feature_extraction.txt` | Feature list + ambiguity register | Architect sign-off on blockers |
| 1b | `prompts/step1b_review.txt` | PASS/FAIL per feature | "Ready for" verdict |
| 2  | (cross-feature interaction prompt — book §2.4.3) | Test table with traceability | Strategist approval |
| 3  | (XTP generation + validation prompt — book §2.4.4) | Signed-off XTP | All 12 validation checks pass |

For each step, paste the prompt + design spec PDF into Claude (or any LLM)
and save the response. Compare to the reference outputs in `outputs/`.

### How to Verify

```bash
# XTP exists and parses
head -50 ch02_testplan/outputs/AHB2APB_Bridge_Spec_testplan.xtp

# Feature count across categories (AHB, APB, conversion, burst, error,
# reset, register) — expect ~47 across 8 categories
grep "FEATURE" ch02_testplan/outputs/AHB2APB_Bridge_Spec_testplan.xtp | wc -l
```

### Key Output

The XTP is the contract handed to Chapter 3. Every test scenario the
testbench generates traces back to a row in this file.

---

## Chapter 3 — UVM Testbench Generation

**Goal:** Generate the UVM testbench infrastructure and verify it compiles and runs with bringup + sanity tests.

> The full generator-driven flow (book §3.7.5) is documented in
> [Quick Start: Chapter 3 Worked Example](#quick-start-chapter-3-worked-example) above.
> The section below describes the **already-generated** reference testbench
> shipped in this repo and how to compile / simulate it directly without
> regenerating.

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

**Goal:** Generate directed test scenarios derived from the XTP, covering datapath, connectivity, protocol, register access, error handling, reset, and cross-feature interactions.

### Where the tests live

The generated tests are not a separate directory — per the Chapter 4 flow they land directly in the testbench's own folders, alongside the Chapter 3 infrastructure (the `ch04_test_scenarios/` folder is a pointer README, not a copy):

```
ch03_testbench/ahb2apb_bridge_uvmtb/
├── sequences/    ← generated stimulus  (ahb_mst_test_<category>_NNN_seq.sv)
└── tests/        ← generated test classes (test_<category>_NNN_test.sv)
```

The current suite is **96 generated test classes** (plus the bring-up and sanity tests) — **98 total, all passing**. Each test self-checks real DUT behaviour (sticky STATUS bits, ERROR_ADDR/ERROR_INFO, HRESP, reset semantics); the APB slave can inject PSLVERR and timeouts, and tests can apply a mid-simulation hard reset.

### Test Categories

| Category | What They Cover |
|----------|-----------------|
| Datapath | Write/read forwarding, address, data, burst types, boundary, enable gating |
| Connectivity | HREADY_OUT, signal stability, PSEL/PENABLE timing |
| Protocol | Wait states, min 2-cycle APB, two-cycle AHB error, APB stability |
| Register Access | CTRL, STATUS, ERROR_ADDR, ERROR_INFO — R/W, W1C, reset values |
| Error | Address-decode error, timeout, PSLVERR, error recovery, interrupt aggregation |
| Reset | Soft reset, active-transfer abort, hard reset, register-default restore |
| Cross-Feature | Reset+transfer, timeout+register, soft-reset+error, wait+timeout |

### Steps to Follow

**Step 1: Compile** (the package includes the sequences/tests directly)
```bash
cd ch03_testbench/ahb2apb_bridge_uvmtb
compile.bat
```

**Step 2: Run a single test**
```bash
sim.bat test_main_datapath_001
```

**Step 3: Run another**
```bash
sim.bat test_error_006
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

> **Naming note:** `ch05_debug_regression/` is a recorded **49-test debug
> snapshot**, so its committed logs keep the older
> `ahb2apb_bridge_<category>_NNN_test` names. The **live** bench you run with
> `sim.bat` uses the current `test_<category>_NNN` class names (98 tests). Both
> are correct — they are different artifacts.

```bash
# Inspect a recorded log from the debug snapshot
cat ch05_debug_regression/logs/ahb2apb_bridge_error_006_test.log | grep -E "ERROR|FAIL|FATAL"

# Run that test live with full verbosity for debugging
cd ch03_testbench/ahb2apb_bridge_uvmtb
sim.bat test_error_006
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

## Chapter 6 — Subsystem Verification (architecture & teaching)

**Goal:** Extend VEGA from IP scope to subsystem scope — where the bugs that matter live in the contracts *between* components, not inside them — without introducing new tooling.

This is a **method / architecture chapter**. It teaches the protocol-agnostic integration-intent taxonomy, the ten integration bug patterns IP-level VIPs cannot see, the **Subsystem Intent Graph (SIG)** (each edge carries a *guarantee* from one component and an *assumption* from its neighbor; every misalignment is a defect site visible before integration), the **assumption harvest**, the category→SVA mapping, and the subsystem-only scenario classes (boundary handoff, failure/reset propagation, shared-resource contention). Unlike the other chapters it ships **no runnable companion code** — the deliverable is the architecture itself. See `ch06_subsystem/README.md` for the method and a future-work roadmap for building it on a concrete subsystem.

---

## Chapter 7 — Quality Metrics

**Goal:** Measure the quality of AI-assisted verification itself — whether a generated testbench is mechanically sound, whether it checks the obligations the specification required, and whether the way it was generated can be trusted.

Ten metrics in three families: **RES, VG, SCR, HR** grade generation (does it build and run); **PMC, CVL, DFS, OBS** grade specification (does it check, and can it observe, the right things); **AUI, RGS** grade the generation process (can it be trusted, and is it repeatable). See `ch07_quality_metrics/` (`README.md` + `metrics.py`); run `python ch07_quality_metrics/metrics.py`.

---

## Chapter 8 — Coverage Analysis & Sign-off

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
cat ch08_coverage_signoff/coverage_report.txt
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
sim.bat test_main_datapath_005

# Run full regression (from ch05)
cd ch05_debug_regression && bash run_all_tests.sh

# Check a test log
cat ch05_debug_regression/logs/<test_name>.log | grep -E "PASSED|FAILED|ERROR"
```

---

## Disclaimer

The views expressed in this repository and the accompanying book are those
of the author and do not represent the position of any employer, standards
body, or organization. No endorsement, sponsorship, or affiliation with any
employer or organization is implied. This work was developed by the author
in a personal capacity and not as part of, or using, any employer
resources, confidential information, or proprietary materials. Any
references to industry standards, protocols, or technologies (including but
not limited to AMBA, AHB, and APB) are based solely on publicly available
information and are used for educational and illustrative purposes.

---

## Third-Party Intellectual Property Notice

This repository may reference third-party technologies, standards,
trademarks, or intellectual property, including but not limited to Arm®
AMBA® protocols (e.g., AHB, APB). All such rights remain the property of
their respective owners. No license, express or implied, is granted by this
repository to any third-party intellectual property, including any rights
of Arm Limited or its affiliates. Use of any third-party technology or
specification referenced herein may require a separate license from the
applicable rights holder.

- **Arm®** and **AMBA®** are registered trademarks of Arm Limited (or its
  subsidiaries) in the US and/or elsewhere.
- **AHB** and **APB** are trademarks of Arm Limited.
- All other trademarks are the property of their respective owners.

---

## Originality of Design Artifacts

The RTL implementation (`rtl_Design/ahb2apb_bridge.sv`), design
specification (`ch01_vega_tools/ahb2apb_spec.pdf`), and IP-XACT description
(`ch01_vega_tools/ahb2apb_bridge.xml`) are author-original works by Vikash
Kumar. The design and its description are based solely on publicly
available specification information; no proprietary or confidential
material from any rights holder is included.

The spec PDF carries its own front-matter Disclaimer, Copyright, and
Third-Party Intellectual Property Notice — see the document's first pages
for the authoritative legal text.

The IP-XACT XML uses the standard SPIRIT/IEEE-1685 bus-type identifier
(`spirit:vendor="arm" spirit:library="amba"`) as required by the IP-XACT
schema for AMBA bus types. This is a schema-mandated identifier and does
not imply any endorsement by, sponsorship from, or affiliation with Arm
Limited.

---

## Third-Party Tool Output

This repository contains simulator log files in
`ch05_debug_regression/logs/` that were produced by Mentor Graphics Questa
Intel FPGA Starter Edition. Those logs include the standard Questa banner
and copyright notices (© Mentor Graphics Corporation), which are the
property of their respective owners and are reproduced here only as
captured tool output for reference.

---

## License

The code in this repository is licensed under the **MIT License** — see
[`LICENSE`](LICENSE) for the full text.

The MIT License applies to author-written source code only. It does not
grant any rights in third-party trademarks, specifications, or simulator
output referenced above. The same notices are mirrored standalone in
[`NOTICE`](NOTICE) at the repo root.

---

## Citation

If you reference this repository or the VEGA framework in academic or
professional work, please cite the book:

```
Kumar, V. (2026). AI-Assisted Hardware Verification: Cognitive Verification
Architecture with the VEGA Framework. Springer. ISBN 978-3-032-34545-5.
Book: https://link.springer.com/book/9783032345455
Companion repository: https://github.com/vksabnima/vega_framework
```

---

## Contact

Author: Vikash Kumar
For permissions requests, academic licensing inquiries, or questions about
the framework: **vikash.singh261@gmail.com**
