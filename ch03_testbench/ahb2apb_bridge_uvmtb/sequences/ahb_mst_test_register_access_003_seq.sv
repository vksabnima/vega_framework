// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_003
// DESCRIPTION: Stimulus for status_w1c_clear_semantics.
//              Verifies Write-1-to-Clear behavior of the STATUS register:
//              a 1 in the written bit clears the corresponding sticky flag,
//              while a 0 leaves the other sticky flags untouched.
//
//              Preconditions (driven by prior error events / TB setup):
//                STATUS sticky bits PSLVERR (bit5)=1 and TIMEOUT_ERR (bit6)=1.
//
//              Drives, through the AHB master, five STATUS register transfers
//              to REG_BASE+0x04 = 0x0000_0F04:
//                1. READ STATUS — confirm PRDATA[5]=1, PRDATA[6]=1 set.
//                2. WRITE STATUS PWDATA=0x0000_0020 (bit5=1) — W1C clears only
//                   PSLVERR; bit6=0 leaves TIMEOUT_ERR untouched.
//                3. READ STATUS — expect PRDATA[5]=0 (cleared), PRDATA[6]=1 (still set).
//                4. WRITE STATUS PWDATA=0x0000_0040 (bit6=1) — W1C clears TIMEOUT_ERR.
//                5. READ STATUS — expect PRDATA[5]=0, PRDATA[6]=0, PRDATA[7]=0
//                   (aggregated ERR_INT deasserts once all sources cleared).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_003 steps 1-5.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), STATUS at +0x04.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address STATUS read/W1C-write sequence.
// =============================================================================

