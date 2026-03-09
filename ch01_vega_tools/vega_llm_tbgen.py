#!/usr/bin/env python3
"""
vega_llm_tbgen.py — VEGA LLM UVM Testbench Generator
Vikash Kumar — Cognitive Verification Architecture: The VEGA Framework

Usage:
  python vega_llm_tbgen.py \\
    --ipxact   manifest/ahb2apb_bridge.xml \\
    --manifest manifest/manifest.json \\
    --intent   manifest/verification_intent.txt \\
    --spec     manifest/ahb2apb_spec.pdf         [optional] \\
    --rtl      ../../rtl/ahb2apb_bridge.sv        [optional] \\
    --output   ahb2apb_bridge_uvmtb

Workflow:
  STEP 1  This script generates TB scaffolding + git init
  STEP 2  cd <output> && claude   (Claude Code reads CLAUDE.md)
  STEP 3  Fix iteratively via natural language
  STEP 4  git log/diff is the experiment record

Requires: pip install anthropic
"""

import os
import re
import sys
import json
import argparse
import subprocess
import textwrap
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime

try:
    import anthropic
except ImportError:
    print("ERROR: pip install anthropic")
    sys.exit(1)

VERSION    = "2.0"
MODEL      = "claude-opus-4-6"
MAX_TOKENS = 32000

client = anthropic.Anthropic()

# ─────────────────────────────────────────────────────────────────────────────
# TERMINAL OUTPUT
# ─────────────────────────────────────────────────────────────────────────────

GRN  = "\033[92m"; YEL = "\033[93m"; RED = "\033[91m"
CYAN = "\033[96m"; BOLD = "\033[1m";  RST = "\033[0m"

def banner(msg): print(f"\n{BOLD}{CYAN}{'='*60}{RST}\n{BOLD}{CYAN}  {msg}{RST}\n{BOLD}{CYAN}{'='*60}{RST}")
def ok(msg):     print(f"  {GRN}✓{RST}  {msg}")
def warn(msg):   print(f"  {YEL}⚠{RST}  {msg}")
def err(msg):    print(f"  {RED}✗{RST}  {msg}")
def info(msg):   print(f"  {CYAN}→{RST}  {msg}")

# ─────────────────────────────────────────────────────────────────────────────
# PROMPT — file lists derived from manifest
# ─────────────────────────────────────────────────────────────────────────────

def _llm_files(ctx):
    """Files the LLM must generate — derived purely from interface list."""
    design = ctx["design"]
    ifaces = ctx["interfaces"]
    files  = []

    for i in ifaces:
        files.append(f"{i['name']}_if.sv")

    files.append(f"config/{design}_dut_config.sv")

    for i in ifaces:
        n = i["name"]
        files += [
            f"env/{n}_agent/{n}_seq_item.sv",
            f"env/{n}_agent/{n}_driver.sv",
            f"env/{n}_agent/{n}_monitor.sv",
            f"env/{n}_agent/{n}_sequencer.sv",
            f"env/{n}_agent/{n}_agent.sv",
        ]

    files += [
        f"env/{design}_scoreboard.sv",
        f"env/{design}_env.sv",
    ]

    for i in ifaces:
        files.append(f"sequences/{i['name']}_bringup_seq.sv")

    files += [
        f"tests/{design}_bringup_test.sv",
        f"tests/{design}_sanity_test.sv",
        f"top/tb_top.sv",
        f"top/{design}_dut_bind.sv",
    ]

    return files


def _script_files(ctx):
    """Files the script generates — LLM must NOT generate these."""
    design = ctx["design"]
    return [
        f"{design}_pkg.sv",
        "tb_list.f",
        "compile.bat",
        "sim.bat",
        "CLAUDE.md",
    ]


def _goal_list(ctx):
    goals = ctx["meta"].get("verification_goals", [])
    if not goals:
        return "  (none — derive goals from intent file and spec)"
    lines = []
    for g in goals:
        lines.append(
            f"  [{g['id']}] ({g.get('priority','must').upper()}) "
            f"{g['goal']}"
        )
    return "\n".join(lines)


def _port_list(ctx):
    lines = []
    for p in ctx["ports"]:
        w = f"[{p['width']-1}:0] " if p["width"] > 1 else "        "
        lines.append(f"  {p['direction']:6s}  {w}{p['name']}")
    return "\n".join(lines)


def _iface_summary(ctx):
    lines = []
    for i in ctx["interfaces"]:
        lines.append(
            f"  {i['name']:20s} protocol={i['protocol']:8s} "
            f"role={i['role']}"
        )
    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# PROMPT — system prompt (LLM persona)
# ─────────────────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are a Senior UVM Verification Engineer with deep expertise in
SystemVerilog, UVM methodology, and AMBA protocols.

You generate UVM testbench scaffolding with:
  - Correct UVM component architecture
  - Heavy inline documentation explaining every decision
  - Explicit edit hints wherever your knowledge is uncertain:
      EDIT_REQUIRED    — must fix before simulation works
      EDIT_RECOMMENDED — verify matches your specific DUT
      EDIT_OPTIONAL    — change only if design is unusual
      PROTOCOL_GAP     — implement manually using protocol spec
  - Protocol-correct driver timing and monitor capture points
  - Scoreboard logic derived from verification intent

