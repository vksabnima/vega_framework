# VEGA Demo — Commands + Claude Code Prompts (Cheat Sheet)

Quick copy-paste reference for the live session. Companion to `DEMO_RUNBOOK.md`
(which has the full narrative). All commands assume **cmd** (Command Prompt) and
a **freshly opened terminal**.

---

## 0. Pre-flight (run once, in a brand-new terminal)
```
cd C:\Users\ritup\Desktop\vikash_projects\vega_framework
echo %LM_LICENSE_FILE%
where gvim
```
Expect: `...LR-287299_License.dat` and `C:\Program Files\Vim\vim91\gvim.exe`.

---

## 1. Open the input files (Act 2 — "what the human writes")
```
gvim -p ch01_vega_tools\verification_intent.txt ch01_vega_tools\manifest.json ch01_vega_tools\ahb2apb_bridge.xml
```
```
start "" ch01_vega_tools\ahb2apb_spec.pdf
```

---

## 2. Dry-run (Act 3 — zero cost, builds the prompt)
```
python ch01_vega_tools\vega_llm_tbgen.py --ipxact ch01_vega_tools\ahb2apb_bridge.xml --manifest ch01_vega_tools\manifest.json --intent ch01_vega_tools\verification_intent.txt --spec ch01_vega_tools\ahb2apb_spec.pdf --rtl rtl_Design\ahb2apb_bridge.sv --dry-run
```

---

## 3. Live generation (Act 4 — the wow)
Delete any previous scratch copy first, then generate:
```
rmdir /s /q ch03_testbench\ahb2apb_bridge_uvmtb_live
```
```
python ch01_vega_tools\vega_llm_tbgen.py --ipxact ch01_vega_tools\ahb2apb_bridge.xml --manifest ch01_vega_tools\manifest.json --intent ch01_vega_tools\verification_intent.txt --spec ch01_vega_tools\ahb2apb_spec.pdf --rtl rtl_Design\ahb2apb_bridge.sv --output ch03_testbench\ahb2apb_bridge_uvmtb_live --no-git
```
Harmless warning to ignore: `Ports in IP-XACT not in RTL: {HWDATA, HADDR, ...}`

---

## 4. Compile + simulate (Act 5 — the payoff)
```
cd ch03_testbench\ahb2apb_bridge_uvmtb_live
```
```
.\compile.bat
```
```
.\sim.bat
```
```
.\sim.bat ahb2apb_bridge_sanity_test
```
**License fallback** (only if you see "Unable to checkout a license"):
```
set LM_LICENSE_FILE=C:\intelFPGA\22.1std\licenses\LR-287299_License.dat
```

---

## 5. Fix loop with Claude Code (Act 6 — the highlight)
From inside `ch03_testbench\ahb2apb_bridge_uvmtb_live`:
```
claude
```
Then paste the **KICKOFF PROMPT** below.

---

## 6. Guaranteed fallback (if anything breaks on stage)
A pre-verified golden copy that always passes:
```
cd C:\Users\ritup\Desktop\vikash_projects\vega_framework\ch03_testbench\ahb2apb_bridge_uvmtb_golden
```
```
.\sim.bat ahb2apb_bridge_sanity_test
```

---
---

# CLAUDE CODE — KICKOFF PROMPT
Paste this into `claude` after launching it inside the generated `_live` dir:

```
You're helping me run a LIVE classroom demo of an AI hardware-verification flow.
This directory is a freshly AI-generated UVM testbench for an AHB-to-APB bridge.
Read CLAUDE.md first — it has the verification goals (VG1–VG6), the Questa FSE
rules, and the compile/sim workflow.

Environment notes (these WILL trip you up otherwise):
- Windows. Run batch files with a leading .\ — i.e. `.\compile.bat` and
  `.\sim.bat`, never bare `compile.bat` (cmd won't find it in the cwd).
- Full sanity run: `.\sim.bat ahb2apb_bridge_sanity_test`
- If a sim aborts with "Unable to checkout a license", run this once then retry:
  set LM_LICENSE_FILE=C:\intelFPGA\22.1std\licenses\LR-287299_License.dat
- Questa FSE has no svverification license: never use .randomize() on objects or
  covergroup (CLAUDE.md has the workarounds).

Goal: get the sanity test to pass cleanly — all of VG1–VG6, UVM_ERROR: 0,
UVM_FATAL: 0.
  1. Run `.\compile.bat`; fix any compile/elaborate errors.
  2. Run `.\sim.bat ahb2apb_bridge_sanity_test`.
  3. If any goal fails or there are UVM_ERRORs, find the ROOT CAUSE in the
     testbench/RTL, make the MINIMAL fix, recompile, and re-run until green.

This is for students, so narrate as you go: before each fix, explain in plain
English what's failing and why, then what your fix does. Keep edits surgical —
fix the cause, don't suppress the symptom.

Start by reading CLAUDE.md and the directory layout, then run the compile and
tell me what you find. Do NOT make code changes until you've shown me the first
failure and your diagnosis.
```

---

# BACKUP HINT
Paste ONLY if Claude Code stalls on a VG3 read-data mismatch (AHB=0 vs APB=non-zero):

```
The AHB monitor samples HRDATA at posedge, but HRDATA/HREADY_OUT are combinational
outputs that settle mid-cycle. Try waiting for completion and sampling read data on
negedge HCLK instead.
```

**Root cause (so you can narrate it):** HRDATA carries real PRDATA only during the
ST_APB_ACCESS + PREADY cycle; one cycle later (ST_IDLE) it's 0 while HREADY_OUT is
still high. A posedge sample hits a delta-race and grabs the 0. Sampling on negedge
(settled values) fixes it — verified in rehearsal: one edit → all VG1–VG6 pass.
