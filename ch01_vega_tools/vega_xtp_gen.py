"""
VEGA XTP Generator
==================
Single-pass extraction from full PDF spec to XTP file.
No chunking. No intermediate files. One API call.

Usage:
  python vega_xtp_gen.py <pdf_file> [--output <dir>]

Output:
  <output_dir>/<pdf_name>_testplan.xtp  (default: current directory)

Pipeline:
  1. Load PDF as base64
  2. Send full PDF + prompt to Claude in one call
  3. Validate quality (12 checks, threshold 80%)
  4. Reprompt with feedback if score < 80% (up to 3x)
  5. Assign REQ/TEST IDs and write XTP

Requirements:
  pip install pymupdf anthropic
  set ANTHROPIC_API_KEY=your-key   (Windows)
  export ANTHROPIC_API_KEY=your-key (Linux/Mac)

Author: Vikash Kumar
Methodology: Cognitive Verification Architecture — VEGA Framework
"""

import os
import sys
import re
import json
import base64
import time
from collections import defaultdict


# =============================================================================
# CONSTANTS
# =============================================================================

QUALITY_THRESHOLD = 80      # Minimum score to accept output
MAX_RETRIES       = 3       # Maximum reprompt attempts
MAX_TOKENS        = 32000   # Claude response token limit
MODEL             = "claude-sonnet-4-20250514"

STANDARD_CATEGORIES = [
    "connectivity",
    "bringup_init",
    "register_access",
    "main_datapath",
    "reset",
    "error",
    "stress",
    "power_aware",
    "dvfs",
    "protocol",
    "cross_feature",
    "ambiguous",
]

CATEGORY_MIN_STEPS = {
    "reset":       10,
    "error":       15,
    "stress":       7,
    "power_aware":  9,
    "dvfs":         7,
    "default":      4,
}

CATEGORY_RULES = {
    "reset": """
RESET TESTS — minimum 10 steps:
1. Configure device (write registers with exact values)
2. Send traffic, verify works (write 0xDEAD_BEEF, read back)
3. Place in specific state (IDLE/ACTIVE/WAITING)
4. Assert reset (RESET=1 or RESETn=0)
5. Hold reset for N cycles
6. Release reset
7. Verify ALL registers at reset values (read and compare)
8. Reconfigure device
9. Send traffic again
10. PROVE: write 0xCAFE_BABE, read back, compare
""",
    "error": """
ERROR TESTS — minimum 15 steps:
1.  Configure device
2.  Send good traffic, verify works
3.  Read error status register — verify clean (ERROR_STATUS=0)
4.  Inject specific error condition
5.  Verify error detected (ERROR=1)
6.  Check interrupt asserted (if applicable)
7.  Read error log — verify error type captured
8.  Read error info (address, transaction type)
9.  Clear interrupt
10. Verify interrupt cleared
11. Perform recovery (soft reset or clear)
12. Read error log after recovery
13. Reconfigure device
14. Send good traffic
15. PROVE: verify data integrity AND error log clean
""",
    "stress": """
STRESS TESTS — minimum 7 steps:
1. Configure for max performance (max freq, min latency)
2. Back-to-back transfers with ZERO idle cycles
3. Run 1000+ write transactions
4. Run 1000+ read transactions
5. Monitor for errors during stress
6. Verify device still works after stress
7. Verify no errors logged (ERROR_STATUS=0)
""",
    "power_aware": """
POWER TESTS — minimum 9 steps:
1. Configure device
2. Verify works (write/read test)
3. Prepare for low power entry
4. Enter low power state
5. Verify isolation/retention signals
6. Exit low power state
7. Wait for clocks stable
8. Reconfigure if needed
9. PROVE: verify device works after power cycle
""",
    "dvfs": """
DVFS TESTS — minimum 7 steps:
1. Configure at initial frequency
2. Verify works at initial frequency
3. Ensure interface IDLE before frequency change
4. Change frequency (write DVFS register)
5. Wait for clock stable
6. Verify works at new frequency
7. Verify data integrity preserved across frequency change
""",
    "protocol": """
PROTOCOL TESTS — signal-level timing required:
1. Verify phase/state transitions with timing (T1, T2, cycles)
2. Check signal relationships and dependencies
3. Test wait state handling (signal stability during wait)
4. Verify handshake completion
5. Check status signals at completion
""",
    "connectivity": """
CONNECTIVITY TESTS:
1. Test address bus (write to 0x0000_0000 and max address)
2. Test data bus (write 0xFFFF_FFFF, 0x0000_0000, 0xAAAA_AAAA)
3. Verify read matches write
4. Test clock connectivity
5. Test reset connectivity
""",
    "main_datapath": """
DATAPATH TESTS:
1. Basic write with hex data (0xDEAD_BEEF to 0x1000)
2. Basic read and verify
3. Test data patterns (all 1s, all 0s, alternating)
4. Test address range
5. Verify data integrity
""",
}


# =============================================================================
# STAGE 1: LOAD PDF
# =============================================================================

def load_pdf(pdf_path):
    """Load PDF file and return base64 string."""
    if not os.path.exists(pdf_path):
        print(f"  ERROR: File not found: {pdf_path}")
        sys.exit(1)

    try:
        import fitz
    except ImportError:
        print("  ERROR: PyMuPDF not installed. Run: pip install pymupdf")
        sys.exit(1)

    try:
        doc = fitz.open(pdf_path)
        total_pages = len(doc)
        doc.close()
    except Exception as e:
        print(f"  ERROR: Cannot open PDF: {e}")
        sys.exit(1)

    with open(pdf_path, "rb") as f:
        pdf_base64 = base64.standard_b64encode(f.read()).decode("utf-8")

    size_mb = os.path.getsize(pdf_path) / (1024 * 1024)
    print(f"  PDF loaded: {total_pages} pages, {size_mb:.1f} MB")
    return pdf_base64, total_pages


# =============================================================================
# STAGE 2: BUILD PROMPT
# =============================================================================

