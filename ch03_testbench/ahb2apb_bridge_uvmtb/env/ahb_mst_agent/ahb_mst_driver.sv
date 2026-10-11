// =============================================================================
// FILE: env/ahb_mst_agent/ahb_mst_driver.sv
// =============================================================================
// COMPONENT  : AHB Master Driver
// DESCRIPTION: Drives AHB transactions on the AHB slave interface of the DUT.
//              Implements the AHB address-phase / data-phase protocol.
//
// DERIVED FROM:
//   - IP-XACT: Signal names HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA,
//              HSEL, HREADY_IN. Directions: all inputs to DUT.
//   - Spec: Section 5.1 (FLOW-1 through FLOW-5), Section 5.4 timing diagram.
//     "Bridge latches on rising HCLK when HREADY_IN=1 and HSEL=1 and
//      HTRANS=NONSEQ or SEQ."
//   - Intent: Drive mix of reads/writes with random addresses in APB range.
//
// PROTOCOL TIMING (from spec Section 5.4):
//   T1: Drive address phase (HADDR, HTRANS=NONSEQ, HWRITE, HSIZE, HBURST,
//       HSEL=1, HREADY_IN=1)
//   T2: Drive data phase (HWDATA for writes), keep HREADY_IN=1
//   T3-T5: Wait for HREADY_OUT=1 from DUT to complete transfer
//
// CONFIDENCE: MEDIUM — AHB protocol timing is well-understood but the exact
//   pipeline behavior depends on DUT implementation. Key assumption: the DUT
//   samples address phase when HREADY_IN=1 && HSEL=1 && HTRANS!=IDLE.
//
// EDIT_RECOMMENDED: Verify the address-phase to data-phase pipeline timing
//   matches your specific DUT. The spec shows a non-pipelined approach where
//   we wait for HREADY_OUT=1 before driving the next address phase.
// =============================================================================

