// =============================================================================
// FILE: env/apb_slv_agent/apb_slv_agent.sv
// =============================================================================
// COMPONENT  : APB Slave Agent
// DESCRIPTION: UVM agent wrapping the APB slave driver (reactive), monitor,
//              and sequencer. The driver acts as a simple memory slave
//              responding to DUT-initiated APB master transactions.
//
// DERIVED FROM:
//   - Manifest: apb_slv interface, role=passive (monitor-perspective),
//     but active in UVM sense because we need to drive responses.
//   - Intent: "APB slave agent should behave as a simple memory slave."
//
// CONFIDENCE: HIGH — standard UVM agent composition.
// =============================================================================

class apb_slv_agent extends uvm_agent;

  `uvm_component_utils(apb_slv_agent)

  // Sub-components
  apb_slv_driver    drv;
  apb_slv_monitor   mon;
  apb_slv_sequencer sqr;

  // Configuration handle
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "apb_slv_agent", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "apb_slv_agent: Failed to get cfg from config_db")

    // Monitor always built
    mon = apb_slv_monitor::type_id::create("mon", this);

    // Driver and sequencer built when active (we need them for reactive slave)
    if (cfg.apb_agent_is_active == UVM_ACTIVE) begin
      drv = apb_slv_driver::type_id::create("drv", this);
      sqr = apb_slv_sequencer::type_id::create("sqr", this);
      `uvm_info("APB_AGT", "Built in ACTIVE mode (reactive driver + sequencer + monitor)", UVM_MEDIUM)
    end else begin
      `uvm_info("APB_AGT", "Built in PASSIVE mode (monitor only)", UVM_MEDIUM)
    end
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg.apb_agent_is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction : connect_phase

endclass : apb_slv_agent