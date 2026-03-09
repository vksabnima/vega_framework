// =============================================================================
// File        : ahb2apb_bridge_env.sv
// Description : Top-level UVM Environment
//
// Instantiates:
//   - ahb_mst_agent: active — drives AHB transactions into bridge
//   - apb_slv_agent: active — reactive slave responds to bridge APB master
//   - scoreboard: compares AHB ↔ APB transactions for all VGs
//
// Derivation:
//   - Manifest: two interfaces (ahb_mst, apb_slv)
//   - Intent: monitor both sides, compare in scoreboard
//
// Confidence: HIGH — standard UVM env pattern.
// =============================================================================

class ahb2apb_bridge_env extends uvm_env;
  `uvm_component_utils(ahb2apb_bridge_env)

  ahb_mst_agent            ahb_agt;
  apb_slv_agent            apb_agt;
  ahb2apb_bridge_scoreboard scb;
  ahb2apb_bridge_coverage   cov;

  ahb2apb_bridge_dut_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve configuration from config_db
    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "ahb2apb_bridge_env: no 'cfg' in config_db")

    // Propagate config down to agents
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, {get_full_name(), ".*"}, "cfg", cfg);

    // Instantiate agents
    ahb_agt = ahb_mst_agent::type_id::create("ahb_agt", this);
    apb_agt = apb_slv_agent::type_id::create("apb_agt", this);

    // Instantiate scoreboard
    scb = ahb2apb_bridge_scoreboard::type_id::create("scb", this);

    // Instantiate coverage collector
    cov = ahb2apb_bridge_coverage::type_id::create("cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis ports to scoreboard
    ahb_agt.mon.ap.connect(scb.ahb_imp);
    apb_agt.mon.ap.connect(scb.apb_imp);

    // Connect monitor analysis ports to coverage collector
    ahb_agt.mon.ap.connect(cov.ahb_imp);
    apb_agt.mon.ap.connect(cov.apb_imp);
  endfunction

endclass