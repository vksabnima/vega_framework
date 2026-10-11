# Chapter 6 — Subsystem Verification Through Intent Composition

> **This folder is intentionally architecture-and-teaching, not runnable code.**
> Unlike Chapters 3, 5, 7, and 8 — which ship a generated testbench, regression
> logs, metrics, and sign-off reports — Chapter 6 extends VEGA from IP scope to
> *subsystem* scope **without introducing new tooling**. Its deliverables are a
> method and a set of reusable, protocol-agnostic structures. They are taught in
> the book and summarized here; no subsystem RTL, testbench, or case-study data
> is reproduced in the repo (doing so would mean fabricating artifacts the
> chapter does not actually ship). What *would* be built to apply the method to a
> concrete subsystem is laid out under **Future Work** below.

## The problem this chapter addresses

A component that passes every IP-level test can still break a tapeout once
integrated. The bugs that matter at subsystem scope do not live *inside*
components — they live in the **contracts between them**: ordering assumptions,
error-propagation chains, reset sequencing, and shared-resource arbitration that
no single component's test plan owns. IP-level VIPs structurally cannot see
them, because each VIP only knows its own side of the interface.

The bridge of Chapters 3–5 is the worked IP example: it passes a clean IP-level
regression, yet that says nothing about how it behaves wired next to a
peripheral, an arbiter, and firmware.

## The architecture (what the chapter teaches)

| Construct | What it is |
|---|---|
| **Integration-intent taxonomy** | A protocol-agnostic **ten-category** classification of the intent that lives *between* components (handoff, ordering, error propagation, reset/CDC, shared-resource, …). |
| **Ten integration bug patterns** | Recurring subsystem defects that IP-level VIPs cannot detect by construction. |
| **Subsystem Intent Graph (SIG)** | A graph whose **nodes are components** and whose **edges each carry a *guarantee* from one component and an *assumption* from its neighbor**. Every guarantee/assumption *misalignment* is a defect site — visible *before* integration begins. |
| **Assumption harvest** | A pass that extracts the implicit cross-component contracts from existing IP-level artifacts (the Chapter 1 `verification_intent.txt`, the Chapter 3 manifest) so they can be checked instead of assumed. |
| **Category → SVA mapping** | Each intent category maps to a concrete SystemVerilog Assertion, turning a harvested assumption into an executable check. |
| **Subsystem manifest** | An extension of the Chapter 3 manifest format that names the components, the SIG edges, and the assertions. |
| **Three subsystem-only scenario classes** | **Boundary handoff**, **failure-mode & reset propagation**, and **shared-resource contention** — none writable at IP level — plus **firmware-style stimulus** and **edge-following fault localization**. |

### Where the bridge's deferred edges land

Two edge cases deferred from the IP-level chapters are subsystem-scope work and
are referenced by Chapters 7 and 8:

- **`EDGE_001` — boundary handoff** (a wrong-edge handoff at a component
  boundary): a SIG-edge scenario, Section 6.5.
- **`EDGE_002` — longer peripheral response** (APB slave response beyond the
  IP-level modeled window): accepted at IP level as a modeling assumption and
  re-verified at subsystem scope.

## How it builds on the rest of the repo

- **Source for the harvest:** `ch01_vega_tools/verification_intent.txt` and the
  Chapter 3 manifest are the IP-level artifacts the assumption harvest reads.
- **Manifest format:** the subsystem manifest extends
  `ch03_testbench/.../` manifest conventions.
- **The bridge is one node:** the subsystem composes the Chapter 3 bridge with
  neighboring components; the SIG edges are the new verification surface.

## Case study (as reported in the chapter)

The chapter reports a quantified result for a worked subsystem: **40 defects
caught at subsystem scope** and a **3.6× per-ECO cost amplification avoided** by
shifting that detection left of integration. These figures are the book's
reported case study; the underlying subsystem and its data are not shipped in
this repo.

## Future work — turning the architecture into artifacts

A concrete, repo-resident implementation of the method on a small subsystem
(e.g., bridge + a peripheral + an arbiter) would produce, in order:

1. **`assumption_register.csv`** — output of the assumption harvest: each
   cross-component assumption, its source artifact, the owning component, and
   the guarantee it pairs with.
2. **`sig.yaml`** — the Subsystem Intent Graph: nodes, edges, and the
   guarantee/assumption pair on each edge, with misalignments flagged.
3. **`subsystem_manifest.json`** — the extended manifest binding components,
   edges, and generated assertions.
4. **`assertions/`** — one SVA per SIG edge, from the category → SVA mapping.
5. **Subsystem UVM env + scenarios** — boundary-handoff, failure/reset, and
   shared-resource-contention sequences, extending the Chapter 3 testbench, plus
   firmware-style stimulus.
6. **Edge-following fault localization** — a mapping from a failing assertion
   back to the SIG edge (and therefore the misaligned contract) that produced it.

Each item is deliberately deferred: it is a build, not a transcription, and the
chapter's contribution is the *architecture* that makes the build well-posed.

## Status

Architecture and teaching chapter. No runnable companion code by design — see
Chapter 6 in the book for the full method, the ten-category taxonomy, the ten
bug patterns, and the worked SIG.
