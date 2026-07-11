// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_010_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_010
// DESCRIPTION: Stimulus for error_info_context_capture.
//              Verifies ERROR_INFO captures direction/beat/error-class context
//              for a target-side (PSLVERR) error.
//
//              Sequence of raw AHB transactions:
//                1. READ ERROR_INFO (REG_BASE+0x0C = 0x0000_0F0C) — expect the
//                   reset value 0x0000_0000 before any error has occurred.
//                2. READ a valid data address 0x0000_0100 — the passive APB
//                   slave returns PSLVERR for this transfer, so the bridge sees
//                   a target-side error: STATUS.PSLVERR is set and HRESP=1 on
//                   the source side. ERROR_INFO latches the read direction and
//                   the target-error coarse class.
//                3. READ ERROR_INFO again — expect a non-zero value whose
//                   direction field indicates read and whose error-class field
//                   indicates a target error. ERROR_INFO is read-only.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_010 steps 1-6 — ERROR_INFO reset read, target
//     (PSLVERR) error on a source-side read, ERROR_INFO re-read expecting
//     read-direction / target-error-class context.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), ERROR_INFO @ +0x0C.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address register reads plus one error-trigger read.
// =============================================================================

class ahb_mst_test_register_access_010_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_010_seq)

  // ERROR_INFO register (REG_BASE 0x0F00 + 0x0C offset), its reset value, and
  // the valid data address whose target-side read provokes the PSLVERR error.
  localparam logic [31:0] ERROR_INFO_ADDR  = 32'h0000_0F0C;
  localparam logic [31:0] ERROR_INFO_RESET = 32'h0000_0000;
  localparam logic [31:0] TARGET_ERR_ADDR  = 32'h0000_0100;

  function new(string name = "ahb_mst_test_register_access_010_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC010_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_010: ERROR_INFO context capture @0x%08h",
                ERROR_INFO_ADDR), UVM_MEDIUM)

    // ── STEP 1-2 — READ ERROR_INFO, expect reset value 0x0000_0000 ───────────
    req = ahb_mst_seq_item::type_id::create("ahb_errinfo_rd_reset");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read — ERROR_INFO is read-only
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC010_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect reset HRDATA=0x%08h)",
                ERROR_INFO_ADDR, ERROR_INFO_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== ERROR_INFO_RESET)
      `uvm_error("REGACC010_SEQ",
        $sformatf("ERROR_INFO reset mismatch: got 0x%08h, expected 0x%08h", req.rdata, ERROR_INFO_RESET))
    else `uvm_info("REGACC010_SEQ", "ERROR_INFO reset OK: 0x00000000", UVM_LOW)

    // ── STEP 3-4 — READ valid addr 0x0000_0100 (target PSLVERR error) ────────
    // The passive APB slave returns PSLVERR for this transfer; the bridge flags
    // STATUS.PSLVERR, returns HRESP=1 on the source side, and latches the read
    // direction + target-error class into ERROR_INFO.
    req = ahb_mst_seq_item::type_id::create("ahb_target_err_rd");
    start_item(req);
    req.addr       = TARGET_ERR_ADDR;
    req.write      = 1'b0;    // Read transfer — direction captured by ERROR_INFO
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC010_SEQ",
      $sformatf("READ HADDR=0x%08h (expect PSLVERR target error + HRESP=1)",
                TARGET_ERR_ADDR), UVM_HIGH)
    finish_item(req);
    if (req.resp !== 1'b1)
      `uvm_error("REGACC010_SEQ",
        $sformatf("Target (PSLVERR) read should return HRESP=1, got %0b", req.resp))
    else `uvm_info("REGACC010_SEQ", "PSLVERR target read HRESP=1 OK", UVM_LOW)

    // ── STEP 5-6 — READ ERROR_INFO, expect non-zero read/target-error context ─
    req = ahb_mst_seq_item::type_id::create("ahb_errinfo_rd_capture");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read — confirm captured context (read-only)
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC010_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect non-zero: direction=read, class=target-error)",
                ERROR_INFO_ADDR), UVM_HIGH)
    finish_item(req);
    // ERR_TYPE[7:4]=3 (PSLVERR/protocol), ERR_WRITE[3]=0 (read),
    // ERR_SIZE[2:0]=2 (word) => 0x0000_0032.
    if (req.rdata !== 32'h0000_0032)
      `uvm_error("REGACC010_SEQ",
        $sformatf("ERROR_INFO context mismatch: got 0x%08h, expected 0x00000032 (pslverr,read,word)", req.rdata))
    else `uvm_info("REGACC010_SEQ", $sformatf("ERROR_INFO target-error context OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC010_SEQ", "TEST_REGISTER_ACCESS_010 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_010_seq
