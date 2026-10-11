// =============================================================================
// FILE: env/apb_slv_agent/apb_slv_driver.sv
// =============================================================================
// COMPONENT  : APB Slave Driver (Reactive)
// DESCRIPTION: Reactive driver that responds to DUT-initiated APB transactions.
//              The DUT is the APB master — it drives PADDR, PSEL, PENABLE,
//              PWRITE, PWDATA. This driver responds with PRDATA, PREADY,
//              PSLVERR.
//
// DERIVED FROM:
//   - IP-XACT: DUT outputs PADDR, PSEL, PENABLE, PWRITE, PWDATA.
//              DUT inputs PRDATA, PREADY, PSLVERR (driven by this driver).
//   - Intent: "APB slave should behave as a simple memory slave.
//              Respond to every APB transaction with PREADY asserted after
//              one clock cycle. No error responses. Store written data and
//              return it on reads using associative array indexed by address."
//   - Spec: Section 5.4-5.5 — SETUP phase (PSEL=1, PENABLE=0), then
//           ACCESS phase (PSEL=1, PENABLE=1). Slave samples when
//           PSEL=1 && PENABLE=1.
//
// PROTOCOL TIMING:
//   1. Wait for PSEL=1 && PENABLE=0 (SETUP phase)
//   2. On next clock, PENABLE=1 (ACCESS phase) — this is when we respond
//   3. Assert PREADY=1, drive PRDATA for reads, PSLVERR=0
//
// CONFIDENCE: MEDIUM — The reactive slave behavior is straightforward but
//   the exact timing of when PRDATA must be valid relative to PENABLE
//   depends on the DUT's sampling point.
//
// EDIT_RECOMMENDED: Verify PRDATA timing — some APB slaves drive PRDATA
//   combinationally when PSEL rises, others only when PENABLE rises.
//   This implementation drives PRDATA when PSEL && !PENABLE (SETUP phase)
//   so it's stable before PENABLE assertion.
// =============================================================================