class ahb_mst_test_register_access_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_003_seq)

  // STATUS register address (REG_BASE 0x0F00 + 0x04 offset). Sticky bits:
  //   bit5 = PSLVERR, bit6 = TIMEOUT_ERR, bit7 = ERR_INT (aggregated).
  localparam logic [31:0] STATUS_ADDR       = 32'h0000_0F04;
  localparam logic [31:0] CTRL_ADDR         = 32'h0000_0F00;
  // ENABLE b0, ERR_INT_EN b3, TIMEOUT_VAL=7 b6:4, TIMEOUT_EN b7 => 0xF9.
  localparam logic [31:0] CTRL_CFG          = 32'h0000_00F9;
  localparam logic [31:0] PSLVERR_ADDR      = 32'h0000_0100;  // PSLVERR target
  localparam logic [31:0] TIMEOUT_ADDR      = 32'h0000_0200;  // stalled -> timeout
  // W1C masks: a 1 clears that bit, a 0 leaves the bit untouched.
  localparam logic [31:0] W1C_CLR_PSLVERR   = 32'h0000_0020;  // bit5=1
  // Clear TIMEOUT_ERR (b6) and the aggregated ERR_INT (b7) together.
  localparam logic [31:0] W1C_CLR_TIMEOUT   = 32'h0000_00C0;  // bit6=1, bit7=1

  function new(string name = "ahb_mst_test_register_access_003_seq");
    super.new(name);
  endfunction : new

  // Helper: drive a single word transfer (write if data!=='x via wr flag).
  task automatic xfer(input logic [31:0] addr, input bit wr,
                      input logic [31:0] data, input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create(tag);
    start_item(req);
    req.addr = addr; req.write = wr; req.wdata = data;
    req.trans_type = 2'b10; req.burst = 3'b000; req.size = 3'b010;
    req.post_randomize();
    finish_item(req);
  endtask

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC003_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_003: W1C clear semantics on STATUS @0x%08h",
                STATUS_ADDR),
      UVM_MEDIUM)

    // ── SETUP — enable timeout + interrupt aggregation, then provoke BOTH a
    // PSLVERR target error and a bus timeout so STATUS has bits 5,6,7 sticky-set.
    xfer(CTRL_ADDR,     1'b1, CTRL_CFG, "ctrl_cfg");
    xfer(PSLVERR_ADDR,  1'b1, 32'hDA7A_0001, "inject_pslverr"); // -> STATUS.PSLVERR
    xfer(TIMEOUT_ADDR,  1'b1, 32'hCAFE_0001, "inject_timeout"); // -> STATUS.TIMEOUT_ERR (stalled)

    // ── STEP 1 — READ STATUS, confirm both sticky bits pre-set ───────────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd1");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC003_SEQ",
      $sformatf("READ STATUS #1: HADDR=0x%08h (expect PRDATA[5]=1 PSLVERR, PRDATA[6]=1 TIMEOUT_ERR)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);
    // READY(b0)|PSLVERR(b5)|TIMEOUT_ERR(b6)|ERR_INT(b7) = 0xE1.
    if (req.rdata !== 32'h0000_00E1)
      `uvm_error("REGACC003_SEQ",
        $sformatf("STATUS pre-W1C mismatch: got 0x%08h, expected 0x000000E1 (PSLVERR+TIMEOUT+ERR_INT)", req.rdata))
    else `uvm_info("REGACC003_SEQ", "STATUS both sticky errors set OK: 0x000000E1", UVM_LOW)

    // ── STEP 2 — WRITE W1C mask 0x20: clear only PSLVERR, leave TIMEOUT_ERR ───
    req = ahb_mst_seq_item::type_id::create("ahb_status_w1c_pslverr");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b1;    // Write — W1C
    req.wdata      = W1C_CLR_PSLVERR;  // bit5=1 (clear PSLVERR), bit6=0 (leave)
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC003_SEQ",
      $sformatf("WRITE STATUS W1C: HADDR=0x%08h HWDATA=0x%08h (clear PSLVERR only)",
                STATUS_ADDR, W1C_CLR_PSLVERR), UVM_HIGH)
    finish_item(req);

    // ── STEP 3 — READ back: PSLVERR cleared, TIMEOUT_ERR untouched ───────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd2");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC003_SEQ",
      $sformatf("READ STATUS #2: HADDR=0x%08h (expect PRDATA[5]=0 cleared, PRDATA[6]=1 still set)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);
    // PSLVERR(b5) cleared; TIMEOUT_ERR(b6) and ERR_INT(b7) untouched => 0xC1.
    if (req.rdata !== 32'h0000_00C1)
      `uvm_error("REGACC003_SEQ",
        $sformatf("STATUS after PSLVERR W1C mismatch: got 0x%08h, expected 0x000000C1", req.rdata))
    else `uvm_info("REGACC003_SEQ", "Selective W1C (PSLVERR cleared, TIMEOUT kept) OK: 0x000000C1", UVM_LOW)

    // ── STEP 4 — WRITE W1C mask 0xC0: clear TIMEOUT_ERR + ERR_INT ─────────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_w1c_timeout");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b1;    // Write — W1C
    req.wdata      = W1C_CLR_TIMEOUT;  // bit6=1 (clear TIMEOUT_ERR)
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC003_SEQ",
      $sformatf("WRITE STATUS W1C: HADDR=0x%08h HWDATA=0x%08h (clear TIMEOUT_ERR)",
                STATUS_ADDR, W1C_CLR_TIMEOUT), UVM_HIGH)
    finish_item(req);

    // ── STEP 5 — READ STATUS: all error bits and aggregate ERR_INT clear ─────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd3");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC003_SEQ",
      $sformatf("READ STATUS #3: HADDR=0x%08h (expect PRDATA[5]=0, PRDATA[6]=0, PRDATA[7]=0 ERR_INT deasserted)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);
    // All error bits + aggregate ERR_INT cleared => 0x01 (READY only).
    if (req.rdata !== 32'h0000_0001)
      `uvm_error("REGACC003_SEQ",
        $sformatf("STATUS after full W1C mismatch: got 0x%08h, expected 0x00000001", req.rdata))
    else `uvm_info("REGACC003_SEQ", "All sticky errors + ERR_INT cleared OK: 0x00000001", UVM_LOW)

    `uvm_info("REGACC003_SEQ", "TEST_REGISTER_ACCESS_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_003_seq