def build_extraction_prompt(filename, total_pages):
    """Build the full extraction prompt."""

    categories_str = ", ".join(STANDARD_CATEGORIES)

    rules_str = ""
    for cat, rule in CATEGORY_RULES.items():
        rules_str += f"\n{cat.upper()} CATEGORY:{rule}"

    return f"""You are an expert hardware verification engineer.
Your task is to read this complete {total_pages}-page specification for "{filename}"
and produce a production-quality verification test plan.

=====================================================================
WHAT TO EXTRACT
=====================================================================

For each functional feature in the spec, extract:

1. FEATURE — a functional block or capability
2. REQUIREMENTS — specific testable rules from the spec
3. TEST — detailed test case with exact signal values and timing
4. CROSS-FEATURE TESTS — interactions between two or more features

=====================================================================
TEST QUALITY REQUIREMENTS — EVERY TEST MUST HAVE:
=====================================================================

1. EXACT SIGNAL VALUES:
   BAD:  "Assert the select signal"
   GOOD: "Drive PSEL=1, PENABLE=0, PADDR=0x0000_1000, PWRITE=1"

2. SPECIFIC DATA PATTERNS:
   BAD:  "Write test data"
   GOOD: "Write PWDATA=0xDEAD_BEEF to PADDR=0x0000_1000"

3. CYCLE-ACCURATE TIMING:
   BAD:  "Wait for completion"
   GOOD: "At clock rising edge T2 (cycle 2), sample PREADY"

4. HEX ADDRESSES:
   BAD:  "Write to register"
   GOOD: "Write to PADDR=0x0000_1000"

5. EXPLICIT EXPECTED VALUES:
   BAD:  "Transfer completes successfully"
   GOOD: "PREADY=1, PSLVERR=0, transfer completes in 2 cycles"

6. VERIFICATION / READ-BACK STEP:
   BAD:  (missing)
   GOOD: "Read back from PADDR=0x1000, verify PRDATA=0xDEAD_BEEF"

7. SPEC RULE REFERENCES:
   BAD:  "The bridge converts transfers"
   GOOD: "Per CONV-1, each AHB beat maps to one APB transfer"

8. CONSISTENT REGISTER ADDRESSES:
   Use the EXACT same hex address every time for the same register.

=====================================================================
CATEGORY-SPECIFIC TEST RULES
=====================================================================
{rules_str}

=====================================================================
STANDARD CATEGORIES (use these; add new ones if the spec warrants)
=====================================================================
{categories_str}

=====================================================================
OUTPUT FORMAT — return a single JSON object with two keys:
=====================================================================

{{
  "features": [
    {{
      "feature_name": "Feature Name",
      "category": "category_name",
      "pages": "page X-Y",
      "description": "One sentence: what this feature does",
      "signals": ["SIGNAL1", "SIGNAL2"],
      "requirements": [
        {{
          "req_text": "Exact requirement from spec, with rule ID e.g. CONV-1",
          "req_page": "page X",
          "test": {{
            "test_name": "short_descriptive_name",
            "objective": "What this test verifies",
            "preconditions": [
              "Clock running at specified frequency",
              "Reset deasserted",
              "Interface in IDLE state"
            ],
            "steps": [
              {{
                "step": 1,
                "action": "At T1, drive PSEL=1, PADDR=0x0000_1000, PWRITE=1, PWDATA=0xDEAD_BEEF, PENABLE=0",
                "expected": "Interface enters SETUP phase, PSEL=1, PENABLE=0"
              }},
              {{
                "step": 2,
                "action": "At T2, drive PENABLE=1, all other signals unchanged",
                "expected": "Interface enters ACCESS phase, PENABLE=1"
              }},
              {{
                "step": 3,
                "action": "Sample PREADY and PSLVERR at T2",
                "expected": "PREADY=1, PSLVERR=0, write completes"
              }},
              {{
                "step": 4,
                "action": "Drive PSEL=0, PENABLE=0 to end transfer",
                "expected": "Interface returns to IDLE"
              }},
              {{
                "step": 5,
                "action": "Read back: drive PSEL=1, PADDR=0x0000_1000, PWRITE=0, PENABLE=0",
                "expected": "Read transfer initiated"
              }},
              {{
                "step": 6,
                "action": "At T2 of read, drive PENABLE=1, sample PRDATA",
                "expected": "PRDATA=0xDEAD_BEEF, PREADY=1, PSLVERR=0"
              }}
            ],
            "pass_criteria": "1. Write completes in 2 cycles. 2. PREADY=1, PSLVERR=0. 3. Read-back matches."
          }}
        }}
      ]
    }}
  ],
  "cross_feature_tests": [
    {{
      "test_name": "cross_reset_during_active_transfer",
      "features_involved": ["feature_name_1", "feature_name_2"],
      "category": "cross_feature",
      "objective": "Verify reset during active transfer recovers correctly",
      "preconditions": ["Transfer in progress", "Device configured"],
      "steps": [
        {{
          "step": 1,
          "action": "Start write: PSEL=1, PADDR=0x1000, PWDATA=0xDEAD_BEEF, PENABLE=0 at T1",
          "expected": "Transfer begins, SETUP phase"
        }},
        {{
          "step": 2,
          "action": "At T2: Assert PRESETn=0 during ACCESS phase",
          "expected": "Reset accepted mid-transfer"
        }},
        {{
          "step": 3,
          "action": "Hold PRESETn=0 for 2 cycles (T2-T4)",
          "expected": "All outputs driven to reset values"
        }},
        {{
          "step": 4,
          "action": "At T4: Deassert PRESETn=1",
          "expected": "Reset released, interface in IDLE"
        }},
        {{
          "step": 5,
          "action": "Read PADDR=0x0000 (status/control register)",
          "expected": "Register at reset value 0x0000_0000"
        }},
        {{
          "step": 6,
          "action": "Write 0xCAFE_BABE to PADDR=0x1000, read back",
          "expected": "PRDATA=0xCAFE_BABE — device fully recovered"
        }}
      ],
      "pass_criteria": "Device recovers cleanly from reset during transfer. All registers at reset values. New transfers succeed."
    }}
  ]
}}

=====================================================================
EXTRACTION RULES
=====================================================================
1. Read the ENTIRE specification — do not skip any section
2. Extract EVERY feature, no matter how small
3. Use ACTUAL signal names from the spec — not generic names
4. Every requirement MUST have a test
5. Every test MUST meet the quality requirements above
6. Cross-feature tests MUST test real interactions between features
7. Reference spec rules by their actual IDs (CONV-1, AHB-2, etc.)
8. DO NOT invent features or requirements not in the spec
9. DO NOT use vague steps — every step needs signal values

Output ONLY valid JSON. No markdown. No explanation. No preamble."""


