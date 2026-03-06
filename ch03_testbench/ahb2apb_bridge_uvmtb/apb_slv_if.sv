// =============================================================================
// File        : apb_slv_if.sv
// Description : APB Slave Interface
//
// This interface bundles all APB signals on the bridge's master port.  From
// the TB's perspective the APB agent is a *slave* (reactive) — it observes
// PADDR/PSEL/PENABLE/PWRITE/PWDATA driven by the DUT and responds with
// PRDATA/PREADY/PSLVERR.
//
// Derivation:
//   - IP-XACT: PADDR[31:0], PSEL, PENABLE, PWRITE, PWDATA[31:0] are DUT
//              outputs; PRDATA[31:0], PREADY, PSLVERR are DUT inputs.
//   - Manifest: apb_slv interface, role=passive (reactive slave).
//   - Intent: simple memory slave, PREADY after one cycle, no errors.
//
// Confidence: HIGH — standard APB2 signal set.
// =============================================================================

interface apb_slv_if (input logic HCLK, input logic HRESETn);

  // ----- APB signals driven by DUT (bridge master outputs) -----
  logic [31:0] PADDR;
  logic        PSEL;
  logic        PENABLE;
  logic        PWRITE;
  logic [31:0] PWDATA;

  // ----- APB signals driven by TB slave (toward DUT inputs) -----
  logic [31:0] PRDATA;
  logic        PREADY;
  logic        PSLVERR;

  // =========================================================================
  // Clocking blocks
  //
  // Driver (slave): samples DUT outputs (PADDR etc.), drives PRDATA/PREADY/
  //   PSLVERR back to DUT.
  // Monitor: samples everything at the rising edge.
  //
  // EDIT_OPTIONAL: Adjust skews for waveform clarity.
  // =========================================================================
  clocking drv_cb @(posedge HCLK);
    default input #1step output #1;
    input  PADDR, PSEL, PENABLE, PWRITE, PWDATA;
    output PRDATA, PREADY, PSLVERR;
  endclocking

  clocking mon_cb @(posedge HCLK);
    default input #1step output #1step;
    input PADDR, PSEL, PENABLE, PWRITE, PWDATA;
    input PRDATA, PREADY, PSLVERR;
  endclocking

endinterface