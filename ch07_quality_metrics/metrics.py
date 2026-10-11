#!/usr/bin/env python3
"""
Chapter 7 - Quality Metrics for AI-Assisted Verification.

Ten metrics in three families that grade an AI-generated UVM testbench:

  Generation side    (did the AI build it right?):        RES, VG, SCR, HR
  Specification side (did it check the right things?):    PMC, CVL, DFS, OBS
  Process side       (can the generation be trusted?):    AUI, RGS

This module implements each formula and reproduces the two scorecards from the
chapter (the bridge on the generation side, a DMA controller on the
specification side). RES, VG, and DFS are recomputed from raw counts and
checked against the published values. PMC and CVL are recorded from the
chapter's reported results (the chapter gives per-dimension percentages and the
bin-weighted aggregate, not every raw bin count, so PMC is not recomputed).

HR, OBS, AUI, and RGS are the four metrics added in chapter v2.12. Their
formulas are implemented here, but the chapter grounds them qualitatively (HR
in the bridge's L2 hallucinated-fields cluster, OBS in the DMA F3 no-monitor
case) rather than as published ratios, and AUI/RGS need instrumented
measurement, so they are demonstrated on clearly-labelled illustrative inputs
and are NOT self-checked against a published number.

Run:  python metrics.py
"""

from math import inf


# ----------------------------------------------------------------------------
# Generation-side metrics
# ----------------------------------------------------------------------------
def res(compile_errors: int, repair_calls: int) -> float:
    """Repair Efficiency Score = errors cleared per repair call. Higher better."""
    return compile_errors / repair_calls


def vg(failures_after_compile_clean: int, total_functional_failures: int) -> float:
    """Verification Gap = share of functional failures that survive a clean
    compile. Lower better. 0 = clean-compiling and functionally complete."""
    return failures_after_compile_clean / total_functional_failures


def scr(behaviors_exercised: int, behaviors_required: int) -> float:
    """Specification Coverage Ratio = fraction of required spec behaviors the
    testbench actually drives. Higher better."""
    return behaviors_exercised / behaviors_required


def hr(hallucinated_refs: int, total_refs: int) -> float:
    """Hallucination Rate = fraction of external symbol references (signals,
    seq-item fields, methods, params, types) that resolve to nothing because
    the package/interface/spec never declared them. Lower better; 0 = every
    name resolves. The leading cause sitting upstream of RES: a high HR
    forecasts a long repair loop. Grounded in mode L2 (the bridge's
    size_type/rw_type cluster behind 18 of 37 compile errors)."""
    return hallucinated_refs / total_refs


# ----------------------------------------------------------------------------
# Specification-side metrics
# ----------------------------------------------------------------------------
def pmc(dimensions: dict) -> float:
    """Programming Model Coverage = bin-weighted Sum(observed)/Sum(defined)
    over behavioral dimensions, where `dimensions` maps name -> (observed,
    defined). Higher better.

    Note: the bin-weighted aggregate is NOT the mean of the per-dimension
    percentages, because dimensions carry different bin counts. The chapter
    reports the aggregate (44.1%) and the per-dimension percentages but not
    every raw bin count, so the DMA scorecard records the percentages rather
    than recomputing the aggregate here.
    """
    observed = sum(o for o, _ in dimensions.values())
    defined = sum(d for _, d in dimensions.values())
    return observed / defined


def cvl(t_detected: float, t_detectable: float) -> float:
    """Contract Violation Latency for one fault class = detected - detectable.
    Lower better. inf means no monitor exists for the fault class at all,
    which no timeout setting can fix."""
    return t_detected - t_detectable


def dfs(generate_hits: int, check_hits: int, boundary_hits: int, n_fields: int) -> float:
    """Descriptor Fidelity Score = (generate + check + boundary) / (3 * N).
    Report the three sub-scores separately; the aggregate hides the weak one."""
    return (generate_hits + check_hits + boundary_hits) / (3 * n_fields)


def obs(observable_obligations: int, total_obligations: int) -> float:
    """Observability Score = fraction of design obligations that have a live
    oracle (a checker, monitor, or assertion that FAILS if the obligation is
    violated). Higher better; 1.0 = every obligation can be caught. The
    precondition that makes coverage meaningful: a bin can close on an
    obligation no oracle watches. Generalizes DFS-check and CVL=inf to the whole
    testbench (DMA F3: OBS = 0 for the IRQ-clear contract)."""
    return observable_obligations / total_obligations


# ----------------------------------------------------------------------------
# Process-side metrics (how dependably did the AI deliver?)
# ----------------------------------------------------------------------------
def aui(ai_lines_retained: int, total_lines: int) -> float:
    """Autonomy Index = fraction of AI-authored content that survives unmodified
    into the signed-off testbench. Higher = more leverage, but only read against
    VG/OBS: high AUI with high VG means code shipped without review."""
    return ai_lines_retained / total_lines


def rgs(quality_values) -> float:
    """Regeneration Stability = 1 - (stdev/mean) of a quality metric (VG, SCR, or
    PMC) measured across K independent regenerations from the same spec. Higher
    = more repeatable. Bounds the confidence of every other number: a good score
    with low RGS may be luck. Rises with specification rigor, not a steadier
    model."""
    vals = list(quality_values)
    n = len(vals)
    mean = sum(vals) / n
    if mean == 0:
        return 0.0
    var = sum((v - mean) ** 2 for v in vals) / n  # population variance
    std = var ** 0.5
    return 1.0 - std / mean