def build_reprompt(original_prompt, issues, attempt):
    """Build reprompt appending quality feedback to original prompt."""

    issues_text = "\n".join(f"  - {i}" for i in issues[:20])

    return f"""{original_prompt}

=====================================================================
QUALITY FEEDBACK — Attempt {attempt}/{MAX_RETRIES} — PLEASE FIX:
=====================================================================

Your previous response scored below {QUALITY_THRESHOLD}%.
Fix ALL of the following issues:

{issues_text}

MANDATORY FIXES:
1. Every step: signal=value format (PSEL=1, PREADY=0, etc.)
2. Every address: hex format (0x0000_1000)
3. Every test: timing references (T1, T2, cycle N)
4. Every test: verification/read-back step
5. Reset tests: minimum 10 steps
6. Error tests: minimum 15 steps
7. Reference ALL spec rule IDs (CONV-1, AHB-2, BURST-4)
8. Same register = same PADDR every time — no inconsistency
9. Same bit field = same [N:M] every time
10. No vague steps ("verify works", "send traffic" are not acceptable)

Output ONLY valid JSON. No markdown. No explanation."""


# =============================================================================
# STAGE 3: CALL CLAUDE API
# =============================================================================

def call_claude(pdf_base64, prompt, api_key):
    """
    Send PDF + prompt to Claude via streaming, return full response text.

    Streaming is required when max_tokens is large enough that generation
    may exceed 10 minutes.  We accumulate all text_delta events and return
    the concatenated result — callers see no difference.

    A progress dot is printed every ~5 seconds so the terminal does not look
    frozen during long generations.
    """
    try:
        import anthropic
    except ImportError:
        print("  ERROR: anthropic not installed. Run: pip install anthropic")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    chunks = []
    dot_interval = 5        # seconds between progress dots
    last_dot = time.time()

    with client.messages.stream(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "document",
                    "source": {
                        "type": "base64",
                        "media_type": "application/pdf",
                        "data": pdf_base64
                    }
                },
                {
                    "type": "text",
                    "text": prompt
                }
            ]
        }]
    ) as stream:
        for text in stream.text_stream:
            chunks.append(text)
            now = time.time()
            if now - last_dot >= dot_interval:
                print(".", end="", flush=True)
                last_dot = now

    return "".join(chunks)


# =============================================================================
# STAGE 3b: PARSE JSON
# =============================================================================

def parse_json(response):
    """
    Parse JSON from Claude response.
    Returns dict with 'features' and 'cross_feature_tests' keys.
    Handles markdown fences and malformed wrappers.
    """
    if not response:
        return None

    text = response.strip()

    # Strip markdown fences
    if "```json" in text:
        start = text.find("```json") + 7
        end = text.find("```", start)
        if end > start:
            text = text[start:end].strip()
    elif "```" in text:
        start = text.find("```") + 3
        end = text.find("```", start)
        if end > start:
            text = text[start:end].strip()

    # Try direct parse
    try:
        data = json.loads(text)
        if isinstance(data, list):
            return {"features": data, "cross_feature_tests": []}
        if isinstance(data, dict):
            if "features" not in data:
                data["features"] = []
            if "cross_feature_tests" not in data:
                data["cross_feature_tests"] = []
            return data
    except Exception:
        pass

    # Find outermost { } object
    if "{" in text:
        start = text.find("{")
        depth = 0
        in_str = False
        esc = False
        end = -1
        for i in range(start, len(text)):
            c = text[i]
            if esc:
                esc = False
                continue
            if c == "\\":
                esc = True
                continue
            if c == '"':
                in_str = not in_str
                continue
            if in_str:
                continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        if end > start:
            try:
                data = json.loads(text[start:end + 1])
                if "features" not in data:
                    data["features"] = []
                if "cross_feature_tests" not in data:
                    data["cross_feature_tests"] = []
                return data
            except Exception:
                pass

    return None


def salvage_partial_json(response):
    """
    Last-resort recovery from a truncated / malformed Claude response.

    Strategy:
      1. Strip markdown fences.
      2. Find opening '{'.
      3. Walk backward from end, stripping trailing incomplete tokens
         (partial strings, dangling commas, whitespace).
      4. Count unclosed '{' and '[' — append the matching closers.
      5. Try json.loads.  If that fails, peel off one unclosed level at a
         time and retry, until we either get valid JSON with at least one
         feature, or give up.

    Returns data dict (same shape as parse_json) or None.
    """
    if not response:
        return None

    text = response.strip()

    # Strip markdown fences
    for fence in ("```json", "```"):
        if fence in text:
            idx = text.find(fence) + len(fence)
            text = text[idx:].strip()
            end_fence = text.find("```")
            if end_fence > 0:
                text = text[:end_fence].strip()
            break

    brace_start = text.find("{")
    if brace_start < 0:
        return None
    text = text[brace_start:]

    def _count_stack(s):
        """Return list of unmatched openers ('{' / '[') in order."""
        stack = []
        in_str = False
        esc = False
        for c in s:
            if esc:
                esc = False
                continue
            if c == "\\" and in_str:
                esc = True
                continue
            if c == '"':
                in_str = not in_str
                continue
            if in_str:
                continue
            if c in "{[":
                stack.append(c)
            elif c == "}" and stack and stack[-1] == "{":
                stack.pop()
            elif c == "]" and stack and stack[-1] == "[":
                stack.pop()
        return stack

    def _strip_trailing(s):
        """Strip trailing partial string / comma / whitespace."""
        i = len(s) - 1
        while i >= 0 and s[i] not in "}]\"":
            i -= 1
        if i >= 0 and s[i] == '"':
            # ends inside a string — back past the opening quote
            i -= 1
            while i >= 0 and s[i] != '"':
                i -= 1
            i -= 1
        while i >= 0 and s[i] in ", \t\n\r":
            i -= 1
        return s[:i + 1]

    def _try_close(s):
        """Append calculated closers and try to parse."""
        stack = _count_stack(s)
        closing = "".join("}" if c == "{" else "]" for c in reversed(stack))
        candidate = s + closing
        try:
            data = json.loads(candidate)
            if isinstance(data, dict):
                data.setdefault("features", [])
                data.setdefault("cross_feature_tests", [])
                if data.get("features"):
                    return data
        except Exception:
            pass
        return None

    truncated = _strip_trailing(text)

    # First attempt: close whatever is open
    result = _try_close(truncated)
    if result:
        return result

    # Iteratively peel off the last unclosed level and retry
    # (handles case where the last partially-written object is malformed)
    for _ in range(6):
        stack = _count_stack(truncated)
        if not stack:
            break
        opener = stack[-1]
        closer = "}" if opener == "{" else "]"
        # Walk backward to find the unmatched opener and cut there
        depth = 0
        i = len(truncated) - 1
        in_str2 = False
        while i >= 0:
            c = truncated[i]
            if c == '"':
                in_str2 = not in_str2
            if not in_str2:
                if c == closer:
                    depth += 1
                elif c == opener:
                    if depth == 0:
                        truncated = truncated[:i].rstrip(", \t\n\r")
                        break
                    else:
                        depth -= 1
            i -= 1
        result = _try_close(truncated)
        if result:
            return result

    return None


