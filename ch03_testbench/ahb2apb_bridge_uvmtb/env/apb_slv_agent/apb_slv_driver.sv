// =============================================================================
// File        : apb_slv_driver.sv
// Description : APB Slave Driver (reactive)
//
// This driver is *reactive*: it doesn't initiate transfers, it responds to
// APB transactions initiated by the DUT's bridge master port.
//
// Protocol timing (APB2):
//   SETUP phase:  PSEL=1, PENABLE=0 — slave sees address/direction
//   ACCESS phase: PSEL=1, PENABLE=1 — slave must drive PREADY, PRDATA, PSLVERR
//                 Transfer completes when PREADY=1 at rising edge.
//
// Behavior (from intent):
//   - Simple memory model: associative array indexed by address
//   - Write: store PWDATA at PADDR
//   - Read:  return stored data (or 0 if address never written)
//   - PREADY asserted after one cycle (no wait states)
//   - PSLVERR always 0 (no error injection for bringup)
//
// The driver does NOT use sequences for reactive behavior — it directly
// observes and responds in run_phase.
//
// EDIT_RECOMMENDED: If you want sequence-driven reactive responses, convert
//   this to use seq_item_port.get_next_item() with a reactive sequence.
//   For bringup simplicity, the memory model is embedded in the driver.
//
// Confidence: MEDIUM — reactive APB slave is straightforward but
//   the exact timing of PREADY relative to PENABLE must match DUT expectations.
// =============================================================================

class apb_slv_driver extends uvm_driver #(apb_slv_seq_item);
  `uvm_component_utils(apb_slv_driver)

  virtual apb_slv_if vif;

  // Simple memory model — associative array keyed by word-aligned address
  bit [31:0] mem [bit[31:0]];

  // ----- Configurable behavior knobs (set by tests) -----
  // Wait state injection: number of extra cycles to hold PREADY=0
  int pready_delay = 0;

  // PSLVERR injection: inject on ALL subsequent transfers
  bit pslverr_inject = 0;

  // PSLVERR injection: inject on NEXT transfer only, auto-clears
  bit pslverr_inject_once = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_slv_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "apb_slv_driver: no virtual interface 'vif' in config_db")
  endfunction

  // =========================================================================
  // run_phase: reactive slave — observe and respond
  //
  // Supports configurable wait states (pready_delay) and error injection
  // (pslverr_inject / pslverr_inject_once).
  //
  // Tests set these fields before starting AHB sequences:
  //   env.apb_agt.drv.pready_delay = N;
  //   env.apb_agt.drv.pslverr_inject = 1;
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    // Initialize outputs to safe defaults
    vif.drv_cb.PRDATA  <= 32'h0;
    vif.drv_cb.PREADY  <= 1'b1;
    vif.drv_cb.PSLVERR <= 1'b0;

    forever begin
      @(vif.drv_cb);

      // ----- Detect SETUP phase: PSEL=1, PENABLE=0 -----
      if (vif.drv_cb.PSEL === 1'b1 && vif.drv_cb.PENABLE === 1'b0) begin
        bit [31:0] addr;
        bit        wr;
        bit [31:0] wdata;
        int        delay;
        bit        inject_err;

        // Capture setup-phase information
        addr  = vif.drv_cb.PADDR;
        wr    = vif.drv_cb.PWRITE;

        // Snapshot behavior for this transfer
        delay      = pready_delay;
        inject_err = pslverr_inject || pslverr_inject_once;
        if (pslverr_inject_once) pslverr_inject_once = 0;

        // For reads: drive stored data
        if (!wr) begin
          if (mem.exists(addr))
            vif.drv_cb.PRDATA <= mem[addr];
          else
            vif.drv_cb.PRDATA <= 32'h0;
        end

        // During setup, pre-drive PREADY and PSLVERR so they are visible
        // to RTL when it enters ST_APB_ACCESS at the next posedge.
        // (output #1 clocking skew means values driven here are seen
        //  by RTL one cycle later — exactly when ST_APB_ACCESS begins.)
        if (delay > 0) begin
          vif.drv_cb.PREADY  <= 1'b0;
          vif.drv_cb.PSLVERR <= 1'b0;
        end else begin
          vif.drv_cb.PREADY  <= 1'b1;
          vif.drv_cb.PSLVERR <= inject_err ? 1'b1 : 1'b0;
        end

        // Wait for ACCESS phase
        @(vif.drv_cb);

        // Verify PENABLE is now high
        if (vif.drv_cb.PSEL === 1'b1 && vif.drv_cb.PENABLE === 1'b1) begin

          // Hold PREADY=0 for delay cycles (wait state injection)
          if (delay > 0) begin : wait_state_loop
            int i;
            for (i = 0; i < delay; i++) begin
              vif.drv_cb.PREADY  <= 1'b0;
              vif.drv_cb.PSLVERR <= 1'b0;
              @(vif.drv_cb);
              // Break if bridge aborted (timeout, error)
              if (vif.drv_cb.PSEL !== 1'b1) break;
            end
          end

          // Complete transfer: PREADY=1, optionally PSLVERR=1
          vif.drv_cb.PREADY  <= 1'b1;
          vif.drv_cb.PSLVERR <= inject_err ? 1'b1 : 1'b0;

          if (wr) begin
            wdata = vif.drv_cb.PWDATA;
            if (!inject_err)
              mem[addr] = wdata;
            `uvm_info("APB_SLV_DRV", $sformatf("WRITE mem[0x%08h] = 0x%08h%s",
                      addr, wdata, inject_err ? " [PSLVERR]" : ""), UVM_HIGH)
          end else begin
            `uvm_info("APB_SLV_DRV", $sformatf("READ  mem[0x%08h] = 0x%08h%s",
                      addr, mem.exists(addr) ? mem[addr] : 32'h0,
                      inject_err ? " [PSLVERR]" : ""), UVM_HIGH)
          end

        end else begin
          `uvm_warning("APB_SLV_DRV", "Expected PENABLE=1 in access phase but not seen")
        end

        // After transfer, return PSLVERR to 0
        vif.drv_cb.PSLVERR <= 1'b0;
      end
    end
  endtask

endclass