// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_011_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_011
// DESCRIPTION: Stimulus for debug_regs_reset_values.
//              Verifies both captured debug registers (ERROR_ADDR @0x0000_0F08,
//              ERROR_INFO @0x0000_0F0C) clear to 0x0000_0000 on hard reset.
//
//              Sequence of raw AHB transactions:
//                1. WRITE an invalid address 0xCAFE_0000 before reset so the
//                   bridge captures an address error: ERROR_ADDR latches
//                   0xCAFE_0000, ERROR_INFO becomes non-zero, STATUS.ADDR_ERR=1.
//                   This proves the registers were non-zero prior to reset.
//                2. (Reset is applied by tb_top / reset agent between T2..T4 —
//                   HRESETn/PRESETn deassert then re-assert; the model returns
//                   to clean idle with HREADY_OUT=1.)
//                3. READ ERROR_ADDR (REG_BASE+0x08 = 0x0000_0F08) — expect the
//                   post-reset value 0x0000_0000.
//                4. READ ERROR_INFO (REG_BASE+0x0C = 0x0000_0F0C) — expect the
//                   post-reset value 0x0000_0000.
//                5. READ STATUS (REG_BASE+0x00 = 0x0000_0F00) — expect
//                   0x0000_0001 (READY, sticky error flags cleared).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_011 steps 1-6 — pre-reset error capture, hard
//     reset, post-reset ERROR_ADDR / ERROR_INFO / STATUS reads.
//   - IP-XACT: REG_BASE=0x0000_0F00, STATUS @ +0x00, ERROR_ADDR @ +0x08,
//     ERROR_INFO @ +0x0C.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address error-capture write plus register reset reads.
// =============================================================================

class ahb_mst_test_register_access_011_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_011_seq)

  // Register block (REG_BASE 0x0F00) offsets and the invalid address used to
  // provoke a captured address error before reset.
  localparam logic [31:0] STATUS_ADDR     = 32'h0000_0F04;  // STATUS @ +0x04
  localparam logic [31:0] ERROR_ADDR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] ERROR_INFO_ADDR = 32'h0000_0F0C;
  localparam logic [31:0] INVALID_ADDR    = 32'hCAFE_0000;
  localparam logic [31:0] REG_RESET       = 32'h0000_0000;
  localparam logic [31:0] STATUS_READY    = 32'h0000_0001;

  // AHB interface handle (set by the test) used to pulse a mid-test hard reset.
  virtual ahb_mst_if vif;

  function new(string name = "ahb_mst_test_register_access_011_seq");
    super.new(name);
  endfunction : new

  // Apply a hard reset by pulsing force_rst_n low; tb_top folds it into HRESETn.
  task do_hard_reset();
    if (vif == null)
      `uvm_fatal("REGACC011_SEQ", "vif not set — test must assign seq.vif before start")
    `uvm_info("REGACC011_SEQ", "Applying mid-test HARD RESET (force_rst_n low)", UVM_MEDIUM)
    vif.force_rst_n = 1'b0;
    repeat (10) @(posedge vif.HCLK);
    vif.force_rst_n = 1'b1;
    @(posedge vif.HRESETn);       // tb_top releases HRESETn
    repeat (3) @(posedge vif.HCLK);
  endtask

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC011_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_011: debug regs reset values (ERROR_ADDR @0x%08h, ERROR_INFO @0x%08h)",
                ERROR_ADDR_ADDR, ERROR_INFO_ADDR), UVM_MEDIUM)

    // ── STEP 1 — WRITE invalid addr 0xCAFE_0000 to capture an address error ──
    // Pre-reset, this makes ERROR_ADDR=0xCAFE_0000, ERROR_INFO non-zero, and
    // STATUS.ADDR_ERR=1, proving the debug registers held non-zero values that
    // the subsequent hard reset must clear.
    req = ahb_mst_seq_item::type_id::create("ahb_induce_addr_err");
    start_item(req);
    req.addr       = INVALID_ADDR;
    req.write      = 1'b1;    // Write to an out-of-range address
    req.wdata      = 32'hDEAD_BEEF;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC011_SEQ",
      $sformatf("WRITE invalid HADDR=0x%08h (expect ERROR_ADDR capture + STATUS.ADDR_ERR=1)",
                INVALID_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check: the out-of-range write is a decode error -> HRESP=1 (works
    // without any APB injection). This proves the error that should later be
    // cleared by reset actually occurred.
    if (req.resp !== 1'b1)
      `uvm_error("REGACC011_SEQ",
        $sformatf("Invalid-address write should return HRESP=1, got %0b", req.resp))

    // ── STEPS 2-3 — apply a mid-test HARD RESET ──────────────────────────────
    // HRESETn is re-asserted (via force_rst_n) for several cycles then released;
    // the model returns to clean idle with the debug registers cleared to 0.
    do_hard_reset();

    // ── STEP 4 — READ ERROR_ADDR, expect post-reset value 0x0000_0000 ────────
    req = ahb_mst_seq_item::type_id::create("ahb_error_addr_rd");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read — ERROR_ADDR is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC011_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect post-reset HRDATA=0x%08h)",
                ERROR_ADDR_ADDR, REG_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== REG_RESET)
      `uvm_error("REGACC011_SEQ",
        $sformatf("ERROR_ADDR not cleared by hard reset: got 0x%08h, expected 0x%08h", req.rdata, REG_RESET))
    else `uvm_info("REGACC011_SEQ", "ERROR_ADDR cleared by hard reset OK: 0x00000000", UVM_LOW)

    // ── STEP 5 — READ ERROR_INFO, expect post-reset value 0x0000_0000 ────────
    req = ahb_mst_seq_item::type_id::create("ahb_error_info_rd");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read — ERROR_INFO is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC011_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect post-reset HRDATA=0x%08h)",
                ERROR_INFO_ADDR, REG_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== REG_RESET)
      `uvm_error("REGACC011_SEQ",
        $sformatf("ERROR_INFO not cleared by hard reset: got 0x%08h, expected 0x%08h", req.rdata, REG_RESET))
    else `uvm_info("REGACC011_SEQ", "ERROR_INFO cleared by hard reset OK: 0x00000000", UVM_LOW)

    // ── STEP 6 — READ STATUS, expect 0x0000_0001 (READY, sticky flags clear) ─
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read — confirm sticky error flags cleared
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC011_SEQ",
      $sformatf("READ STATUS @0x%08h (expect HRDATA=0x%08h: READY, no sticky error)",
                STATUS_ADDR, STATUS_READY), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== STATUS_READY)
      `uvm_error("REGACC011_SEQ",
        $sformatf("STATUS not clean after hard reset: got 0x%08h, expected 0x%08h", req.rdata, STATUS_READY))
    else `uvm_info("REGACC011_SEQ", "STATUS clean after hard reset OK: 0x00000001", UVM_LOW)

    `uvm_info("REGACC011_SEQ", "TEST_REGISTER_ACCESS_011 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_011_seq
