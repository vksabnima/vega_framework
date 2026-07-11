# VEGA Framework — Development Change Log

Major decisions and code changes made during this session. Newest at top.

---

## 2026-06-08 — `vega_test_generator.py` (Phase 1 — coding pass)

### New file: `ch01_vega_tools/vega_test_generator.py`
- **Architecture:** Per-test `claude -p` subprocess; orchestrator is thin (parse XTP → spawn → footprint detect → tier classify → compile-gate → baseline JSON).
- **Phase 1 goal:** every xtp `<test_case>` becomes a compile-clean test+sequence file in the TB. Sim verification is Phase 2's job.
- **Backend:** Claude Code CLI (Pro/Max plan quota; **no API tokens**). Spawn signature: `claude -p <prompt> --model claude-opus-4-8 --allowedTools Read,Write,Edit,Bash --permission-mode bypassPermissions --max-turns 25 --output-format text`.
- **No-harm baseline:** stored at `<TB>/.no_harm_baseline.json`. Each compile-clean test_id appended. Future tests that break the baseline get reverted via snapshot restore.
- **Tier policy:**
  - Tier 1 = `tests/`, `sequences/`, `tb_list.f`, `ahb2apb_bridge_pkg.sv` (additive `\`include` line)
  - Tier 2 = `env/`, `agents/`, `config/`, `top/` (shared infra)
  - Tier 3 = `rtl_Design/` (DUT — hard block, paused for human)
- **Snapshot/restore:** copy-based, only source files (skips `work/`, `sim_results/`, `__pycache__`, `.vega_snapshots`).

