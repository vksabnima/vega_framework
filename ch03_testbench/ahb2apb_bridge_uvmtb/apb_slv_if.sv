// =============================================================================
// FILE: apb_slv_if.sv
// =============================================================================
// COMPONENT  : APB Slave Interface
// DESCRIPTION: SystemVerilog interface that bundles all APB-side signals
//              connecting the UVM testbench to the DUT's APB master port.
//
// DERIVED FROM:
//   - IP-XACT: All signal names, widths, and directions taken from
//     component ahb2apb_bridge, busInterface APB_MASTER (Table 3-4).
//   - Spec: Section 3.2 Peripheral-side Interface signal table.
//   - Manifest: Single clock domain — PCLK tied to HCLK in DUT.
//
// CONFIDENCE: HIGH — signal names and widths are unambiguous in IP-XACT.
//
// NOTE: The DUT is the APB master. It drives PADDR, PSEL, PENABLE, PWRITE,
//       PWDATA. The testbench APB slave agent drives PRDATA, PREADY, PSLVERR.
//       No timescale here [TC2]. No modports [U1].
// =============================================================================

interface apb_slv_if(input logic HCLK, input logic HRESETn);

  // ── DUT Outputs (APB Master drives these) ────────────────────────────────

  // APB address — 32 bits, driven by DUT
  logic [31:0] PADDR;

  // APB slave select — driven by DUT
  logic        PSEL;

  // APB enable — driven by DUT, asserted in ACCESS phase
  logic        PENABLE;

  // APB direction — driven by DUT, 1=write, 0=read
  logic        PWRITE;

  // APB write data — 32 bits, driven by DUT
  logic [31:0] PWDATA;

  // ── Testbench Drives (APB Slave responses) ───────────────────────────────

  // APB read data — 32 bits, driven by testbench APB slave agent
  logic [31:0] PRDATA;

  // APB ready — driven by testbench APB slave agent
  logic        PREADY;

  // APB slave error — driven by testbench APB slave agent
  logic        PSLVERR;

endinterface : apb_slv_if