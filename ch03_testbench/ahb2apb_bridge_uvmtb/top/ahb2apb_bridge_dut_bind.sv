// =============================================================================
// File        : ahb2apb_bridge_dut_bind.sv
// Description : DUT Bind File (placeholder for assertions/coverage)
//
// This file uses SystemVerilog `bind` to attach assertion modules or
// coverage interfaces to the DUT without modifying RTL.
//
// For bringup: this file is a placeholder.  Assertions and coverage are
// explicitly OUT OF SCOPE per the verification intent.
//
// Derivation:
//   - Intent: "Out of scope: assertions, coverage collection"
//   - IP-XACT: DUT port list for reference
//
// EDIT_REQUIRED: When adding assertions, verify all port names match the
//   RTL module declaration exactly.  IP-XACT names used as reference below.
//
// Confidence: N/A — placeholder only.
// =============================================================================

// =============================================================================
// Example bind (commented out — activate when adding protocol assertions):
//
// bind ahb2apb_bridge ahb_protocol_checker #(
//   .ADDR_WIDTH(32),
//   .DATA_WIDTH(32)
// ) u_ahb_checker (
//   .HCLK       (HCLK),          // EDIT_REQUIRED: verify RTL port name
//   .HRESETn    (HRESETn),       // EDIT_REQUIRED: verify RTL port name
//   .HADDR      (HADDR),         // EDIT_REQUIRED: verify RTL port name
//   .HTRANS     (HTRANS),        // EDIT_REQUIRED: verify RTL port name
//   .HWRITE     (HWRITE),        // EDIT_REQUIRED: verify RTL port name
//   .HSIZE      (HSIZE),         // EDIT_REQUIRED: verify RTL port name
//   .HBURST     (HBURST),        // EDIT_REQUIRED: verify RTL port name
//   .HWDATA     (HWDATA),        // EDIT_REQUIRED: verify RTL port name
//   .HSEL       (HSEL),          // EDIT_REQUIRED: verify RTL port name
//   .HREADY_IN  (HREADY_IN),     // EDIT_REQUIRED: verify RTL port name
//   .HRDATA     (HRDATA),        // EDIT_REQUIRED: verify RTL port name
//   .HREADY_OUT (HREADY_OUT),    // EDIT_REQUIRED: verify RTL port name
//   .HRESP      (HRESP),         // EDIT_REQUIRED: verify RTL port name
//   .PADDR      (PADDR),         // EDIT_REQUIRED: verify RTL port name
//   .PSEL       (PSEL),          // EDIT_REQUIRED: verify RTL port name
//   .PENABLE    (PENABLE),       // EDIT_REQUIRED: verify RTL port name
//   .PWRITE     (PWRITE),        // EDIT_REQUIRED: verify RTL port name
//   .PWDATA     (PWDATA),        // EDIT_REQUIRED: verify RTL port name
//   .PRDATA     (PRDATA),        // EDIT_REQUIRED: verify RTL port name
//   .PREADY     (PREADY),        // EDIT_REQUIRED: verify RTL port name
//   .PSLVERR    (PSLVERR)        // EDIT_REQUIRED: verify RTL port name
// );
// =============================================================================

// Placeholder module — keeps the file compilable
// This module is empty; bind statements above are commented out.
// Uncomment and populate when protocol assertions are in scope.