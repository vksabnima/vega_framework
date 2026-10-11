# Chapter 7 — Quality Metrics for AI-Assisted Verification

Companion artifacts for Chapter 7. When an AI writes the testbench, pass rate
and coverage closure only say the testbench *ran* — not whether it was asked to
check the right things. This chapter adds **ten metrics in three families** that
turn AI-assisted verification quality from a claim into a measurement.

## The three families

**Generation-side — "did the AI build it right?"**

| Metric | Question | Formula | Better |
|---|---|---|---|
| RES — Repair Efficiency Score | How much does each automated repair call clear? | compile errors ÷ repair calls | higher |
| VG — Verification Gap | What share of functional failures survive a clean compile? | failures after compile-clean ÷ total functional failures | lower |
| SCR — Specification Coverage Ratio | How much of the spec does the testbench actually drive? | spec behaviors exercised ÷ spec behaviors required | higher |
| HR — Hallucination Rate | How much of the code names symbols that don't exist? | symbol refs that resolve to nothing ÷ total external refs | lower |

**Specification-side — "did the AI check the right things?"**

| Metric | Question | Formula | Better |
|---|---|---|---|
| PMC — Programming Model Coverage | How much of the behavioral space did it reach? | Σ bins observed ÷ Σ bins defined (bin-weighted) | higher |
| CVL — Contract Violation Latency | How long from observable to flagged, per fault class? | t_detected − t_detectable | lower (∞ = no monitor) |
| DFS — Descriptor Fidelity Score | Per descriptor field: generated, checked, boundary-stressed? | (generate + check + boundary) ÷ (3 · N_fields) | higher |
| OBS — Observability Score | What share of obligations have a live oracle that can fail? | obligations with an oracle ÷ obligations needing one | higher |

**Process-side — "can the generation be trusted?"**

| Metric | Question | Formula | Better |
|---|---|---|---|
| AUI — Autonomy Index | How much AI output survived review unmodified? | AI lines kept at sign-off ÷ total final lines | higher (with low VG) |
| RGS — Regeneration Stability | Is quality repeatable across regenerations? | 1 − stdev/mean of a quality metric over K runs | higher |

> HR and OBS are grounded qualitatively in the chapter (HR in the bridge's L2
> hallucinated-fields cluster; OBS in the DMA F3 no-monitor case), and AUI/RGS
> need instrumented measurement — so `metrics.py` implements all four formulas
> but demonstrates them on clearly-labelled illustrative inputs, not published
> book values.

## The thesis

The largest return in LLM-based verification is **a more rigorous specification,
not a more capable model**. The model faithfully verifies what the spec made
explicit and just as faithfully ignores what it left implicit (the DMA's
firmware IRQ-clear handshake — generated, never checked, CVL = ∞).

## How this differs from functional coverage

Functional coverage asks *"of the bins I defined, how many did my tests hit?"* —
it can only see what was put in the coverage model. These metrics ask *"did the
testbench check the right things in the first place?"* — they grade the
**adequacy** of the verification against the specification, catching holes a
covergroup was never written for. (Closure sign-off lives in Chapter 8.)

## Scorecards (from the chapter)

**Bridge — generation side:**
- RES = 37 / 15 = **2.47**
- VG  = 6 / 8 = **0.75** (six of eight modes survive a clean compile; compile + elaboration catch one each)
- SCR < 1.0 until directed stimulus fills transfer types, response codes, reset-boundary behavior

**DMA controller — specification side:**
- PMC = **44.1%** (completion-status 20%, IRQ-delivery 0%; channel/out-of-order/fault 100%)
- CVL: F1 = 595 ns, F2 = 1735 ns, **F3 = ∞** (IRQ asserted, never cleared — no monitor)
- DFS = 11 / 21 = **52.4%** (generate 7/7, check 3/7, boundary 1/7)

## Run

```bash
python metrics.py
```

Prints both scorecards and self-checks RES, VG, and DFS against the published
values, plus the HR/OBS/AUI/RGS formulas on illustrative inputs.

> Note: per the book's locked order, Chapter 7 is Quality Metrics and Chapter 8
> is Verification Closure. The Chapter 8 (closure/sign-off) artifacts live in
> `ch08_coverage_signoff/`.
