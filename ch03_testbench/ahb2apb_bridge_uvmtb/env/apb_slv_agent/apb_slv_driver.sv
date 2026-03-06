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
  // Waits for PSEL=1 && PENABLE=0 (setup phase), then on next clock
  // (access phase with PENABLE=1) drives PRDATA/PREADY/PSLVERR.
  //
  // Per intent: PREADY after one clock, no wait states, no errors.
  //
  // PROTOCOL_GAP: The exact behavior when bridge deasserts PSEL mid-transfer
  //   is not tested in bringup.  The driver simply returns to idle.
  // =========================================================================
  virtual task run_phase(uvm_phase phase);
    // Initialize outputs to safe defaults
    vif.drv_cb.PRDATA  <= 32'h0;
    vif.drv_cb.PREADY  <= 1'b1;  // Default ready (no wait states)
    vif.drv_cb.PSLVERR <= 1'b0;

    forever begin
      @(vif.drv_cb);

      // ----- Detect SETUP phase: PSEL=1, PENABLE=0 -----
      if (vif.drv_cb.PSEL === 1'b1 && vif.drv_cb.PENABLE === 1'b0) begin
        bit [31:0] addr;
        bit        wr;
        bit [31:0] wdata;

        // Capture setup-phase information
        addr  = vif.drv_cb.PADDR;
        wr    = vif.drv_cb.PWRITE;

        // ----- ACCESS phase: next clock, PENABLE should go high -----
        // Drive PREADY=1 (no wait states per intent)
        // For reads: drive stored data
        // For writes: data captured in access phase
        if (!wr) begin
          // Read: return previously stored value, or 0 if never written
          if (mem.exists(addr))
            vif.drv_cb.PRDATA <= mem[addr];
          else
            vif.drv_cb.PRDATA <= 32'h0;
        end

        vif.drv_cb.PREADY  <= 1'b1;
        vif.drv_cb.PSLVERR <= 1'b0;

        // Wait for ACCESS phase
        @(vif.drv_cb);

        // Verify PENABLE is now high (sanity check)
        if (vif.drv_cb.PSEL === 1'b1 && vif.drv_cb.PENABLE === 1'b1) begin
          if (wr) begin
            // Write: capture PWDATA and store in memory
            wdata = vif.drv_cb.PWDATA;
            mem[addr] = wdata;
            `uvm_info("APB_SLV_DRV", $sformatf("WRITE mem[0x%08h] = 0x%08h", addr, wdata), UVM_HIGH)
          end else begin
            `uvm_info("APB_SLV_DRV", $sformatf("READ  mem[0x%08h] = 0x%08h", addr,
                      mem.exists(addr) ? mem[addr] : 32'h0), UVM_HIGH)
          end
        end else begin
          `uvm_warning("APB_SLV_DRV", "Expected PENABLE=1 in access phase but not seen")
        end

        // After transfer complete, deassert PRDATA (not required but clean)
        // PREADY stays high as default
      end
    end
  endtask

endclass