// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_012_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_012
// DESCRIPTION: Stimulus for debug_regs_read_only_write_ignored.
//              Verifies that attempted writes to the captured debug registers
//              ERROR_ADDR (@0x0000_0F08) and ERROR_INFO (@0x0000_0F0C) have no
//              effect on the stored value — both are read-only (RO).
//
//              Sequence of raw AHB transactions:
//                1. WRITE a valid target address 0x0000_0100 that the slave
//                   errors on, so the bridge captures ERROR_ADDR=0x0000_0100 and
//                   sets STATUS.PSLVERR=1 (known good capture).
//                2. WRITE ERROR_ADDR (0x0000_0F08) with 0xFFFF_FFFF — accepted
//                   on the bus but the RO register must ignore the data.
//                3. WRITE ERROR_INFO (0x0000_0F0C) with 0xAAAA_AAAA — likewise
//                   ignored by the RO register.
//                4. READ ERROR_ADDR (0x0000_0F08) — expect the unchanged captured
//                   value 0x0000_0100 (NOT 0xFFFF_FFFF).
//                5. READ ERROR_INFO (0x0000_0F0C) — expect retained captured
//                   context (NOT 0xAAAA_AAAA).
//                6. Compare confirms both registers are write-immune (RO).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_012 steps 1-6 — induce capture, attempt RO writes,
//     read-back to prove the stored values are unchanged.
//   - IP-XACT: REG_BASE=0x0000_0F00, ERROR_ADDR @ +0x08, ERROR_INFO @ +0x0C.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address capture then RO-write/read-back sequence.
// =============================================================================

class ahb_mst_test_register_access_012_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_012_seq)

  // Register block (REG_BASE 0x0F00) offsets and the captured/attempted values.
  localparam logic [31:0] ERROR_ADDR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] ERROR_INFO_ADDR = 32'h0000_0F0C;
  localparam logic [31:0] CAPTURE_ADDR    = 32'h0000_0100;  // valid known capture
  localparam logic [31:0] RO_WR_PATTERN_A = 32'hFFFF_FFFF;  // ignored by ERROR_ADDR
  localparam logic [31:0] RO_WR_PATTERN_B = 32'hAAAA_AAAA;  // ignored by ERROR_INFO

  function new(string name = "ahb_mst_test_register_access_012_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC012_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_012: debug regs read-only / write-ignored (ERROR_ADDR @0x%08h, ERROR_INFO @0x%08h)",
                ERROR_ADDR_ADDR, ERROR_INFO_ADDR), UVM_MEDIUM)

    // ── STEP 1 — induce a target error so ERROR_ADDR captures 0x0000_0100 ─────
    // A write to 0x0000_0100 that the slave errors on latches ERROR_ADDR with a
    // valid known value and raises STATUS.PSLVERR=1.
    req = ahb_mst_seq_item::type_id::create("ahb_induce_capture");
    start_item(req);
    req.addr       = CAPTURE_ADDR;
    req.write      = 1'b1;    // Write that provokes a target error capture
    req.wdata      = 32'hDEAD_BEEF;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC012_SEQ",
      $sformatf("WRITE HADDR=0x%08h (expect ERROR_ADDR capture + STATUS.PSLVERR=1)",
                CAPTURE_ADDR), UVM_HIGH)
    finish_item(req);
    if (req.resp !== 1'b1)
      `uvm_error("REGACC012_SEQ",
        $sformatf("Target (PSLVERR) write should return HRESP=1, got %0b", req.resp))

    // ── STEP 2 — attempt WRITE to ERROR_ADDR with 0xFFFF_FFFF (RO, ignored) ───
    req = ahb_mst_seq_item::type_id::create("ahb_error_addr_ro_wr");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b1;    // Write attempt to a read-only register
    req.wdata      = RO_WR_PATTERN_A;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC012_SEQ",
      $sformatf("WRITE ERROR_ADDR @0x%08h = 0x%08h (RO — must be ignored)",
                ERROR_ADDR_ADDR, RO_WR_PATTERN_A), UVM_HIGH)
    finish_item(req);

    // ── STEP 3 — attempt WRITE to ERROR_INFO with 0xAAAA_AAAA (RO, ignored) ───
    req = ahb_mst_seq_item::type_id::create("ahb_error_info_ro_wr");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b1;    // Write attempt to a read-only register
    req.wdata      = RO_WR_PATTERN_B;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC012_SEQ",
      $sformatf("WRITE ERROR_INFO @0x%08h = 0x%08h (RO — must be ignored)",
                ERROR_INFO_ADDR, RO_WR_PATTERN_B), UVM_HIGH)
    finish_item(req);

    // ── STEP 4 — READ ERROR_ADDR back, expect unchanged 0x0000_0100 ──────────
    req = ahb_mst_seq_item::type_id::create("ahb_error_addr_rd");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read — ERROR_ADDR is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC012_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect HRDATA=0x%08h, NOT 0x%08h)",
                ERROR_ADDR_ADDR, CAPTURE_ADDR, RO_WR_PATTERN_A), UVM_HIGH)
    finish_item(req);
    // ERROR_ADDR is read-only: the 0xFFFF_FFFF write was ignored, so it still
    // holds the captured 0x0000_0100.
    if (req.rdata !== CAPTURE_ADDR)
      `uvm_error("REGACC012_SEQ",
        $sformatf("ERROR_ADDR RO violated: got 0x%08h, expected 0x%08h", req.rdata, CAPTURE_ADDR))
    else `uvm_info("REGACC012_SEQ", $sformatf("ERROR_ADDR RO + captured OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 5 — READ ERROR_INFO back, expect retained captured context ──────
    req = ahb_mst_seq_item::type_id::create("ahb_error_info_rd");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read — ERROR_INFO is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC012_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect retained context, NOT 0x%08h)",
                ERROR_INFO_ADDR, RO_WR_PATTERN_B), UVM_HIGH)
    finish_item(req);
    // ERROR_INFO is read-only and retains the captured context of the write
    // target error: ERR_TYPE=3 (pslverr), ERR_WRITE=1 (write), size=word => 0x3A.
    if (req.rdata !== 32'h0000_003A)
      `uvm_error("REGACC012_SEQ",
        $sformatf("ERROR_INFO RO/context mismatch: got 0x%08h, expected 0x0000003A", req.rdata))
    else `uvm_info("REGACC012_SEQ", $sformatf("ERROR_INFO RO + context OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 6 — compare is performed by the scoreboard / checker. ───────────
    // Both read-backs proving write-immune confirms RO semantics for the two
    // captured debug registers.
    `uvm_info("REGACC012_SEQ", "TEST_REGISTER_ACCESS_012 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_012_seq
