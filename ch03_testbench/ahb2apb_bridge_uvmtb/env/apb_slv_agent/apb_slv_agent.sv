// =============================================================================
// File        : apb_slv_agent.sv
// Description : APB Slave Agent
//
// Contains driver, monitor, and sequencer for the APB slave (reactive) side.
// Always active — must respond to bridge-initiated APB transactions.
//
// Derivation:
//   - Manifest: apb_slv interface, role=passive (from DUT perspective,
//               but the TB agent is ACTIVE to drive PRDATA/PREADY/PSLVERR)
//   - Intent: simple memory slave behavior
//
// EDIT_RECOMMENDED: Manifest says role=passive, but the agent needs to
//   *drive* responses (PRDATA, PREADY, PSLVERR).  We treat the agent as
//   UVM_ACTIVE so the driver is instantiated.  "Passive" in manifest means
//   the APB side is the slave role (reactive), not UVM passive.
//
// Confidence: HIGH — standard UVM agent pattern.
// =============================================================================

class apb_slv_agent extends uvm_agent;
  `uvm_component_utils(apb_slv_agent)

  apb_slv_driver    drv;
  apb_slv_monitor   mon;
  apb_slv_sequencer sqr;

  ahb2apb_bridge_dut_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "apb_slv_agent: no 'cfg' in config_db")

    // Monitor always present
    mon = apb_slv_monitor::type_id::create("mon", this);

    // Driver always instantiated — reactive slave must drive responses
    // Sequencer instantiated for future use (sequences not used in bringup)
    if (cfg.apb_slv_is_active == UVM_ACTIVE) begin
      drv = apb_slv_driver::type_id::create("drv", this);
      sqr = apb_slv_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Driver does not use seq_item_port in current reactive implementation.
    // If sequence-driven reactive model is used in future, connect here:
    // if (cfg.apb_slv_is_active == UVM_ACTIVE)
    //   drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass