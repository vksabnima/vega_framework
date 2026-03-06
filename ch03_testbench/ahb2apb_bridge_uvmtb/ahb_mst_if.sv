// =============================================================================
// File        : ahb_mst_if.sv
// Description : AHB Master Interface
//
// This interface bundles all AHB signals that the bridge's slave port connects
// to.  Signal names, directions (from the master/TB perspective), and widths
// are taken verbatim from the IP-XACT component description.
//
// Derivation:
//   - IP-XACT: signal names HADDR[31:0], HTRANS[1:0], HWRITE, HSIZE[2:0],
//              HBURST[2:0], HWDATA[31:0], HSEL, HREADY_IN (all driven by TB
//              toward DUT input pins), and HRDATA[31:0], HREADY_OUT, HRESP
//              (DUT outputs sampled by TB).
//   - Manifest: HCLK period=10ns, HRESETn active-low asserted 100ns.
//   - Spec/Intent: single-clock domain, AHB-Lite pipelined address/data.
//
// Confidence: HIGH — standard AHB-Lite signal set.
//
// EDIT_RECOMMENDED: If your DUT uses a multiplexed HREADY (no HREADY_IN vs
//   HREADY_OUT split), adjust accordingly.  The IP-XACT shows both signals.
// =============================================================================

interface ahb_mst_if (input logic HCLK, input logic HRESETn);

  // ----- AHB signals driven by the master (TB drives toward DUT inputs) -----
  logic [31:0] HADDR;      // AHB address bus
  logic [ 1:0] HTRANS;     // Transfer type: IDLE/BUSY/NONSEQ/SEQ
  logic        HWRITE;     // 1=write, 0=read
  logic [ 2:0] HSIZE;      // Transfer size
  logic [ 2:0] HBURST;     // Burst type
  logic [31:0] HWDATA;     // Write data (data phase)
  logic        HSEL;       // Slave select
  logic        HREADY_IN;  // Ready from mux (driven by TB as bus ready)

  // ----- AHB signals driven by DUT (sampled by TB) -----
  logic [31:0] HRDATA;     // Read data
  logic        HREADY_OUT; // Slave ready output
  logic        HRESP;      // 0=OKAY, 1=ERROR

  // =========================================================================
  // Clocking blocks — define when the driver drives and monitor samples.
  //
  // Driver:  drives inputs one tick after the rising edge (output skew)
  //          so that DUT sees stable values at the next rising edge.
  // Monitor: samples outputs at the rising edge (no skew) to capture
  //          DUT-stable values.
  //
  // EDIT_OPTIONAL: Adjust skews if setup/hold violations occur in simulation.
  // =========================================================================
  clocking drv_cb @(posedge HCLK);
    default input #1step output #1;
    output HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA, HSEL, HREADY_IN;
    input  HRDATA, HREADY_OUT, HRESP;
  endclocking

  clocking mon_cb @(posedge HCLK);
    default input #1step output #1step;
    input HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA, HSEL, HREADY_IN;
    input HRDATA, HREADY_OUT, HRESP;
  endclocking

endinterface