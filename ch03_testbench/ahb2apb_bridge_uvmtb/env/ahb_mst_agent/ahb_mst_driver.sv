// =============================================================================
// File        : ahb_mst_driver.sv
// Description : AHB Master Driver
//
// Drives AHB transactions onto the ahb_mst_if interface toward the DUT's
// AHB slave port.  Implements AHB-Lite single transfer protocol:
//
//   1. Wait for HREADY_OUT=1 (bus idle / previous transfer done)
//   2. ADDRESS PHASE: Drive HADDR, HTRANS=NONSEQ, HWRITE, HSIZE, HBURST,
//      HSEL=1, HREADY_IN=1
//   3. Wait one clock for data phase
//   4. DATA PHASE: Drive HWDATA (for writes), wait for HREADY_OUT=1
//   5. Capture HRDATA (for reads), HRESP
//   6. Return to idle (HTRANS=IDLE)
//
// Derivation:
//   - IP-XACT: all signal names from AHB slave interface ports
//   - Intent: simple single transfers, no bursts
//   - Protocol: AHB-Lite pipelined address/data phases
//
// Confidence: MEDIUM — AHB pipelining is well-known but the exact bridge
//   handshake (HREADY_IN vs HREADY_OUT) must match DUT behavior.
//
// EDIT_RECOMMENDED: The HREADY_IN driving strategy assumes the TB is the
//   only master.  If a multi-master scenario is used, HREADY_IN must be
//   driven by an interconnect model.
// =============================================================================

class ahb_mst_driver extends uvm_driver #(ahb_mst_seq_item);
  `uvm_component_utils(ahb_mst_driver)

  // Virtual interface handle — no modport suffix per [U1]
  virtual ahb_mst_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // =========================================================================
  // build_phase: retrieve virtual interface from config_db
  // =========================================================================
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "ahb_mst_driver: no virtual interface 'vif' in config_db")
  endfunction

  // =========================================================================
  // run_phase: main driving loop
  //
  // Protocol timing:
  //   Cycle N  : Address phase — drive HADDR, HTRANS, HWRITE, etc.
  //   Cycle N+1: Data phase    — drive HWDATA, wait for HREADY_OUT=1
  //   When HREADY_OUT=1 in data phase, transfer is complete.
  //
  // Between transactions: drive HTRANS=IDLE, HSEL=0 for one idle cycle.
  // This matches the intent requirement of no back-to-back transfers.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_seq_item req;

    // Initialize all outputs to idle/safe values at time 0
    drive_idle();
    @(vif.drv_cb);  // Sync to first clock edge

    forever begin
      // Get next transaction from sequencer
      seq_item_port.get_next_item(req);

      `uvm_info("AHB_DRV", $sformatf("Driving: %s", req.convert2string()), UVM_MEDIUM)

      // ---- Wait for bus to be ready (HREADY_OUT=1) before address phase ----
      @(vif.drv_cb);
      while (vif.drv_cb.HREADY_OUT !== 1'b1) begin
        @(vif.drv_cb);
      end

      // ---- ADDRESS PHASE ----
      // Drive address and control signals at this clock edge.
      // Assignments schedule for this edge + output skew (1ns).
      vif.drv_cb.HADDR     <= req.HADDR;
      vif.drv_cb.HTRANS    <= req.HTRANS;  // NONSEQ (2'b10) for single
      vif.drv_cb.HWRITE    <= req.HWRITE;
      vif.drv_cb.HSIZE     <= req.HSIZE;
      vif.drv_cb.HBURST    <= req.HBURST;
      vif.drv_cb.HSEL      <= req.HSEL;
      vif.drv_cb.HREADY_IN <= 1'b1;

      @(vif.drv_cb); // Address visible on bus; bridge samples at this edge

      // ---- DATA PHASE ----
      // Drive HWDATA at this edge (one cycle after address phase).
      // Move HTRANS to IDLE to indicate no pipelined next transfer.
      // These schedule for this edge + output skew — a different clock
      // than the address, so no collision.
      vif.drv_cb.HWDATA    <= req.HWRITE ? req.HWDATA : 32'h0;
      vif.drv_cb.HTRANS    <= 2'b00;  // IDLE — no back-to-back
      vif.drv_cb.HSEL      <= 1'b0;   // Deselect for idle

      // Wait one clock for bridge to transition out of IDLE (deassert
      // HREADY_OUT).  Without this, we sample HREADY_OUT while the bridge
      // is still in IDLE state and falsely "complete" the transaction.
      @(vif.drv_cb);

      // Now wait for bridge to finish APB transfer: HREADY_OUT=1
      while (vif.drv_cb.HREADY_OUT !== 1'b1) begin
        @(vif.drv_cb);
      end

      // ---- Capture response ----
      // At this point HREADY_OUT=1, so HRDATA and HRESP are valid.
      req.HRDATA     = vif.drv_cb.HRDATA;
      req.HRESP      = vif.drv_cb.HRESP;
      req.HREADY_OUT = vif.drv_cb.HREADY_OUT;

      `uvm_info("AHB_DRV", $sformatf("Completed: %s", req.convert2string()), UVM_MEDIUM)

      // Return item to sequencer (marks transaction as done)
      seq_item_port.item_done();

      // ---- Idle gap ----
      // Drive one idle cycle between transactions per intent (no back-to-back).
      drive_idle();
      @(vif.drv_cb);
    end
  endtask

  // =========================================================================
  // drive_idle — put AHB bus in IDLE state
  //
  // HTRANS=IDLE, HSEL=0, HREADY_IN=1 (bus is free).
  // All other signals driven to 0 for cleanliness.
  // =========================================================================
  virtual task drive_idle();
    vif.drv_cb.HADDR     <= 32'h0;
    vif.drv_cb.HTRANS    <= 2'b00;  // IDLE
    vif.drv_cb.HWRITE    <= 1'b0;
    vif.drv_cb.HSIZE     <= 3'b000;
    vif.drv_cb.HBURST    <= 3'b000;
    vif.drv_cb.HWDATA    <= 32'h0;
    vif.drv_cb.HSEL      <= 1'b0;
    vif.drv_cb.HREADY_IN <= 1'b1;   // Bus is always ready in idle
  endtask

endclass