def _skeleton_data():
    """
    Minimal valid data structure used when all extraction attempts fail.
    Produces an XTP the engineer can open and fill in manually.
    """
    return {
        "features": [
            {
                "feature_name": "MANUAL_REVIEW_REQUIRED",
                "category": "connectivity",
                "pages": "all",
                "description": (
                    "WARNING: Automatic extraction failed after all retries. "
                    "This placeholder was inserted so the tool produces an XTP "
                    "file. Replace with actual features from the spec."
                ),
                "signals": [],
                "requirements": [
                    {
                        "req_text": "Manual review required — automatic extraction produced no usable data",
                        "req_page": "1",
                        "test": {
                            "test_name": "manual_review_placeholder",
                            "objective": "Replace this placeholder with real test plan content",
                            "preconditions": ["Manual review of spec required"],
                            "steps": [
                                {
                                    "step": 1,
                                    "action": "Open spec and review extraction failure",
                                    "expected": "Identify why extraction failed"
                                },
                                {
                                    "step": 2,
                                    "action": "Manually populate features and requirements",
                                    "expected": "XTP updated with real content"
                                }
                            ],
                            "pass_criteria": "Manual review complete and XTP populated with real test plan."
                        }
                    }
                ]
            }
        ],
        "cross_feature_tests": []
    }


# =============================================================================
# STAGE 4: QUALITY VALIDATOR — 12 CHECKS
# =============================================================================

def _steps_text(test):
    parts = []
    for s in test.get("steps", []):
        parts.append(str(s.get("action", "")))
        parts.append(str(s.get("expected", "")))
    return " ".join(parts)


# Per-test checks (return score 0-2, issue string or None)

def chk_step_count(test, category):
    minimum = CATEGORY_MIN_STEPS.get(category, CATEGORY_MIN_STEPS["default"])
    actual = len(test.get("steps", []))
    if actual >= minimum:
        return 2, None
    return 0, f"Only {actual} steps, need {minimum} for '{category}'"


def chk_signal_values(test):
    if re.search(r"=\s*[01]\b|=\s*0x", _steps_text(test)):
        return 2, None
    return 0, "Missing signal=value format (e.g. PSEL=1)"


def chk_hex_addresses(test):
    if "0x" in _steps_text(test):
        return 2, None
    return 0, "Missing hex values (need 0x format)"


def chk_timing(test):
    text = _steps_text(test).lower()
    keywords = ["t1", "t2", "t3", "t4", "cycle", "clock", "edge",
                "rising", "falling", "phase", "setup", "access"]
    if any(k in text for k in keywords):
        return 2, None
    return 0, "Missing timing references (T1, T2, cycle N)"


def chk_verification(test):
    text = _steps_text(test).lower()
    keywords = ["read back", "verify", "check", "confirm", "matches",
                "equals", "compare", "prove"]
    if any(k in text for k in keywords):
        return 2, None
    return 0, "Missing verification/read-back step"


def chk_placeholders(test, test_name):
    vague = [
        r"^verify\s+(it\s+)?works",
        r"^check\s+operation",
        r"^normal\s+(transfer|operation)",
        r"^send\s+(good\s+)?traffic$",
        r"^complete\s+transfer",
    ]
    steps = test.get("steps", [])
    if not steps:
        return 0, f"{test_name}: no steps at all"
    count = 0
    for s in steps:
        act = str(s.get("action", "")).strip().lower()
        exp = str(s.get("expected", "")).strip().lower()
        act_vague = (any(re.search(p, act) for p in vague) or
                     (len(act) < 20 and "=" not in act and "0x" not in act))
        exp_vague = len(exp) < 15 and "=" not in exp and "0x" not in exp
        if act_vague and exp_vague:
            count += 1
    ratio = count / len(steps)
    if ratio <= 0.10:
        return 2, None
    elif ratio <= 0.30:
        return 1, f"{test_name}: {count}/{len(steps)} steps are vague"
    return 0, f"{test_name}: {count}/{len(steps)} steps lack signal detail"


# Global checks (return score, list of issues)

def chk_rule_coverage(features):
    pat = re.compile(r"\b([A-Z][A-Z0-9_]{0,5})-(\d{1,2})\b")
    rules = set()
    for f in features:
        for req in f.get("requirements", []):
            text = req.get("req_text", "")
            for prefix, num in pat.findall(text):
                rules.add(f"{prefix}-{num}")
    if not rules:
        return 0, ["No named spec rules found (e.g. CONV-1, AHB-2)"]
    by_prefix = defaultdict(set)
    for r in rules:
        by_prefix[r.rsplit("-", 1)[0]].add(r)
    issues = []
    total_est = total_cov = 0
    for prefix, rs in sorted(by_prefix.items()):
        nums = [int(r.rsplit("-", 1)[1]) for r in rs]
        mx = max(nums)
        cov = len(rs)
        total_est += mx
        total_cov += cov
        if cov < mx * 0.5:
            issues.append(f"Rule family {prefix}: {cov}/{mx} covered")
    if total_est == 0:
        return 0, ["Cannot estimate rule coverage"]
    ratio = total_cov / total_est
    score = 3 if ratio >= 0.7 else (2 if ratio >= 0.5 else (1 if ratio >= 0.3 else 0))
    if ratio < 0.7:
        issues.insert(0, f"Rule coverage: {total_cov}/{total_est} ({int(ratio*100)}%), need 70%+")
    return score, issues


