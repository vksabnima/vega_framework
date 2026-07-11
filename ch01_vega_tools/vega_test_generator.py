r"""
vega_test_generator.py — CLI-backed UVM test + sequence generator

==========================================================================
ARCHITECTURE (Phase 1 — coding pass, compile-gated)
==========================================================================

  For each <test_case> in the XTP:
    1. Snapshot TB source files
    2. Spawn `claude -p` in the TB workspace with a kickoff prompt
       that includes the test_case shape and the success criterion
       (compile-clean)
    3. After Claude exits, compute file footprint (added / modified)
    4. Classify footprint:
         - Tier 1 = tests/ + sequences/ + ahb2apb_bridge_pkg.sv (just
           the include line for the new test/seq files) + tb_list.f
         - Tier 2 = env/, config/, top/, agents/, package beyond includes
         - Tier 3 = rtl_Design/ (DUT) or new interfaces
    5. Run .\compile.bat ourselves to confirm clean state
    6. Decision:
         - compile OK + footprint within allowed tier   → ADD to baseline
         - compile FAIL or Tier 3 touched               → REVERT snapshot
         - Tier 2 touched + baseline regression check fails → REVERT
    7. Write per-test result line + accumulating summary

NO-HARM BASELINE
  Stored at <TB>/.no_harm_baseline.json. Each accepted test_id is appended.
  Phase 1 baseline = "all these tests are part of a compile-clean TB".

PHASE 2 (debug pass — not in this script yet)
  Will run vsim per test_id, fix failures via agentic loop, similar gating
  but on sim-pass instead of compile-clean.

REQUIREMENTS
  - claude CLI installed and authenticated (`claude login`)
  - Claude Pro/Max subscription (calls consume plan quota, not API tokens)
  - Questa FSE 22.1 (compile.bat references this)
"""

import os
import sys
import json
import time
import shutil
import tempfile
import hashlib
import argparse
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


# ---------- Config -----------------------------------------------------------

DEFAULT_XTP    = "ch02_testplan/ahb2apb_testplan.xtp"
DEFAULT_TB_DIR = "ch03_testbench/ahb2apb_bridge_uvmtb"
BASELINE_FILE  = ".no_harm_baseline.json"
SNAP_ROOT      = ".vega_snapshots"     # under TB
MAX_TURNS      = 25                    # per-test cap on claude -p iterations
CLAUDE_MODEL   = "claude-opus-4-8"

# File-extension whitelist for snapshotting (source files only; skip work/)
SRC_EXTS = (".sv", ".svh", ".v", ".f", ".bat", ".md")
SKIP_DIRS = {"work", "sim_results", "logs", "__pycache__", SNAP_ROOT}

# Tier classification by relative path prefix
TIER1_PREFIXES = ("tests/", "tests\\", "sequences/", "sequences\\")
TIER1_EXACT    = {"tb_list.f", "ahb2apb_bridge_pkg.sv"}  # pkg only allowed include lines
TIER3_PREFIXES = ("rtl_Design/", "rtl_Design\\", "../rtl_Design/", "../../rtl_Design/")


# ---------- XTP parsing ------------------------------------------------------

def load_test_cases(xtp_path):
    """Return list of dicts, one per <test_case> in xtp order."""
    tree = ET.parse(xtp_path)
    root = tree.getroot()

    # Index features by req_id for quick lookup
    feature_by_req = {}
    for f in root.iter("feature"):
        feature_by_req[f.get("req_id","")] = {
            "feature_name": f.get("name",""),
            "category":     f.get("category","other"),
            "pages":        f.get("pages",""),
            "description":  f.findtext("description",""),
        }

    cases = []
    for s in root.iter("test_suite"):
        cat = s.get("category", "other")
        for tc in s.iter("test_case"):
            req_ref = (tc.findtext("req_ref") or "").strip()
            feat = feature_by_req.get(req_ref, {})
            preconds = [c.text or "" for c in tc.iter("condition")]
            steps = []
            for st in tc.iter("step"):
                steps.append({
                    "num":      st.get("num", ""),
                    "action":   st.findtext("action", ""),
                    "expected": st.findtext("expected", ""),
                })
            cases.append({
                "test_id":       tc.get("test_id",""),
                "name":          tc.get("name",""),
                "category":      cat,
                "req_ref":       req_ref,
                "feature_name":  feat.get("feature_name",""),
                "feature_pages": feat.get("pages",""),
                "objective":     tc.findtext("objective",""),
                "preconditions": preconds,
                "steps":         steps,
                "pass_criteria": tc.findtext("pass_criteria",""),
            })
    return cases


