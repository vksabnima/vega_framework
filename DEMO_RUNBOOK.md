# VEGA Live Demo — Stage Runbook

Rehearsed end-to-end on 2026-05-24. Everything below ran clean: generation →
compile → bringup → sanity, all PASS, zero manual fixes.

---

## ⚠️ FIRST THING TOMORROW (60-second pre-flight)

Open a **brand-new terminal** (not one left running from before — env changes
only reach freshly launched shells). Then verify the license is healthy:

```cmd
echo %LM_LICENSE_FILE%
```
Must print: `C:\intelFPGA\22.1std\licenses\LR-287299_License.dat`

- If it prints `LR-285140...` (the old/broken one) → close the terminal app
  completely and reopen, or run this once in the session you'll demo from:
  ```cmd
  set LM_LICENSE_FILE=C:\intelFPGA\22.1std\licenses\LR-287299_License.dat
  ```
  (A persistent fix was already applied via `setx`; this is only a fallback.)

Optional polish — nicer Unicode (checkmarks / box borders render cleanly):
```cmd
chcp 65001
```

---

## The demo arc (~20 min)

### Act 1 — Hook (talk, 2 min)
"Verification takes longer than design. Watch AI write a full UVM testbench in
~4 minutes, then watch it pass in a real simulator."

### Act 2 — What the human writes (3 min)
Open and walk through:
- `ch01_vega_tools\verification_intent.txt`  ← the star: plain English,
  DRIVE / OBSERVE / CHECK (VG1–VG6) / OUT OF SCOPE. No SystemVerilog, no UVM.
- `ch01_vega_tools\manifest.json`            ← design name, interfaces, paths
- `ch01_vega_tools\ahb2apb_spec.pdf`         ← the spec
- `ch01_vega_tools\ahb2apb_bridge.xml`       ← IP-XACT port list

### Act 3 — Dry-run (zero cost, 1 min) — safe stall segment if wifi is flaky
```cmd
cd C:\Users\ritup\Desktop\vikash_projects\vega_framework

python ch01_vega_tools\vega_llm_tbgen.py ^
   --ipxact   ch01_vega_tools\ahb2apb_bridge.xml ^
   --manifest ch01_vega_tools\manifest.json ^
   --intent   ch01_vega_tools\verification_intent.txt ^
   --spec     ch01_vega_tools\ahb2apb_spec.pdf ^
   --rtl      rtl_Design\ahb2apb_bridge.sv ^
   --dry-run
```
Shows pre-flight pass + the auto-assembled master prompt + token count.

### Act 4 — Live generation (THE moment, 4–5 min)
Generate into a fresh sibling dir so the committed reference stays pristine:
```cmd
python ch01_vega_tools\vega_llm_tbgen.py ^
   --ipxact   ch01_vega_tools\ahb2apb_bridge.xml ^
   --manifest ch01_vega_tools\manifest.json ^
   --intent   ch01_vega_tools\verification_intent.txt ^
   --spec     ch01_vega_tools\ahb2apb_spec.pdf ^
   --rtl      rtl_Design\ahb2apb_bridge.sv ^
   --output   ch03_testbench\ahb2apb_bridge_uvmtb_live ^
   --no-git
```
21 files stream out live. **Expected harmless warning** — don't flinch:
`⚠ Ports in IP-XACT not in RTL: {HWDATA, HADDR, ...}` → it then binds from RTL
and continues to `DONE`.

### Act 5 — It actually runs (the payoff, 4 min)
```cmd
cd ch03_testbench\ahb2apb_bridge_uvmtb_live
compile.bat
```
Expect: `*** COMPILE + ELABORATE PASSED ***`, `Errors: 0, Warnings: 0`
```cmd
sim.bat
```
Expect: `TEST PASSED`, `UVM_ERROR: 0`, `UVM_FATAL: 0`
```cmd
sim.bat ahb2apb_bridge_sanity_test
```
Expect: `ALL VERIFICATION GOALS PASSED`, `AHB=5 APB=5`, VG1–VG6 all PASS.

### Act 6 — The fix loop (the real highlight)

**Live LLM generation is non-deterministic** — tomorrow's fresh run may pass
first try, or may fail (e.g. a `VG3` read-data mismatch from a monitor
sampling-timing bug, which is what happened in rehearsal). EITHER outcome is a
good demo:
- **If sanity PASSES:** great — show the green result, then mention "and when
  it doesn't pass first try, here's how we close the loop" and do the fix
  segment anyway for teaching.
- **If sanity FAILS:** perfect — this IS the VEGA generate→fix workflow.

From inside the generated dir:
```cmd
claude
```
Then type (Claude Code auto-reads `CLAUDE.md` with the VG1–VG6 goals + rules):
```
run compile.bat, then run sim.bat ahb2apb_bridge_sanity_test, and fix any UVM_ERROR or failing verification goal
```
Watch it diagnose, edit, recompile, re-run to green. Budget ~3–8 min; it may
take 1–3 iterations — that's realistic engineering, not a flaw.

**Backup hint if it stalls** (paste this to steer it):
```
The AHB monitor samples HRDATA at posedge, but HRDATA/HREADY_OUT are combinational outputs that settle mid-cycle. Try sampling the completion data on negedge HCLK instead.
```

**Rehearsed root cause (so you can narrate it):** `HRDATA` only carries real
`PRDATA` during the `ST_APB_ACCESS`+`PREADY` cycle; one cycle later (`ST_IDLE`)
it's `0` while `HREADY_OUT` is still high. A posedge sample hits a delta-race
and grabs the `0`. Sampling on **negedge** (settled combinational values) fixes
it. Verified: one edit → all goals pass.

Closing alternative if you skip live fixing: show the finished artifact —
`type ..\..\ch07_coverage_signoff\coverage_report.txt` → 128/128 bins, 100%.

---

## Fallbacks (if live generation or API fails on stage)

The single trustworthy, fully-debugged copy is:
```
ch03_testbench\ahb2apb_bridge_uvmtb_golden\
```
It genuinely verifies (real data flows AHB→APB; VG2/VG3 are meaningful). If
Act 4 fails, `cd` into golden and run `.\compile.bat` / `.\sim.bat
ahb2apb_bridge_sanity_test` — guaranteed green.

⚠️ Do NOT fall back to `..._demo\` or the committed `..._uvmtb\` for the
"it verifies" beat — those (and any fresh generation) **pass vacuously**:
their write/read data is 0, so VG2/VG3 compare 0==0 and check nothing. Only
`golden` has the driver + monitor fixes that make the checks real.

If the API itself is down: pivot to Act 2 + Act 3 (dry-run) + run `golden`.
The story still lands.

---

## Notes / cleanup
- `_demo` and `_live` dirs are untracked scratch — delete after the demo:
  `rmdir /s /q ch03_testbench\ahb2apb_bridge_uvmtb_live`
- Generator model is `claude-opus-4-8` (hardcoded, line 42 of the generator) —
  confirmed working tonight.
- Full 49-test regression (`ch05_debug_regression\run_all_tests.sh`) is too slow
  for stage — show the pre-baked coverage report instead.