You never invent signal names — only what IP-XACT provides.
You never use .randomize() — Questa FSE has no svverification license.
You never leave silent gaps — every uncertainty gets an explicit comment.

Output files using FILE: / END_FILE markers exactly as instructed.
"""


# ─────────────────────────────────────────────────────────────────────────────
# PROMPT — master prompt builder
# ─────────────────────────────────────────────────────────────────────────────

def build_master_prompt(ctx):
    """
    Single master prompt sent to LLM.
    LLM is the verification engineer given a job brief.
    Four inputs carry the knowledge — prompt carries the frame and rules.
    """
    design = ctx["design"]
    clk    = ctx["clocks"][0]["name"]              if ctx["clocks"] else "CLK"
    rst    = ctx["resets"][0]["name"]              if ctx["resets"] else "RESETn"
    per_ns = ctx["clocks"][0].get("period_ns", 10) if ctx["clocks"] else 10
    a_low  = ctx["resets"][0].get("active_low", True) if ctx["resets"] else True
    a_ns   = ctx["resets"][0].get("assert_ns", 100)   if ctx["resets"] else 100
    sim    = ctx["meta"].get("tool", {}).get("simulator", "questa_fse")
    uvm    = ctx["meta"].get("tool", {}).get("uvm_version", "uvm-1.1d")

    llm_files    = _llm_files(ctx)
    script_files = _script_files(ctx)

    EQ  = "=" * 70
    SEP = "-" * 70

    return f"""\
You are a Senior UVM Verification Engineer.

You have been given a verification job. Read ALL four inputs before
generating anything. Your inputs contain everything you need.

{EQ}
SECTION 1 — YOUR INPUTS
{EQ}

{SEP}
INPUT 1 — IP-XACT (hardware structure — authoritative signal source)
{SEP}
Use ONLY signal names, directions, and widths from this document.
Never invent signal names. Never guess widths.

{ctx['ipxact_text']}

{SEP}
INPUT 2 — MANIFEST (hardware and tool configuration)
{SEP}
Treat every field as a hard requirement — not a suggestion.
Clock, reset, interfaces, tool paths, verification goals, stimulus.

{json.dumps(ctx['meta'], indent=2)}

{SEP}
INPUT 3 — VERIFICATION INTENT (your strategy — implement this)
{SEP}
What to drive, what to observe, what constitutes correct behavior.
Implement this intent in the driver, monitor, scoreboard, and sequences.

{ctx.get('intent_text') or
 '(no intent file — infer strategy from manifest verification_goals)'}

{SEP}
INPUT 4 — DESIGN SPECIFICATION (protocol and functional knowledge)
{SEP}
How the DUT behaves. Use for driver protocol timing, monitor capture
points, and scoreboard comparison logic.

{ctx.get('spec_text') or
 '(no spec provided — use training knowledge of ' +
 ', '.join(set(i['protocol'] for i in ctx['interfaces'])) +
 ' protocol(s) and the verification intent above)'}

{EQ}
SECTION 2 — WHAT YOU KNOW
{EQ}

Design   : {design}
Clock    : {clk}  period={per_ns}ns  half-period={per_ns//2}ns
Reset    : {rst}  active_low={a_low}  assert_after={a_ns}ns
Simulator: {sim}  UVM: {uvm}

Interfaces:
{_iface_summary(ctx)}

Ports from IP-XACT (use ONLY these names — never invent):
{_port_list(ctx)}

Verification goals (implement ALL in scoreboard):
{_goal_list(ctx)}

{EQ}
SECTION 3 — YOUR JOB
{EQ}

Generate a UVM testbench SCAFFOLDING for the {design} design.

This is a BRINGUP testbench — not a complete verification environment.
Goal: compile clean, simulate, prove DUT is reachable, check basic goals.

Generate TWO tests with different purposes:

  1. {design}_bringup_test
     — Drive ONE transaction only
     — No scoreboard checks
     — Pass if simulation completes without UVM_FATAL or UVM_ERROR
     — Purpose: if this fails, the TB infrastructure is broken (not DUT)

  2. {design}_sanity_test
     — Drive num_txns transactions (from manifest stimulus.num_txns)
     — Full scoreboard — check every verification goal
     — Pass if all goals pass and TEST PASSED is printed
     — Purpose: if bringup passes but sanity fails, DUT behavior is wrong

COMMENT STRATEGY — as important as the code:

  Every file must have:

  A) HEADER BLOCK:
     - What this component does in the UVM TB
     - What you derived from which input (IP-XACT / manifest / intent / spec)
     - Confidence level in the protocol implementation

  B) INLINE COMMENTS:
     - Why each protocol decision was made
     - Which signal is driven/sampled and why at that moment
     - What each scoreboard check is verifying

  C) EDIT HINTS — use these four tags:

     // EDIT_REQUIRED: <what is missing and why LLM cannot determine it>
     //   Must be filled in before simulation will work correctly.

     // EDIT_RECOMMENDED: <what LLM assumed and what to verify>
     //   LLM made a reasonable assumption. Verify against your DUT.

     // EDIT_OPTIONAL: <what LLM implemented and when to change it>
     //   Common case implemented. Change only for unusual designs.

     // PROTOCOL_GAP: <what is needed and where to find it>
     //   LLM training data insufficient for this specific behavior.
     //   Refer to protocol specification for correct implementation.

  Silent gaps are the worst outcome.
  An EDIT_REQUIRED comment is better than wrong silent code.

