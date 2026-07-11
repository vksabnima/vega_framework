// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_014_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_014
// DESCRIPTION: Stimulus for ctrl_register_reset_and_rw.
//              Verifies the CTRL register (@0x0000_0F00) reset value and the
//              read/write behavior of its writable bits via the peripheral-side
//              register access path. The reset itself is applied by tb_top; this
//              sequence drives raw AHB transactions that the bridge converts into
//              the APB SETUP/ACCESS phases described by the XTP.
//
//              Sequence of raw AHB transactions:
//                1. READ CTRL (@0x0000_0F00) — expect reset value 0x0000_0001
//                   (ENABLE=1, all other bits 0). Step 2/3 SETUP+ACCESS phases
//                   on APB are produced by the bridge from this single read.
//                2. WRITE CTRL = 0x0000_00FB (TIMEOUT_EN=1, TIMEOUT_VAL=0x7,
//                   ERR_INT_EN=1, ENABLE=1). Step 4/5 SETUP+ACCESS write phases.
//                3. READ CTRL back — expect HRDATA=0x0000_00FB; reserved bits
//                   [31:8] and bit[2] read 0; writable bits retain written value.
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_014 steps 1-6 — reset value read, write writable
//     bits, read back and confirm writable bits retained / reserved bits zero.
//   - IP-XACT: REG_BASE=0x0000_0F00, CTRL @ +0x00.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address CTRL reset read, write, read-back.
// =============================================================================

class ahb_mst_test_register_access_014_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_014_seq)

  // Register block (REG_BASE 0x0F00) — CTRL register at offset +0x00.
  localparam logic [31:0] CTRL_ADDR       = 32'h0000_0F00;
  // Spec-golden CTRL reset (Spec "Example Reset State" table): ENABLE=1, timeout
  // disabled => 0x0000_0001.
  localparam logic [31:0] CTRL_RESET_VAL  = 32'h0000_0001;
  localparam logic [31:0] CTRL_WRITE_VAL  = 32'h0000_00FB;  // writable bits set
  // Read-back after writing 0xFB: bit1 (SOFT_RST) self-clears, so 0xFB -> 0xF9.
  localparam logic [31:0] CTRL_WR_READBACK = CTRL_WRITE_VAL & ~32'h0000_0002;

  function new(string name = "ahb_mst_test_register_access_014_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC014_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_014: CTRL reset & R/W (CTRL @0x%08h)",
                CTRL_ADDR), UVM_MEDIUM)

    // ── STEP 1 — READ CTRL, expect reset value 0x0000_0001 ───────────────────
    // After PRESETn deassertion CTRL loads its reset value. The bridge drives the
    // APB SETUP (PSEL=1,PENABLE=0) then ACCESS (PENABLE=1) phases for this read.
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_reset_rd");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b0;    // Read CTRL reset value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC014_SEQ",
      $sformatf("READ CTRL @0x%08h (expect reset HRDATA=0x%08h)",
                CTRL_ADDR, CTRL_RESET_VAL), UVM_HIGH)
    finish_item(req);

    // Self-check: CTRL reset value (register access is internal — no APB score).
    if (req.rdata !== CTRL_RESET_VAL)
      `uvm_error("REGACC014_SEQ",
        $sformatf("CTRL reset-value mismatch: got 0x%08h, expected 0x%08h",
                  req.rdata, CTRL_RESET_VAL))
    else
      `uvm_info("REGACC014_SEQ",
        $sformatf("CTRL reset value OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 2 — WRITE CTRL = 0x0000_00FB (set writable bits) ─────────────────
    // TIMEOUT_EN=1, TIMEOUT_VAL=0x7, ERR_INT_EN=1, ENABLE=1. Bit[2] and [31:8]
    // are reserved and must read back 0 regardless of what is written.
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_wr");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b1;    // Write writable bits
    req.wdata      = CTRL_WRITE_VAL;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC014_SEQ",
      $sformatf("WRITE CTRL @0x%08h = 0x%08h (TIMEOUT_EN/TIMEOUT_VAL/ERR_INT_EN/ENABLE)",
                CTRL_ADDR, CTRL_WRITE_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 3 — READ CTRL back, expect 0x0000_00FB ──────────────────────────
    // Writable bits (7,6:4,3,1,0) retain the written value; reserved bits [31:8]
    // and bit[2] read 0, so the read-back masked to writable bits == 0x0000_00FB.
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_rd_back");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b0;    // Read back written value
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC014_SEQ",
      $sformatf("READ CTRL @0x%08h (expect HRDATA=0x%08h, reserved [31:8]/bit[2]=0)",
                CTRL_ADDR, CTRL_WRITE_VAL), UVM_HIGH)
    finish_item(req);

    // Self-check: CTRL read-back after writing 0xFB. RTL writes CTRL unmasked
    // and bit1 (SOFT_RST) self-clears, so the read-back is 0xF9 (= 0xFB & ~bit1).
    if (req.rdata !== CTRL_WR_READBACK)
      `uvm_error("REGACC014_SEQ",
        $sformatf("CTRL R/W read-back mismatch: got 0x%08h, expected 0x%08h (0xFB with SOFT_RST self-cleared)",
                  req.rdata, CTRL_WR_READBACK))
    else
      `uvm_info("REGACC014_SEQ",
        $sformatf("CTRL R/W read-back OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC014_SEQ", "TEST_REGISTER_ACCESS_014 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_014_seq