def chk_reg_addr_consistency(features):
    haddr = re.compile(r"P?ADDR\s*=\s*(0x[0-9A-Fa-f_]+)", re.IGNORECASE)
    ctx   = re.compile(
        r"(?:read|write|access)\s+(?:\w+\s+)*?(CTRL|STATUS|ERROR_ADDR|ERROR_INFO)\b"
        r"|\b(CTRL|STATUS|ERROR_ADDR|ERROR_INFO)\s+(?:register|reg)",
        re.IGNORECASE)
    reg_map = defaultdict(set)
    for f in features:
        for req in f.get("requirements", []):
            for step in req.get("test", {}).get("steps", []):
                action = str(step.get("action", ""))
                m = ctx.search(action)
                if not m:
                    continue
                reg = (m.group(1) or m.group(2)).upper()
                a = haddr.search(action)
                if a:
                    reg_map[reg].add(a.group(1).replace("_", "").lower())
    issues = []
    bad = 0
    for reg, addrs in sorted(reg_map.items()):
        if len(addrs) > 1:
            bad += 1
            issues.append(f"Register {reg}: inconsistent addresses {sorted(addrs)}")
    if not reg_map:
        return 1, []
    return (2 if bad == 0 else (1 if bad <= 1 else 0)), issues


def chk_bitfield_consistency(features):
    bracket = re.compile(r"\b([A-Z][A-Z0-9_]{2,20})\[(\d{1,2}(?::\d{1,2})?)\]")
    skip = {"HADDR","HRDATA","HWDATA","PADDR","PRDATA","PWDATA",
            "HTRANS","HBURST","HSIZE","CTRL","STATUS","ERROR"}
    field_bits = defaultdict(set)
    for f in features:
        for req in f.get("requirements", []):
            for step in req.get("test", {}).get("steps", []):
                txt = str(step.get("action","")) + " " + str(step.get("expected",""))
                for name, bits in bracket.findall(txt):
                    if name not in skip:
                        field_bits[name].add(bits)
    issues = []
    bad = sum(1 for bits in field_bits.values() if len(bits) > 1)
    for name, bits in sorted(field_bits.items()):
        if len(bits) > 1:
            issues.append(f"Field {name}: inconsistent bit positions {sorted(bits)}")
    return (2 if bad == 0 else (1 if bad <= 2 else 0)), issues


def chk_category_coverage(features):
    cats = {f.get("category", "other").lower() for f in features}
    if len(cats) < 4:
        return 0, [f"Only {len(cats)} categories, need 4+"]
    return 1, []


def chk_signal_encoding(features):
    pat = re.compile(r"\b([A-Z][A-Z0-9_]*)\s*=\s*([\w'bxh]+)")
    sig_fmts = defaultdict(set)
    for f in features:
        for req in f.get("requirements", []):
            for step in req.get("test", {}).get("steps", []):
                txt = str(step.get("action","")) + " " + str(step.get("expected",""))
                for sig, val in pat.findall(txt):
                    if "'b" in val or val.startswith("0b"):
                        sig_fmts[sig].add("binary")
                    elif val.startswith("0x") or "'h" in val:
                        sig_fmts[sig].add("hex")
                    elif val.isdigit():
                        sig_fmts[sig].add("decimal")
    issues = []
    mixed = 0
    for sig, fmts in sorted(sig_fmts.items()):
        if len(fmts) > 1:
            mixed += 1
            issues.append(f"Signal {sig}: mixed encoding {sorted(fmts)}")
    return (1 if mixed <= 2 else 0), issues


def chk_traceability(features, cross_tests):
    req_ids = set()
    tested  = set()
    empty   = []
    for f in features:
        rid = f.get("req_id", "")
        is_cross = f.get("category", "").lower() == "cross_feature"
        if rid and not is_cross:
            req_ids.add(rid)
        for req in f.get("requirements", []):
            test = req.get("test", {})
            if test and test.get("test_id"):
                tested.add(rid)
                # Cross-feature tests have no single req_ref by design —
                # traceability is via features_involved, not req_ref.
                if not is_cross and not test.get("req_ref", ""):
                    empty.append(test.get("test_id", "?"))
    for ct in (cross_tests or []):
        # Only flag if neither req_ref nor features_involved present.
        if not ct.get("req_ref", "") and not ct.get("features_involved"):
            empty.append(ct.get("test_id", "?"))
    issues = []
    untested = req_ids - tested
    if untested:
        issues.append(f"Requirements with no test: {sorted(untested)}")
    if empty:
        issues.append(f"Tests with empty req_ref: {empty}")
    total = len(untested) + len(empty)
    return (1 if total == 0 else (1 if total <= 2 else 0)), issues


def validate_quality(features, cross_tests=None):
    """
    Run all 12 checks.
    Returns (is_valid: bool, issues: list, score: int 0-100).
    Scoring: 50% per-test + 50% global.
    """
    if not features:
        return False, ["No features extracted"], 0

    all_issues = []
    pt_score = pt_max = 0

    for f in features:
        cat = f.get("category", "other").lower()
        for req in f.get("requirements", []):
            test = req.get("test")
            if not test:
                all_issues.append(
                    f"{f.get('feature_name','?')}: requirement has no test")
                continue
            tname = test.get("test_name", test.get("test_id", "?"))
            pt_max += 12  # 6 checks x 2 pts each

            for check_fn in [
                lambda t: chk_step_count(t, cat),
                chk_signal_values,
                chk_hex_addresses,
                chk_timing,
                chk_verification,
            ]:
                s, iss = check_fn(test)
                pt_score += s
                if iss:
                    all_issues.append(f"{tname}: {iss}")

            s, iss = chk_placeholders(test, tname)
            pt_score += s
            if iss:
                all_issues.append(iss)

    # Global checks
    g_score = 0
    g_max   = 10   # 3+2+2+1+1+1

    all_feats = list(features)
    if cross_tests:
        for ct in cross_tests:
            all_feats.append({
                "req_id": ct.get("test_id", ""),
                "feature_name": ct.get("test_name", ""),
                "category": "cross_feature",
                "description": ct.get("objective", ""),
                "requirements": [{"req_text": ct.get("objective",""), "test": ct}],
            })

    for fn, _max in [
        (chk_rule_coverage,         3),
        (chk_reg_addr_consistency,  2),
        (chk_bitfield_consistency,  2),
        (chk_category_coverage,     1),
        (chk_signal_encoding,       1),
    ]:
        s, iss = fn(all_feats)
        g_score += s
        all_issues.extend(iss)

    s, iss = chk_traceability(all_feats, cross_tests)
    g_score += s
    all_issues.extend(iss)

    pt_pct = (pt_score / pt_max * 100) if pt_max else 0
    g_pct  = (g_score  / g_max  * 100) if g_max  else 0
    score  = int(pt_pct * 0.5 + g_pct * 0.5)

    is_valid = score >= QUALITY_THRESHOLD and \
               len(all_issues) < len(features) * 3

    return is_valid, all_issues, score


