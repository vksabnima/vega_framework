// =============================================================================
// FILE: env/ahb_mst_agent/ahb_mst_agent.sv
// =============================================================================
// COMPONENT  : AHB Master Agent
// DESCRIPTION: UVM agent wrapping the AHB master driver, monitor, and
//              sequencer. Configurable as active (drives+monitors) or
//              passive (monitors only).
//
// DERIVED FROM:
//   - Manifest: ahb_mst interface, role=active.
//   - Standard UVM agent pattern.
//
// CONFIDENCE: HIGH — standard UVM agent composition.
// =============================================================================

class ahb_mst_agent extends uvm_agent;

  `uvm_component_utils(ahb_mst_agent)

  // Sub-components
  ahb_mst_driver    drv;
  ahb_mst_monitor   mon;
  ahb_mst_sequencer sqr;

  // Configuration handle
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "ahb_mst_agent", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration from config_db
    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "ahb_mst_agent: Failed to get cfg from config_db")

    // Monitor is always built (active or passive)
    mon = ahb_mst_monitor::type_id::create("mon", this);

    // Driver and sequencer only built in active mode
    if (cfg.ahb_agent_is_active == UVM_ACTIVE) begin
      drv = ahb_mst_driver::type_id::create("drv", this);
      sqr = ahb_mst_sequencer::type_id::create("sqr", this);
      `uvm_info("AHB_AGT", "Built in ACTIVE mode (driver + sequencer + monitor)", UVM_MEDIUM)
    end else begin
      `uvm_info("AHB_AGT", "Built in PASSIVE mode (monitor only)", UVM_MEDIUM)
    end
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect driver to sequencer in active mode
    if (cfg.ahb_agent_is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction : connect_phase

endclass : ahb_mst_agent