// =============================================================================
// File        : ahb_mst_monitor.sv
// Description : AHB Master Monitor
//
// Passively observes AHB transactions on the ahb_mst_if interface.
// Captures complete transfers (address phase + data phase) and writes
// them to an analysis port for the scoreboard.
//
// Capture point:
//   1. Detect address phase: HSEL=1 && HTRANS=NONSEQ/SEQ && HREADY_IN=1
//      (bridge latches address when all three are true per IP-XACT).
//   2. Latch HADDR, HWRITE, HSIZE, HBURST from address phase.
//   3. Wait for data phase completion: HREADY_OUT=1.
//   4. Capture HWDATA (writes) or HRDATA (reads), HRESP.
//   5. Broadcast completed transaction.
//
// Derivation:
//   - IP-XACT: signal names, capture conditions from port descriptions
//   - Intent:  "Monitor every AHB transaction as it enters the bridge"
//   - Protocol: AHB pipelined — address valid when HREADY=1
//
// Confidence: HIGH — standard AHB monitoring technique.
// =============================================================================

class ahb_mst_monitor extends uvm_monitor;
  `uvm_component_utils(ahb_mst_monitor)

  // Analysis port — scoreboard subscribes to this
  uvm_analysis_port #(ahb_mst_seq_item) ap;

  // Virtual interface — no modport per [U1]
  virtual ahb_mst_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual ahb_mst_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "ahb_mst_monitor: no virtual interface 'vif' in config_db")
  endfunction

  // =========================================================================
  // run_phase: continuously observe AHB bus
  //
  // Uses monitor clocking block (mon_cb) to sample signals cleanly.
  // The monitor is purely passive — never drives any signal.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    ahb_mst_seq_item txn;

    forever begin
      @(vif.mon_cb);

      // ----- Detect address phase -----
      // Per IP-XACT: bridge latches on rising HCLK when
      // HREADY_IN=1 && HSEL=1 && HTRANS=NONSEQ or SEQ
      if (vif.mon_cb.HSEL === 1'b1 &&
          vif.mon_cb.HREADY_IN === 1'b1 &&
          (vif.mon_cb.HTRANS == 2'b10 || vif.mon_cb.HTRANS == 2'b11)) begin

        txn = ahb_mst_seq_item::type_id::create("ahb_txn");

        // Latch address-phase signals
        txn.HADDR  = vif.mon_cb.HADDR;
        txn.HTRANS = vif.mon_cb.HTRANS;
        txn.HWRITE = vif.mon_cb.HWRITE;
        txn.HSIZE  = vif.mon_cb.HSIZE;
        txn.HBURST = vif.mon_cb.HBURST;
        txn.HSEL   = vif.mon_cb.HSEL;

        // ----- Wait for data phase completion -----
        // Move to next clock edge (data phase begins)
        @(vif.mon_cb);

        // Wait until HREADY_OUT=1 (transfer complete)
        while (vif.mon_cb.HREADY_OUT !== 1'b1) begin
          @(vif.mon_cb);
        end

        // Capture data-phase signals
        txn.HWDATA     = vif.mon_cb.HWDATA;    // Valid for writes
        txn.HRDATA     = vif.mon_cb.HRDATA;    // Valid for reads
        txn.HRESP      = vif.mon_cb.HRESP;
        txn.HREADY_OUT = vif.mon_cb.HREADY_OUT;

        // Per [U4]: call post_randomize() after capturing all signals
        txn.post_randomize();

        `uvm_info("AHB_MON", $sformatf("Observed: %s", txn.convert2string()), UVM_MEDIUM)

        // Broadcast to scoreboard
        ap.write(txn);
      end
    end
  endtask

endclass