# =============================================================================
# STAGE 5: ASSIGN IDs
# =============================================================================

def assign_ids(data):
    """
    Assign REQ_001 to features and TEST_<CATEGORY>_001 to tests.
    Skips any test that already has a test_id (prevents duplicate
    assignment across reprompt attempts).
    Modifies data in place. Returns data.
    """
    features    = data.get("features", [])
    cross_tests = data.get("cross_feature_tests", [])

    req_counter   = 1
    test_counters = {}

    for f in features:
        req_id = f"REQ_{req_counter:03d}"
        f["req_id"] = req_id
        req_counter += 1

        cat = f.get("category", "other").upper()

        for req in f.get("requirements", []):
            test = req.get("test")
            if not test or test.get("test_id"):  # skip already assigned
                continue
            if cat not in test_counters:
                test_counters[cat] = 1
            test_id = f"TEST_{cat}_{test_counters[cat]:03d}"
            test["test_id"] = test_id
            test["req_ref"] = req_id
            test_counters[cat] += 1

    if cross_tests:
        cat = "CROSS_FEATURE"
        if cat not in test_counters:
            test_counters[cat] = 1
        for ct in cross_tests:
            if ct.get("test_id"):  # skip already assigned
                continue
            test_id = f"TEST_{cat}_{test_counters[cat]:03d}"
            ct["test_id"] = test_id
            test_counters[cat] += 1

    data["_test_counters"] = test_counters
    return data


# =============================================================================
# STAGE 6: WRITE XTP
# =============================================================================

def esc(text):
    """XML-escape a string."""
    if text is None:
        return ""
    return (str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))


def write_xtp(data, filename, output_path):
    """Write final XTP file from extracted data."""

    features    = data.get("features", [])
    cross_tests = data.get("cross_feature_tests", [])

    total_reqs  = len(features)
    total_tests = sum(len(f.get("requirements", [])) for f in features) \
                  + len(cross_tests)
    categories  = sorted({f.get("category","other") for f in features})
    if cross_tests:
        categories.append("cross_feature")

    lines = []
    a = lines.append

    a('<?xml version="1.0" encoding="UTF-8"?>')
    a("<!--")
    a(f"  VEGA Executable Test Plan")
    a(f"  Generated by: vega_xtp_gen.py")
    a(f"  Methodology:  Cognitive Verification Architecture — VEGA Framework")
    a(f"  Author:       Vikash Kumar")
    a(f"")
    a(f"  Source:       {esc(filename)}")
    a(f"  Features:     {total_reqs}")
    a(f"  Test Cases:   {total_tests}")
    a(f"  Categories:   {len(categories)}")
    a(f"  Generated:    {time.strftime('%Y-%m-%d %H:%M:%S')}")
    a("-->")
    a(f'<testplan name="{esc(filename)}_verification" version="2.0">')
    a("  <metadata>")
    a(f"    <source>{esc(filename)}</source>")
    a(f"    <generated>{time.strftime('%Y-%m-%d %H:%M:%S')}</generated>")
    a(f"    <methodology>VEGA — Cognitive Verification Architecture</methodology>")
    a(f"    <author>Vikash Kumar</author>")
    a(f"    <total_features>{total_reqs}</total_features>")
    a(f"    <total_tests>{total_tests}</total_tests>")
    a("  </metadata>")
    a("")

    # --- Features and requirements ---
    a(f'  <features count="{total_reqs}">')
    for f in features:
        signals = esc(", ".join(f.get("signals", [])))
        a(f'    <feature req_id="{f.get("req_id","")}"'
          f' name="{esc(f.get("feature_name",""))}"'
          f' category="{esc(f.get("category",""))}"'
          f' pages="{esc(f.get("pages",""))}">')
        a(f'      <description>{esc(f.get("description",""))}</description>')
        a(f'      <signals>{signals}</signals>')
        a(f'      <requirements>')
        for req in f.get("requirements", []):
            test    = req.get("test", {})
            test_id = test.get("test_id", "") if test else ""
            a(f'        <requirement'
              f' text="{esc(req.get("req_text",""))}"'
              f' page="{esc(req.get("req_page",""))}"'
              f' test_ref="{test_id}"/>')
        a(f'      </requirements>')
        a(f'    </feature>')
    a(f'  </features>')
    a("")

    # --- Test suites grouped by category ---
    tests_by_cat = defaultdict(list)
    for f in features:
        cat = f.get("category", "other")
        for req in f.get("requirements", []):
            test = req.get("test")
            if test:
                t = dict(test)
                t["_req_id"]       = f.get("req_id", "")
                t["_feature_name"] = f.get("feature_name", "")
                tests_by_cat[cat].append(t)
    if cross_tests:
        tests_by_cat["cross_feature"].extend(cross_tests)

    a('  <test_suites>')
    for cat in sorted(tests_by_cat.keys()):
        tests = tests_by_cat[cat]
        if not tests:
            continue
        a(f'    <test_suite name="{cat}_tests"'
          f' category="{cat}"'
          f' count="{len(tests)}">')
        for test in tests:
            test_id  = test.get("test_id", "")
            req_ref  = esc(test.get("req_ref", test.get("_req_id", "")))
            fi       = test.get("features_involved", [])
            fn_names = test.get("feature_names", [])

            a(f'      <test_case test_id="{test_id}"'
              f' name="{esc(test.get("test_name",""))}">')
            a(f'        <req_ref>{req_ref}</req_ref>')
            if fi:
                a(f'        <features_involved>{esc(", ".join(fi))}</features_involved>')
            if fn_names:
                a(f'        <feature_names>{esc(", ".join(fn_names))}</feature_names>')
            a(f'        <objective>{esc(test.get("objective",""))}</objective>')
            a(f'        <preconditions>')
            for pre in test.get("preconditions", []):
                a(f'          <condition>{esc(pre)}</condition>')
            a(f'        </preconditions>')
            a(f'        <steps>')
            for step in test.get("steps", []):
                a(f'          <step num="{step.get("step","")}">')
                a(f'            <action>{esc(step.get("action",""))}</action>')
                a(f'            <expected>{esc(step.get("expected",""))}</expected>')
                a(f'          </step>')
            a(f'        </steps>')
            a(f'        <pass_criteria>{esc(test.get("pass_criteria",""))}</pass_criteria>')
            a(f'      </test_case>')
        a(f'    </test_suite>')
    a('  </test_suites>')
    a('</testplan>')

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))

    return True


# =============================================================================
# MAIN PIPELINE
# =============================================================================


