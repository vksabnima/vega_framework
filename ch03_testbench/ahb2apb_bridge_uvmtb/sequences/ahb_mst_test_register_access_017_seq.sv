// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_017_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_017
// DESCRIPTION: Stimulus for register_map_offset_decode.
//              Verifies that each defined register offset decodes to the correct
//              register and that the 4-byte stride mapping is correct. The bridge
//              converts each raw AHB transfer into the APB SETUP/ACCESS phases;
//              PRDATA is sampled on PREADY=1.
//
//              Sequence of raw AHB transactions:
//                1. READ CTRL       (@0x0000_0F00) — expect reset 0x0000_0001.
//                2. READ STATUS     (@0x0000_0F04) — expect reset 0x0000_0001.
//                3. READ ERROR_ADDR (@0x0000_0F08) — expect reset 0x0000_0000.
//                4. READ ERROR_INFO (@0x0000_0F0C) — expect reset 0x0000_0000.
//                5. WRITE CTRL      (@0x0000_0F00) = 0x0000_0080.
//                6. READ STATUS     (@0x0000_0F04) — expect unchanged (no aliasing).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_017 steps 1-5 — per-offset decode of the register
//     map, 4-byte stride, and offset isolation (writing CTRL must not alias
//     STATUS).
//   - IP-XACT: REG_BASE=0x0000_0F00, CTRL @ +0x00, STATUS @ +0x04,
//     ERROR_ADDR @ +0x08, ERROR_INFO @ +0x0C.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address per-offset reset reads plus a write/read
//             offset-isolation check.
// =============================================================================

