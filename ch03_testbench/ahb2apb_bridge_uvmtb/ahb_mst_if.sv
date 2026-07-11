// =============================================================================
// FILE: ahb_mst_if.sv
// =============================================================================
// COMPONENT  : AHB Master Interface
// DESCRIPTION: SystemVerilog interface that bundles all AHB-side signals
//              connecting the UVM testbench to the DUT's AHB slave port.
//
// DERIVED FROM:
//   - IP-XACT: All signal names, widths, and directions taken from
//     component ahb2apb_bridge, busInterface AHB_SLAVE (Tables 2-3).
//   - Manifest: HCLK period=10ns, HRESETn active-low.
//   - Spec: Section 3.1 Source-side Interface signal table.
//
// CONFIDENCE: HIGH — signal names and widths are unambiguous in IP-XACT.
//
// NOTE: No timescale here — timescale is only in tb_top.sv per [TC2].
//       No modports defined — config_db must not use modport suffix [U1].
// =============================================================================

interface ahb_mst_if(input logic HCLK, input logic HRESETn);

  // ── AHB Slave Interface Signals ──────────────────────────────────────────
  // Directions are named from the AHB MASTER's perspective (testbench drives).
  // The DUT sees these as inputs (it is the AHB slave).

  // Address bus — 32 bits, driven by AHB master (testbench) to DUT
  logic [31:0] HADDR;

  // Transfer type — 2 bits: 00=IDLE, 01=BUSY, 10=NONSEQ, 11=SEQ
  logic [1:0]  HTRANS;

  // Transfer direction — 1=write, 0=read
  logic        HWRITE;

  // Transfer size — 3 bits: 000=byte, 001=halfword, 010=word
  logic [2:0]  HSIZE;

  // Burst type — 3 bits: 000=SINGLE through 111=INCR16
  logic [2:0]  HBURST;

  // Write data — 32 bits, valid one cycle after address phase
  logic [31:0] HWDATA;

  // Slave select — asserted when bridge is the target
  logic        HSEL;

  // Bus ready input — from upstream, indicates previous slave ready
  logic        HREADY_IN;

  // ── DUT Outputs (monitored by testbench) ─────────────────────────────────

  // Read data — 32 bits, driven by DUT
  logic [31:0] HRDATA;

  // Slave ready output — 0=wait, 1=complete
  logic        HREADY_OUT;

  // Response — 0=OKAY, 1=ERROR
  logic        HRESP;

  // ── Test-driven hard reset request ───────────────────────────────────────
  // A test pulses this LOW (then HIGH) to request a mid-simulation hard reset.
  // tb_top folds it into HRESETn (HRESETn = power_on_reset & force_rst_n), so
  // driving it low re-asserts the DUT's active-low reset. Defaults HIGH (no
  // reset) so existing tests are unaffected.
  logic        force_rst_n = 1'b1;

endinterface : ahb_mst_if