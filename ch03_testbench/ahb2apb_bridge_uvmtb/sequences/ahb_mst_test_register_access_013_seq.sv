// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_013_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_013
// DESCRIPTION: Stimulus for error_addr_overwrite_most_recent.
//              Verifies that a subsequent error overwrites the previously
//              captured ERROR_ADDR — the captured debug register always
//              reflects the most recent error event.
//
//              Sequence of raw AHB transactions:
//                1. Generate a FIRST error: write to invalid HADDR=0x1111_0000
//                   so the bridge captures ERROR_ADDR=0x1111_0000 (STATUS.ADDR_ERR=1,
//                   HRESP=ERROR).
//                2. READ ERROR_ADDR (@0x0000_0F08) — expect HRDATA=0x1111_0000.
//                3. Generate a SECOND error: write to invalid HADDR=0x2222_0000
//                   so ERROR_ADDR is re-captured = 0x2222_0000 (ADDR_ERR re-asserted,
//                   HRESP=ERROR).
//                4. READ ERROR_ADDR (@0x0000_0F08) again — expect HRDATA=0x2222_0000
//                   (overwritten with the most recent error address).
//                5. Compare confirms the value changed from 0x1111_0000 to
//                   0x2222_0000, proving most-recent capture; ADDR_ERR stays sticky.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_013 steps 1-5 — induce two errors and read
//     ERROR_ADDR between/after each to prove most-recent overwrite.
//   - IP-XACT: REG_BASE=0x0000_0F00, ERROR_ADDR @ +0x08.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — two fixed-address error captures with read-back between.
// =============================================================================

class ahb_mst_test_register_access_013_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_013_seq)

  // Register block (REG_BASE 0x0F00) offset and the two invalid error addresses.
  localparam logic [31:0] ERROR_ADDR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] FIRST_ERR_ADDR  = 32'h1111_0000;  // first invalid target
  localparam logic [31:0] SECOND_ERR_ADDR = 32'h2222_0000;  // second invalid target

  function new(string name = "ahb_mst_test_register_access_013_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC013_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_013: ERROR_ADDR overwrite most-recent (ERROR_ADDR @0x%08h)",
                ERROR_ADDR_ADDR), UVM_MEDIUM)

    // ── STEP 1 — generate FIRST error at invalid HADDR=0x1111_0000 ────────────
    // The invalid target makes the bridge capture ERROR_ADDR=0x1111_0000 and
    // raise STATUS.ADDR_ERR=1 with HRESP=ERROR.
    req = ahb_mst_seq_item::type_id::create("ahb_first_error");
    start_item(req);
    req.addr       = FIRST_ERR_ADDR;
    req.write      = 1'b1;    // Write to invalid address provokes error capture
    req.wdata      = 32'hDEAD_BEEF;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC013_SEQ",
      $sformatf("WRITE invalid HADDR=0x%08h (expect ERROR_ADDR capture + STATUS.ADDR_ERR=1, HRESP=1)",
                FIRST_ERR_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 2 — READ ERROR_ADDR, expect captured 0x1111_0000 ────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_error_addr_rd1");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read — ERROR_ADDR is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC013_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect HRDATA=0x%08h)",
                ERROR_ADDR_ADDR, FIRST_ERR_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check: ERROR_ADDR captured the first offending address.
    if (req.rdata !== FIRST_ERR_ADDR)
      `uvm_error("REGACC013_SEQ",
        $sformatf("ERROR_ADDR (first) mismatch: got 0x%08h, expected 0x%08h",
                  req.rdata, FIRST_ERR_ADDR))
    else
      `uvm_info("REGACC013_SEQ",
        $sformatf("ERROR_ADDR first-capture OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 3 — generate SECOND error at invalid HADDR=0x2222_0000 ──────────
    // ERROR_ADDR must be overwritten to 0x2222_0000; ADDR_ERR re-asserted.
    req = ahb_mst_seq_item::type_id::create("ahb_second_error");
    start_item(req);
    req.addr       = SECOND_ERR_ADDR;
    req.write      = 1'b1;    // Write to invalid address provokes new error capture
    req.wdata      = 32'hCAFE_F00D;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC013_SEQ",
      $sformatf("WRITE invalid HADDR=0x%08h (expect ERROR_ADDR overwrite + STATUS.ADDR_ERR re-asserted, HRESP=1)",
                SECOND_ERR_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 4 — READ ERROR_ADDR again, expect overwritten 0x2222_0000 ───────
    req = ahb_mst_seq_item::type_id::create("ahb_error_addr_rd2");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read — ERROR_ADDR is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC013_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect HRDATA=0x%08h, overwritten with most recent)",
                ERROR_ADDR_ADDR, SECOND_ERR_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check: per spec, ERROR_ADDR captures the MOST RECENT error event, so
    // after the second error it is overwritten to 0x2222_0000.
    if (req.rdata !== SECOND_ERR_ADDR)
      `uvm_error("REGACC013_SEQ",
        $sformatf("ERROR_ADDR (after 2nd error) mismatch: got 0x%08h, expected 0x%08h (most-recent capture)",
                  req.rdata, SECOND_ERR_ADDR))
    else
      `uvm_info("REGACC013_SEQ",
        $sformatf("ERROR_ADDR most-recent overwrite OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC013_SEQ", "TEST_REGISTER_ACCESS_013 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_013_seq
