// =============================================================================
// FILE: env/ahb_mst_agent/ahb_mst_monitor.sv
// =============================================================================
// COMPONENT  : AHB Master Monitor
// DESCRIPTION: Passively observes AHB transactions on the interface and
//              broadcasts captured transactions via analysis port.
//
// DERIVED FROM:
//   - IP-XACT: Monitors HADDR, HTRANS, HWRITE, HSIZE, HBURST, HWDATA (inputs)
//              and HRDATA, HREADY_OUT, HRESP (outputs) from the DUT.
//   - Intent: "Monitor every AHB transaction as it enters the bridge.
//              Capture address, direction, write data, read data, and error
//              response at the end of each AHB transfer — after the bridge
//              has indicated it is ready."
//   - Spec: Section 5.4 — address phase captured when HREADY_IN=1 && HSEL=1
//           && HTRANS=NONSEQ/SEQ. Data phase completes when HREADY_OUT=1.
//
// CAPTURE POINT: The monitor captures the address phase signals, then waits
//   for HREADY_OUT=1 to capture data-phase signals (HWDATA, HRDATA, HRESP).
//   This ensures we observe the complete transaction.
//
// CONFIDENCE: MEDIUM-HIGH — capture logic follows standard AHB monitoring.
// =============================================================================

class ahb_mst_monitor extends uvm_monitor;

  `uvm_component_utils(ahb_mst_monitor)

  // Virtual interface — no modport [U1]
  virtual ahb_mst_if vif;

  // Analysis port — broadcasts captured AHB transactions to scoreboard
  uvm_analysis_port #(ahb_mst_seq_item) ap;

  function new(string name = "ahb_mst_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "ahb_vif", vif))
      `uvm_fatal("NOVIF", "ahb_mst_monitor: Failed to get ahb_vif from config_db")
  endfunction : build_phase

  // ── Run Phase: Continuously monitor AHB transactions ─────────────────────
  task run_phase(uvm_phase phase);
    // Wait for reset deassertion before monitoring
    @(posedge vif.HRESETn);
    @(posedge vif.HCLK);

    `uvm_info("AHB_MON", "Reset released, starting AHB monitor", UVM_MEDIUM)

    forever begin
      ahb_mst_seq_item txn;
      txn = ahb_mst_seq_item::type_id::create("ahb_txn");

      // ── DETECT ADDRESS PHASE ─────────────────────────────────────────────
      // Wait for a valid address phase: HSEL=1, HREADY_IN=1,
      // HTRANS=NONSEQ(10) or SEQ(11)
      // IP-XACT: "Bridge latches on rising HCLK when HREADY_IN=1 and
      //           HSEL=1 and HTRANS=NONSEQ or SEQ"
      @(posedge vif.HCLK);
      while (!(vif.HSEL === 1'b1 &&
               vif.HREADY_IN === 1'b1 &&
               (vif.HTRANS === 2'b10 || vif.HTRANS === 2'b11))) begin
        @(posedge vif.HCLK);
      end

      // Capture address-phase signals at this clock edge
      txn.addr       = vif.HADDR;
      txn.trans_type = vif.HTRANS;
      txn.write      = vif.HWRITE;
      txn.size       = vif.HSIZE;
      txn.burst      = vif.HBURST;

      `uvm_info("AHB_MON", $sformatf("Address phase captured: addr=0x%08h %s",
                txn.addr, txn.write ? "WR" : "RD"), UVM_HIGH)

      // ── WAIT FOR DATA PHASE COMPLETION ───────────────────────────────────
      // Advance into the data phase. The bridge has accepted the address and
      // deasserts HREADY_OUT while it runs the APB SETUP/ACCESS handshake.
      @(posedge vif.HCLK);

      // Wait for transfer completion, sampling on the NEGEDGE so the AHB
      // signals are fully settled for the current cycle. This avoids the
      // posedge delta-race that otherwise captures HWDATA/HRDATA as 0 (the
      // driver drives them via NBA on the same posedge the monitor samples).
      begin
        int timeout_cnt = 0;
        forever begin
          @(negedge vif.HCLK);
          if (vif.HREADY_OUT === 1'b1) break;
          timeout_cnt++;
          // Allow beyond the largest bridge timeout window (TIMEOUT_VAL=7 =>
          // 2048 cycles) so a legitimate timeout response is not flagged here.
          if (timeout_cnt > 3000) begin
            `uvm_error("AHB_MON", "Timeout waiting for HREADY_OUT in monitor")
            break;
          end
        end
      end

      // ── CAPTURE DATA-PHASE SIGNALS ───────────────────────────────────────
      // Sampled on the settled negedge at transfer completion. The master
      // holds HWDATA from the data phase through completion, so it is valid
      // here; HRDATA/HRESP are valid this cycle (HREADY_OUT=1).
      if (txn.write) begin
        txn.wdata = vif.HWDATA;
      end
      txn.rdata = vif.HRDATA;
      txn.resp  = vif.HRESP;

      // NOTE: do NOT call txn.post_randomize() here — a monitor must report
      // exactly what it observed on the bus. This seq_item's post_randomize()
      // force-resets burst/size/trans_type to SINGLE/WORD/NONSEQ (a generator
      // bringup default), which would clobber the captured HBURST/HSIZE/HTRANS
      // and hide all burst/size functional-coverage bins. Found via coverage.
      `uvm_info("AHB_MON", {"Captured: ", txn.convert2string()}, UVM_MEDIUM)

      // Broadcast to scoreboard via analysis port
      ap.write(txn);
    end
  endtask : run_phase

endclass : ahb_mst_monitor