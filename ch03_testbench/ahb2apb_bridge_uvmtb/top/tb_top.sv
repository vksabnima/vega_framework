// =============================================================================
// FILE: top/tb_top.sv
// =============================================================================
// COMPONENT  : Testbench Top Module
// DESCRIPTION: Top-level testbench module that:
//   1. Declares timescale (only place per [TC2])
//   2. Generates clock (HCLK) and reset (HRESETn)
//   3. Instantiates interfaces
//   4. Instantiates DUT and binds interfaces
//   5. Sets virtual interfaces into config_db
//   6. Starts UVM test via run_test()
//
// DERIVED FROM:
//   - Manifest: HCLK period=10ns, HRESETn active-low assert=100ns.
//   - IP-XACT: All DUT port names and widths.
//   - Manifest: simulator=questa_fse, uvm_version=uvm-1.1d.
//
// CONFIDENCE: HIGH for clock/reset generation. MEDIUM for DUT port mapping
//   (marked with EDIT_REQUIRED in dut_bind.sv).
//
// NOTE: Driver must NOT generate clock or reset [U8] — done here only.
// =============================================================================

// Timescale — ONLY in tb_top.sv [TC2]
`timescale 1ns/1ps

// Include the package — the build script generates ahb2apb_bridge_pkg.sv
// and includes it in the compile order via tb_list.f
// EDIT_REQUIRED: Ensure ahb2apb_bridge_pkg.sv is compiled before this file.
// The build script should handle this via tb_list.f.

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ahb2apb_bridge_pkg::*;

  // ── Clock Generation ─────────────────────────────────────────────────────
  // Manifest: HCLK period=10ns → half-period=5ns
  logic HCLK;
  initial begin
    HCLK = 1'b0;
    forever #5ns HCLK = ~HCLK;  // 10ns period = 100MHz
  end

  // ── Reset Generation ─────────────────────────────────────────────────────
  // Manifest: HRESETn active-low, assert for 100ns
  // IP-XACT: "Active-low synchronous reset. All outputs deasserted.
  //           HREADY_OUT driven high after reset release."
  logic HRESETn;

  // ── Interface Instantiation ──────────────────────────────────────────────
  // Pass HCLK and HRESETn to both interfaces (single clock domain)
  ahb_mst_if ahb_if (.HCLK(HCLK), .HRESETn(HRESETn));
  apb_slv_if apb_if (.HCLK(HCLK), .HRESETn(HRESETn));

  // Single driver of HRESETn: power-on reset, then re-assert on any test
  // request. A test pulses ahb_if.force_rst_n LOW (then HIGH) to apply a
  // mid-simulation hard reset; HRESETn = power_on_reset & force_rst_n.
  initial begin
    HRESETn = 1'b0;       // Power-on reset assert (active-low)
    #100ns;               // Hold reset for 100ns (manifest: assert_ns=100)
    HRESETn = 1'b1;       // Deassert
    `uvm_info("TB_TOP", "Reset deasserted", UVM_MEDIUM)
    forever begin
      @(negedge ahb_if.force_rst_n);     // test requests a hard reset
      HRESETn = 1'b0;
      `uvm_info("TB_TOP", "Hard reset asserted (test request)", UVM_MEDIUM)
      @(posedge ahb_if.force_rst_n);     // test releases the request
      @(posedge HCLK);
      HRESETn = 1'b1;
      `uvm_info("TB_TOP", "Hard reset released", UVM_MEDIUM)
    end
  end

  // ── DUT Instantiation ───────────────────────────────────────────────────
  // IP-XACT port mapping — connect interfaces to DUT ports
  // EDIT_REQUIRED: Verify RTL module name matches "ahb2apb_bridge"
  // EDIT_REQUIRED: Verify all port names in RTL match IP-XACT names exactly.
  //   If RTL uses different names (e.g., haddr vs HADDR), update connections.
  ahb2apb_bridge #(
    // EDIT_RECOMMENDED: Verify parameter names match RTL
    .ADDR_WIDTH    (32),
    .DATA_WIDTH    (32),
    .APB_ADDR_START(32'h0000_0000),
    .APB_ADDR_END  (32'h0000_FFFF)
  ) dut (
    // ── Clock and Reset ──────────────────────────────────────────────────
    .HCLK       (HCLK),              // IP-XACT: in, clock
    .HRESETn    (HRESETn),           // IP-XACT: in, active-low reset

    // ── AHB Slave Interface (DUT inputs from AHB master agent) ───────────
    .HADDR      (ahb_if.HADDR),      // IP-XACT: in [31:0]
    .HTRANS     (ahb_if.HTRANS),     // IP-XACT: in [1:0]
    .HWRITE     (ahb_if.HWRITE),     // IP-XACT: in
    .HSIZE      (ahb_if.HSIZE),      // IP-XACT: in [2:0]
    .HBURST     (ahb_if.HBURST),     // IP-XACT: in [2:0]
    .HWDATA     (ahb_if.HWDATA),     // IP-XACT: in [31:0]
    .HSEL       (ahb_if.HSEL),       // IP-XACT: in
    .HREADY_IN  (ahb_if.HREADY_IN),  // IP-XACT: in

    // ── AHB Slave Interface (DUT outputs to AHB master agent) ────────────
    .HRDATA     (ahb_if.HRDATA),     // IP-XACT: out [31:0]
    .HREADY_OUT (ahb_if.HREADY_OUT), // IP-XACT: out
    .HRESP      (ahb_if.HRESP),      // IP-XACT: out

    // ── APB Master Interface (DUT outputs to APB slave agent) ────────────
    .PADDR      (apb_if.PADDR),      // IP-XACT: out [31:0]
    .PSEL       (apb_if.PSEL),       // IP-XACT: out
    .PENABLE    (apb_if.PENABLE),     // IP-XACT: out
    .PWRITE     (apb_if.PWRITE),      // IP-XACT: out
    .PWDATA     (apb_if.PWDATA),      // IP-XACT: out [31:0]

    // ── APB Master Interface (DUT inputs from APB slave agent) ───────────
    .PRDATA     (apb_if.PRDATA),      // IP-XACT: in [31:0]
    .PREADY     (apb_if.PREADY),      // IP-XACT: in
    .PSLVERR    (apb_if.PSLVERR)      // IP-XACT: in
  );

  // ── Config DB: Publish virtual interfaces ────────────────────────────────
  // Set with null scope [U2], no modport suffix [U1]
  initial begin
    uvm_config_db#(virtual ahb_mst_if)::set(null, "*", "ahb_vif", ahb_if);
    uvm_config_db#(virtual apb_slv_if)::set(null, "*", "apb_vif", apb_if);
  end

  // ── Start UVM Test ───────────────────────────────────────────────────────
  // Test name passed via +UVM_TESTNAME=<test_name> on command line
  initial begin
    run_test();
  end

  // ── Simulation Timeout ───────────────────────────────────────────────────
  // Safety net — prevent infinite simulation
  // EDIT_OPTIONAL: Increase timeout for longer tests
  initial begin
    #100_000ns;
    `uvm_fatal("TB_TOP", "Simulation timeout — exceeded 100us")
  end

endmodule : tb_top