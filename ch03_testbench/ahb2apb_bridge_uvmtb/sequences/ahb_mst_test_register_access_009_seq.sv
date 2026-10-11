// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_009_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_009
// DESCRIPTION: Stimulus for error_addr_capture_on_addr_error.
//              Verifies ERROR_ADDR captures the source-side address of an
//              address-error transaction.
//
//              Sequence of raw AHB transactions:
//                1. READ ERROR_ADDR (REG_BASE+0x08 = 0x0000_0F08) — expect the
//                   reset value 0x0000_0000 before any error has occurred.
//                2. WRITE to an invalid source-side address 0xDEAD_BEEF — this
//                   triggers the ADDR_ERR scenario; STATUS.ADDR_ERR is set and
//                   the bridge captures the offending address into ERROR_ADDR.
//                3. READ ERROR_ADDR again — expect 0xDEAD_BEEF (the most recent
//                   errored address). ERROR_ADDR is read-only.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_009 steps 1-6 — ERROR_ADDR reset read, invalid
//     transfer to 0xDEAD_BEEF, ERROR_ADDR re-read expecting 0xDEAD_BEEF.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), ERROR_ADDR @ +0x08.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address register reads plus one error-trigger write.
// =============================================================================

class ahb_mst_test_register_access_009_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_009_seq)

  // ERROR_ADDR register (REG_BASE 0x0F00 + 0x08 offset), its reset value, and
  // the invalid source-side address used to provoke the ADDR_ERR capture.
  localparam logic [31:0] ERROR_ADDR_ADDR  = 32'h0000_0F08;
  localparam logic [31:0] ERROR_ADDR_RESET = 32'h0000_0000;
  localparam logic [31:0] INVALID_ADDR     = 32'hDEAD_BEEF;
  localparam logic [31:0] INVALID_WDATA    = 32'h1234_5678;

  function new(string name = "ahb_mst_test_register_access_009_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC009_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_009: ERROR_ADDR capture @0x%08h",
                ERROR_ADDR_ADDR), UVM_MEDIUM)

    // ── STEP 1-2 — READ ERROR_ADDR, expect reset value 0x0000_0000 ───────────
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_rd_reset");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read — ERROR_ADDR is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC009_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect reset HRDATA=0x%08h)",
                ERROR_ADDR_ADDR, ERROR_ADDR_RESET), UVM_HIGH)
    finish_item(req);

    // Self-check: ERROR_ADDR reset value (internal register read).
    if (req.rdata !== ERROR_ADDR_RESET)
      `uvm_error("REGACC009_SEQ",
        $sformatf("ERROR_ADDR reset mismatch: got 0x%08h, expected 0x%08h",
                  req.rdata, ERROR_ADDR_RESET))
    else
      `uvm_info("REGACC009_SEQ",
        $sformatf("ERROR_ADDR reset OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 3-4 — WRITE to invalid address 0xDEAD_BEEF (triggers ADDR_ERR) ──
    // The bridge flags STATUS.ADDR_ERR, returns an error response on the source
    // side, and latches the offending address into ERROR_ADDR.
    req = ahb_mst_seq_item::type_id::create("ahb_invalid_wr");
    start_item(req);
    req.addr       = INVALID_ADDR;
    req.write      = 1'b1;    // Write transfer to invalid address
    req.wdata      = INVALID_WDATA;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC009_SEQ",
      $sformatf("WRITE invalid HADDR=0x%08h HWDATA=0x%08h (expect ADDR_ERR + HRESP=1)",
                INVALID_ADDR, INVALID_WDATA), UVM_HIGH)
    finish_item(req);

    // Self-check: an out-of-range address is a decode error — the bridge must
    // return HRESP=ERROR(1) (this path is DUT-internal, no APB/PSLVERR needed).
    if (req.resp !== 1'b1)
      `uvm_error("REGACC009_SEQ",
        $sformatf("Invalid-address write should return HRESP=1, got %0b", req.resp))
    else
      `uvm_info("REGACC009_SEQ", "Decode error HRESP=1 OK", UVM_LOW)

    // ── STEP 5-6 — READ ERROR_ADDR, expect captured 0xDEAD_BEEF ──────────────
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_rd_capture");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read — confirm captured address (read-only)
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC009_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect captured HRDATA=0x%08h)",
                ERROR_ADDR_ADDR, INVALID_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check: ERROR_ADDR must have captured the offending address.
    if (req.rdata !== INVALID_ADDR)
      `uvm_error("REGACC009_SEQ",
        $sformatf("ERROR_ADDR capture mismatch: got 0x%08h, expected 0x%08h",
                  req.rdata, INVALID_ADDR))
    else
      `uvm_info("REGACC009_SEQ",
        $sformatf("ERROR_ADDR capture OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC009_SEQ", "TEST_REGISTER_ACCESS_009 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_009_seq