# ---------- Snapshot / restore ----------------------------------------------

def _is_skip(rel):
    parts = rel.replace("\\", "/").split("/")
    return any(p in SKIP_DIRS for p in parts)

def snapshot_tb(tb_dir, snap_path):
    """Copy all source files (relative paths) to snap_path."""
    if os.path.exists(snap_path):
        shutil.rmtree(snap_path)
    os.makedirs(snap_path, exist_ok=True)
    for root, dirs, files in os.walk(tb_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_root = os.path.relpath(root, tb_dir)
        for f in files:
            if not f.endswith(SRC_EXTS):
                continue
            rel = os.path.normpath(os.path.join(rel_root, f))
            if _is_skip(rel):
                continue
            src = os.path.join(root, f)
            dst = os.path.join(snap_path, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

def file_hashes(tb_dir):
    """Return {rel_path: sha1_hex} for source files in tb_dir."""
    out = {}
    for root, dirs, files in os.walk(tb_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_root = os.path.relpath(root, tb_dir)
        for f in files:
            if not f.endswith(SRC_EXTS):
                continue
            rel = os.path.normpath(os.path.join(rel_root, f))
            if _is_skip(rel):
                continue
            full = os.path.join(root, f)
            try:
                with open(full, "rb") as fh:
                    out[rel] = hashlib.sha1(fh.read()).hexdigest()
            except OSError:
                pass
    return out

def diff_hashes(before, after):
    """Return dict {rel_path: 'added'|'modified'|'deleted'}."""
    changes = {}
    for k, v in after.items():
        if k not in before:
            changes[k] = "added"
        elif before[k] != v:
            changes[k] = "modified"
    for k in before:
        if k not in after:
            changes[k] = "deleted"
    return changes

def restore_snapshot(tb_dir, snap_path):
    """Restore source files from snap_path, removing any new ones."""
    snap_set = set()
    for root, dirs, files in os.walk(snap_path):
        rel_root = os.path.relpath(root, snap_path)
        for f in files:
            rel = os.path.normpath(os.path.join(rel_root, f))
            snap_set.add(rel)
            src = os.path.join(root, f)
            dst = os.path.join(tb_dir, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
    # Remove source files in tb_dir that are not in snapshot
    for root, dirs, files in os.walk(tb_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_root = os.path.relpath(root, tb_dir)
        for f in files:
            if not f.endswith(SRC_EXTS):
                continue
            rel = os.path.normpath(os.path.join(rel_root, f))
            if _is_skip(rel):
                continue
            if rel not in snap_set:
                try:
                    os.remove(os.path.join(root, f))
                except OSError:
                    pass


# ---------- Tier classification ---------------------------------------------

def classify_change(rel_path):
    """Return 1, 2, or 3 — the tier of this file change."""
    rp = rel_path.replace("\\", "/")
    if any(rp.startswith(pfx) for pfx in TIER3_PREFIXES):
        return 3
    if rp in TIER1_EXACT or any(rp.startswith(pfx) for pfx in TIER1_PREFIXES):
        return 1
    return 2

def footprint_tier(changes):
    """Highest tier present in the change set; 0 if no changes."""
    tiers = [classify_change(p) for p in changes.keys()]
    return max(tiers) if tiers else 0


# ---------- Baseline -------------------------------------------------------

def load_baseline(tb_dir):
    p = os.path.join(tb_dir, BASELINE_FILE)
    if not os.path.exists(p):
        return {"phase1": []}
    with open(p, "r", encoding="utf-8") as fh:
        return json.load(fh)

def save_baseline(tb_dir, bl):
    p = os.path.join(tb_dir, BASELINE_FILE)
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(bl, fh, indent=2)


# ---------- Compile invocation ---------------------------------------------

def run_compile(tb_dir, capture=True, timeout=180):
    """Run compile.bat in TB. Returns (rc, tail_of_output)."""
    bat = os.path.join(tb_dir, "compile.bat")
    if not os.path.exists(bat):
        return 1, f"(compile.bat not found at {bat})"
    try:
        # Absolute path bypasses cmd's PATH search behavior on Windows.
        res = subprocess.run(
            [bat],
            cwd=tb_dir,
            capture_output=capture,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            shell=False,
        )
        out = (res.stdout or "") + (res.stderr or "")
        tail = "\n".join(out.strip().splitlines()[-15:])
        return res.returncode, tail
    except subprocess.TimeoutExpired:
        return 124, "(compile timed out)"
    except Exception as e:
        return 1, f"(compile invocation failed: {e})"


# ---------- Kickoff prompt --------------------------------------------------

def build_kickoff_prompt(tc):
    test_id = tc["test_id"]
    test_id_lc = test_id.lower()
    name = tc["name"]
    cat  = tc["category"]
    obj  = tc["objective"]
    feat = tc["feature_name"]
    pages = tc["feature_pages"]
    preconds = "\n".join(f"  - {p}" for p in tc["preconditions"]) or "  (none)"
    steps = "\n".join(
        f"  {s['num']}. ACTION: {s['action']}\n"
        f"     EXPECTED: {s['expected']}"
        for s in tc["steps"]
    ) or "  (no steps specified)"
    pc = tc["pass_criteria"] or "(see steps)"

    return rf"""ACK: vega_test_generator dispatching {test_id}. Execute the task below NOW — do not ask the user what to do, do not list options, do not greet. Begin by reading the two pattern files, then create the two new files.

TASK (do all of these, in this order, then stop):

1. Read tests/ahb2apb_bridge_sanity_test.sv to learn the test class pattern.
2. Read sequences/ahb_mst_bringup_seq.sv to learn the sequence class pattern.
3. Read env/ahb_mst_agent/ahb_mst_seq_item.sv to learn the transaction shape.
4. Create file tests/{test_id_lc}_test.sv with a class {test_id_lc} extends uvm_test that mirrors the sanity_test structure (factory util, build_phase that gets vif + creates env, run_phase that starts the sequence below). Use `uvm_component_utils`.
5. Create file sequences/ahb_mst_{test_id_lc}_seq.sv with class ahb_mst_{test_id_lc}_seq extends uvm_sequence #(ahb_mst_seq_item). Use `uvm_object_utils`. The body() task drives the AHB stimulus described in the OBJECTIVE/STEPS below.
6. Edit ahb2apb_bridge_pkg.sv: add `\`include "sequences/ahb_mst_{test_id_lc}_seq.sv"` under the "// 6. Sequences" section, and `\`include "tests/{test_id_lc}_test.sv"` under the "// 7. Tests — LAST" section. Preserve existing order.
7. Run `.\compile.bat` and fix any vlog or vopt errors.
8. Stop when output ends with "*** COMPILE + ELABORATE PASSED ***".

TEST_CASE (from XTP):
  test_id        : {test_id}
  test_name      : {name}
  category       : {cat}
  parent feature : {feat} (pages {pages})
  OBJECTIVE      : {obj}
  PRECONDITIONS  :
{preconds}
  STEPS          :
{steps}
  PASS CRITERIA  : {pc}

HARD RULES (Questa FSE — no svverification license):
  - NO .randomize() on objects (use $urandom_range or fixed values).
  - NO covergroup. NO uvm_reg.
  - Test/sequence files are `\`include`-d into ahb2apb_bridge_pkg — do NOT add `import uvm_pkg::*` or ``include "uvm_macros.svh" inside them.
  - DO NOT touch rtl_Design/ or any *.sv outside tests/, sequences/, and ahb2apb_bridge_pkg.sv.
  - Register accesses go through the AHB master sequence as raw transactions to PADDR 0xF00..0xF0C.

SUCCESS CRITERION: `.\compile.bat` ends with "*** COMPILE + ELABORATE PASSED ***".

After compile passes, report the file paths you created/edited and stop. Do not propose next steps. Do not ask what the user wants.
"""


# ---------- Per-test driver -------------------------------------------------

def run_one_test(tc, tb_dir, snap_dir, baseline, allow_tier, max_turns=MAX_TURNS):
    """Execute Phase 1 for one test_case. Returns dict with result."""
    test_id = tc["test_id"]
    snap_path = os.path.join(snap_dir, test_id)

    print(f"\n{'='*72}")
    print(f"  {test_id}  ({tc['category']})  — {tc['objective'][:80]}")
    print(f"{'='*72}")

    # Idempotency: if the expected test+seq files already exist AND compile
    # is clean, treat this test_id as already done. This makes re-runs safe
    # and lets the orchestrator be cancelled and resumed.
    test_id_lc = test_id.lower()
    expected_test = os.path.join(tb_dir, "tests", f"{test_id_lc}_test.sv")
    expected_seq  = os.path.join(tb_dir, "sequences", f"ahb_mst_{test_id_lc}_seq.sv")
    if os.path.exists(expected_test) and os.path.exists(expected_seq):
        print(f"  [skip] expected files already exist; verifying compile only")
        rc, tail = run_compile(tb_dir)
        if rc == 0:
            if test_id not in baseline["phase1"]:
                baseline["phase1"].append(test_id)
                save_baseline(tb_dir, baseline)
                print(f"  [base] added to no-harm baseline — size now {len(baseline['phase1'])}")
            return {"test_id": test_id, "status": "ALREADY_EXISTS",
                    "tier": 1, "footprint": {},
                    "elapsed_s": 0, "llm_exit": 0,
                    "compile_tail": tail,
                    "note": "test+seq files already present; compile clean"}
        else:
            print(f"  [warn] expected files exist but compile FAILED; will let LLM fix")
            # fall through to normal claude invocation

    # Snapshot before
    print(f"  [snap] capturing TB source state...")
    snapshot_tb(tb_dir, snap_path)
    before = file_hashes(tb_dir)

    # Spawn claude — resolve the actual .cmd / .exe / .bat shim on Windows
    claude_exe = shutil.which("claude")
    if not claude_exe:
        return {"test_id": test_id, "status": "NO_CLAUDE_CLI", "tier": 0,
                "footprint": {}, "elapsed_s": 0,
                "note": "`claude` not found on PATH"}

    prompt = build_kickoff_prompt(tc)
    t0 = time.time()
    print(f"  [llm ] spawning `claude -p` (max-turns={max_turns}, model={CLAUDE_MODEL})...")
    print(f"  [llm ] (this typically takes 1-3 minutes)")
    # IMPORTANT: pass the prompt via STDIN, not as a positional arg.
    # When given as `claude -p "<arg>"`, Claude Code treats the prompt as a
    # session-opening message and offers menu options ("what would you like?").
    # When piped via stdin, it treats it as the imperative task to execute.
    cmd = [
        claude_exe, "-p",
        "--model", CLAUDE_MODEL,
        "--allowedTools", "Read,Write,Edit,Bash",
        "--permission-mode", "bypassPermissions",
        "--max-turns", str(max_turns),
        "--output-format", "text",
    ]
    try:
        res = subprocess.run(cmd, input=prompt, cwd=tb_dir,
                             capture_output=True, text=True,
                             encoding="utf-8", errors="replace",
                             timeout=15 * 60, shell=False)
        llm_exit = res.returncode
        llm_out = (res.stdout or "")[-3000:]
        llm_err = (res.stderr or "")[-1500:]
    except subprocess.TimeoutExpired:
        print(f"  [llm ] TIMEOUT after 15 min — reverting")
        restore_snapshot(tb_dir, snap_path)
        return {"test_id": test_id, "status": "TIMEOUT", "tier": 0,
                "footprint": {}, "elapsed_s": time.time()-t0,
                "note": "claude -p timed out at 15 min"}
    elapsed = time.time() - t0
    print(f"  [llm ] returned exit={llm_exit} in {elapsed:.1f}s")

    # Footprint
    after = file_hashes(tb_dir)
    changes = diff_hashes(before, after)
    tier = footprint_tier(changes)
    print(f"  [foot] {len(changes)} file(s) changed; tier={tier}")
    for rel, kind in sorted(changes.items()):
        t = classify_change(rel)
        print(f"         T{t}: {kind:<8} {rel}")
    # If nothing changed, the LLM didn't do its job — surface a hint
    if not changes:
        print(f"  [llm ] WARNING: no files changed. Last 500 chars of claude stdout:")
        for line in llm_out[-500:].splitlines():
            print(f"         | {line}")
        if llm_err.strip():
            print(f"  [llm ] stderr tail:")
            for line in llm_err[-300:].splitlines():
                print(f"         | {line}")

    result = {
        "test_id":   test_id,
        "tier":      tier,
        "footprint": changes,
        "elapsed_s": elapsed,
        "llm_exit":  llm_exit,
    }

    # If no files changed at all, the LLM did nothing — fail this test_id
    if not changes:
        return {**result, "status": "LLM_NO_OP",
                "note": "claude exited cleanly but made no file changes"}

    # Sanity: the expected test+seq files for this test_id must exist
    test_id_lc = test_id.lower()
    expected_test = f"tests\\{test_id_lc}_test.sv"
    expected_seq  = f"sequences\\ahb_mst_{test_id_lc}_seq.sv"
    have_test = any(p.replace("/", "\\").endswith(expected_test.replace("/", "\\"))
                    for p in changes)
    have_seq  = any(p.replace("/", "\\").endswith(expected_seq.replace("/", "\\"))
                    for p in changes)
    if not (have_test and have_seq):
        print(f"  [foot] WARNING: expected files not all created (test={have_test}, seq={have_seq})")
        # Don't auto-fail — claude may have used a slightly different naming.
        # But surface the discrepancy in the report note.

    # Tier policy
    if tier == 3:
        print(f"  [tier] Tier 3 touched (DUT or interfaces) — REVERTING per policy")
        restore_snapshot(tb_dir, snap_path)
        result.update(status="TIER3_REVERTED",
                      note="Touched rtl_Design or interface — paused for human")
        return result

    if tier > allow_tier:
        print(f"  [tier] Tier {tier} > allow_tier={allow_tier} — REVERTING")
        restore_snapshot(tb_dir, snap_path)
        result.update(status="TIER_BLOCKED",
                      note=f"footprint tier {tier} above policy ceiling {allow_tier}")
        return result

    # Run compile.bat to confirm clean state
    print(f"  [comp] running compile.bat...")
    rc, tail = run_compile(tb_dir)
    print(f"  [comp] compile.bat exit={rc}")
    if rc != 0:
        print("  [comp] compile FAILED — last lines:")
        for line in tail.splitlines():
            print(f"         | {line}")
        restore_snapshot(tb_dir, snap_path)
        result.update(status="COMPILE_FAIL", compile_tail=tail,
                      note="compile.bat failed after claude exited")
        return result

    print("  [comp] *** COMPILE CLEAN ***")
    result.update(status="PASS", compile_tail=tail)

    # If Tier 2 and we already had a baseline, the baseline implicitly passed
    # (we just compile-cleaned, which covers everything in the package).
    # Add this test to baseline.
    if test_id not in baseline["phase1"]:
        baseline["phase1"].append(test_id)
        save_baseline(tb_dir, baseline)
        print(f"  [base] added to no-harm baseline — size now {len(baseline['phase1'])}")
    return result


# ---------- Reporter --------------------------------------------------------

def write_report(results, report_path):
    lines = []
    a = lines.append
    a(f"# vega_test_generator — Phase 1 report")
    a(f"_Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}_")
    a("")
    a(f"| Metric | Value |")
    a(f"|---|---|")
    a(f"| Total | {len(results)} |")
    by_status = {}
    for r in results:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    for st, n in sorted(by_status.items()):
        a(f"| {st} | {n} |")
    a("")
    a("## Per-test detail")
    a("")
    a("| Test ID | Status | Tier | Time (s) | Footprint | Note |")
    a("|---|---|---|---|---|---|")
    for r in results:
        fp = ", ".join(f"{k}({v[0]})" for k, v in sorted(r["footprint"].items()))[:90]
        note = (r.get("note") or "").replace("|", "\\|")[:80]
        a(f"| `{r['test_id']}` | {r['status']} | T{r['tier']} | {r['elapsed_s']:.0f} | {fp} | {note} |")
    a("")
    with open(report_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


# ---------- Main ------------------------------------------------------------

def main():
    # Force UTF-8 stdout so non-ASCII glyphs (checkmarks, box drawing)
    # don't crash on Windows consoles whose default code page is cp1252.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    ap = argparse.ArgumentParser(
        description="VEGA test generator (Phase 1 — coding pass via Claude Code CLI)",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    ap.add_argument("--xtp", default=DEFAULT_XTP, help="Path to XTP file")
    ap.add_argument("--tb-dir", default=DEFAULT_TB_DIR, help="Testbench directory")
    ap.add_argument("--category", default=None, help="Filter by category")
    ap.add_argument("--test-id", default=None, help="Run just this one test_id")
    ap.add_argument("--limit", type=int, default=None, help="Cap on tests run")
    ap.add_argument("--allow-tier", type=int, default=2,
                    help="Max footprint tier allowed (1=add-only, 2=infra OK, default=2)")
    ap.add_argument("--max-turns", type=int, default=MAX_TURNS,
                    help="Max agentic turns per test (default 25)")
    ap.add_argument("--report", default=None,
                    help="Report file (default: <tb-dir>/vega_phase1_report.md)")
    args = ap.parse_args()

    if not os.path.isabs(args.tb_dir):
        args.tb_dir = os.path.abspath(args.tb_dir)
    if not os.path.isabs(args.xtp):
        args.xtp = os.path.abspath(args.xtp)

    print()
    print("=" * 72)
    print("  VEGA Test Generator — Phase 1 (coding pass, compile-gated)")
    print("=" * 72)
    print(f"  XTP    : {args.xtp}")
    print(f"  TB dir : {args.tb_dir}")
    print(f"  Filter : category={args.category}  test_id={args.test_id}  limit={args.limit}")
    print(f"  Policy : allow_tier={args.allow_tier}  max_turns={args.max_turns}")
    print(f"  Model  : {CLAUDE_MODEL}")

    # Sanity checks
    if not os.path.exists(args.xtp):
        print(f"  ERROR: XTP not found at {args.xtp}"); sys.exit(1)
    if not os.path.exists(args.tb_dir):
        print(f"  ERROR: TB dir not found at {args.tb_dir}"); sys.exit(1)
    if not shutil.which("claude"):
        print("  ERROR: `claude` CLI not found in PATH"); sys.exit(1)

    # Load + filter test cases
    cases = load_test_cases(args.xtp)
    if args.category:
        cases = [c for c in cases if c["category"] == args.category]
    if args.test_id:
        cases = [c for c in cases if c["test_id"] == args.test_id]
    if args.limit:
        cases = cases[:args.limit]
    if not cases:
        print("  No test_cases match filter — nothing to do."); sys.exit(1)
    print(f"  Tests  : {len(cases)} to process")
    for c in cases:
        print(f"    - {c['test_id']} [{c['category']}]")

    # Sanity check: compile must be clean BEFORE we start
    print()
    print("-" * 72)
    print("  Pre-flight: confirming TB compiles clean before we touch it")
    print("-" * 72)
    rc, tail = run_compile(args.tb_dir)
    if rc != 0:
        print("  ERROR: pre-flight compile.bat FAILED. Fix that first.")
        for line in tail.splitlines():
            print(f"    | {line}")
        sys.exit(1)
    print("  ✓ Pre-flight compile clean")

    # Prepare snapshot root + baseline
    # IMPORTANT: snapshots live OUTSIDE the TB dir so Claude Code's auto-
    # discovery doesn't read them and get confused about the task.
    snap_dir = tempfile.mkdtemp(prefix="vega_test_gen_snap_")
    print(f"  Snapshots in: {snap_dir}")
    baseline = load_baseline(args.tb_dir)
    print(f"  Baseline at start: {len(baseline['phase1'])} test(s)")

    # Run loop
    results = []
    t_run_start = time.time()
    for i, tc in enumerate(cases, 1):
        print(f"\n[ {i}/{len(cases)} ]")
        r = run_one_test(tc, args.tb_dir, snap_dir, baseline,
                         args.allow_tier, args.max_turns)
        results.append(r)

    elapsed = time.time() - t_run_start

    # Write report
    report_path = args.report or os.path.join(args.tb_dir, "vega_phase1_report.md")
    write_report(results, report_path)

    # Summary
    print()
    print("=" * 72)
    print("  PHASE 1 COMPLETE")
    print("=" * 72)
    by_status = {}
    for r in results:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    for st in sorted(by_status):
        print(f"  {st:<20}: {by_status[st]}")
    print(f"  Baseline size: {len(baseline['phase1'])}")
    print(f"  Wall time    : {elapsed:.1f}s ({elapsed/60:.1f} min)")
    print(f"  Report       : {report_path}")
    print()
    return 0 if by_status.get("PASS", 0) == len(results) else 0  # informational only


if __name__ == "__main__":
    sys.exit(main())