class apb_slv_driver extends uvm_driver #(apb_slv_seq_item);

  `uvm_component_utils(apb_slv_driver)

  // Virtual interface — no modport [U1]
  virtual apb_slv_if vif;

  // Test configuration — carries optional error/stall injection lists.
  ahb2apb_bridge_dut_config cfg;

  // ── Memory Model ─────────────────────────────────────────────────────────
  // Intent: "Store written data and return it on reads using an associative
  //          array indexed by address."
  logic [31:0] mem [int unsigned];

  function new(string name = "apb_slv_driver", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NOVIF", "apb_slv_driver: Failed to get apb_vif from config_db")
    // cfg is optional: when absent the slave behaves as a plain memory slave
    // (no error/stall injection).
    if (!uvm_config_db#(ahb2apb_bridge_dut_config)::get(this, "", "cfg", cfg))
      cfg = null;
  endfunction : build_phase

  // ── Run Phase: Reactive slave loop ───────────────────────────────────────
  task run_phase(uvm_phase phase);
    // Initialize slave response signals
    vif.PRDATA  <= 32'h0;
    vif.PREADY  <= 1'b1;    // Default ready (no wait states initially)
    vif.PSLVERR <= 1'b0;    // No error

    // Wait for reset deassertion
    @(posedge vif.HRESETn);
    @(posedge vif.HCLK);

    `uvm_info("APB_DRV", "Reset released, starting APB slave driver", UVM_MEDIUM)

    // Reactive slave — runs forever [U3]
    // Gets items from the reactive sequence, which monitors PSEL/PENABLE
    forever begin
      apb_slv_seq_item req;

      // Get response item from reactive sequence
      seq_item_port.get_next_item(req);

      // Drive the response based on the request
      drive_response(req);

      seq_item_port.item_done();
    end
  endtask : run_phase

  // ── Drive Response ───────────────────────────────────────────────────────
  // Waits for APB SETUP phase from DUT, then responds in ACCESS phase
  task drive_response(apb_slv_seq_item req);
    bit inject_err;
    bit inject_stall;

    // ── Wait for SETUP phase: PSEL=1, PENABLE=0 ─────────────────────────
    while (!(vif.PSEL === 1'b1 && vif.PENABLE === 1'b0)) begin
      @(posedge vif.HCLK);
    end

    // We're in SETUP phase — capture the DUT's request
    req.addr  = vif.PADDR;
    req.write = vif.PWRITE;
    if (req.write) begin
      req.wdata = vif.PWDATA;
    end

    // Decide whether this address is configured for error/stall injection.
    inject_err   = (cfg != null) && cfg.apb_is_err_addr(req.addr);
    inject_stall = (cfg != null) && cfg.apb_is_stall_addr(req.addr);

    `uvm_info("APB_DRV", $sformatf("SETUP detected: addr=0x%08h %s%s%s",
              req.addr, req.write ? "WR" : "RD",
              inject_err ? " [INJECT PSLVERR]" : "",
              inject_stall ? " [INJECT STALL]" : ""), UVM_HIGH)

    // For reads: prepare read data from memory model.
    // Drive PRDATA during SETUP so it's stable when PENABLE rises.
    if (!req.write) begin
      if (mem.exists(req.addr)) begin
        req.rdata = mem[req.addr];
      end else begin
        req.rdata = 32'hDEAD_BEEF;  // Default for uninitialized addresses
        // EDIT_OPTIONAL: Change default read value if needed
      end
      vif.PRDATA <= req.rdata;
    end

    // Drive PSLVERR (and, for stall, deassert PREADY) during SETUP so they are
    // stable in the ACCESS phase when the bridge samples them. PREADY defaults
    // high, so the bridge can complete the access on the very first ACCESS
    // cycle — driving these only after ACCESS is detected would be one cycle
    // too late (the bridge would have already completed / dropped PSEL).
    vif.PSLVERR <= inject_err ? 1'b1 : 1'b0;
    req.slverr   = inject_err;
    if (inject_stall) vif.PREADY <= 1'b0;   // target not ready -> bridge times out

    // ── Wait for ACCESS phase: PENABLE rises ─────────────────────────────
    // Intent: "PREADY asserted after one clock cycle"
    // On the next posedge, PENABLE should be 1 (DUT drives this)
    @(posedge vif.HCLK);

    // ── STALL injection: hold PREADY=0 while the bridge counts toward its
    // timeout window. The bridge aborts to its error state and drops PSEL —
    // stop stalling as soon as that happens (or after the bounded cap) and
    // return to the ready default.
    if (inject_stall) begin
      int unsigned s = 0;
      while (s < cfg.apb_stall_cycles && vif.PSEL === 1'b1) begin
        @(posedge vif.HCLK);
        s++;
      end
      vif.PREADY <= 1'b1;   // restore ready default for subsequent transfers
      `uvm_info("APB_DRV", $sformatf("STALL injected at 0x%08h for %0d cycles (PSEL=%0b)",
                req.addr, s, vif.PSEL), UVM_MEDIUM)
      return;               // no completion / no mem update for a timed-out xfer
    end

    // ── Normal / PSLVERR response ─────────────────────────────────────────
    vif.PREADY  <= 1'b1;

    // For writes (that did not error): store data into memory model
    if (req.write && !inject_err) begin
      mem[req.addr] = req.wdata;
      `uvm_info("APB_DRV", $sformatf("MEM WRITE: addr=0x%08h data=0x%08h",
                req.addr, req.wdata), UVM_HIGH)
    end else if (!req.write) begin
      `uvm_info("APB_DRV", $sformatf("MEM READ: addr=0x%08h data=0x%08h%s",
                req.addr, req.rdata, inject_err ? " [PSLVERR]" : ""), UVM_HIGH)
    end

    // Hold PREADY for one cycle, then return PSLVERR low for clean state.
    @(posedge vif.HCLK);
    vif.PSLVERR <= 1'b0;
    // PREADY stays high as default — matches intent "respond after one clock"

  endtask : drive_response

endclass : apb_slv_driver