class ahb_mst_test_register_access_017_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_017_seq)

  // Register block (REG_BASE 0x0F00) — 4-byte stride.
  localparam logic [31:0] CTRL_ADDR        = 32'h0000_0F00;  // CTRL       @ +0x00
  localparam logic [31:0] STATUS_ADDR      = 32'h0000_0F04;  // STATUS     @ +0x04
  localparam logic [31:0] ERROR_ADDR_ADDR  = 32'h0000_0F08;  // ERROR_ADDR @ +0x08
  localparam logic [31:0] ERROR_INFO_ADDR  = 32'h0000_0F0C;  // ERROR_INFO @ +0x0C

  // Expected reset values per Table 4.
  localparam logic [31:0] CTRL_RESET        = 32'h0000_0001;  // CTRL reset (spec: ENABLE=1, timeout disabled)
  localparam logic [31:0] STATUS_RESET      = 32'h0000_0001;  // STATUS reset (READY=1)
  localparam logic [31:0] ERROR_ADDR_RESET  = 32'h0000_0000;  // ERROR_ADDR reset
  localparam logic [31:0] ERROR_INFO_RESET  = 32'h0000_0000;  // ERROR_INFO reset

  localparam logic [31:0] CTRL_WRITE_VAL    = 32'h0000_0080;  // CTRL write payload

  function new(string name = "ahb_mst_test_register_access_017_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC017_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_017: offset decode (CTRL @0x%08h, STATUS @0x%08h, ERROR_ADDR @0x%08h, ERROR_INFO @0x%08h)",
                CTRL_ADDR, STATUS_ADDR, ERROR_ADDR_ADDR, ERROR_INFO_ADDR), UVM_MEDIUM)

    // ── STEP 1 — READ CTRL @0xF00, expect reset 0x0000_0001 ───────────────────
    // Confirms offset 0xF00 decodes to CTRL. The bridge drives the APB SETUP
    // (PSEL=1,PENABLE=0) then ACCESS (PENABLE=1) phases; PRDATA on PREADY=1.
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_rd");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b0;    // Read CTRL reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC017_SEQ",
      $sformatf("READ CTRL @0x%08h (expect HRDATA=0x%08h — 0xF00 decodes to CTRL)",
                CTRL_ADDR, CTRL_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== CTRL_RESET)
      `uvm_error("REGACC017_SEQ", $sformatf("0xF00 (CTRL) decode/reset mismatch: got 0x%08h, expected 0x%08h", req.rdata, CTRL_RESET))
    else `uvm_info("REGACC017_SEQ", $sformatf("CTRL @0xF00 OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 2 — READ STATUS @0xF04, expect reset 0x0000_0001 ─────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read STATUS reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC017_SEQ",
      $sformatf("READ STATUS @0x%08h (expect HRDATA=0x%08h — 0xF04 decodes to STATUS, READY=1)",
                STATUS_ADDR, STATUS_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== STATUS_RESET)
      `uvm_error("REGACC017_SEQ", $sformatf("0xF04 (STATUS) decode/reset mismatch: got 0x%08h, expected 0x%08h", req.rdata, STATUS_RESET))
    else `uvm_info("REGACC017_SEQ", $sformatf("STATUS @0xF04 OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 3 — READ ERROR_ADDR @0xF08, expect reset 0x0000_0000 ─────────────
    req = ahb_mst_seq_item::type_id::create("ahb_erraddr_rd");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR;
    req.write      = 1'b0;    // Read ERROR_ADDR reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC017_SEQ",
      $sformatf("READ ERROR_ADDR @0x%08h (expect HRDATA=0x%08h — 0xF08 decodes to ERROR_ADDR)",
                ERROR_ADDR_ADDR, ERROR_ADDR_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== ERROR_ADDR_RESET)
      `uvm_error("REGACC017_SEQ", $sformatf("0xF08 (ERROR_ADDR) decode/reset mismatch: got 0x%08h, expected 0x%08h", req.rdata, ERROR_ADDR_RESET))
    else `uvm_info("REGACC017_SEQ", $sformatf("ERROR_ADDR @0xF08 OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 4 — READ ERROR_INFO @0xF0C, expect reset 0x0000_0000 ─────────────
    req = ahb_mst_seq_item::type_id::create("ahb_errinfo_rd");
    start_item(req);
    req.addr       = ERROR_INFO_ADDR;
    req.write      = 1'b0;    // Read ERROR_INFO reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC017_SEQ",
      $sformatf("READ ERROR_INFO @0x%08h (expect HRDATA=0x%08h — 0xF0C decodes to ERROR_INFO)",
                ERROR_INFO_ADDR, ERROR_INFO_RESET), UVM_HIGH)
    finish_item(req);
    if (req.rdata !== ERROR_INFO_RESET)
      `uvm_error("REGACC017_SEQ", $sformatf("0xF0C (ERROR_INFO) decode/reset mismatch: got 0x%08h, expected 0x%08h", req.rdata, ERROR_INFO_RESET))
    else `uvm_info("REGACC017_SEQ", $sformatf("ERROR_INFO @0xF0C OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 5a — WRITE CTRL @0xF00 = 0x0000_0080 ─────────────────────────────
    // Write only the CTRL register; the APB SETUP then ACCESS write phases are
    // emitted by the bridge (PENABLE=1/PREADY=1 completion).
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_wr");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b1;    // Write CTRL
    req.wdata      = CTRL_WRITE_VAL;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC017_SEQ",
      $sformatf("WRITE CTRL @0x%08h = 0x%08h (CTRL only — must not alias STATUS)",
                CTRL_ADDR, CTRL_WRITE_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 5b — READ STATUS @0xF04, expect unchanged (no aliasing) ──────────
    // The CTRL write must not affect STATUS: offset isolation. STATUS read-back
    // stays at its reset/unaffected value, proving no address aliasing.
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd_final");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Re-read STATUS after CTRL write
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC017_SEQ",
      $sformatf("READ STATUS @0x%08h (expect unchanged HRDATA=0x%08h — no CTRL->STATUS aliasing)",
                STATUS_ADDR, STATUS_RESET), UVM_HIGH)
    finish_item(req);
    // Offset isolation: writing CTRL must not alias STATUS.
    if (req.rdata !== STATUS_RESET)
      `uvm_error("REGACC017_SEQ", $sformatf("STATUS aliased by CTRL write: got 0x%08h, expected unchanged 0x%08h", req.rdata, STATUS_RESET))
    else `uvm_info("REGACC017_SEQ", $sformatf("Offset isolation OK: STATUS still 0x%08h after CTRL write", req.rdata), UVM_LOW)

    // ── Pass criteria evaluated by the scoreboard / checker. ─────────────────
    // 1) Each offset 0xF00/0xF04/0xF08/0xF0C returns the correct register's reset
    // value, 2) access type per offset matches Table 4, 3) writing CTRL does not
    // alter STATUS (no address aliasing — offset isolation).
    `uvm_info("REGACC017_SEQ", "TEST_REGISTER_ACCESS_017 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_017_seq
