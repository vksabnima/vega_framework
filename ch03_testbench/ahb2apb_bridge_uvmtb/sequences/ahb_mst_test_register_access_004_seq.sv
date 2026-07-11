// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_004
// DESCRIPTION: Stimulus for status_readonly_busy_ready_behavior.
//              Verifies the STATUS register READY (bit0) and BUSY (bit1) fields
//              reflect live model state and are immune to software writes
//              (they are read-only / hardware-driven).
//
//              Preconditions: PCLK/HCLK running, reset deasserted,
//              CTRL.ENABLE=1, bridge idle (READY=1).
//
//              Drives, through the AHB master, STATUS transfers to
//              REG_BASE+0x04 = 0x0000_0F04 plus one normal datapath transfer:
//                1. READ STATUS while idle  — expect PRDATA[0]=1, PRDATA[1]=0.
//                2. WRITE a normal datapath transfer @0x0000_0300 — the target
//                   stalls (PREADY held low by the slave model), keeping the
//                   bridge busy; BUSY->1, READY->0.
//                3. READ STATUS while busy   — expect PRDATA[1]=1, PRDATA[0]=0.
//                4. WRITE STATUS PWDATA=0x0000_0003 (bit0=1, bit1=1) — attempt
//                   to write the RO BUSY/READY bits; access completes but the
//                   write is ignored.
//                5. READ STATUS after the transfer completes — expect
//                   PRDATA[1]=0, PRDATA[0]=1, tracking live HW state (the
//                   attempted write had no effect).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_004 steps 1-5.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), STATUS at +0x04.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address STATUS read/write + datapath transfer.
// =============================================================================

class ahb_mst_test_register_access_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_004_seq)

  // STATUS register address (REG_BASE 0x0F00 + 0x04 offset). Live HW bits:
  //   bit0 = READY, bit1 = BUSY (both read-only, hardware-driven).
  localparam logic [31:0] STATUS_ADDR    = 32'h0000_0F04;
  // Normal datapath address used to put the bridge into the BUSY state.
  localparam logic [31:0] DATAPATH_ADDR  = 32'h0000_0300;
  // Software attempt to set RO READY+BUSY bits — must be ignored by HW.
  localparam logic [31:0] STATUS_RO_WR   = 32'h0000_0003;  // bit0=1, bit1=1

  function new(string name = "ahb_mst_test_register_access_004_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC004_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_004: STATUS RO BUSY/READY behavior @0x%08h",
                STATUS_ADDR),
      UVM_MEDIUM)

    // ── STEP 1 — READ STATUS while idle: READY=1, BUSY=0 ─────────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd_idle");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC004_SEQ",
      $sformatf("READ STATUS (idle): HADDR=0x%08h (expect PRDATA[0]=1 READY, PRDATA[1]=0 BUSY)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 2 — WRITE datapath @0x300 to drive the bridge BUSY ──────────────
    // The APB slave model stalls (PREADY low), so the bridge stays busy:
    // BUSY transitions to 1, READY to 0 for the duration of the transfer.
    req = ahb_mst_seq_item::type_id::create("ahb_datapath_wr");
    start_item(req);
    req.addr       = DATAPATH_ADDR;
    req.write      = 1'b1;    // Write
    req.wdata      = 32'hA5A5_1234;  // arbitrary payload
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC004_SEQ",
      $sformatf("WRITE datapath: HADDR=0x%08h HWDATA=0x%08h (drives bridge BUSY)",
                DATAPATH_ADDR, req.wdata), UVM_HIGH)
    finish_item(req);

    // ── STEP 3 — READ STATUS while busy: BUSY=1, READY=0 ─────────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd_busy");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC004_SEQ",
      $sformatf("READ STATUS (busy): HADDR=0x%08h (expect PRDATA[1]=1 BUSY, PRDATA[0]=0 READY)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 4 — WRITE STATUS RO bits: attempt to set READY+BUSY, ignored ────
    req = ahb_mst_seq_item::type_id::create("ahb_status_wr_ro");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b1;    // Write — RO bits, must be ignored
    req.wdata      = STATUS_RO_WR;  // bit0=1, bit1=1
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC004_SEQ",
      $sformatf("WRITE STATUS RO: HADDR=0x%08h HWDATA=0x%08h (RO bit0/bit1 — must be ignored)",
                STATUS_ADDR, STATUS_RO_WR), UVM_HIGH)
    finish_item(req);

    // ── STEP 5 — READ STATUS after completion: BUSY=0, READY=1 (live state) ──
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd_done");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC004_SEQ",
      $sformatf("READ STATUS (done): HADDR=0x%08h (expect PRDATA[1]=0 BUSY, PRDATA[0]=1 READY — write had no effect)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("REGACC004_SEQ", "TEST_REGISTER_ACCESS_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_004_seq
