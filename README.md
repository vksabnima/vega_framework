# VEGA Framework — Companion Repository

This repository accompanies the book:
**Cognitive Verification Architecture: A Structured Approach to Modern Hardware Verification — The VEGA Framework**
by Vikash Kumar

## How to Use This Repo

Each folder maps to a chapter in the book.
Copy the prompts, substitute your own design spec, and compare your output to the reference outputs provided.

## Prerequisites

- Access to an LLM (ChatGPT, Claude, or similar) via browser or API
- A SystemVerilog/UVM simulator (VCS, Questa, Xcelium, or equivalent)
- Basic familiarity with UVM testbench structure

## Chapter Structure
## Chapter Structure

| Folder            | Chapter   | What You Build             |
|-------------------|-----------|----------------------------|
| ch02_testplan     | Chapter 2 | XTP — Executable Test Plan |
| ch03_testbench    | Chapter 3 | UVM testbench scaffold     |
| ch04_scenarios    | Chapter 4 | Test scenarios             |
| ch05_debug        | Chapter 5 | Debug session artifacts    |
| ch06_subsystem    | Chapter 6 | Subsystem Intent Graph     |
| ch07_closure      | Chapter 7 | Sign-off argument          |


## Reference Design

All examples use the **AHB2APB protocol bridge** as the worked example.
The same workflow applies to any design.