# =============================================================================
# MANAGEMENT SUMMARY TABLE
# =============================================================================

# Category display order and labels for management report
CATEGORY_ORDER = [
    ("bringup",       "Bring-Up"),
    ("connectivity",  "Connectivity"),
    ("reset",         "Reset"),
    ("register_access","Register Access"),
    ("main_datapath", "Main Datapath"),
    ("protocol",      "Protocol"),
    ("stress",        "Stress"),
    ("error",         "Error Handling"),
    ("cross_feature", "Cross-Feature"),
    ("other",         "Other"),
]

def _cat_sort_key(cat):
    order = [c for c, _ in CATEGORY_ORDER]
    try:
        return order.index(cat)
    except ValueError:
        return len(order)

def _cat_label(cat):
    for key, label in CATEGORY_ORDER:
        if key == cat:
            return label
    return cat.replace("_", " ").title()

def _truncate(text, max_len):
    if not text:
        return ""
    text = str(text).replace("\n", " ").strip()
    return text if len(text) <= max_len else text[:max_len - 3] + "..."

def write_summary_table(data, basename, out_dir):
    """
    Parse extracted data and write a management-ready summary table as:
      - <basename>_summary.txt   (plain text, formatted with column padding)
      - <basename>_summary.csv   (comma-separated, for Excel / Confluence)

    Columns  : Sl.No | Test ID | Test Name | Objective | Category
    Ordering : categories follow CATEGORY_ORDER (bringup → connectivity →
               reset → register_access → main_datapath → protocol → stress
               → error → cross_feature)
    """
    features    = data.get("features", [])
    cross_tests = data.get("cross_feature_tests", [])

    rows = []   # (category, test_id, test_name, objective)

    # Collect per-feature tests
    for feat in features:
        cat = feat.get("category", "other")
        for req in feat.get("requirements", []):
            test = req.get("test")
            if not test:
                continue
            rows.append((
                cat,
                test.get("test_id", "—"),
                test.get("test_name", "—"),
                test.get("objective", req.get("req_text", "—")),
            ))

    # Collect cross-feature tests
    for ct in cross_tests:
        rows.append((
            "cross_feature",
            ct.get("test_id", "—"),
            ct.get("test_name", "—"),
            ct.get("objective", "—"),
        ))

    # Sort by category order, then by test_id within each category
    rows.sort(key=lambda r: (_cat_sort_key(r[0]), r[1]))

    # ── plain-text table ──────────────────────────────────────────────────────
    COL_NO   = 6
    COL_ID   = 26
    COL_NAME = 38
    COL_OBJ  = 55

    def hr(char="-"):
        return (char * COL_NO + "+" +
                char * COL_ID + "+" +
                char * COL_NAME + "+" +
                char * COL_OBJ)

    def row_line(no, tid, name, obj):
        return (str(no).ljust(COL_NO) + "|" +
                tid .ljust(COL_ID)   + "|" +
                name.ljust(COL_NAME) + "|" +
                obj .ljust(COL_OBJ))

    txt_lines = []
    txt_lines.append("=" * (COL_NO + 1 + COL_ID + 1 + COL_NAME + 1 + COL_OBJ))
    txt_lines.append(f"  VEGA Test Plan — Management Summary")
    txt_lines.append(f"  Source: {basename}   |   "
                     f"Total tests: {len(rows)}   |   "
                     f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    txt_lines.append("=" * (COL_NO + 1 + COL_ID + 1 + COL_NAME + 1 + COL_OBJ))
    txt_lines.append(row_line("Sl.No", "Test ID", "Test Name", "Objective / Description"))
    txt_lines.append(hr("="))

    current_cat = None
    sl = 1

    for cat, tid, tname, obj in rows:
        if cat != current_cat:
            current_cat = cat
            label = _cat_label(cat)
            txt_lines.append(hr())
            txt_lines.append(f"  ▶  {label}")
            txt_lines.append(hr())

        txt_lines.append(row_line(
            str(sl),
            _truncate(tid,   COL_ID   - 1),
            _truncate(tname, COL_NAME - 1),
            _truncate(obj,   COL_OBJ  - 1),
        ))
        sl += 1

    txt_lines.append(hr("="))
    txt_lines.append(f"  Total: {len(rows)} test cases across {len(set(r[0] for r in rows))} categories")
    txt_lines.append("=" * (COL_NO + 1 + COL_ID + 1 + COL_NAME + 1 + COL_OBJ))

    txt_path = os.path.join(out_dir, f"{basename}_summary.txt")
    with open(txt_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(txt_lines))

    # ── CSV table ─────────────────────────────────────────────────────────────
    import csv, io
    buf = io.StringIO()
    writer = csv.writer(buf, quoting=csv.QUOTE_ALL)
    writer.writerow(["Sl.No", "Test ID", "Test Name",
                     "Objective / Description", "Category"])
    sl = 1
    for cat, tid, tname, obj in rows:
        writer.writerow([sl, tid, tname, obj, _cat_label(cat)])
        sl += 1

    csv_path = os.path.join(out_dir, f"{basename}_summary.csv")
    with open(csv_path, "w", encoding="utf-8", newline="") as fh:
        fh.write(buf.getvalue())

    return txt_path, csv_path, len(rows)


def main(pdf_path, output_dir=None):

    filename  = os.path.basename(pdf_path)
    basename  = os.path.splitext(filename)[0]
    out_dir   = output_dir if output_dir else os.getcwd()
    os.makedirs(out_dir, exist_ok=True)
    xtp_path  = os.path.join(out_dir, f"{basename}_testplan.xtp")

    print()
    print("=" * 65)
    print("  VEGA XTP Generator")
    print("  Cognitive Verification Architecture — VEGA Framework")
    print("  Author: Vikash Kumar")
    print("=" * 65)
    print(f"  Input : {filename}")
    print(f"  Output: {xtp_path}")
    print(f"  Model : {MODEL}")
    print(f"  Quality threshold: {QUALITY_THRESHOLD}%  Max retries: {MAX_RETRIES}")

    # --- API key ---
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        print("\n  ERROR: ANTHROPIC_API_KEY not set")
        print("  Windows: set ANTHROPIC_API_KEY=your-key")
        print("  Linux:   export ANTHROPIC_API_KEY=your-key")
        sys.exit(1)

    # --- Stage 1: Load PDF ---
    print()
    print("-" * 65)
    print("  Stage 1: Loading PDF")
    print("-" * 65)
    pdf_base64, total_pages = load_pdf(pdf_path)

    # --- Stage 2+3: Extract with reprompt loop ---
    print()
    print("-" * 65)
    print("  Stage 2: Extracting (single full-document API call)")
    print("-" * 65)

    prompt     = build_extraction_prompt(filename, total_pages)
    best_data  = None
    best_score = 0

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"\n  Attempt {attempt}/{MAX_RETRIES} — calling Claude API...",
              end="", flush=True)

        t0 = time.time()
        try:
            raw = call_claude(pdf_base64, prompt, api_key)
        except Exception as e:
            print(f"\n  API ERROR: {e}")
            if attempt < MAX_RETRIES:
                print(f"  Retrying in 5 seconds...")
                time.sleep(5)
                continue
            else:
                break
        elapsed = time.time() - t0
        print(f" done ({elapsed:.1f}s)")

        data = parse_json(raw)
        if data is None:
            print("  JSON parse failed — attempting partial salvage...")
            data = salvage_partial_json(raw)
            if data:
                n_salvaged = len(data.get("features", []))
                print(f"  Salvage recovered {n_salvaged} feature(s) from partial response")
            else:
                if attempt < MAX_RETRIES:
                    print("  Salvage failed — will retry")
                    time.sleep(3)
                else:
                    print("  Salvage failed on final attempt")
                continue

        features    = data.get("features", [])
        cross_tests = data.get("cross_feature_tests", [])
        print(f"  Parsed: {len(features)} features, "
              f"{len(cross_tests)} cross-feature tests")

        # Validate quality
        is_valid, issues, score = validate_quality(features, cross_tests)
        print(f"  Quality score: {score}%  "
              f"{'✓ PASS' if is_valid else '✗ NEEDS IMPROVEMENT'}")

        if score > best_score:
            best_score = score
            best_data  = data

        if is_valid:
            print("  Threshold met — proceeding.")
            break

        # Report issues
        print(f"  Issues ({len(issues)}):")
        for iss in issues[:8]:
            print(f"    - {iss}")

        if attempt < MAX_RETRIES:
            print(f"  Building reprompt for attempt {attempt+1}...")
            prompt = build_reprompt(
                build_extraction_prompt(filename, total_pages),
                issues, attempt + 1)
            time.sleep(3)
        else:
            print(f"\n  Max retries reached. Using best result ({best_score}%).")

    if best_data is None:
        print("\n  WARNING: No usable data after all attempts — inserting placeholder XTP.")
        print("  Engineer review required: open XTP and replace placeholder content.")
        best_data = _skeleton_data()

    # --- Stage 3: Assign IDs ---
    print()
    print("-" * 65)
    print("  Stage 3: Assigning REQ / TEST IDs")
    print("-" * 65)
    assign_ids(best_data)

    features    = best_data.get("features", [])
    cross_tests = best_data.get("cross_feature_tests", [])
    counters    = best_data.get("_test_counters", {})

    total_features = len(features)
    total_reqs     = sum(len(f.get("requirements",[])) for f in features)
    total_tests    = sum(counters.values())

    print(f"  Features     : {total_features}")
    print(f"  Requirements : {total_reqs}")
    print(f"  Tests        : {total_tests}")
    for cat, cnt in sorted(counters.items()):
        print(f"    TEST_{cat}_xxx : {cnt}")

    # --- Stage 4: Write XTP ---
    print()
    print("-" * 65)
    print("  Stage 4: Writing XTP")
    print("-" * 65)
    write_xtp(best_data, basename, xtp_path)
    print(f"  Saved: {xtp_path}")

    # --- Stage 5: Management summary table ---
    print()
    print("-" * 65)
    print("  Stage 5: Writing Management Summary Table")
    print("-" * 65)
    txt_path, csv_path, n_tests = write_summary_table(
        best_data, basename, out_dir)
    print(f"  Saved: {txt_path}")
    print(f"  Saved: {csv_path}")
    print(f"  Summary: {n_tests} test cases tabulated")

    # --- Final quality report ---
    final_valid, final_issues, final_score = validate_quality(
        features, cross_tests)

    print()
    print("=" * 65)
    print("  COMPLETE")
    print("=" * 65)
    print(f"""
  Source       : {filename}
  Output       : {xtp_path}
  Pages        : {total_pages}
  Features     : {total_features}
  Requirements : {total_reqs}
  Tests        : {total_tests}
  Quality      : {final_score}%  {'✓ PASS' if final_valid else '✗ REVIEW NEEDED'}
""")

    if final_issues:
        print(f"  Remaining issues ({len(final_issues)}):")
        for iss in final_issues[:15]:
            print(f"    - {iss}")

    print(f"""
  Next steps:
    1. Open {xtp_path} and review
    2. Fix any quality issues listed above
    3. Feed into UVM testbench generator:
         python vega_llm_tbgen.py --ipxact ch01_vega_tools/ahb2apb_bridge.xml \\
           --meta ch01_vega_tools/manifest.json \\
           --intent ch01_vega_tools/verification_intent.txt \\
           --output_dir ch03_testbench/ahb2apb_bridge_uvmtb
""")
    print("=" * 65)
    return True


