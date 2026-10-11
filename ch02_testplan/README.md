# Chapter 2 — Design-Intent Understanding and TestPlan Synthesis

## What This Chapter Builds

An Executable Test Plan (XTP) derived directly from the design specification.

## Folder Contents

| File | Contents |
|------|----------|
| `ahb2apb_testplan.xtp` | Reference XTP for the Educational Bridge Model (AHB-to-APB bridge) — 21 features, 96 test cases |
| `ahb2apb_summary.csv` | Feature/test summary table |
| `ahb2apb_summary.txt` | Human-readable summary |
| `ahb2apb_review.md` | Per-feature quality review written by the generator |

## Steps to Follow

1. Save the specification from the book's Appendix A as
   `ch01_vega_tools/ahb2apb_spec.pdf` (see the main README,
   "Getting the specification").
2. Generate the XTP (book §2.8):

   ```
   python ch01_vega_tools/vega_xtp_gen.py ch01_vega_tools/ahb2apb_spec.pdf --output ch02_testplan/outputs
   ```

3. Compare `ch02_testplan/outputs/ahb2apb_testplan.xtp` with the reference
   `ahb2apb_testplan.xtp` in this folder.

For the four-step flow with review gates (book §2.2–§2.6), see the main
README, "Chapter 2 — Test Plan Synthesis".

## Key Output

`ahb2apb_testplan.xtp` — the complete Executable Test Plan for the
Educational Bridge Model, ready for Chapter 3.
