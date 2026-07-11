// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_016_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_016
// DESCRIPTION: Stimulus for error_addr_error_info_readonly.
//              Verifies the read-only debug registers ERROR_ADDR (@0x0000_0F08)
//              and ERROR_INFO (@0x0000_0F0C): they reset to 0, capture the error
//              context when an ADDR_ERR event occurs, and reject write attempts
//              (RO). The reset itself is applied by tb_top; this sequence drives
//              raw AHB transactions that the bridge converts into the APB
//              SETUP/ACCESS phases described by the XTP.
//
//              Sequence of raw AHB transactions:
//                1. READ ERROR_ADDR (@0x0000_0F08) — expect reset 0x0000_0000.
//                2. READ ERROR_INFO (@0x0000_0F0C) — expect reset 0x0000_0000.
//                3. WRITE to invalid address (HADDR=0x0000_ABCD) — triggers an
//                   ADDR_ERR event; the model captures the error context into the
//                   debug registers.
//                4. READ ERROR_ADDR (@0x0000_0F08) — expect captured 0x0000_ABCD.
//                5. READ ERROR_INFO (@0x0000_0F0C) — expect non-zero context
//                   (encodes write direction, beat index, ADDR_ERR coarse class).
//                6. WRITE ERROR_ADDR (@0x0000_0F08) = 0xDEADBEEF — RO, ignored.
//                7. READ ERROR_ADDR (@0x0000_0F08) — expect still 0x0000_ABCD
//                   (write had no effect; value unchanged).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_016 steps 1-6 — RO debug-register reset value,
//     error-context capture on ADDR_ERR, and RO write-ignore read-back.
//   - IP-XACT: REG_BASE=0x0000_0F00, ERROR_ADDR @ +0x08, ERROR_INFO @ +0x0C.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address RO-register reset read, error capture,
//             RO write-ignore read-back.
// =============================================================================

class ahb_mst_test_register_access_016_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_016_seq)

  // Register block (REG_BASE 0x0F00) — RO debug registers.
  localparam logic [31:0] ERROR_ADDR_ADDR  = 32'h0000_0F08;  // ERROR_ADDR @ +0x08
  localparam logic [31:0] ERROR_INFO_ADDR  = 32'h0000_0F0C;  // ERROR_INFO @ +0x0C
  localparam logic [31:0] INVALID_ADDR     = 32'h0000_ABCD;  // out-of-range -> ADDR_ERR
  localparam logic [31:0] RO_WRITE_VAL      = 32'hDEAD_BEEF;  // attempted RO write
  localparam logic [31:0] RESET_VAL         = 32'h0000_0000;  // RO reset value

  function new(string name = "ahb_mst_test_register_access_016_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC016_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_016: ERROR_ADDR/ERROR_INFO RO (ERROR_ADDR @0x%08h, ERROR_INFO @0x%08h)",
                ERROR_ADDR_ADDR, ERROR_INFO_ADDR), UVM_MEDIUM)

    // ── STEP 1 — READ ERROR_ADDR, expect reset 0x0000_0000 ───────────────────
    // After PRESETn deassertion the RO debug registers load 0. The bridge drives
    // the APB SETUP (PSEL=1,PENABLE=0) then ACCESS (PENABLE=1) phases for this
    // read; PRDATA sampled on PREADY=1.
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_reset_rd");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read ERROR_ADDR reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect reset HRDATA=0x%08h)",
                ERROR_ADDR_ADDR, RESET_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 2 — READ ERROR_INFO, expect reset 0x0000_0000 ───────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_errinfo_reset_rd");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read ERROR_INFO reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect reset HRDATA=0x%08h)",
                ERROR_INFO_ADDR, RESET_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 3 — WRITE to invalid address — trigger ADDR_ERR event ───────────
    // A write transfer to an out-of-range address (0x0000_ABCD) produces an
    // ADDR_ERR event. The model captures the error context (address, direction,
    // beat index, coarse class) into the RO debug registers.
    req = ahb_mst_seq_item::type_id::create("ahb_invalid_wr");
    start_item(req);
    req.addr       = INVALID_ADDR;
    req.write      = 1'b1;    // write transfer to invalid address
    req.wdata      = 32'h0;   // payload irrelevant — the address triggers ADDR_ERR
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("WRITE invalid @0x%08h (expect ADDR_ERR; model captures error context)",
                INVALID_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 4 — READ ERROR_ADDR, expect captured 0x0000_ABCD ────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_captured_rd");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read captured error address
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect captured HRDATA=0x%08h)",
                ERROR_ADDR_ADDR, INVALID_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 5 — READ ERROR_INFO, expect non-zero error context ──────────────
    // ERROR_INFO encodes write direction, beat index, and the ADDR_ERR coarse
    // class — a non-zero context value after the error event.
    req = ahb_mst_seq_item::type_id::create("ahb_errinfo_captured_rd");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read captured error context
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect non-zero context: dir/beat/ADDR_ERR class)",
                ERROR_INFO_ADDR), UVM_HIGH)
    finish_item(req);

    // ── STEP 6 — WRITE ERROR_ADDR = 0xDEADBEEF — RO, must be ignored ──────────
    // Attempt to write the read-only ERROR_ADDR register. The bridge emits the
    // APB SETUP then ACCESS write phases, but the RO register ignores the value.
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_ro_wr");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b1;    // attempt write to RO register
    req.wdata      = RO_WRITE_VAL;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("WRITE ERROR_ADDR @0x%08h = 0x%08h (RO — must be ignored)",
                ERROR_ADDR_ADDR, RO_WRITE_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 7 — READ ERROR_ADDR back, expect unchanged 0x0000_ABCD ──────────
    // The RO write had no effect: the captured error address is unchanged.
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_rd_final");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Re-read after RO write attempt
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC016_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect unchanged HRDATA=0x%08h — RO write ignored)",
                ERROR_ADDR_ADDR, INVALID_ADDR), UVM_HIGH)
    finish_item(req);

    // ── Pass criteria evaluated by the scoreboard / checker. ─────────────────
    // 1) ERROR_ADDR/ERROR_INFO reset == 0x0000_0000, 2) ERROR_ADDR captures
    // 0x0000_ABCD on the ADDR_ERR event, 3) ERROR_INFO captures non-zero coarse
    // context, 4) writing the RO ERROR_ADDR has no effect (read-back unchanged).
    `uvm_info("REGACC016_SEQ", "TEST_REGISTER_ACCESS_016 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_016_seq
