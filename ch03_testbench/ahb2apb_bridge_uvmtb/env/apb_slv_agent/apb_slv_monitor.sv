// =============================================================================
// File        : apb_slv_monitor.sv
// Description : APB Slave Monitor
//
// Passively observes APB transactions on the apb_slv_if interface.
// Captures completed transfers and writes them to an analysis port.
//
// Capture point (from IP-XACT and APB2 protocol):
//   - Transfer completes when PSEL=1 && PENABLE=1 && PREADY=1
//   - At that rising edge: capture PADDR, PWRITE, PWDATA, PRDATA, PSLVERR
//
// Derivation:
//   - IP-XACT: signal names from APB master interface
//   - Intent: "Monitor every APB transaction as it exits the bridge.
//             Capture when PREADY is asserted."
//
// Confidence: HIGH — standard APB monitor capture logic.
// =============================================================================

class apb_slv_monitor extends uvm_monitor;
  `uvm_component_utils(apb_slv_monitor)

  uvm_analysis_port #(apb_slv_seq_item) ap;
  virtual apb_slv_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "apb_slv_monitor: no virtual interface 'vif' in config_db")
  endfunction

  // =========================================================================
  // run_phase: continuously observe APB bus
  //
  // APB transfer completes at rising edge when PSEL && PENABLE && PREADY.
  // This is the "access phase completion" per APB2 spec.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    apb_slv_seq_item txn;

    forever begin
      @(vif.mon_cb);

      // Detect transfer completion: PSEL=1 && PENABLE=1 && PREADY=1
      if (vif.mon_cb.PSEL === 1'b1 &&
          vif.mon_cb.PENABLE === 1'b1 &&
          vif.mon_cb.PREADY === 1'b1) begin

        txn = apb_slv_seq_item::type_id::create("apb_txn");

        txn.PADDR   = vif.mon_cb.PADDR;
        txn.PSEL    = vif.mon_cb.PSEL;
        txn.PENABLE = vif.mon_cb.PENABLE;
        txn.PWRITE  = vif.mon_cb.PWRITE;
        txn.PWDATA  = vif.mon_cb.PWDATA;
        txn.PRDATA  = vif.mon_cb.PRDATA;
        txn.PREADY  = vif.mon_cb.PREADY;
        txn.PSLVERR = vif.mon_cb.PSLVERR;

        // NOTE: Do NOT call post_randomize() here — it would overwrite
        // captured PSLVERR with 0, breaking VG5 error propagation checks.

        `uvm_info("APB_MON", $sformatf("Observed: %s", txn.convert2string()), UVM_MEDIUM)

        ap.write(txn);
      end
    end
  endtask

endclass