# =============================================================================
# ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    import argparse
    import sys

    # Force UTF-8 stdout/stderr so any non-ASCII glyphs in progress output
    # don't crash on Windows consoles whose default code page is cp1252
    # (Python 3.13+).
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

    parser = argparse.ArgumentParser(
        prog="vega_xtp_gen.py",
        description="VEGA XTP Generator — full PDF to XTP in one Claude API call.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""
Examples:
  python vega_xtp_gen.py ch01_vega_tools/ahb2apb_spec.pdf
  python vega_xtp_gen.py ch01_vega_tools/ahb2apb_spec.pdf --output ch02_testplan/outputs

Requirements:
  pip install pymupdf anthropic
  set ANTHROPIC_API_KEY=your-key   (Windows)
  export ANTHROPIC_API_KEY=your-key (Linux/Mac)

Quality checks: 12 (6 per-test + 6 global). Threshold: 80%.
Reprompts automatically up to 3x if quality is below threshold.
""")

    parser.add_argument(
        "pdf_file",
        help="Path to the PDF specification file")

    parser.add_argument(
        "--output", "-o",
        metavar="DIR",
        default=None,
        help="Output directory for the XTP file (default: current directory)")

    args = parser.parse_args()

    success = main(args.pdf_file, output_dir=args.output)
    sys.exit(0 if success else 1)
