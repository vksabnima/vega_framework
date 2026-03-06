# Chapter 2 — Design-Intent Understanding and TestPlan Synthesis

## What This Chapter Builds

An Executable Test Plan (XTP) derived directly from the design specification.

## Folder Contents

| Folder  | Contents |
|---------|----------|
| spec/   | Input specification — AHB2APB bridge spec PDF |
| prompts/ | The three VEGA prompts used in this chapter |
| outputs/ | Reference XTP YAML generated from the prompts |

## Steps to Follow

1. Place your design spec in the spec/ folder
2. Open prompts/step1_feature_extraction.txt
3. Paste the prompt into your LLM with your spec
4. Save the output, then move to step2
5. Repeat for step3
6. Compare your final XTP to outputs/ahb2apb_xtp.yaml

## Key Output

`outputs/ahb2apb_xtp.yaml` — the complete Executable Test Plan
for the AHB2APB bridge, ready for Chapter 3.