{EQ}
SECTION 4 — TOOL CONSTRAINTS (Questa FSE — hard rules)
{EQ}

[TC1] NEVER use .randomize()
      No svverification license in Questa FSE.
      WRONG: req.randomize() with {{ HADDR inside {{[0:32'hEFFF]}}; }}
      RIGHT: req.HADDR = $urandom_range(0, 32'hEFFF);
             req.post_randomize();

[TC2] timescale directive in tb_top.sv ONLY
      Never in package, interface, or component files.

[TC3] +define+UVM_NO_DPI always — never use DPI imports.

[TC4] UVM 1.1d syntax — `uvm_info not uvm_report_info

{EQ}
SECTION 5 — UVM RULES (violations cause compile or UVM_FATAL)
{EQ}

[U1] config_db virtual interface — NO modport suffix ever
     WRONG: uvm_config_db#(virtual ahb_mst_if.driver)::get(...)
     RIGHT: uvm_config_db#(virtual ahb_mst_if)::get(...)

[U2] config_db set() scope — null not this
     WRONG: uvm_config_db#(...)::set(this, ...)
     RIGHT: uvm_config_db#(...)::set(null, "*", "cfg", cfg)

[U3] Passive/reactive sequences — forever loop not repeat()
     WRONG: repeat(cfg.num_txns) begin ... end
     RIGHT: forever begin ... end

[U4] Monitors — call post_randomize() after capturing all signals
     txn.post_randomize();
     ap.write(txn);

[U5] uvm_analysis_imp_decl macros at FILE SCOPE before class definition

[U6] Objection raised/dropped only in base_test run_phase

[U7] Package include order (script enforces this in pkg.sv):
     1. import uvm_pkg + include uvm_macros
     2. typedef enum declarations
     3. config class
     4. seq_items
     5. scoreboard
     6. per interface: driver → monitor → sequencer → agent
     7. env
     8. sequences
     9. tests  ← LAST, nothing after

[U8] Drivers never generate clock or reset (tb_top.sv only)

{EQ}
SECTION 6 — FILES YOU MUST GENERATE
{EQ}

Generate exactly these {len(llm_files)} files:

{chr(10).join(f'  FILE: {f}' for f in llm_files)}

DO NOT generate these — the script generates them correctly:
{chr(10).join(f'  SKIP: {f}' for f in script_files)}

The script generates pkg.sv and tb_list.f to guarantee correct include
and compile order. If you generate them they will be overwritten.

{EQ}
SECTION 7 — OUTPUT FORMAT
{EQ}

For each file output EXACTLY:

FILE: <relative/path/filename.sv>
<complete file content>
END_FILE

Rules:
  - Every file in Section 6 must appear
  - Complete content — no "// TODO implement this"
    Use EDIT_REQUIRED instead — explicit gap beats silent gap
  - Output in dependency order:
    interfaces → config → seq_items → drivers → monitors →
    sequencers → agents → scoreboard → env → sequences →
    tests → tb_top → dut_bind
  - dut_bind.sv: generate from IP-XACT port list with EDIT_REQUIRED
    on every connection — RTL port names often differ from IP-XACT

{EQ}
SECTION 8 — CHECKLIST BEFORE YOU GENERATE
{EQ}

Verify before outputting any file:

  Inputs read:
  [ ] IP-XACT — I know all signal names, directions, widths
  [ ] Manifest — clock, reset, interfaces, tool constraints, goals
  [ ] Intent   — what to drive, observe, check, and what is out of scope
  [ ] Spec     — protocol timing for drivers and monitor capture points

  Tool constraints:
  [ ] No .randomize() in any file
  [ ] timescale only in tb_top.sv
  [ ] No modport suffix in config_db vif type
  [ ] config_db set() uses null scope

  Output completeness:
  [ ] All {len(llm_files)} files will be generated
  [ ] Every file has header, inline comments, and edit hints
  [ ] bringup_test: one transaction, no scoreboard
  [ ] sanity_test: num_txns transactions, all goals checked
  [ ] dut_bind: EDIT_REQUIRED on every port connection

Generate the files now.
"""


# ─────────────────────────────────────────────────────────────────────────────
# INPUT PARSING
# ─────────────────────────────────────────────────────────────────────────────

def parse_ipxact(path):
    """Extract design name and port list from IP-XACT XML."""
    with open(path, encoding="utf-8", errors="ignore") as f:
        ipxact_text = f.read()

    tree = ET.parse(path)
    root = tree.getroot()
    ns_m = re.match(r'\{(.+?)\}', root.tag)
    ns   = {'ip': ns_m.group(1)} if ns_m else {}

    def find(tag):
        el = root.find(f"ip:{tag}", ns)
        return el.text.strip() if el is not None and el.text else ""

    design = find("name") or Path(path).stem

    ports = []
    for port in root.findall('.//ip:port', ns):
        pname = port.find('ip:name', ns)
        wire  = port.find('ip:wire', ns)
        if pname is None or wire is None:
            continue
        direction = wire.find('ip:direction', ns)
        vector    = wire.find('ip:vector', ns)
        width = 1
        if vector is not None:
            left  = vector.find('ip:left', ns)
            right = vector.find('ip:right', ns)
            try:
                width = abs(int(left.text) - int(right.text)) + 1
            except Exception:
                width = 1
        ports.append({
            "name"     : pname.text.strip(),
            "direction": direction.text.strip() if direction is not None else "in",
            "width"    : width,
        })

    ok(f"IP-XACT   : {design}  |  {len(ports)} ports")
    return design, ipxact_text, ports


def parse_manifest(path):
    """Load and validate manifest.json."""
    with open(path, encoding="utf-8") as f:
        meta = json.load(f)

    for key in ["interfaces", "clocks", "resets", "dut", "tool"]:
        if key not in meta:
            warn(f"Manifest missing '{key}' section")

    ifaces = meta.get("interfaces", [])
    ok(f"Manifest  : {len(ifaces)} interface(s): "
       f"{', '.join(i['name'] for i in ifaces)}")
    return meta


def parse_intent(path):
    """Read verification intent file."""
    with open(path, encoding="utf-8", errors="ignore") as f:
        text = f.read()
    ok(f"Intent    : {len(text):,} chars")
    for section in ["DRIVE:", "OBSERVE:", "CHECK:", "OUT OF SCOPE:"]:
        if section not in text:
            warn(f"Intent missing recommended section '{section}'")
    return text


def parse_spec(path):
    """Read design spec — text, markdown, or PDF."""
    if not path or not os.path.exists(path):
        warn("No spec — LLM uses training knowledge of protocols")
        return ""

    suffix = Path(path).suffix.lower()

    if suffix == ".pdf":
        text = _extract_pdf(path)
    else:
        with open(path, encoding="utf-8", errors="ignore") as f:
            text = f.read()

    if text:
        ok(f"Spec      : {len(text):,} chars from {Path(path).name}")
    else:
        warn(f"Spec      : could not extract text from {Path(path).name}")
    return text


def _extract_pdf(path):
    """Try pdfplumber then pypdf for PDF text extraction."""
    try:
        import pdfplumber
        with pdfplumber.open(path) as pdf:
            return "\n".join(p.extract_text() or "" for p in pdf.pages)
    except ImportError:
        pass
    try:
        import pypdf
        reader = pypdf.PdfReader(path)
        return "\n".join(p.extract_text() or "" for p in reader.pages)
    except ImportError:
        pass
    warn("PDF extraction: pip install pdfplumber  or  pip install pypdf")
    return ""


def parse_rtl(path):
    """Parse RTL module declaration for actual port names."""
    if not path or not os.path.exists(path):
        return None

    with open(path, encoding="utf-8", errors="ignore") as f:
        text = f.read()

    # Remove comments
    text = re.sub(r'//.*', '', text)
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)

    m = re.search(
        r'module\s+(\w+)\s*(?:#\s*\([^)]*\))?\s*\(([^;]+?)\)\s*;',
        text, re.DOTALL
    )
    if not m:
        warn(f"RTL: could not parse module declaration in {path}")
        return None

    module_name = m.group(1)
    port_block  = m.group(2)

    ports = []
    for line in port_block.split(','):
        line = line.strip()
        pm   = re.search(
            r'(input|output|inout)\s+(?:wire\s+|reg\s+|logic\s+)?'
            r'(?:\[(\d+)\s*:\s*(\d+)\]\s+)?(\w+)\s*$', line
        )
        if pm:
            left  = pm.group(2)
            right = pm.group(3)
            ports.append({
                "name"     : pm.group(4),
                "direction": pm.group(1),
                "width"    : (abs(int(left)-int(right))+1
                              if left is not None else 1),
            })

    ok(f"RTL       : {module_name}  |  {len(ports)} ports parsed")
    return {"module": module_name, "ports": ports}


# ─────────────────────────────────────────────────────────────────────────────
# PRE-FLIGHT CHECK
# ─────────────────────────────────────────────────────────────────────────────

def preflight_check(design, meta, intent_text):
    """Cross-check inputs before calling API. Fast, no LLM."""
    banner("PRE-FLIGHT CHECK")
    issues = []

    design_meta = meta.get("dut", {}).get("top_module", "")
    if design_meta and design_meta != design:
        issues.append(
            f"Design name mismatch: IP-XACT='{design}' "
            f"manifest='{design_meta}'"
        )

    if not meta.get("clocks"):
        issues.append("Manifest missing 'clocks'")
    if not meta.get("resets"):
        issues.append("Manifest missing 'resets'")
    if not meta.get("interfaces"):
        issues.append("Manifest missing 'interfaces'")

    if not meta.get("verification_goals"):
        warn("No verification_goals in manifest — "
             "scoreboard goals from intent file only")

    if issues:
        for issue in issues:
            err(issue)
        err(f"{len(issues)} issue(s) — fix before continuing")
        sys.exit(1)
    else:
        ok("All checks passed")


# ─────────────────────────────────────────────────────────────────────────────
# DIRECTORY STRUCTURE — script owns this, not manifest, not LLM
# ─────────────────────────────────────────────────────────────────────────────

def create_directories(outdir, ifaces):
    """Standard UVM directory layout. Script-enforced, protocol-agnostic."""
    dirs = [
        outdir,
        f"{outdir}/config",
        f"{outdir}/env",
        f"{outdir}/sequences",
        f"{outdir}/tests",
        f"{outdir}/top",
    ]
    for i in ifaces:
        dirs.append(f"{outdir}/env/{i['name']}_agent")

    for d in dirs:
        os.makedirs(d, exist_ok=True)

    ok(f"Directories: {len(dirs)} created")
    for d in dirs:
        info(d)


# ─────────────────────────────────────────────────────────────────────────────
# LLM CALL
# ─────────────────────────────────────────────────────────────────────────────

def call_llm(ctx):
    """
    Single API call using streaming.
    Streaming is required for large outputs (21 files) that take >10 minutes.
    Shows live progress as files are generated.
    """
    prompt = build_master_prompt(ctx)
    n_tok  = len(prompt) // 4
    info(f"Prompt     : ~{n_tok:,} tokens")
    info(f"Files      : {len(_llm_files(ctx))} to generate")
    info(f"Model      : {MODEL}")
    info("Streaming response — files will appear as generated...")
    print()

    chunks   = []
    file_count = 0
    char_count = 0

    with client.messages.stream(
        model      = MODEL,
        max_tokens = MAX_TOKENS,
        system     = SYSTEM_PROMPT,
        messages   = [{"role": "user", "content": prompt}]
    ) as stream:
        for text_chunk in stream.text_stream:
            chunks.append(text_chunk)
            char_count += len(text_chunk)

            # Count FILE: markers as they arrive — shows live progress
            accumulated = "".join(chunks)
            new_count   = accumulated.count("\nFILE:")
            if new_count > file_count:
                file_count = new_count
                # Extract last file name for progress display
                last_file = re.findall(r'\nFILE:\s*(.+)', accumulated)
                fname = last_file[-1].strip() if last_file else ""
                print(f"\r  {GRN}→{RST}  [{file_count:2d}/21] {fname:<50s}", end="", flush=True)

    print()  # newline after progress line
    full_text = "".join(chunks)
    info(f"Response   : ~{len(full_text)//4:,} tokens  ({file_count} FILE: blocks found)")
    return full_text


def parse_llm_response(text):
    """Parse FILE:/END_FILE blocks. Returns dict {filepath: content}."""
    files   = {}
    pattern = r'^FILE:\s*(.+?)\n(.*?)^END_FILE'
    for m in re.finditer(pattern, text, re.MULTILINE | re.DOTALL):
        filepath = m.group(1).strip()
        content  = m.group(2).strip()
        content  = re.sub(r'^```\w*\n?', '', content)
        content  = re.sub(r'\n?```$',   '', content)
        files[filepath] = content.strip()
    return files


def write_file(path, content):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def write_llm_files(generated, outdir, required):
    """Write LLM-generated files. Report missing."""
    written = []
    missing = []

    for filepath, content in generated.items():
        write_file(os.path.join(outdir, filepath), content)
        written.append(filepath)
        ok(f"  [LLM]     {filepath}")

    for req in required:
        if req not in generated:
            missing.append(req)
            warn(f"  [MISSING] {req}")

    return written, missing


# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT-GENERATED FILES
# ─────────────────────────────────────────────────────────────────────────────

def write_pkg(ctx, outdir):
    """
    <design>_pkg.sv — include order guaranteed correct by script.
    This is the most common source of compile errors when LLM-generated.
    Script owns it. Engineers do not edit it.
    """
    design = ctx["design"]
    ifaces = ctx["interfaces"]

    lines = [
        f"// {design}_pkg.sv",
        f"// Generated by vega_llm_tbgen.py v{VERSION} — DO NOT EDIT",
        f"// Include order is script-enforced. Reordering causes compile errors.",
        "",
        f"package {design}_pkg;",
        "",
        "  import uvm_pkg::*;",
        "  `include \"uvm_macros.svh\"",
        "",
        "  // 1. Config",
        f"  `include \"config/{design}_dut_config.sv\"",
        "",
        "  // 2. Seq items (enums defined here — must precede all other classes)",
    ]
    for i in ifaces:
        lines.append(f"  `include \"env/{i['name']}_agent/{i['name']}_seq_item.sv\"")

    lines += ["", "  // 3. Scoreboard",
              f"  `include \"env/{design}_scoreboard.sv\"",
              "", "  // 4. Agents"]
    for i in ifaces:
        n = i["name"]
        lines += [
            f"  `include \"env/{n}_agent/{n}_driver.sv\"",
            f"  `include \"env/{n}_agent/{n}_monitor.sv\"",
            f"  `include \"env/{n}_agent/{n}_sequencer.sv\"",
            f"  `include \"env/{n}_agent/{n}_agent.sv\"",
        ]

    lines += ["", "  // 5. Environment",
              f"  `include \"env/{design}_env.sv\"",
              "", "  // 6. Sequences"]
    for i in ifaces:
        lines.append(f"  `include \"sequences/{i['name']}_bringup_seq.sv\"")

    lines += ["", "  // 7. Tests — LAST",
              f"  `include \"tests/{design}_bringup_test.sv\"",
              f"  `include \"tests/{design}_sanity_test.sv\"",
              "", "endpackage"]

    write_file(os.path.join(outdir, f"{design}_pkg.sv"), "\n".join(lines))
    ok(f"  [SCRIPT]  {design}_pkg.sv  (include order guaranteed)")


def write_tb_list(ctx, outdir):
    """tb_list.f — vlog compile order."""
    design    = ctx["design"]
    ifaces    = ctx["interfaces"]
    rtl_files = ctx["meta"].get("dut", {}).get("rtl_files", [])

    lines = [
        f"// tb_list.f — {design} UVM Testbench compile filelist",
        f"// Generated by vega_llm_tbgen.py v{VERSION} — DO NOT EDIT",
        "",
        "// RTL",
    ]
    if rtl_files:
        lines += rtl_files
    else:
        lines += [
            f"// EDIT_REQUIRED: add RTL file path here",
            f"// ../../rtl/{design}.sv",
        ]

    lines += ["", "// Interfaces"]
    for i in ifaces:
        lines.append(f"{i['name']}_if.sv")

    lines += [
        "", "// Package",
        f"{design}_pkg.sv",
        "", "// Top",
        "top/tb_top.sv",
    ]

    write_file(os.path.join(outdir, "tb_list.f"), "\n".join(lines))
    ok(f"  [SCRIPT]  tb_list.f")


def write_compile_bat(ctx, outdir):
    """compile.bat — vlog + vopt."""
    design = ctx["design"]
    tool   = ctx["meta"].get("tool", {})
    questa = tool.get("questa_path", "C:\\intelFPGA\\22.1std\\questa_fse")
    lic    = tool.get("license_file", "")

    content = f"""@echo off
:: compile.bat — {design.upper()} UVM Testbench
:: Generated by vega_llm_tbgen.py v{VERSION}

set QUESTA_HOME={questa}
set UVM_HOME=%QUESTA_HOME%\\verilog_src\\uvm-1.1d
{"set LM_LICENSE_FILE=" + lic if lic else ":: set LM_LICENSE_FILE=<path>"}

echo [{design.upper()} COMPILE]

if not exist work (
    "%QUESTA_HOME%\\win64\\vlib" work
)

"%QUESTA_HOME%\\win64\\vlog" -sv -timescale 1ns/1ps ^
    +define+UVM_NO_DPI ^
    +incdir+%UVM_HOME%\\src ^
    -f tb_list.f

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo *** COMPILE FAILED ***
    echo Run: claude "run compile.bat and fix any errors"
    exit /b 1
)

"%QUESTA_HOME%\\win64\\vopt" tb_top -o tb_top_opt +acc

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo *** ELABORATE FAILED ***
    echo Run: claude "fix elaborate errors"
    exit /b 1
)

echo.
echo *** COMPILE + ELABORATE PASSED ***
echo Next: sim.bat
"""
    write_file(os.path.join(outdir, "compile.bat"), content)
    ok(f"  [SCRIPT]  compile.bat")


def write_sim_bat(ctx, outdir):
    """sim.bat — vsim. Usage: sim.bat [testname]"""
    design = ctx["design"]
    tool   = ctx["meta"].get("tool", {})
    questa = tool.get("questa_path", "C:\\intelFPGA\\22.1std\\questa_fse")
    lic    = tool.get("license_file", "")

    content = f"""@echo off
:: sim.bat — {design.upper()} UVM Testbench
:: Generated by vega_llm_tbgen.py v{VERSION}
:: Usage: sim.bat [testname]
::   Default test: {design}_bringup_test
::   Sanity test : sim.bat {design}_sanity_test

set QUESTA_HOME={questa}
{"set LM_LICENSE_FILE=" + lic if lic else ":: set LM_LICENSE_FILE=<path>"}

set TESTNAME=%1
if "%TESTNAME%"=="" set TESTNAME={design}_bringup_test

echo [{design.upper()} SIM] %TESTNAME%

"%QUESTA_HOME%\\win64\\vsim" -c tb_top_opt ^
    +UVM_TESTNAME=%TESTNAME% ^
    +UVM_NO_RELNOTES ^
    -do "run -all; quit -f"

echo.
echo If failed: claude "run sim.bat and fix any UVM_FATAL or UVM_ERROR"
"""
    write_file(os.path.join(outdir, "sim.bat"), content)
    ok(f"  [SCRIPT]  sim.bat  (default: {design}_bringup_test)")


def write_claude_md(ctx, outdir, missing_files):
    """
    CLAUDE.md — read by Claude Code at session start.
    Contains all project context so engineer never re-explains the project.
    """
    design = ctx["design"]
    ifaces = ctx["interfaces"]
    questa = ctx["meta"].get("tool", {}).get(
        "questa_path", "C:\\intelFPGA\\22.1std\\questa_fse")
    goals  = ctx["meta"].get("verification_goals", [])
    intent = ctx.get("intent_text", "")

    iface_lines = "".join(
        f"  - {i['name']:20s} protocol={i['protocol']}  "
        f"role={i['role']}\n"
        for i in ifaces
    )

    goal_lines = "".join(
        f"  [{g['id']}] {g['goal']}\n"
        for g in goals
    ) if goals else "  (see verification_intent.txt)\n"

    missing_block = ""
    if missing_files:
        missing_block = "\n## ⚠ MISSING FILES — LLM DID NOT GENERATE\n"
        missing_block += "".join(f"  {f}\n" for f in missing_files)
        missing_block += (
            "\nTo generate missing files:\n"
            "  claude 'generate <filename> for this UVM testbench'\n"
        )

    intent_summary = textwrap.fill(
        intent[:400].replace('\n', ' '), width=68,
        initial_indent='  ', subsequent_indent='  '
    ) if intent else "  (see verification_intent.txt)"

    content = f"""# CLAUDE.md — {design} UVM Testbench
# Generated by vega_llm_tbgen.py v{VERSION} — {datetime.now().strftime('%Y-%m-%d')}
#
# Read by Claude Code at start of every session.
# Do not delete. Update manually when design changes.

## Project
Design : {design}
Tool   : Questa FSE — {questa}

## Interfaces
{iface_lines}
## Verification Goals — all must be implemented in scoreboard
{goal_lines}
## Verification Intent
{intent_summary}

## Tests
  {design}_bringup_test  — ONE txn, no scoreboard, proves TB alive
                            run this FIRST — if this fails TB is broken
  {design}_sanity_test   — num_txns, full scoreboard, all goals
                            if bringup passes but sanity fails, DUT is wrong

## CRITICAL RULES

### No .randomize() — Questa FSE has no svverification license
  WRONG: req.randomize() with {{ ... }}
  RIGHT: req.HADDR = $urandom_range(0, 32'hEFFF);
         req.post_randomize();

### config_db — no modport suffix in virtual interface type
  WRONG: uvm_config_db#(virtual ahb_mst_if.driver)::get(...)
  RIGHT: uvm_config_db#(virtual ahb_mst_if)::get(...)

### config_db — null scope in set(), not this
  WRONG: uvm_config_db#(...)::set(this, ...)
  RIGHT: uvm_config_db#(...)::set(null, "*", "cfg", cfg)

### Passive sequences — forever loop not repeat()
  WRONG: repeat(cfg.num_txns) begin ... end
  RIGHT: forever begin ... end

### Monitors — post_randomize() after capturing signals
  txn.post_randomize();
  ap.write(txn);

### uvm_analysis_imp_decl — at file scope, before class definition
### timescale — in tb_top.sv ONLY

## Edit Hint Tags
  EDIT_REQUIRED    — fix before simulation works
  EDIT_RECOMMENDED — verify against your DUT
  EDIT_OPTIONAL    — change only for unusual designs
  PROTOCOL_GAP     — implement manually from protocol spec

## Workflow
  compile.bat                    — compile + elaborate
  sim.bat                        — run bringup_test
  sim.bat {design}_sanity_test   — run sanity_test

  Fixing with Claude Code:
    "run compile.bat and fix any errors"
    "run sim.bat and fix any UVM_FATAL"
    "check scoreboard implements all verification goals"
    "commit as iteration-N"

  Experiment record:
    git log --oneline
    git diff HEAD~1 HEAD
{missing_block}"""

    write_file(os.path.join(outdir, "CLAUDE.md"), content)
    ok(f"  [SCRIPT]  CLAUDE.md  ({len(content):,} chars)")


def write_dut_bind_from_rtl(ctx, rtl_info, outdir):
    """Replace LLM dut_bind with RTL-based version when --rtl provided."""
    design      = ctx["design"]
    rtl_ports   = rtl_info["ports"]
    rtl_module  = rtl_info["module"]
    ipxact_names = {p["name"] for p in ctx["ports"]}
    rtl_names    = {p["name"] for p in rtl_ports}

    only_rtl  = rtl_names - ipxact_names
    only_xact = ipxact_names - rtl_names
    if only_rtl:
        warn(f"Ports in RTL not in IP-XACT: {only_rtl}")
    if only_xact:
        warn(f"Ports in IP-XACT not in RTL: {only_xact}")

    params = ctx["meta"].get("dut", {}).get("parameters", {})
    param_block = ""
    if params:
        param_lines = [f"    .{k}({v})" for k, v in params.items()]
        param_block = "#(\n" + ",\n".join(param_lines) + "\n) "

    port_lines = []
    for p in rtl_ports:
        note = ("  // EDIT_REQUIRED: not in IP-XACT"
                if p["name"] in only_rtl else "")
        port_lines.append(f"    .{p['name']:20s}(){note}")

    lines = [
        f"// {design}_dut_bind.sv",
        f"// Generated from RTL port list by vega_llm_tbgen.py v{VERSION}",
        f"// RTL module: {rtl_module}",
        (f"// Cross-check: OK" if not only_rtl and not only_xact
         else f"// Cross-check: MISMATCHES — see warnings above"),
        "",
        "// EDIT_REQUIRED: connect every port to the appropriate interface signal",
        "",
        f"{rtl_module} {param_block}dut (",
        ",\n".join(port_lines),
        ");",
    ]

    path = os.path.join(outdir, "top", f"{design}_dut_bind.sv")
    write_file(path, "\n".join(lines))
    ok(f"  [RTL]     top/{design}_dut_bind.sv  (from RTL, not IP-XACT)")


# ─────────────────────────────────────────────────────────────────────────────
# GIT
# ─────────────────────────────────────────────────────────────────────────────

def git_init_and_commit(outdir):
    """Init repo and make iteration-0 commit."""
    def run(cmd):
        r = subprocess.run(cmd, shell=True, cwd=outdir,
                           capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    run("git init")
    run('git config user.email "vega@tbgen.local"')
    run('git config user.name "VEGA TBGen"')
    run("git add .")
    rc, out = run('git commit -m "iteration-0: LLM generated scaffolding"')

    if rc == 0:
        ok("Git: iteration-0 committed")
        info("Next commits: git add . && git commit -m 'iteration-N: what changed'")
    else:
        warn(f"git commit: {out.strip()[:100]}")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description=f"VEGA LLM UVM Testbench Generator v{VERSION}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(f"""
        Example:
          python vega_llm_tbgen.py \\
            --ipxact   manifest/ahb2apb_bridge.xml \\
            --manifest manifest/manifest.json \\
            --intent   manifest/verification_intent.txt \\
            --spec     manifest/ahb2apb_spec.pdf \\
            --output   ahb2apb_bridge_uvmtb

        After generation:
          cd ahb2apb_bridge_uvmtb
          claude
          > "run compile.bat and fix any errors"
          > "commit as iteration-1"
        """)
    )
    ap.add_argument("--ipxact",   required=True,
                    help="IP-XACT XML file")
    ap.add_argument("--manifest", required=True,
                    help="manifest.json")
    ap.add_argument("--intent",   required=True,
                    help="verification_intent.txt")
    ap.add_argument("--spec",     default=None,
                    help="Design spec pdf/md/txt [optional]")
    ap.add_argument("--rtl",      default=None,
                    help="RTL .sv for dut_bind generation [optional]")
    ap.add_argument("--output",   default="uvmtb",
                    help="Output directory [default: uvmtb]")
    ap.add_argument("--no-git",   action="store_true",
                    help="Skip git init")
    ap.add_argument("--dry-run",  action="store_true",
                    help="Show prompt, no API call")
    args = ap.parse_args()

    print(f"\n{BOLD}VEGA LLM Testbench Generator v{VERSION}{RST}")
    print(f"Model : {MODEL}  |  {datetime.now().strftime('%Y-%m-%d %H:%M')}")

    # ── Parse inputs ──────────────────────────────────────────────────
    banner("PARSING INPUTS")
    design, ipxact_text, ports = parse_ipxact(args.ipxact)
    meta                       = parse_manifest(args.manifest)
    intent_text                = parse_intent(args.intent)
    spec_text                  = parse_spec(args.spec)
    rtl_info                   = parse_rtl(args.rtl)

    design = meta.get("dut", {}).get("top_module", design)

    ctx = {
        "design"     : design,
        "ipxact_text": ipxact_text,
        "ports"      : ports,
        "meta"       : meta,
        "interfaces" : meta.get("interfaces", []),
        "clocks"     : meta.get("clocks", []),
        "resets"     : meta.get("resets", []),
        "intent_text": intent_text,
        "spec_text"  : spec_text,
    }

    # ── Pre-flight ────────────────────────────────────────────────────
    preflight_check(design, meta, intent_text)

    # ── Dry run ───────────────────────────────────────────────────────
    if args.dry_run:
        banner("DRY RUN — PROMPT PREVIEW")
        prompt = build_master_prompt(ctx)
        print(prompt[:4000])
        print(f"\n... [{len(prompt)-4000} more chars]")
        print(f"\nPrompt : {len(prompt):,} chars  (~{len(prompt)//4:,} tokens)")
        print(f"Files  : {len(_llm_files(ctx))} LLM + "
              f"{len(_script_files(ctx))} script")
        return

    # ── Directories ───────────────────────────────────────────────────
    banner("CREATING DIRECTORY STRUCTURE")
    create_directories(args.output, ctx["interfaces"])

    # ── LLM generation ────────────────────────────────────────────────
    banner("LLM GENERATION")
    response_text = call_llm(ctx)

    # Save raw response (reproducibility artifact for book)
    write_file(os.path.join(args.output, ".vega_raw_response.txt"),
               response_text)

    generated        = parse_llm_response(response_text)
    required         = _llm_files(ctx)
    ok(f"Parsed {len(generated)} files from LLM response")

    banner("WRITING LLM FILES")
    written, missing = write_llm_files(generated, args.output, required)

    if rtl_info:
        banner("RTL DUT BIND")
        write_dut_bind_from_rtl(ctx, rtl_info, args.output)

    # ── Script-generated files ────────────────────────────────────────
    banner("WRITING SCRIPT FILES")
    write_pkg(ctx, args.output)
    write_tb_list(ctx, args.output)
    write_compile_bat(ctx, args.output)
    write_sim_bat(ctx, args.output)
    write_claude_md(ctx, args.output, missing)

    # ── Git ───────────────────────────────────────────────────────────
    if not args.no_git:
        banner("GIT")
        git_init_and_commit(args.output)

    # ── Summary ───────────────────────────────────────────────────────
    banner("DONE")
    ok(f"Output    : {args.output}/")
    ok(f"LLM files : {len(written)} generated")
    ok(f"Script    : pkg.sv  tb_list.f  compile.bat  sim.bat  CLAUDE.md")
    if missing:
        warn(f"Missing   : {len(missing)} files — see CLAUDE.md")

    print(f"""
  {BOLD}Next steps:{RST}

    cd {args.output}
    claude

    Inside Claude Code:
      "run compile.bat and fix any errors"
      "commit as iteration-1"
      "run sim.bat and fix any UVM_FATAL"
      "commit as iteration-2"

  {BOLD}Experiment record:{RST}

    git log --oneline
    git diff HEAD~1 HEAD
""")


if __name__ == "__main__":
    main()
