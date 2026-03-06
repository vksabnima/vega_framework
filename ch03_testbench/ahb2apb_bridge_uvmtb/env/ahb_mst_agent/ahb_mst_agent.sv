// =============================================================================
// File        : ahb_mst_agent.sv
// Description : AHB Master Agent
//
// Contains driver, monitor, and sequencer for the AHB master interface.
// Active by default (drives transactions).  Can be set passive via config.
//
// Derivation:
//   - Manifest: ahb_mst interface, role=active
//   - Config:   ahb_mst_is_active controls instantiation
//
// Confidence: HIGH — standard UVM agent pattern.
// =============================================================================

class ahb_mst_agent extends uvm_agent;
  `uvm_component_utils(ahb_mst_agent)

  ahb_mst_driver    drv;
  ahb_mst_monitor   mon;
  ahb_mst_sequencer sqr;

  ahb2apb_bridge_dut_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve configuration
    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "ahb_mst_agent: no 'cfg' in config_db")

    // Monitor is always instantiated (passive observation)
    mon = ahb_mst_monitor::type_id::create("mon", this);

    // Driver + sequencer only in active mode
    if (cfg.ahb_mst_is_active == UVM_ACTIVE) begin
      drv = ahb_mst_driver::type_id::create("drv", this);
      sqr = ahb_mst_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect driver to sequencer in active mode
    if (cfg.ahb_mst_is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass