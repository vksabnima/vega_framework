// =============================================================================
// FILE: env/apb_slv_agent/apb_slv_monitor.sv
// =============================================================================
// COMPONENT  : APB Slave Monitor
// DESCRIPTION: Passively observes APB transactions on the APB interface and
//              broadcasts captured transactions via analysis port.
//
// DERIVED FROM:
//   - IP-XACT: Monitors PADDR, PSEL, PENABLE, PWRITE, PWDATA (DUT outputs)
//              and PRDATA, PREADY, PSLVERR (testbench-driven responses).
//   - Intent: "Monitor every APB transaction as it exits the bridge.
//              Capture address, direction, write data, read data, and
//              slave error signal when the APB transfer completes
//              — when PREADY is asserted."
//   - Spec: APB transfer completes when PSEL=1 && PENABLE=1 && PREADY=1.
//
// CAPTURE POINT: PSEL=1 && PENABLE=1 && PREADY=1 on rising HCLK.
//   This is the standard APB completion point.
//
// CONFIDENCE: HIGH — APB monitoring is well-defined and straightforward.
// =============================================================================

class apb_slv_monitor extends uvm_monitor;

  `uvm_component_utils(apb_slv_monitor)

  // Virtual interface — no modport [U1]
  virtual apb_slv_if vif;

  // Analysis port — broadcasts captured APB transactions to scoreboard
  uvm_analysis_port #(apb_slv_seq_item) ap;

  function new(string name = "apb_slv_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NOVIF", "apb_slv_monitor: Failed to get apb_vif from config_db")
  endfunction : build_phase

  // ── Run Phase: Continuously monitor APB transactions ─────────────────────
  task run_phase(uvm_phase phase);
    // Wait for reset deassertion
    @(posedge vif.HRESETn);
    @(posedge vif.HCLK);

    `uvm_info("APB_MON", "Reset released, starting APB monitor", UVM_MEDIUM)

    forever begin
      apb_slv_seq_item txn;
      txn = apb_slv_seq_item::type_id::create("apb_txn");

      // ── WAIT FOR APB TRANSFER COMPLETION ─────────────────────────────────
      // APB protocol: transfer is complete when PSEL=1, PENABLE=1, PREADY=1
      // on the rising edge of PCLK (=HCLK in single clock domain).
      @(posedge vif.HCLK);
      while (!(vif.PSEL === 1'b1 &&
               vif.PENABLE === 1'b1 &&
               vif.PREADY === 1'b1)) begin
        @(posedge vif.HCLK);
      end

      // ── CAPTURE ALL SIGNALS AT COMPLETION POINT ──────────────────────────
      txn.addr   = vif.PADDR;
      txn.write  = vif.PWRITE;
      txn.wdata  = vif.PWDATA;
      txn.rdata  = vif.PRDATA;
      txn.slverr = vif.PSLVERR;

      // Call post_randomize before broadcasting [U4]
      txn.post_randomize();

      `uvm_info("APB_MON", {"Captured: ", txn.convert2string()}, UVM_MEDIUM)

      // Broadcast to scoreboard via analysis port
      ap.write(txn);
    end
  endtask : run_phase

endclass : apb_slv_monitor