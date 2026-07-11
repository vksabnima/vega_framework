// =============================================================================
// FILE: env/ahb2apb_bridge_env.sv
// =============================================================================
// COMPONENT  : AHB-to-APB Bridge Environment
// DESCRIPTION: Top-level UVM environment containing both agents and the
//              scoreboard. Wires analysis ports from monitors to scoreboard.
//
// DERIVED FROM:
//   - Manifest: Two interfaces (ahb_mst, apb_slv).
//   - Intent: Full scoreboard checking VG1-VG6.
//   - Architecture: AHB active agent + APB active (reactive) agent + scoreboard.
//
// CONFIDENCE: HIGH — standard UVM env composition.
// =============================================================================

class ahb2apb_bridge_env extends uvm_env;

  `uvm_component_utils(ahb2apb_bridge_env)

  // Sub-components
  ahb_mst_agent             ahb_agt;
  apb_slv_agent             apb_agt;
  ahb2apb_bridge_scoreboard scb;
  ahb2apb_bridge_coverage   cov;

  // Configuration
  ahb2apb_bridge_dut_config cfg;

  function new(string name = "ahb2apb_bridge_env", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration from config_db
    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "ahb2apb_bridge_env: Failed to get cfg from config_db")

    // Propagate config to sub-components via config_db
    // Using null scope [U2] — set to wildcard paths under this env
    uvm_config_db#(ahb2apb_bridge_dut_config)::set(null, {get_full_name(), ".*"}, "cfg", cfg);

    // Propagate virtual interfaces to agents
    // Agents will get these from config_db in their build_phase
    uvm_config_db#(virtual ahb_mst_if)::set(null, {get_full_name(), ".ahb_agt.*"}, "ahb_vif", cfg.ahb_vif);
    uvm_config_db#(virtual apb_slv_if)::set(null, {get_full_name(), ".apb_agt.*"}, "apb_vif", cfg.apb_vif);

    // Build agents
    ahb_agt = ahb_mst_agent::type_id::create("ahb_agt", this);
    apb_agt = apb_slv_agent::type_id::create("apb_agt", this);

    // Build scoreboard only if enabled
    if (cfg.scoreboard_enable) begin
      scb = ahb2apb_bridge_scoreboard::type_id::create("scb", this);
      `uvm_info("ENV", "Scoreboard ENABLED", UVM_MEDIUM)
    end else begin
      `uvm_info("ENV", "Scoreboard DISABLED (bringup mode)", UVM_MEDIUM)
    end

    // Functional coverage collector — always built; harmless under bringup.
    cov = ahb2apb_bridge_coverage::type_id::create("cov", this);

  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis ports to scoreboard if enabled
    if (cfg.scoreboard_enable && scb != null) begin
      ahb_agt.mon.ap.connect(scb.ahb_ap);
      apb_agt.mon.ap.connect(scb.apb_ap);
      `uvm_info("ENV", "Monitor analysis ports connected to scoreboard", UVM_MEDIUM)
    end

    // Monitor analysis ports also feed the functional coverage collector.
    ahb_agt.mon.ap.connect(cov.ahb_imp);
    apb_agt.mon.ap.connect(cov.apb_imp);
  endfunction : connect_phase

endclass : ahb2apb_bridge_env