class ahb_mst_driver extends uvm_driver #(ahb_mst_seq_item);

  `uvm_component_utils(ahb_mst_driver)

  // Virtual interface handle — set via config_db, no modport [U1]
  virtual ahb_mst_if vif;

  function new(string name = "ahb_mst_driver", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // ── Build Phase: Get virtual interface from config_db ────────────────────
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", vif))
      `uvm_fatal("NOVIF", "ahb_mst_driver: Failed to get ahb_vif from config_db")
  endfunction : build_phase

  // ── Run Phase: Main driving loop ─────────────────────────────────────────
  task run_phase(uvm_phase phase);
    // Initialize all driven signals to idle/safe values at time 0
    // Driver must NOT generate clock or reset [U8]
    drive_idle();

    // Wait for reset to deassert before driving any transactions
    @(posedge vif.HRESETn);
    // Wait one more clock to ensure DUT has settled after reset
    @(posedge vif.HCLK);

    `uvm_info("AHB_DRV", "Reset released, starting AHB master driver", UVM_MEDIUM)

    // Main loop: get items from sequencer and drive them
    forever begin
      ahb_mst_seq_item req;

      // Get next transaction from sequencer
      seq_item_port.get_next_item(req);

      `uvm_info("AHB_DRV", {"Driving: ", req.convert2string()}, UVM_HIGH)

      // Drive the AHB transaction
      drive_transfer(req);

      // Signal sequencer that item is complete
      seq_item_port.item_done();
    end
  endtask : run_phase

  // ── Drive Idle: Set all AHB signals to idle state ────────────────────────
  // Called at initialization and between transactions.
  task drive_idle();
    vif.HADDR     <= 32'h0;
    vif.HTRANS    <= 2'b00;  // IDLE — DUT ignores IDLE transfers
    vif.HWRITE    <= 1'b0;
    vif.HSIZE     <= 3'b010; // Word
    vif.HBURST    <= 3'b000; // SINGLE
    vif.HWDATA    <= 32'h0;
    vif.HSEL      <= 1'b0;   // Deselect bridge
    vif.HREADY_IN <= 1'b1;   // Ready — no other slaves on bus
  endtask : drive_idle

  // ── Drive Transfer: Execute one AHB single transfer ──────────────────────
  // Protocol from spec Section 5.4:
  //   Address Phase: HSEL=1, HTRANS=NONSEQ, HADDR=addr, HWRITE, HREADY_IN=1
  //   Data Phase: HWDATA=wdata (for writes), wait for HREADY_OUT=1
  task drive_transfer(ahb_mst_seq_item req);

    // ── ADDRESS PHASE ──────────────────────────────────────────────────────
    // Wait for HREADY_OUT=1 to ensure bus is free (DUT not busy)
    // IP-XACT: "Bridge samples address phase only when HREADY_IN=1"
    while (vif.HREADY_OUT !== 1'b1) begin
      @(posedge vif.HCLK);
    end

    // Drive address phase signals on the rising edge
    @(posedge vif.HCLK);
    vif.HADDR     <= req.addr;
    vif.HTRANS    <= req.trans_type;  // NONSEQ for single transfers
    vif.HWRITE    <= req.write;
    vif.HSIZE     <= req.size;
    vif.HBURST    <= req.burst;
    vif.HSEL      <= 1'b1;           // Select this bridge
    vif.HREADY_IN <= 1'b1;           // Bus ready
    // Present write data WITH the address and hold it stable. This bridge
    // captures HWDATA into PWDATA at its IDLE->SETUP transition, so the data
    // must already be valid in the address-phase cycle — driving it one cycle
    // later (strict AHB data phase) makes the bridge latch 0.
    vif.HWDATA    <= req.write ? req.wdata : 32'h0;

    // ── DATA PHASE ─────────────────────────────────────────────────────────
    // Keep HWDATA stable (the bridge may re-sample it entering ACCESS).
    @(posedge vif.HCLK);
    if (req.write) begin
      vif.HWDATA <= req.wdata;
    end else begin
      vif.HWDATA <= 32'h0;           // Don't care for reads, drive 0
    end
    // Deassert address phase — go to IDLE so no back-to-back pipeline
    // Intent says "no back-to-back transfers without idle cycles"
    vif.HTRANS <= 2'b00;  // IDLE
    vif.HSEL   <= 1'b0;   // Deselect

    // ── WAIT FOR COMPLETION + CAPTURE RESPONSE ─────────────────────────────
    // Mirror the AHB monitor's timing EXACTLY (env/ahb_mst_agent/
    // ahb_mst_monitor.sv): advance one clock so the bridge FSM has reacted to
    // the request it latched (-> ST_APB_SETUP, ST_REG_READ, or ST_ERROR), then
    // sample on the NEGEDGE where HREADY_OUT=1 and the combinational AHB
    // outputs (HRDATA/HRESP) are fully settled.
    //
    // Why negedge, and why not "wait for the bridge to go busy" first: a
    // single-cycle internal register access (ST_REG_READ) keeps HREADY_OUT
    // HIGH the whole time — it NEVER goes busy — so any "wait for HREADY_OUT
    // low" handshake hangs on register reads. The monitor solved this by
    // advancing exactly one cycle (past the 1-cycle request latch) and then
    // negedge-sampling; we do the same so req.rdata/req.resp are correct for
    // EVERY transfer type (APB data, internal register, decode error).
    @(posedge vif.HCLK);   // into the data/processing phase (FSM has reacted)
    begin
      int wait_count = 0;
      forever begin
        @(negedge vif.HCLK);
        if (vif.HREADY_OUT === 1'b1) break;   // completion cycle reached
        wait_count++;
        // A legitimate bridge timeout can hold HREADY_OUT low for up to the
        // largest timeout window (TIMEOUT_VAL=7 => 2048 cycles) before the
        // bridge aborts to its error response, so allow well beyond that.
        if (wait_count > 3000) begin
          `uvm_error("AHB_DRV", "Timeout waiting for HREADY_OUT — DUT may be stuck")
          break;
        end
      end
    end

    // HREADY_OUT=1 on a settled negedge: HRDATA/HRESP are valid this cycle.
    // Capture them back into the seq_item so the sequence can self-check the
    // result (register read-back values, error responses, etc.).
    req.rdata = vif.HRDATA;
    req.resp  = vif.HRESP;

    // Hold the bus (HWDATA in particular) stable across ONE more rising edge
    // before returning to idle. A single-cycle internal register WRITE
    // (ST_REG_READ) latches HWDATA into the target register on the rising edge
    // AFTER HREADY_OUT goes high — if we drop HWDATA to 0 at the completion
    // negedge (drive_idle) the register would capture 0 instead of the data.
    // For multi-cycle APB writes the bridge already captured PWDATA earlier, so
    // this extra held cycle is harmless.
    @(posedge vif.HCLK);

    // Return to idle for one clock cycle between transactions
    // Intent: "no back-to-back transfers without idle cycles"
    drive_idle();
    @(posedge vif.HCLK);

  endtask : drive_transfer

endclass : ahb_mst_driver