### Bug fixes during initial bring-up

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `'compile.bat' is not recognized` | `cmd /c compile.bat` doesn't search cwd | Pass absolute path to `compile.bat` to subprocess |
| 2 | `UnicodeEncodeError: charmap can't encode '✓'` | Windows cp1252 console | `sys.stdout.reconfigure(encoding="utf-8")` at main() entry |
| 3 | `FileNotFoundError: claude` | `claude` on Windows is `claude.CMD` shim | Use `shutil.which("claude")` to get full path |
| 4 | All tests reported PASS with 0 file changes | `-p` mode default permission silently denied Write/Edit | Added `--permission-mode bypassPermissions` |
| 5 | PASS-with-no-changes was mis-classified | Orchestrator only checked compile, not "did anything happen" | Added `LLM_NO_OP` status; also check expected test+seq files exist |
| 6 | Claude `-p` exits with 0 file changes even with permissions bypassed | Verbose, "you-are-X" framed prompt interpreted as session-opening; Claude responded with "common next steps... what would you like?" using CLAUDE.md workflow tips | Rewrote prompt: imperative numbered task list, leading "ACK: …" sentinel, explicit "do not ask user, do not list options" tail |
| 7 | Even with imperative prompt, Claude asked "What's the real task?" referencing `.vega_snapshots\TEST_ID\` files it was reading | Snapshot dir lived INSIDE TB; Claude Code's auto-discovery read it and interpreted task as snapshot-restore | Moved snapshot dir to system tempdir via `tempfile.mkdtemp(prefix="vega_test_gen_snap_")` — outside TB so auto-discovery doesn't see it |
| 8 | Claude STILL asked "What did you intend?" even with snapshots out | **`claude -p "<positional-arg>"` mode treats prompt as session-opening message.** Manual test with `cat prompt | claude -p` worked first try. | Changed subprocess call from `[claude_exe, "-p", prompt, ...]` to passing prompt via `input=prompt` parameter (stdin). This was the breakthrough. |

### State recovery during pilot
- Found TB package had **96 stale `\`include` lines** pointing to `../../ch04_tests/*` — these are leftover from a pre-existing book-chapter restructure commit. ch04_tests was parked as `ch04_tests_old` earlier in this session so those paths are now broken.
- **Surgical fix:** Python edit stripped all `../../ch04_tests/*` includes plus the section headers `// 6b. ch04 XTP-derived test sequences` and `// 7b. ch04 XTP-derived tests`.
- Also removed two more broken includes: `env/ahb2apb_bridge_coverage.sv` (no coverage file in TB — Questa FSE no covergroup support anyway) and `sequences/ahb_mst_base_seq.sv` (file doesn't exist).
- Package is now down to 20 includes (was 96+), matches actual file structure, compiles clean.
- This is the TRUE starting state for the test generation work.

### First successful orchestrator run
- 2026-06-08 ~18:30
- `python vega_test_generator.py --test-id TEST_BRINGUP_INIT_001`
- Footprint: T1: modified `ahb2apb_bridge_pkg.sv`, added `tests/test_bringup_init_001_test.sv`, added `sequences/ahb_mst_test_bringup_init_001_seq.sv`
- Compile clean, baseline → 1, wall time 77s
- Class naming: `test_<test_id_lc>` and `ahb_mst_<test_id_lc>_seq` (e.g. `test_bringup_init_001`). Doesn't match historical `ahb2apb_bridge_<cat>_NNN` style — flagging for later normalization if it matters.

### Pilot complete — bringup_init category (4/4 in baseline)
- 002, 003, 004 PASS'd cleanly in 3.5 min total
- 001 was LLM_NO_OP (already existed from earlier pilot) — bug fixed (see #9 below)

### Idempotency fix (bug #9)
| 9 | Re-running a previously-coded test triggered LLM_NO_OP because Claude correctly recognized files exist | Orchestrator's hard rule "no file changes = no_op" didn't account for already-done tests | Added pre-spawn check: if `tests/<id>_test.sv` and `sequences/ahb_mst_<id>_seq.sv` both exist AND compile is clean, skip Claude entirely, mark `ALREADY_EXISTS`, add to baseline. Makes runs safely resumable. |

### Full 90-test Phase 1 run kicked off
- 2026-06-08 ~18:40
- `python vega_test_generator.py` (no filter — all 90 tests across all 8 categories)
- Expected wall time ~110 min (90 × ~75s avg) — actual pace ~7 min/test, slower than estimated
- Idempotent for the 4 bringup_init tests already in baseline (skip-if-exists)

### Bug: cross_feature gap in new staged xtp_gen pipeline
- **Symptom:** Current XTP has 0 cross_feature features / 0 cross_feature test_cases. First v3 run had 4 cross_feature tests by accident (one feature happened to get classified there); fresh re-run had 0.
- **Root cause:** I dropped the old mega-call's `4. CROSS-FEATURE TESTS — interactions between two or more features` instruction when I refactored to the staged pipeline. New Stages A.1/A.2/A.3 find features; Stage B generates per-feature tests; no stage explicitly asks "what feature interactions need dedicated tests?". The hardcoded `cross_feature_tests: []` in `assemble_data()` confirmed it.
- **Why this matters:** Cross-feature tests are where most real bugs live (reset during transfer, error during stress, register write during back-pressure, etc.).

### Two-part fix (no rework, no API)

**Part 1 — Permanent fix in `vega_xtp_gen.py`:**
- Added `build_stage_a4_prompt(filename, all_features)` — asks LLM for 3-6 cross-feature scenarios after A.1+A.2+A.3 settle.
- Wired Stage A.4 into `main()` between A.3 audit application and Stage B parallel test gen.
- Cross-feature scenarios become "features" with `category="cross_feature"`, processed by Stage B same as any other.
- Future xtp_gen runs will include cross-feature tests automatically.

**Part 2 — Patch current XTP via Claude Code CLI (no API):**
- Spawned `claude -p` with a focused prompt in `ch02_testplan/`. Tools: Read, Edit, Write, Bash.
- Prompt instructed Claude to: read current XTP, identify 4-6 cross-feature scenarios from existing features, add a new `<test_suite category="cross_feature">` with full `<test_case>` entries (signal=value steps, hex, T1/T2 timing, verification step), update `<total_tests>` metadata + header comment, validate XML.
- Cost: $0 (Pro/Max plan quota, not API tokens).
- Doesn't interrupt running Phase 1 (orchestrator parses XTP once at startup; in-memory list is unaffected by XTP file edits during the run).
- New cross_feature tests will be picked up on next `vega_test_generator.py` run via the idempotency check (90 existing tests skipped).

### Discovered design constraints
- Tests are NOT in `tb_list.f` — they're `\`include`-ed into `ahb2apb_bridge_pkg.sv`. So Claude must edit the package, not the filelist.
- Test/seq files must NOT have their own `import uvm_pkg::*` or `\`include "uvm_macros.svh"` — they're inside the package context already.
- Questa FSE — no `.randomize()`, no covergroup, no `uvm_reg`.

---

## 2026-06-08 — `vega_xtp_gen.py` rewrite (staged pipeline)

### Architecture change
- **Old:** single mega API call (PDF → 26-test xtp via Sonnet 4.6, often failed/truncated, 7+ min/attempt × 3 retries).
- **New:** staged pipeline A.1 → A.2 → A.3 → B(parallel) → C → D → E. Per-stage small outputs, PDF cached across calls, per-feature failures isolated.
- **Model:** `claude-sonnet-4-6` → `claude-opus-4-8` (latest per Anthropic docs as of 2026-06-08).

### Key code changes
- `MAX_TOKENS = 32000` → split into `MAX_TOKENS_A=8000, MAX_TOKENS_B=12000, MAX_TOKENS_D=4000` (right-size per stage).
- Added `STAGE_B_PARALLEL = 6` for thread-pool per-feature gen.
- Added `STANDARD_CATEGORIES += "miscellaneous"` as a deliberate escape hatch (separate from "ambiguous" which is LLM-uncertain).
- Added Stage A.3 prompt with explicit rule: *"Only propose features for testable DUT behavior. Do NOT propose features for verification-usage / methodology / informational / meta sections."*
- Added `cache_control: {"type": "ephemeral"}` on the PDF document block — 90% input-token discount on subsequent calls.
- Opus 4.8 deprecated `temperature` parameter; conditional pin: only pass for models that accept it.
- Added `local_xtp_lint()` — deterministic XML/cross-ref/category validation post-write.
- Added `write_review_md()` — new human-friendly markdown report with audit findings + per-stage status.
- Stripped `_spec` / `_specification` (case-insensitive) from input filename for output naming (`ahb2apb_spec.pdf` → `ahb2apb_testplan.xtp`).
- Fixed off-by-one in Stage C ID-counter reporting (counter is next-id; actual count = counter - 1 per category).
- **Removed:** the `_skeleton_data()` placeholder fallback. Per failure principle: never write a fake XTP. Either ship a real (possibly degraded) XTP or exit non-zero with no file.

### Validation results
- **First run (this session):** 19→21 features (audit added 3, removed 1, reclassified 2), 90 test cases, 84% quality, lint clean, wall time ~3.75 min.
- **Reproducibility re-run:** same 21 features, same 90 tests, same 84% quality. Content varied (different feature names, distribution); shape stable.
- **Manual cleanup:** removed bogus `verification_artifact_generation` feature (§8 of spec is informational, not testable). Stage A.3 prompt updated to prevent regeneration.

---

## 2026-06-08 — Repo cleanup

- Renamed `ch03_testbench/ahb2apb_bridge_uvmtb_golden/` → `ahb2apb_bridge_uvmtb/`. Deleted `_demo`, `_live`, and the original tracked `ahb2apb_bridge_uvmtb` (tracked content replaced by golden).
- Sanity test still passes after rename: `ALL VERIFICATION GOALS PASSED`, VG1–VG6, 0 errors.
- Parked old reference catalog `ch04_tests/` → `ch04_tests_old/` (47 hand-curated tests + sequences). New `ch04_tests/` reserved for vega_test_generator output.
- `ch02_testplan/` flattened: deleted stale `outputs/` and `prompts/`; all generated files live at the chapter root.

---

## Design decisions (recorded for the book)

### Phased generation (Phase 1: coding, Phase 2: debug)
**Insight:** the agentic loop conflates "make this code make sense" (compile-clean) with "make this test actually verify" (sim-pass). Phase them. Phase 1 cost ~2-3h for 90 tests; Phase 2 is targeted on failures only. Saves ~5h vs intertwined approach.

### No-harm growing baseline
**Insight:** every passing test becomes a guardrail. Future infra changes must preserve the baseline. Tier 1 changes (additive, can't break others) skip the check; Tier 2 triggers a baseline-compile sweep; Tier 3 pauses for human.

### Backend split — API vs CLI
- **One-shot generation** (vega_xtp_gen, vega_llm_tbgen): API. Deterministic, scriptable, fast.
- **Iterative loops** (vega_test_generator, vega_debug): CLI subprocess (`claude -p`). Uses Pro/Max plan quota — zero API token cost.

### Two-bucket category strategy
- **STANDARD_CATEGORIES** for industry-recognized features (connectivity, datapath, etc.)
- **miscellaneous** as a deliberate human-curation reserve for DUT-specific behaviors
- **ambiguous** preserved as a separate "LLM was unsure" bucket

---