# ----------------------------------------------------------------------------
# Scorecards (values from the chapter)
# ----------------------------------------------------------------------------
def bridge_scorecard():
    """Generation-side scorecard for the AHB-to-APB bridge."""
    return {
        "RES": res(compile_errors=37, repair_calls=15),     # 2.47
        "VG":  vg(failures_after_compile_clean=6,           # 0.75 (6 of 8 survive)
                  total_functional_failures=8),
        "SCR": "< 1.0 (NONSEQ/OKAY default; directed stimulus fills the rest)",
    }


def dma_scorecard():
    """Specification-side scorecard for the two-channel DMA controller.

    PMC per-dimension percentages are the chapter's reported results. The
    bin-weighted aggregate (44.1%) is dominated by the high-bin-count
    dimensions that scored low (completion status, 2 of 10 bins; IRQ, 0), so
    it sits well below the simple mean of the percentages.
    """
    pmc_per_dimension = {
        "channel_utilization":       1.00,
        "descriptor_field_combos":   0.60,
        "completion_status_codes":   0.20,   # only STAT_SUCCESS, ERR_NONE of 10 bins
        "error_response_codes":      1.00,
        "out_of_order_completion":   1.00,   # UID tracker enabled this
        "fault_injection_scenarios": 1.00,
        "irq_delivery_paths":        0.00,   # no IRQ_CLEAR handshake
    }
    cvl_faults = {
        "F1 invalid descriptor length":     cvl(595, 0),    # 595 ns, scoreboard
        "F2 channel disabled mid-transfer": cvl(1735, 0),   # 1735 ns, scoreboard
        "F3 IRQ asserted, never cleared":   inf,            # no monitor exists
    }
    return {
        "PMC_per_dimension": pmc_per_dimension,
        "PMC_published_bin_weighted": 0.441,
        "PMC_simple_mean": sum(pmc_per_dimension.values()) / len(pmc_per_dimension),
        "CVL": cvl_faults,
        "DFS": dfs(generate_hits=7, check_hits=3, boundary_hits=1, n_fields=7),  # 52.4%
        "DFS_subscores": "generate 7/7, check 3/7, boundary 1/7",
    }


def _ns(v):
    return "inf (no monitor)" if v == inf else f"{v:g} ns"


def main():
    print("=" * 66)
    print("  Chapter 7 - Quality Metrics scorecards")
    print("=" * 66)

    b = bridge_scorecard()
    print("\nBRIDGE (generation side):")
    print(f"  RES = {b['RES']:.2f}   (compile errors cleared per repair call)")
    print(f"  VG  = {b['VG']:.2f}   (functional failures surviving a clean compile)")
    print(f"  SCR = {b['SCR']}")

    d = dma_scorecard()
    print("\nDMA CONTROLLER (specification side):")
    print(f"  PMC = {d['PMC_published_bin_weighted']:.1%} (bin-weighted)   "
          f"vs simple mean {d['PMC_simple_mean']:.1%} - the gap is why bins, not")
    print(f"        dimensions, are weighted:")
    for name, pct in d["PMC_per_dimension"].items():
        print(f"          {name:<28} {pct:.0%}")
    print("  CVL per fault class:")
    for name, v in d["CVL"].items():
        print(f"          {name:<36} {_ns(v)}")
    print(f"  DFS = {d['DFS']:.1%}   ({d['DFS_subscores']})")

    # New metrics (chapter v2.12). The book grounds these qualitatively, not as
    # published ratios, so the inputs below are ILLUSTRATIVE - they show the
    # formula, not a measured book value.
    print("\nNEW METRICS (illustrative inputs - not published book values):")
    print(f"  HR  = {hr(hallucinated_refs=2, total_refs=40):.1%}   "
          f"(generation: fraction of referenced symbols that resolve to nothing)")
    print(f"  OBS = {obs(observable_obligations=9, total_obligations=10):.1%}   "
          f"(specification: obligations with a live oracle; DMA F3 was OBS=0)")
    print(f"  AUI = {aui(ai_lines_retained=820, total_lines=1000):.1%}   "
          f"(process: AI-authored content surviving unmodified to sign-off)")
    print(f"  RGS = {rgs([0.10, 0.12, 0.11, 0.13]):.2f}   "
          f"(process: 1 - stdev/mean of a quality metric over K regenerations)")

    # Self-check the recomputable values against the published numbers.
    assert round(b["RES"], 2) == 2.47, b["RES"]
    assert round(b["VG"], 2) == 0.75, b["VG"]
    assert round(d["DFS"], 3) == 0.524, d["DFS"]
    # New-metric formulas self-check on the illustrative inputs above.
    assert round(hr(2, 40), 2) == 0.05, hr(2, 40)
    assert round(obs(9, 10), 2) == 0.90, obs(9, 10)
    assert round(aui(820, 1000), 2) == 0.82, aui(820, 1000)
    assert round(rgs([10, 10, 10]), 6) == 1.0, rgs([10, 10, 10])
    print("\nself-check: RES=2.47, VG=0.75, DFS=52.4%  OK")
    print("self-check: HR/OBS/AUI/RGS formulas OK (illustrative inputs)")


if __name__ == "__main__":
    main()
